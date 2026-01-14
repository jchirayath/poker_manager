-- =============================================
-- Consolidated RLS Policies and Security
-- Consolidates migrations 004, 010-015, 018, 024
-- =============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_statistics ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_invitations ENABLE ROW LEVEL SECURITY;

-- =============================================
-- HELPER SECURITY FUNCTIONS
-- =============================================

-- Check if user is group admin or creator
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

-- Check if user is group member or creator
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
-- RLS POLICIES: profiles
-- =============================================

CREATE POLICY "Profiles are viewable by everyone"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- =============================================
-- RLS POLICIES: groups
-- =============================================

CREATE POLICY "Users can view their groups"
  ON groups FOR SELECT
  USING (
    id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
    OR created_by = auth.uid()
  );

CREATE POLICY "Users can create groups"
  ON groups FOR INSERT
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Group admins can update groups"
  ON groups FOR UPDATE
  USING (public.is_group_admin(id));

CREATE POLICY "Group admins can delete games"
  ON groups FOR DELETE
  USING (public.is_group_admin(id));

-- =============================================
-- RLS POLICIES: group_members
-- =============================================

CREATE POLICY "Users can view group members"
  ON group_members FOR SELECT
  USING (public.is_group_member(group_id));

CREATE POLICY "Group admins can add members"
  ON group_members FOR INSERT
  WITH CHECK (public.is_group_admin(group_id));

CREATE POLICY "Group admins can update member roles"
  ON group_members FOR UPDATE
  USING (public.is_group_admin(group_id))
  WITH CHECK (
    public.is_group_admin(group_id)
    AND (is_creator = FALSE OR role = 'admin')
  );

-- =============================================
-- RLS POLICIES: locations
-- =============================================

CREATE POLICY "Users can view group locations"
  ON locations FOR SELECT
  USING (
    group_id IS NULL
    OR group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
    OR group_id IN (
      SELECT id FROM groups WHERE created_by = auth.uid()
    )
  );

CREATE POLICY "Users can view own locations"
  ON locations FOR SELECT
  USING (profile_id = auth.uid());

CREATE POLICY "Users can insert own locations"
  ON locations FOR INSERT
  WITH CHECK (
    profile_id = auth.uid()
    OR (
      group_id IS NOT NULL AND 
      public.is_group_member(group_id) AND
      created_by = auth.uid()
    )
  );

CREATE POLICY "Users can update own locations"
  ON locations FOR UPDATE
  USING (
    profile_id = auth.uid()
    OR (
      group_id IS NOT NULL AND 
      public.is_group_admin(group_id)
    )
  );

CREATE POLICY "Users can delete own locations"
  ON locations FOR DELETE
  USING (
    profile_id = auth.uid()
    OR (
      group_id IS NOT NULL AND 
      public.is_group_admin(group_id)
    )
  );

-- =============================================
-- RLS POLICIES: games
-- =============================================

CREATE POLICY "Users can view group games"
  ON games FOR SELECT
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
    OR group_id IN (
      SELECT id FROM groups WHERE created_by = auth.uid()
    )
  );

CREATE POLICY "Group members can create games"
  ON games FOR INSERT
  WITH CHECK (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
    OR group_id IN (
      SELECT id FROM groups WHERE created_by = auth.uid()
    )
  );

CREATE POLICY "Group admins can modify games"
  ON games FOR UPDATE
  USING (public.is_group_admin(group_id));

CREATE POLICY "Group admins can delete games"
  ON games FOR DELETE
  USING (public.is_group_admin(group_id));

-- =============================================
-- RLS POLICIES: game_participants
-- =============================================

CREATE POLICY "Users can view game participants"
  ON game_participants FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM games 
      WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
      OR group_id IN (
        SELECT id FROM groups WHERE created_by = auth.uid()
      )
    )
  );

CREATE POLICY "Users can join games"
  ON game_participants FOR INSERT
  WITH CHECK (
    game_id IN (
      SELECT id FROM games 
      WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
      OR group_id IN (
        SELECT id FROM groups WHERE created_by = auth.uid()
      )
    )
  );

CREATE POLICY "Users can update own participation"
  ON game_participants FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Admins can manage all participants"
  ON game_participants FOR UPDATE
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  )
  WITH CHECK (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

-- =============================================
-- RLS POLICIES: transactions
-- =============================================

CREATE POLICY "Users can view transactions"
  ON transactions FOR SELECT
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid()
    )
    OR game_id IN (
      SELECT g.id FROM games g
      WHERE g.group_id IN (
        SELECT id FROM groups WHERE created_by = auth.uid()
      )
    )
  );

CREATE POLICY "Users can create transactions"
  ON transactions FOR INSERT
  WITH CHECK (
    game_id IN (
      SELECT g.id FROM games g
      WHERE g.group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
      OR g.group_id IN (
        SELECT id FROM groups WHERE created_by = auth.uid()
      )
    )
    AND game_id IN (
      SELECT id FROM games 
      WHERE status IN ('scheduled', 'in_progress')
    )
  );

CREATE POLICY "Only admins can modify transactions"
  ON transactions FOR UPDATE
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

CREATE POLICY "Only admins can delete transactions"
  ON transactions FOR DELETE
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

-- =============================================
-- RLS POLICIES: settlements
-- =============================================

CREATE POLICY "Users can view settlements"
  ON settlements FOR SELECT
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid()
    )
    OR game_id IN (
      SELECT g.id FROM games g
      WHERE g.group_id IN (
        SELECT id FROM groups WHERE created_by = auth.uid()
      )
    )
  );

CREATE POLICY "Only group admins can create settlements"
  ON settlements FOR INSERT
  WITH CHECK (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

CREATE POLICY "Only involved parties or admins can update settlements"
  ON settlements FOR UPDATE
  USING (
    (auth.uid() = from_user_id OR auth.uid() = to_user_id)
    OR game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  )
  WITH CHECK (
    (auth.uid() = from_user_id OR auth.uid() = to_user_id)
    OR game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

CREATE POLICY "Settlements cannot be deleted"
  ON settlements FOR DELETE
  USING (false);

-- =============================================
-- RLS POLICIES: player_statistics
-- =============================================

CREATE POLICY "Users can view group statistics"
  ON player_statistics FOR SELECT
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
    OR group_id IN (
      SELECT id FROM groups WHERE created_by = auth.uid()
    )
  );



-- =============================================
-- RLS POLICIES: group_invitations
-- =============================================

CREATE POLICY "Members can view group invitations"
  ON public.group_invitations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.group_members
      WHERE group_members.group_id = group_invitations.group_id
        AND group_members.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.groups
      WHERE groups.id = group_invitations.group_id
        AND groups.created_by = auth.uid()
    )
  );

CREATE POLICY "Admins can create invitations"
  ON public.group_invitations FOR INSERT
  WITH CHECK (
    public.is_group_admin(group_id)
    AND invited_by = auth.uid()
  );

CREATE POLICY "Admins can manage invitations"
  ON public.group_invitations FOR UPDATE
  USING (public.is_group_admin(group_id));

CREATE POLICY "Invited users can accept invitations"
  ON public.group_invitations FOR UPDATE
  USING (email = (SELECT email FROM profiles WHERE id = auth.uid()));
