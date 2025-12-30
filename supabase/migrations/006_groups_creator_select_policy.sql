-- Allow group creators to view their groups so insert+select works

DROP POLICY IF EXISTS "Group creators can view their groups" ON public.groups;

CREATE POLICY "Group creators can view their groups"
  ON public.groups FOR SELECT
  USING (created_by = auth.uid());
