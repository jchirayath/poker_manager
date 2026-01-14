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
  SELECT status, group_id INTO v_game_status, v_group_id
  FROM games
  WHERE id = p_game_id
  FOR UPDATE;

  IF v_game_status IS NULL THEN
    RAISE EXCEPTION 'Game % not found', p_game_id;
  END IF;

  IF v_game_status != 'completed' THEN
    RAISE EXCEPTION 'Cannot calculate settlements for % game', v_game_status;
  END IF;

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

  PERFORM 1 FROM game_participants
  WHERE game_id = p_game_id
  FOR UPDATE;

  SELECT 
    COALESCE(SUM(total_buyin), 0),
    COALESCE(SUM(total_cashout), 0)
  INTO v_total_buyin, v_total_cashout
  FROM game_participants
  WHERE game_id = p_game_id;

  v_difference := v_total_buyin - v_total_cashout;
  
  IF ABS(v_difference) > v_tolerance THEN
    RAISE EXCEPTION 'Financial mismatch: Buy-in $% vs Cash-out $%. Difference: $%',
      v_total_buyin, v_total_cashout, v_difference;
  END IF;

  CREATE TEMP TABLE temp_net_positions AS
  SELECT 
    user_id,
    net_result
  FROM game_participants
  WHERE game_id = p_game_id
  ORDER BY net_result;

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

        UPDATE temp_net_positions 
        SET net_result = net_result + v_transfer_amount 
        WHERE user_id = v_debtor.user_id;
        
        UPDATE temp_net_positions 
        SET net_result = net_result - v_transfer_amount 
        WHERE user_id = v_creditor.user_id;

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
