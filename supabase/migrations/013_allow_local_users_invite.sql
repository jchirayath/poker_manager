-- Allow local users to create invitations for their groups
-- This policy allows users who are local users (is_local_user=true) to create invitations

DROP POLICY IF EXISTS "Admins can create invitations" ON public.group_invitations;

CREATE POLICY "Admins can create invitations"
  ON public.group_invitations FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_members.group_id = group_invitations.group_id
        AND group_members.user_id = auth.uid()
        AND (
          group_members.role = 'admin'
          OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = group_members.user_id
            AND profiles.is_local_user = true
          )
        )
    )
  );

-- Also update the UPDATE policy for local users
DROP POLICY IF EXISTS "Admins can update invitations" ON public.group_invitations;

CREATE POLICY "Admins can update invitations"
  ON public.group_invitations FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_members.group_id = group_invitations.group_id
        AND group_members.user_id = auth.uid()
        AND (
          group_members.role = 'admin'
          OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = group_members.user_id
            AND profiles.is_local_user = true
          )
        )
    )
  );

-- Also update the DELETE policy for local users
DROP POLICY IF EXISTS "Admins can delete invitations" ON public.group_invitations;

CREATE POLICY "Admins can delete invitations"
  ON public.group_invitations FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_members.group_id = group_invitations.group_id
        AND group_members.user_id = auth.uid()
        AND (
          group_members.role = 'admin'
          OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = group_members.user_id
            AND profiles.is_local_user = true
          )
        )
    )
  );
