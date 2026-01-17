-- Migration: Fix group_members DELETE policy to allow admins to remove members
-- Created: 2026-01-16
-- Issue: RLS policy was blocking member deletion by group admins

-- Drop existing DELETE policy if it exists
DROP POLICY IF EXISTS "Members can be deleted by group admins or themselves" ON group_members;
DROP POLICY IF EXISTS "delete_group_members" ON group_members;
DROP POLICY IF EXISTS "Users can remove themselves from groups" ON group_members;

-- Create new DELETE policy that allows:
-- 1. Group creators to delete any member (except themselves)
-- 2. Group admins to delete any member (except creator and themselves)
-- 3. Users to delete themselves from groups
CREATE POLICY "Members can be deleted by admins or themselves"
ON group_members
FOR DELETE
USING (
  -- User is deleting themselves
  auth.uid() = user_id
  OR
  -- User is a group creator and can delete others (but not themselves)
  EXISTS (
    SELECT 1 FROM group_members gm
    WHERE gm.group_id = group_members.group_id
    AND gm.user_id = auth.uid()
    AND gm.role = 'creator'
    AND group_members.role != 'creator'  -- Cannot delete the creator
  )
  OR
  -- User is a group admin and can delete non-admin/non-creator members
  EXISTS (
    SELECT 1 FROM group_members gm
    WHERE gm.group_id = group_members.group_id
    AND gm.user_id = auth.uid()
    AND gm.role = 'admin'
    AND group_members.role NOT IN ('creator', 'admin')  -- Cannot delete creator or other admins
  )
);

-- Add comment explaining the policy
COMMENT ON POLICY "Members can be deleted by admins or themselves" ON group_members IS
'Allows group creators to delete any non-creator member, admins to delete regular members, and users to remove themselves from groups';
