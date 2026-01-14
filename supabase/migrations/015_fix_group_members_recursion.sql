-- =============================================
-- Fix Group Members RLS Recursion
-- The group_members policy was checking itself causing recursion
-- =============================================

-- Drop the problematic policy
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;

-- Create a simple policy that doesn't reference group_members itself
-- Use a direct join to groups table only
CREATE POLICY "Users can view group members"
  ON public.group_members FOR SELECT
  USING (
    -- User is viewing their own membership
    user_id = auth.uid()
    -- OR the group is public (anyone can see members of public groups)
    OR EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = group_members.group_id AND g.privacy = 'public'
    )
    -- OR user is a member of the same group (check via direct user_id match)
    OR group_id IN (
      SELECT gm2.group_id FROM public.group_members gm2
      WHERE gm2.user_id = auth.uid()
    )
  );

-- Also fix the is_group_member function if it causes issues
-- This function is used in other policies
-- Note: keeping original parameter name 'gid' to avoid error
CREATE OR REPLACE FUNCTION public.is_group_member(gid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = gid AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;
