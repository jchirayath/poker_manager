-- =============================================
-- Fix Duplicate/Conflicting RLS Policies
-- Remove older policies that don't include public group visibility
-- =============================================

-- Drop conflicting older policies that were superseded by migration 005

-- game_participants: Remove older policy that doesn't include public groups
DROP POLICY IF EXISTS "Only group members can view participants" ON public.game_participants;

-- transactions: Remove older policy that doesn't include public groups
DROP POLICY IF EXISTS "Only group members can view transactions" ON public.transactions;

-- groups: Remove older policy if exists (may have been renamed)
DROP POLICY IF EXISTS "Group creators can view their groups" ON public.groups;
DROP POLICY IF EXISTS "Users can view their groups" ON public.groups;

-- Ensure the correct policies exist (recreate if needed)

-- Groups SELECT policy
DROP POLICY IF EXISTS "Users can view groups" ON public.groups;
CREATE POLICY "Users can view groups"
  ON public.groups FOR SELECT
  USING (
    id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid())
    OR created_by = auth.uid()
    OR privacy = 'public'
  );

-- Games SELECT policy
DROP POLICY IF EXISTS "Users can view games" ON public.games;
DROP POLICY IF EXISTS "Users can view group games" ON public.games;
CREATE POLICY "Users can view games"
  ON public.games FOR SELECT
  USING (
    group_id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid())
    OR group_id IN (SELECT id FROM public.groups WHERE created_by = auth.uid())
    OR group_id IN (SELECT id FROM public.groups WHERE privacy = 'public')
  );

-- Game participants SELECT policy
DROP POLICY IF EXISTS "Users can view game participants" ON public.game_participants;
CREATE POLICY "Users can view game participants"
  ON public.game_participants FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM public.games
      WHERE
        group_id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid())
        OR group_id IN (SELECT id FROM public.groups WHERE created_by = auth.uid())
        OR group_id IN (SELECT id FROM public.groups WHERE privacy = 'public')
    )
  );

-- Group members SELECT policy
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;
CREATE POLICY "Users can view group members"
  ON public.group_members FOR SELECT
  USING (
    public.is_group_member(group_id)
    OR group_id IN (SELECT id FROM public.groups WHERE privacy = 'public')
  );

-- Transactions SELECT policy
DROP POLICY IF EXISTS "Users can view transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can view game transactions" ON public.transactions;
CREATE POLICY "Users can view transactions"
  ON public.transactions FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM public.games
      WHERE
        group_id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid())
        OR group_id IN (SELECT id FROM public.groups WHERE created_by = auth.uid())
        OR group_id IN (SELECT id FROM public.groups WHERE privacy = 'public')
    )
  );

-- Settlements SELECT policy
DROP POLICY IF EXISTS "Users can view settlements" ON public.settlements;
CREATE POLICY "Users can view settlements"
  ON public.settlements FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM public.games
      WHERE
        group_id IN (SELECT group_id FROM public.group_members WHERE user_id = auth.uid())
        OR group_id IN (SELECT id FROM public.groups WHERE created_by = auth.uid())
        OR group_id IN (SELECT id FROM public.groups WHERE privacy = 'public')
    )
  );
