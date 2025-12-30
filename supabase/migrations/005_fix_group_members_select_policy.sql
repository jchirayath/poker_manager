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

-- Replace recursive SELECT policy with helper
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;

CREATE POLICY "Users can view group members"
  ON public.group_members FOR SELECT
  USING (public.is_group_member(group_id));
