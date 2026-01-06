-- Refresh RLS policies to ensure members can read seeded data in UI
-- Run with Supabase migration tooling

-- Groups: creators and members can view
DROP POLICY IF EXISTS "Users can view their groups" ON public.groups;
CREATE POLICY "Users can view their groups"
  ON public.groups FOR SELECT
  USING (
    created_by = auth.uid()
    OR id IN (
      SELECT group_id FROM public.group_members WHERE user_id = auth.uid()
    )
  );

-- Group members: users can view members of groups they belong to
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;
CREATE POLICY "Users can view group members"
  ON public.group_members FOR SELECT
  USING (
    group_id IN (
      SELECT id FROM public.groups WHERE created_by = auth.uid()
    )
    OR group_id IN (
      SELECT group_id FROM public.group_members WHERE user_id = auth.uid()
    )
  );

-- Allow service role to insert group members (for seeding and creating groups)
DROP POLICY IF EXISTS "Service role can manage members" ON public.group_members;
CREATE POLICY "Service role can manage members"
  ON public.group_members FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- Allow authenticated users who are admins to add members
DROP POLICY IF EXISTS "Group admins can add members" ON public.group_members;
CREATE POLICY "Group admins can add members"
  ON public.group_members FOR INSERT
  WITH CHECK (
    group_id IN (
      SELECT id FROM public.groups WHERE created_by = auth.uid()
    )
    OR group_id IN (
      SELECT group_id FROM public.group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Allow update for group admins
DROP POLICY IF EXISTS "Group admins can update member roles" ON public.group_members;
CREATE POLICY "Group admins can update member roles"
  ON public.group_members FOR UPDATE
  USING (
    group_id IN (
      SELECT id FROM public.groups WHERE created_by = auth.uid()
    )
    OR group_id IN (
      SELECT group_id FROM public.group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    group_id IN (
      SELECT id FROM public.groups WHERE created_by = auth.uid()
    )
    OR group_id IN (
      SELECT group_id FROM public.group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Games: members of the group OR group creator can view
DROP POLICY IF EXISTS "Users can view group games" ON public.games;
CREATE POLICY "Users can view group games"
  ON public.games FOR SELECT
  USING (
    group_id IN (
      SELECT id FROM public.groups WHERE created_by = auth.uid()
    )
    OR group_id IN (
      SELECT group_id FROM public.group_members WHERE user_id = auth.uid()
    )
  );

-- Game participants: members of the game's group OR group creator can view
DROP POLICY IF EXISTS "Users can view game participants" ON public.game_participants;
CREATE POLICY "Users can view game participants"
  ON public.game_participants FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM public.games g
      WHERE g.group_id IN (
        SELECT id FROM public.groups WHERE created_by = auth.uid()
      )
      OR g.group_id IN (
        SELECT group_id FROM public.group_members WHERE user_id = auth.uid()
      )
    )
  );

-- Locations: allow viewing own locations, unbound locations, or group locations where user is a member/creator
DROP POLICY IF EXISTS "Users can view group locations" ON public.locations;
DROP POLICY IF EXISTS "Users can view own locations" ON public.locations;
CREATE POLICY "Users can view locations"
  ON public.locations FOR SELECT
  USING (
    profile_id = auth.uid()
    OR group_id IS NULL
    OR group_id IN (
      SELECT id FROM public.groups WHERE created_by = auth.uid()
    )
    OR group_id IN (
      SELECT group_id FROM public.group_members WHERE user_id = auth.uid()
    )
  );
