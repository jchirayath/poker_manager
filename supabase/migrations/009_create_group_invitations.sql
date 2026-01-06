-- =============================================
-- GROUP INVITATIONS TABLE
-- Tracks email invitations to join groups
-- =============================================

CREATE TABLE IF NOT EXISTS public.group_invitations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  invited_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  invited_name TEXT,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'cancelled', 'expired')),
  token TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days')
);

-- Index for efficient queries
CREATE INDEX IF NOT EXISTS idx_group_invitations_group_id ON public.group_invitations(group_id);
CREATE INDEX IF NOT EXISTS idx_group_invitations_email ON public.group_invitations(email);
CREATE INDEX IF NOT EXISTS idx_group_invitations_status ON public.group_invitations(status);
CREATE INDEX IF NOT EXISTS idx_group_invitations_token ON public.group_invitations(token);

-- Trigger to update updated_at timestamp
CREATE TRIGGER update_group_invitations_updated_at
  BEFORE UPDATE ON group_invitations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- RLS POLICIES FOR GROUP INVITATIONS
-- =============================================

ALTER TABLE public.group_invitations ENABLE ROW LEVEL SECURITY;

-- Users can view invitations for groups they are members/admins of
CREATE POLICY "Members can view group invitations"
  ON public.group_invitations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_members.group_id = group_invitations.group_id
        AND group_members.user_id = auth.uid()
    )
  );

-- Admins can create invitations
CREATE POLICY "Admins can create invitations"
  ON public.group_invitations FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_members.group_id = group_invitations.group_id
        AND group_members.user_id = auth.uid()
        AND group_members.role = 'admin'
    )
  );

-- Admins can update invitations
CREATE POLICY "Admins can update invitations"
  ON public.group_invitations FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_members.group_id = group_invitations.group_id
        AND group_members.user_id = auth.uid()
        AND group_members.role = 'admin'
    )
  );

-- Admins can delete invitations
CREATE POLICY "Admins can delete invitations"
  ON public.group_invitations FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_members.group_id = group_invitations.group_id
        AND group_members.user_id = auth.uid()
        AND group_members.role = 'admin'
    )
  );
