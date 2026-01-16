-- Fix: The transaction integrity trigger should NOT block transactions during in-progress games
-- It should only validate that buy-ins = cash-outs when the game is being completed

-- Drop the existing problematic trigger
DROP TRIGGER IF EXISTS check_transaction_integrity ON transactions;

-- Update the function to only validate for completed games
CREATE OR REPLACE FUNCTION validate_game_financial_integrity()
RETURNS TRIGGER AS $$
DECLARE
  v_game_status TEXT;
  v_total_buyin DECIMAL(10, 2);
  v_total_cashout DECIMAL(10, 2);
  v_difference DECIMAL(10, 2);
  v_tolerance DECIMAL(10, 2) := 0.01;
BEGIN
  -- Get the game status
  SELECT status INTO v_game_status
  FROM games
  WHERE id = NEW.game_id;

  -- Only validate financial integrity for completed games
  -- During in_progress or scheduled games, allow any transactions
  IF v_game_status = 'completed' THEN
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
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Recreate the trigger (optional - we may not need this trigger at all for transactions)
-- The validation is better done when changing game status to 'completed'
-- For now, don't recreate the trigger on transactions - let transactions flow freely
-- The game completion logic already validates balance before allowing completion
