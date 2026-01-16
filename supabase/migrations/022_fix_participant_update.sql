-- Fix: Allow group members to update game_participants financial data
-- This is needed because adding buy-ins/cash-outs for other players requires updating their participant record

-- Option 1: Add RLS policy for group members to update participant totals
-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "Group members can update participant totals" ON game_participants;

CREATE POLICY "Group members can update participant totals"
  ON game_participants FOR UPDATE
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid()
    )
  )
  WITH CHECK (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid()
    )
  );

-- Option 2: Create a SECURITY DEFINER function to update participant totals
-- This bypasses RLS and is called from the app after inserting a transaction
CREATE OR REPLACE FUNCTION update_participant_totals(
  p_game_id UUID,
  p_user_id UUID,
  p_total_buyin DECIMAL(10,2),
  p_total_cashout DECIMAL(10,2)
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE game_participants
  SET
    total_buyin = p_total_buyin,
    total_cashout = p_total_cashout
  WHERE game_id = p_game_id AND user_id = p_user_id;

  -- If no row was updated, the participant doesn't exist
  -- This shouldn't happen in normal flow but handle it gracefully
  IF NOT FOUND THEN
    INSERT INTO game_participants (game_id, user_id, total_buyin, total_cashout, rsvp_status)
    VALUES (p_game_id, p_user_id, p_total_buyin, p_total_cashout, 'going');
  END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_participant_totals TO authenticated;
