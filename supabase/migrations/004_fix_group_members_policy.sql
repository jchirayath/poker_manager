-- Fix infinite recursion in group_members policies by using a SECURITY DEFINER helper

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

-- Clean up existing insert/update policies to avoid recursion
DROP POLICY IF EXISTS "Group admins can add members" ON public.group_members;
DROP POLICY IF EXISTS "Group creator can add self" ON public.group_members;
DROP POLICY IF EXISTS "Group admins can update member roles" ON public.group_members;

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
