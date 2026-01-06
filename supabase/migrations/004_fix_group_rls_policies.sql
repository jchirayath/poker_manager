-- =============================================
-- FIX GROUP RLS POLICIES
-- Consolidates group_members and groups RLS policies
-- =============================================

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

-- Helper function to check if the current user is a group admin or the creator
CREATE OR REPLACE FUNCTION public.is_group_admin(gid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.groups g
    WHERE g.id = gid AND g.created_by = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.group_id = gid
      AND gm.user_id = auth.uid()
      AND gm.role = 'admin'
  );
END;
$$;

-- Helper to check if current user belongs to a group (creator or member)
CREATE OR REPLACE FUNCTION public.is_group_member(gid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.groups g
    WHERE g.id = gid AND g.created_by = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.group_id = gid
      AND gm.user_id = auth.uid()
  );
END;
$$;

-- =============================================
-- GROUP_MEMBERS POLICIES
-- =============================================

-- Clean up existing insert/update policies to avoid recursion
DROP POLICY IF EXISTS "Group admins can add members" ON public.group_members;
DROP POLICY IF EXISTS "Group creator can add self" ON public.group_members;
DROP POLICY IF EXISTS "Group admins can update member roles" ON public.group_members;
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;

-- Insert policy: allow creator or admins to add members
CREATE POLICY "Group admins can add members"
  ON public.group_members FOR INSERT
  WITH CHECK (public.is_group_admin(group_id));

-- Update policy: allow admins to update member roles; preserve creator safety
CREATE POLICY "Group admins can update member roles"
  ON public.group_members FOR UPDATE
  USING (public.is_group_admin(group_id))
  WITH CHECK (
    public.is_group_admin(group_id)
    AND (is_creator = FALSE OR role = 'admin')
  );

-- Select policy: users can view group members if they belong to the group
CREATE POLICY "Users can view group members"
  ON public.group_members FOR SELECT
  USING (public.is_group_member(group_id));

-- =============================================
-- GROUPS POLICIES
-- =============================================

-- Allow group creators to view their groups so insert+select works
DROP POLICY IF EXISTS "Group creators can view their groups" ON public.groups;

CREATE POLICY "Group creators can view their groups"
  ON public.groups FOR SELECT
  USING (created_by = auth.uid());
