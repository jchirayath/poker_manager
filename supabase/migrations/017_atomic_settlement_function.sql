-- Migration: Add atomic settlement calculation function
-- Purpose: Prevent race conditions during settlement calculation
-- Date: January 4, 2026

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
    AND deleted_at IS NULL
    LIMIT 1
  ) THEN
    RETURN QUERY
    SELECT 
      s.id,
      s.payer_id,
      s.payee_id,
      s.amount,
      s.status,
      s.created_at
    FROM settlements s
    WHERE s.game_id = p_game_id
    AND s.deleted_at IS NULL
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

  -- Validate all participants have valid net results
  IF EXISTS (
    SELECT 1 FROM game_participants
    WHERE game_id = p_game_id
    AND net_result IS NULL
  ) THEN
    RAISE EXCEPTION 'Invalid net results for some participants';
  END IF;

  -- Validate no self-payments
  IF EXISTS (
    SELECT gp1.user_id
    FROM game_participants gp1
    JOIN game_participants gp2 ON gp1.game_id = gp2.game_id
    WHERE gp1.game_id = p_game_id
    AND gp1.net_result > v_tolerance
    AND gp2.net_result < -v_tolerance
    AND gp1.user_id = gp2.user_id
  ) THEN
    RAISE EXCEPTION 'Invalid settlement: user cannot pay themselves';
  END IF;

  -- Calculate and insert settlements
  RETURN QUERY
  INSERT INTO settlements (game_id, payer_id, payee_id, amount, status, created_at)
  SELECT 
    p_game_id,
    gp_debtor.user_id,
    gp_creditor.user_id,
    ROUND(
      LEAST(
        ABS(gp_debtor.net_result),
        gp_creditor.net_result
      )::NUMERIC, 2
    ),
    'pending',
    NOW()
  FROM (
    SELECT user_id, net_result
    FROM game_participants
    WHERE game_id = p_game_id
    AND net_result < -v_tolerance
    ORDER BY net_result ASC
  ) gp_debtor
  CROSS JOIN LATERAL (
    SELECT user_id, net_result
    FROM game_participants
    WHERE game_id = p_game_id
    AND net_result > v_tolerance
    AND net_result > 0
    LIMIT 1
  ) gp_creditor
  WHERE LEAST(ABS(gp_debtor.net_result), gp_creditor.net_result) > v_tolerance
  ON CONFLICT DO NOTHING
  RETURNING 
    settlements.id,
    settlements.payer_id,
    settlements.payee_id,
    settlements.amount,
    settlements.status,
    settlements.created_at;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
