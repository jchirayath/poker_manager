CREATE OR REPLACE FUNCTION validate_game_financial_integrity()
RETURNS TRIGGER AS $$
DECLARE
  v_total_buyin DECIMAL(10, 2);
  v_total_cashout DECIMAL(10, 2);
  v_difference DECIMAL(10, 2);
  v_tolerance DECIMAL(10, 2) := 0.01;
BEGIN
  SELECT 
    COALESCE(SUM(total_buyin), 0),
    COALESCE(SUM(total_cashout), 0)
  INTO v_total_buyin, v_total_cashout
  FROM game_participants
  WHERE game_id = NEW.game_id;

  v_difference := v_total_buyin - v_total_cashout;
  
  IF ABS(v_difference) > v_tolerance THEN
    RAISE EXCEPTION 'Transaction violates financial integrity: Buy-in $% vs Cash-out $%',
      v_total_buyin, v_total_cashout;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
