-- Allow group admins to manage participant records (insert/update) for their games

-- Admins can insert game_participants (e.g., when recording buy-ins for others)
CREATE POLICY "Group admins can insert participants"
  ON game_participants FOR INSERT
  WITH CHECK (
    game_id IN (
      SELECT id FROM games
      WHERE group_id IN (
        SELECT group_id FROM group_members
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    )
  );

-- Admins can update participant records in their groups
CREATE POLICY "Group admins can update participants"
  ON game_participants FOR UPDATE
  USING (
    game_id IN (
      SELECT id FROM games
      WHERE group_id IN (
        SELECT group_id FROM group_members
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    )
  );
