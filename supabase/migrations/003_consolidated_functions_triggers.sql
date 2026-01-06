-- =============================================
-- Consolidated Functions, Triggers, and Procedures
-- Consolidates migrations 016, 017, 019-023
-- =============================================

-- =============================================
-- PLAYER STATISTICS TRIGGER & FUNCTIONS
-- =============================================

-- Update player statistics when game completes
CREATE OR REPLACE FUNCTION update_player_statistics()
RETURNS TRIGGER AS $$
BEGIN
  -- Update statistics when game is completed
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    -- Update statistics for all participants
    INSERT INTO player_statistics (
      user_id, 
      group_id, 
      games_played, 
      total_buyin, 
      total_cashout, 
      net_profit, 
      biggest_win, 
      biggest_loss
    )
    SELECT 
      gp.user_id,
      g.group_id,
      1,
      gp.total_buyin,
      gp.total_cashout,
      gp.net_result,
      CASE WHEN gp.net_result > 0 THEN gp.net_result ELSE 0 END,
      CASE WHEN gp.net_result < 0 THEN gp.net_result ELSE 0 END
    FROM game_participants gp
    JOIN games g ON g.id = gp.game_id
    WHERE gp.game_id = NEW.id
    ON CONFLICT (user_id, group_id) DO UPDATE SET
      games_played = player_statistics.games_played + 1,
      total_buyin = player_statistics.total_buyin + EXCLUDED.total_buyin,
      total_cashout = player_statistics.total_cashout + EXCLUDED.total_cashout,
      net_profit = player_statistics.net_profit + EXCLUDED.net_profit,
      biggest_win = GREATEST(player_statistics.biggest_win, EXCLUDED.biggest_win),
      biggest_loss = LEAST(player_statistics.biggest_loss, EXCLUDED.biggest_loss),
      updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER update_stats_on_game_complete
  AFTER UPDATE ON games
  FOR EACH ROW
  EXECUTE FUNCTION update_player_statistics();

-- =============================================
-- SETTLEMENT CALCULATION FUNCTION
-- Atomic settlement calculation with validation
-- =============================================

CREATE OR REPLACE FUNCTION calculate_settlement_atomic(p_game_id UUID)
RETURNS TABLE (
  settlement_id UUID,
  payer_id UUID,
  payee_id UUID,
  amount DECIMAL(10, 2),
  status TEXT,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_game_status TEXT;
  v_total_buyin DECIMAL(10, 2);
  v_total_cashout DECIMAL(10, 2);
  v_difference DECIMAL(10, 2);
  v_tolerance DECIMAL(10, 2) := 0.01;
  v_group_id UUID;
  v_participant RECORD;
  v_creditor RECORD;
  v_debtor RECORD;
  v_transfer_amount DECIMAL(10, 2);
  v_settlement_id UUID;
BEGIN
  -- Lock the game row to prevent concurrent modifications
  SELECT status, group_id INTO v_game_status, v_group_id
  FROM games
  WHERE id = p_game_id
  FOR UPDATE;

  -- Verify game exists
  IF v_game_status IS NULL THEN
    RAISE EXCEPTION 'Game % not found', p_game_id;
  END IF;

  -- Verify game is completed
  IF v_game_status != 'completed' THEN
    RAISE EXCEPTION 'Cannot calculate settlements for % game', v_game_status;
  END IF;

  -- Return existing settlements if they exist (idempotent)
  IF EXISTS (
    SELECT 1 FROM settlements 
    WHERE game_id = p_game_id 
    LIMIT 1
  ) THEN
    RETURN QUERY
    SELECT 
      s.id,
      s.from_user_id,
      s.to_user_id,
      s.amount,
      s.status,
      s.created_at
    FROM settlements s
    WHERE s.game_id = p_game_id
    ORDER BY s.created_at;
    RETURN;
  END IF;

  -- Lock all game_participants rows
  PERFORM 1 FROM game_participants
  WHERE game_id = p_game_id
  FOR UPDATE;

  -- Calculate totals from locked data
  SELECT 
    COALESCE(SUM(total_buyin), 0),
    COALESCE(SUM(total_cashout), 0)
  INTO v_total_buyin, v_total_cashout
  FROM game_participants
  WHERE game_id = p_game_id;

  -- Validate financial consistency
  v_difference := v_total_buyin - v_total_cashout;
  
  IF ABS(v_difference) > v_tolerance THEN
    RAISE EXCEPTION 'Financial mismatch: Buy-in $% vs Cash-out $%. Difference: $%',
      v_total_buyin, v_total_cashout, v_difference;
  END IF;

  -- Create temporary table for settlement calculation
  CREATE TEMP TABLE temp_net_positions AS
  SELECT 
    user_id,
    net_result
  FROM game_participants
  WHERE game_id = p_game_id
  ORDER BY net_result;

  -- Process settlements using greedy algorithm
  FOR v_debtor IN 
    SELECT user_id, net_result 
    FROM temp_net_positions
    WHERE net_result < 0 
    ORDER BY net_result ASC
  LOOP
    FOR v_creditor IN 
      SELECT user_id, net_result 
      FROM temp_net_positions
      WHERE net_result > 0 
      ORDER BY net_result DESC
    LOOP
      IF v_debtor.net_result >= 0 THEN
        EXIT;
      END IF;

      v_transfer_amount := LEAST(ABS(v_debtor.net_result), v_creditor.net_result);
      
      IF v_transfer_amount > 0 THEN
        -- Create settlement record
        INSERT INTO settlements (
          game_id,
          from_user_id,
          to_user_id,
          amount,
          status
        ) VALUES (
          p_game_id,
          v_debtor.user_id,
          v_creditor.user_id,
          v_transfer_amount,
          'pending'
        )
        RETURNING id INTO v_settlement_id;

        -- Update temporary balances
        UPDATE temp_net_positions 
        SET net_result = net_result + v_transfer_amount 
        WHERE user_id = v_debtor.user_id;
        
        UPDATE temp_net_positions 
        SET net_result = net_result - v_transfer_amount 
        WHERE user_id = v_creditor.user_id;

        -- Yield the settlement
        RETURN QUERY
        SELECT 
          v_settlement_id,
          v_debtor.user_id,
          v_creditor.user_id,
          v_transfer_amount,
          'pending'::TEXT,
          NOW()::TIMESTAMPTZ;
      END IF;
    END LOOP;
  END LOOP;

  DROP TABLE temp_net_positions;
  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================
-- SETTLEMENT HELPER FUNCTION
-- Idempotent settlement retrieval/calculation
-- =============================================

CREATE OR REPLACE FUNCTION get_or_calculate_settlements(p_game_id UUID)
RETURNS TABLE (
  settlement_id UUID,
  payer_id UUID,
  payee_id UUID,
  amount DECIMAL(10, 2),
  status TEXT
) AS $$
BEGIN
  -- Try to return existing settlements first
  RETURN QUERY
  SELECT 
    s.id,
    s.from_user_id,
    s.to_user_id,
    s.amount,
    s.status
  FROM settlements s
  WHERE s.game_id = p_game_id
  ORDER BY s.created_at;

  -- If no settlements exist, calculate them atomically
  IF NOT FOUND THEN
    RETURN QUERY
    SELECT 
      c.settlement_id,
      c.payer_id,
      c.payee_id,
      c.amount,
      c.status
    FROM calculate_settlement_atomic(p_game_id) c;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================
-- SETTLEMENT RECORDING PROCEDURE
-- Record or update a settlement with idempotency
-- =============================================

CREATE OR REPLACE FUNCTION public.record_settlement(
  p_game_id UUID,
  p_from_user_id UUID,
  p_to_user_id UUID,
  p_amount DECIMAL,
  p_payment_method VARCHAR DEFAULT 'cash'
)
RETURNS TABLE(
  id UUID,
  game_id UUID,
  from_user_id UUID,
  to_user_id UUID,
  amount DECIMAL,
  payment_method VARCHAR,
  status TEXT,
  settled_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  INSERT INTO public.settlements (
    game_id,
    from_user_id,
    to_user_id,
    amount,
    payment_method,
    status
  )
  VALUES (
    p_game_id,
    p_from_user_id,
    p_to_user_id,
    p_amount,
    COALESCE(p_payment_method, 'cash')
  )
  ON CONFLICT (game_id, from_user_id, to_user_id) DO UPDATE
  SET 
    amount = p_amount,
    payment_method = COALESCE(p_payment_method, 'cash'),
    settled_at = CURRENT_TIMESTAMP
  RETURNING 
    settlements.id,
    settlements.game_id,
    settlements.from_user_id,
    settlements.to_user_id,
    settlements.amount,
    settlements.payment_method,
    settlements.status,
    settlements.settled_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.record_settlement TO authenticated;

-- =============================================
-- FINANCIAL VALIDATION CONSTRAINT FUNCTION
-- Ensures data integrity during transactions
-- =============================================

CREATE OR REPLACE FUNCTION validate_game_financial_integrity()
RETURNS TRIGGER AS $$
DECLARE
  v_total_buyin DECIMAL(10, 2);
  v_total_cashout DECIMAL(10, 2);
  v_difference DECIMAL(10, 2);
  v_tolerance DECIMAL(10, 2) := 0.01;
BEGIN
  -- Calculate totals
  SELECT 
    COALESCE(SUM(total_buyin), 0),
    COALESCE(SUM(total_cashout), 0)
  INTO v_total_buyin, v_total_cashout
  FROM game_participants
  WHERE game_id = NEW.game_id;

  -- Check financial balance
  v_difference := v_total_buyin - v_total_cashout;
  
  IF ABS(v_difference) > v_tolerance THEN
    RAISE EXCEPTION 'Transaction violates financial integrity: Buy-in $% vs Cash-out $%',
      v_total_buyin, v_total_cashout;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_transaction_integrity
  BEFORE INSERT OR UPDATE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION validate_game_financial_integrity();

-- =============================================
-- LOCAL USER SUPPORT FUNCTIONS
-- Handle local users without auth FK
-- =============================================

-- Allow creating local user profiles without auth.users entry
-- Local users have is_local_user = TRUE and are accessed via group permissions

-- Function to create local user within a group
CREATE OR REPLACE FUNCTION create_local_user(
  p_email TEXT,
  p_first_name TEXT,
  p_last_name TEXT,
  p_group_id UUID,
  p_created_by UUID
)
RETURNS UUID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Create a pseudo-UUID based on email for consistency
  v_user_id := gen_random_uuid();
  
  -- Insert local profile
  INSERT INTO profiles (
    id,
    email,
    first_name,
    last_name,
    country,
    is_local_user,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    p_email,
    p_first_name,
    p_last_name,
    'United States',
    TRUE,
    NOW(),
    NOW()
  )
  ON CONFLICT (email) DO UPDATE
  SET is_local_user = TRUE
  RETURNING id INTO v_user_id;

  -- Add to group if specified
  IF p_group_id IS NOT NULL THEN
    INSERT INTO group_members (
      group_id,
      user_id,
      role,
      joined_at
    ) VALUES (
      p_group_id,
      v_user_id,
      'member',
      NOW()
    )
    ON CONFLICT (group_id, user_id) DO NOTHING;
  END IF;

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.create_local_user TO authenticated;

-- =============================================
-- LEGACY SETTLEMENT FUNCTION (deprecated)
-- Kept for backward compatibility
-- =============================================

CREATE OR REPLACE FUNCTION calculate_settlement(game_uuid UUID)
RETURNS TABLE(payer UUID, payee UUID, amount DECIMAL) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.payer_id,
    c.payee_id,
    c.amount
  FROM calculate_settlement_atomic(game_uuid) c;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
