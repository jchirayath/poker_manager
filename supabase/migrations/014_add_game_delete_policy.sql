-- =============================================
-- Add DELETE policy for games table
-- =============================================

-- Group admins can delete games
CREATE POLICY "Group admins can delete games"
  ON games FOR DELETE
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
