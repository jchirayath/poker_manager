-- =============================================
-- Fix RLS Policy Recursion
-- Simplify policies to avoid infinite recursion
-- =============================================

-- The issue: policies on 'games' reference 'groups', and policies on 'groups'
-- may indirectly reference 'games' through subqueries, causing recursion.

-- Solution: Use simpler, direct conditions that don't cause circular references.

-- =============================================
-- GROUPS: Simple policy without subqueries to groups
-- =============================================
DROP POLICY IF EXISTS "Users can view groups" ON public.groups;

CREATE POLICY "Users can view groups"
  ON public.groups FOR SELECT
  USING (
    -- User is a member of the group
    EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = groups.id AND gm.user_id = auth.uid()
    )
    -- OR user created the group
    OR created_by = auth.uid()
    -- OR the group is public
    OR privacy = 'public'
  );

-- =============================================
-- GAMES: Avoid referencing groups table in subquery
-- =============================================
DROP POLICY IF EXISTS "Users can view games" ON public.games;

CREATE POLICY "Users can view games"
  ON public.games FOR SELECT
  USING (
    -- User is a member of the game's group
    EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = games.group_id AND gm.user_id = auth.uid()
    )
    -- OR user created the group (direct join to avoid recursion)
    OR EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = games.group_id AND g.created_by = auth.uid()
    )
    -- OR the game's group is public (direct join)
    OR EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = games.group_id AND g.privacy = 'public'
    )
  );

-- =============================================
-- GAME_PARTICIPANTS: Use EXISTS for efficiency and avoid recursion
-- =============================================
DROP POLICY IF EXISTS "Users can view game participants" ON public.game_participants;

CREATE POLICY "Users can view game participants"
  ON public.game_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.games g
      WHERE g.id = game_participants.game_id
      AND (
        -- User is member of the group
        EXISTS (
          SELECT 1 FROM public.group_members gm
          WHERE gm.group_id = g.group_id AND gm.user_id = auth.uid()
        )
        -- OR user created the group
        OR EXISTS (
          SELECT 1 FROM public.groups grp
          WHERE grp.id = g.group_id AND grp.created_by = auth.uid()
        )
        -- OR group is public
        OR EXISTS (
          SELECT 1 FROM public.groups grp
          WHERE grp.id = g.group_id AND grp.privacy = 'public'
        )
      )
    )
  );

-- =============================================
-- GROUP_MEMBERS: Simplified policy
-- =============================================
DROP POLICY IF EXISTS "Users can view group members" ON public.group_members;

CREATE POLICY "Users can view group members"
  ON public.group_members FOR SELECT
  USING (
    -- User is a member of this group
    EXISTS (
      SELECT 1 FROM public.group_members gm2
      WHERE gm2.group_id = group_members.group_id AND gm2.user_id = auth.uid()
    )
    -- OR the group is public
    OR EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = group_members.group_id AND g.privacy = 'public'
    )
  );

-- =============================================
-- TRANSACTIONS: Use EXISTS pattern
-- =============================================
DROP POLICY IF EXISTS "Users can view transactions" ON public.transactions;

CREATE POLICY "Users can view transactions"
  ON public.transactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.games g
      WHERE g.id = transactions.game_id
      AND (
        EXISTS (
          SELECT 1 FROM public.group_members gm
          WHERE gm.group_id = g.group_id AND gm.user_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.groups grp
          WHERE grp.id = g.group_id AND grp.created_by = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.groups grp
          WHERE grp.id = g.group_id AND grp.privacy = 'public'
        )
      )
    )
  );

-- =============================================
-- SETTLEMENTS: Use EXISTS pattern
-- =============================================
DROP POLICY IF EXISTS "Users can view settlements" ON public.settlements;

CREATE POLICY "Users can view settlements"
  ON public.settlements FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.games g
      WHERE g.id = settlements.game_id
      AND (
        EXISTS (
          SELECT 1 FROM public.group_members gm
          WHERE gm.group_id = g.group_id AND gm.user_id = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.groups grp
          WHERE grp.id = g.group_id AND grp.created_by = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.groups grp
          WHERE grp.id = g.group_id AND grp.privacy = 'public'
        )
      )
    )
  );
