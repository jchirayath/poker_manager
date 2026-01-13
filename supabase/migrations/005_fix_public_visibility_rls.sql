-- =============================================
-- Fix RLS Policies for Public Group/Game Visibility
-- Allows anyone to view public groups and their games
-- =============================================

-- =============================================
-- GROUPS: Allow viewing public groups
-- =============================================

-- Drop existing policy
DROP POLICY IF EXISTS "Users can view their groups" ON public.groups;

-- Create new policy that allows:
-- 1. Members to view their groups
-- 2. Creators to view their groups
-- 3. Anyone to view public groups
CREATE POLICY "Users can view groups"
  ON public.groups FOR SELECT
  USING (
    -- User is a member of the group
    id IN (
      SELECT group_id FROM public.group_members
      WHERE user_id = auth.uid()
    )
    -- OR user created the group
    OR created_by = auth.uid()
    -- OR the group is public (anyone can view)
    OR privacy = 'public'
  );

-- =============================================
-- GAMES: Allow viewing games from public groups
-- =============================================

-- Drop existing policy
DROP POLICY IF EXISTS "Users can view group games" ON public.games;

-- Create new policy that allows:
-- 1. Members to view games in their groups
-- 2. Creators to view games in their groups
-- 3. Anyone to view games from public groups
CREATE POLICY "Users can view games"
  ON public.games FOR SELECT
  USING (
    -- User is a member of the game's group
    group_id IN (
      SELECT group_id FROM public.group_members
      WHERE user_id = auth.uid()
    )
    -- OR user created the group
    OR group_id IN (
      SELECT id FROM public.groups WHERE created_by = auth.uid()
    )
    -- OR the game belongs to a public group
    OR group_id IN (
      SELECT id FROM public.groups WHERE privacy = 'public'
    )
  );

-- =============================================
-- GAME_PARTICIPANTS: Allow viewing participants from public groups
-- =============================================

-- Drop existing policy
DROP POLICY IF EXISTS "Users can view game participants" ON public.game_participants;

-- Create new policy that allows:
-- 1. Members to view participants in their groups' games
-- 2. Creators to view participants in their groups' games
-- 3. Anyone to view participants from games in public groups
CREATE POLICY "Users can view game participants"
  ON public.game_participants FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM public.games
      WHERE
        -- User is a member of the game's group
        group_id IN (
          SELECT group_id FROM public.group_members
          WHERE user_id = auth.uid()
        )
        -- OR user created the group
        OR group_id IN (
          SELECT id FROM public.groups WHERE created_by = auth.uid()
        )
        -- OR the game belongs to a public group
        OR group_id IN (
          SELECT id FROM public.groups WHERE privacy = 'public'
        )
    )
  );

-- =============================================
-- GROUP_MEMBERS: Allow viewing members of public groups
-- =============================================

-- Drop existing policy
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;

-- Create new policy that allows:
-- 1. Members to view other members in their groups
-- 2. Anyone to view members of public groups
CREATE POLICY "Users can view group members"
  ON public.group_members FOR SELECT
  USING (
    -- User is a member of the group
    public.is_group_member(group_id)
    -- OR the group is public
    OR group_id IN (
      SELECT id FROM public.groups WHERE privacy = 'public'
    )
  );

-- =============================================
-- TRANSACTIONS: Allow viewing transactions from public groups
-- =============================================

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can view transactions in their games" ON public.transactions;
DROP POLICY IF EXISTS "Users can view transactions" ON public.transactions;

-- Create new policy for viewing transactions
CREATE POLICY "Users can view transactions"
  ON public.transactions FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM public.games
      WHERE
        -- User is a member of the game's group
        group_id IN (
          SELECT group_id FROM public.group_members
          WHERE user_id = auth.uid()
        )
        -- OR user created the group
        OR group_id IN (
          SELECT id FROM public.groups WHERE created_by = auth.uid()
        )
        -- OR the game belongs to a public group
        OR group_id IN (
          SELECT id FROM public.groups WHERE privacy = 'public'
        )
    )
  );

-- =============================================
-- SETTLEMENTS: Allow viewing settlements from public groups
-- =============================================

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can view settlements" ON public.settlements;

-- Create new policy for viewing settlements
CREATE POLICY "Users can view settlements"
  ON public.settlements FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM public.games
      WHERE
        -- User is a member of the game's group
        group_id IN (
          SELECT group_id FROM public.group_members
          WHERE user_id = auth.uid()
        )
        -- OR user created the group
        OR group_id IN (
          SELECT id FROM public.groups WHERE created_by = auth.uid()
        )
        -- OR the game belongs to a public group
        OR group_id IN (
          SELECT id FROM public.groups WHERE privacy = 'public'
        )
    )
  );
