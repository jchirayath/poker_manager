-- =============================================
-- Complete RLS Rewrite to Fix All Recursion Issues
-- Using SECURITY DEFINER functions to avoid policy recursion
-- =============================================

-- Step 1: Create helper functions that bypass RLS (SECURITY DEFINER)
-- These functions run with elevated privileges and don't trigger RLS

-- Function to check if a group is public (bypasses RLS)
CREATE OR REPLACE FUNCTION public.is_group_public(check_group_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = check_group_id AND privacy = 'public'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

-- Function to check if user is member of a group (bypasses RLS)
CREATE OR REPLACE FUNCTION public.is_user_group_member(check_group_id UUID, check_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = check_group_id AND user_id = check_user_id
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

-- Function to check if user created a group (bypasses RLS)
CREATE OR REPLACE FUNCTION public.is_group_creator(check_group_id UUID, check_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.groups
    WHERE id = check_group_id AND created_by = check_user_id
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

-- Function to get the group_id for a game (bypasses RLS)
CREATE OR REPLACE FUNCTION public.get_game_group_id(check_game_id UUID)
RETURNS UUID AS $$
  SELECT group_id FROM public.games WHERE id = check_game_id;
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

-- Step 2: Drop all existing SELECT policies that cause recursion

DROP POLICY IF EXISTS "Users can view groups" ON public.groups;
DROP POLICY IF EXISTS "Users can view games" ON public.games;
DROP POLICY IF EXISTS "Users can view game participants" ON public.game_participants;
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;
DROP POLICY IF EXISTS "Users can view transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can view settlements" ON public.settlements;

-- Step 3: Create new simple policies using the helper functions

-- GROUPS: Simple policy using helper functions
CREATE POLICY "Users can view groups"
  ON public.groups FOR SELECT
  USING (
    privacy = 'public'
    OR created_by = auth.uid()
    OR public.is_user_group_member(id, auth.uid())
  );

-- GAMES: Use helper functions to avoid recursion
CREATE POLICY "Users can view games"
  ON public.games FOR SELECT
  USING (
    public.is_group_public(group_id)
    OR public.is_group_creator(group_id, auth.uid())
    OR public.is_user_group_member(group_id, auth.uid())
  );

-- GAME_PARTICIPANTS: Use helper functions
CREATE POLICY "Users can view game participants"
  ON public.game_participants FOR SELECT
  USING (
    public.is_group_public(public.get_game_group_id(game_id))
    OR public.is_group_creator(public.get_game_group_id(game_id), auth.uid())
    OR public.is_user_group_member(public.get_game_group_id(game_id), auth.uid())
  );

-- GROUP_MEMBERS: Use helper functions
CREATE POLICY "Users can view group members"
  ON public.group_members FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_group_public(group_id)
    OR public.is_user_group_member(group_id, auth.uid())
  );

-- TRANSACTIONS: Use helper functions
CREATE POLICY "Users can view transactions"
  ON public.transactions FOR SELECT
  USING (
    public.is_group_public(public.get_game_group_id(game_id))
    OR public.is_group_creator(public.get_game_group_id(game_id), auth.uid())
    OR public.is_user_group_member(public.get_game_group_id(game_id), auth.uid())
  );

-- SETTLEMENTS: Use helper functions
CREATE POLICY "Users can view settlements"
  ON public.settlements FOR SELECT
  USING (
    public.is_group_public(public.get_game_group_id(game_id))
    OR public.is_group_creator(public.get_game_group_id(game_id), auth.uid())
    OR public.is_user_group_member(public.get_game_group_id(game_id), auth.uid())
  );

-- Grant execute permissions on the helper functions
GRANT EXECUTE ON FUNCTION public.is_group_public(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_user_group_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_group_creator(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_game_group_id(UUID) TO authenticated;
