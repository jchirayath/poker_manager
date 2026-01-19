-- Auto-update participant totals when transactions are inserted, updated, or deleted
-- This eliminates the need to manually update totals in application code

-- Function to recalculate participant totals from transactions
CREATE OR REPLACE FUNCTION update_participant_totals_from_transaction()
RETURNS TRIGGER AS $$
DECLARE
  v_game_id UUID;
  v_user_id UUID;
  v_total_buyin DECIMAL(10,2);
  v_total_cashout DECIMAL(10,2);
BEGIN
  -- Determine which game_id and user_id to update
  IF TG_OP = 'DELETE' THEN
    v_game_id := OLD.game_id;
    v_user_id := OLD.user_id;
  ELSE
    v_game_id := NEW.game_id;
    v_user_id := NEW.user_id;
  END IF;

  -- Calculate totals from all transactions for this participant
  SELECT
    COALESCE(SUM(CASE WHEN type = 'buyin' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN type = 'cashout' THEN amount ELSE 0 END), 0)
  INTO v_total_buyin, v_total_cashout
  FROM transactions
  WHERE game_id = v_game_id AND user_id = v_user_id;

  -- Update the participant totals
  UPDATE game_participants
  SET
    total_buyin = v_total_buyin,
    total_cashout = v_total_cashout
  WHERE game_id = v_game_id AND user_id = v_user_id;

  -- If this was an update and the user_id changed, also update the old user
  IF TG_OP = 'UPDATE' AND OLD.user_id != NEW.user_id THEN
    SELECT
      COALESCE(SUM(CASE WHEN type = 'buyin' THEN amount ELSE 0 END), 0),
      COALESCE(SUM(CASE WHEN type = 'cashout' THEN amount ELSE 0 END), 0)
    INTO v_total_buyin, v_total_cashout
    FROM transactions
    WHERE game_id = OLD.game_id AND user_id = OLD.user_id;

    UPDATE game_participants
    SET
      total_buyin = v_total_buyin,
      total_cashout = v_total_cashout
    WHERE game_id = OLD.game_id AND user_id = OLD.user_id;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Create trigger on transactions table
DROP TRIGGER IF EXISTS update_participant_totals_trigger ON transactions;
CREATE TRIGGER update_participant_totals_trigger
  AFTER INSERT OR UPDATE OR DELETE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_participant_totals_from_transaction();
