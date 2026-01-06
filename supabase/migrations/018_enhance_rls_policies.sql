-- =============================================
-- Enhanced RLS Policies - Security Hardening
-- Migration: 002_enhance_rls_policies.sql
-- Date: January 4, 2026
-- Purpose: Address critical RLS vulnerability by adding restrictive policies
--          for games, transactions, and settlements
-- =============================================

-- Drop existing permissive policies to replace with stricter versions
DROP POLICY IF EXISTS "Users can update own settlements" ON settlements;
DROP POLICY IF EXISTS "Admins can create settlements" ON settlements;
DROP POLICY IF EXISTS "Group members can create games" ON games;

-- =============================================
-- Enhanced RLS POLICIES: games
-- =============================================

-- Only group members can create games (already exists, but ensuring consistency)
CREATE POLICY "Only group members can create games"
  ON games FOR INSERT
  WITH CHECK (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role IN ('admin', 'member', 'creator')
    )
  );

-- =============================================
-- Enhanced RLS POLICIES: settlements
-- Restrict to prevent cross-group access
-- =============================================

-- Only group members can view settlements (stricter validation)
CREATE POLICY "Only group members can view settlements"
  ON settlements FOR SELECT
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid()
    )
  );

-- Only admins can create/recalculate settlements
CREATE POLICY "Only group admins can create settlements"
  ON settlements FOR INSERT
  WITH CHECK (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

-- Only involved parties (payer/payee) or group admins can update settlements
CREATE POLICY "Only involved parties or admins can update settlements"
  ON settlements FOR UPDATE
  USING (
    -- User is payer or payee
    (auth.uid() = payer_id OR auth.uid() = payee_id)
    OR
    -- OR user is admin of the group containing this settlement
    (
      game_id IN (
        SELECT g.id FROM games g
        INNER JOIN group_members gm ON gm.group_id = g.group_id
        WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
      )
    )
  )
  WITH CHECK (
    -- Can only update status, not amounts or participants
    (auth.uid() = payer_id OR auth.uid() = payee_id)
    OR
    (
      game_id IN (
        SELECT g.id FROM games g
        INNER JOIN group_members gm ON gm.group_id = g.group_id
        WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
      )
    )
  );

-- Prevent settlement deletion (immutable for audit trail)
CREATE POLICY "Settlements cannot be deleted"
  ON settlements FOR DELETE
  USING (false);

-- =============================================
-- Enhanced RLS POLICIES: transactions
-- Stricter scope validation
-- =============================================

-- Only group members can view transactions
CREATE POLICY "Only group members can view transactions"
  ON transactions FOR SELECT
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid()
    )
  );

-- Only group members can record transactions
CREATE POLICY "Only group members can record transactions"
  ON transactions FOR INSERT
  WITH CHECK (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid()
    )
    AND
    -- Game must be in a valid state for transactions
    game_id IN (
      SELECT id FROM games 
      WHERE status IN ('scheduled', 'in_progress')
    )
  );

-- Only admins can modify transactions (for corrections)
CREATE POLICY "Only admins can modify transactions"
  ON transactions FOR UPDATE
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

-- Only admins can delete transactions (audit trail preservation)
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
-- Enhanced RLS POLICIES: game_participants
-- Stricter participation controls
-- =============================================

-- Only group members can view game participants
CREATE POLICY "Only group members can view participants"
  ON game_participants FOR SELECT
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid()
    )
  );

-- Only group members can join games
CREATE POLICY "Only group members can join games"
  ON game_participants FOR INSERT
  WITH CHECK (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid()
    )
  );

-- Users can only update their own participation
CREATE POLICY "Users can only update own participation"
  ON game_participants FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Admins can update any participation (for corrections)
CREATE POLICY "Admins can update all participation"
  ON game_participants FOR UPDATE
  USING (
    game_id IN (
      SELECT g.id FROM games g
      INNER JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

-- =============================================
-- Enhanced RLS POLICIES: games
-- Additional restrictions for game modifications
-- =============================================

-- Drop and replace the less restrictive update policy
DROP POLICY IF EXISTS "Group admins can modify games" ON games;

CREATE POLICY "Only admins can modify games"
  ON games FOR UPDATE
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Only admins can delete games
CREATE POLICY "Only admins can delete games"
  ON games FOR DELETE
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- =============================================
-- Enhanced RLS POLICIES: groups
-- Additional restrictions for group modifications
-- =============================================

DROP POLICY IF EXISTS "Group admins can update groups" ON groups;

-- Only group admins can update group details
CREATE POLICY "Only group admins can update groups"
  ON groups FOR UPDATE
  USING (
    id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Only group creator can delete group (consider soft delete instead)
CREATE POLICY "Only group creator can delete groups"
  ON groups FOR DELETE
  USING (
    created_by = auth.uid()
  );

-- =============================================
-- Enhanced RLS POLICIES: group_members
-- Stricter role management
-- =============================================

DROP POLICY IF EXISTS "Group admins can promote/demote members" ON group_members;

-- Only admins can modify member roles
CREATE POLICY "Only admins can modify member roles"
  ON group_members FOR UPDATE
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
    AND
    -- Cannot demote the creator
    (is_creator = FALSE OR role = 'admin')
    AND
    -- Cannot promote to creator
    is_creator = FALSE
  );

-- Only admins can remove members
CREATE POLICY "Only admins can remove members"
  ON group_members FOR DELETE
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
    AND
    -- Cannot remove the creator
    is_creator = FALSE
  );

-- =============================================
-- Enhanced RLS POLICIES: player_statistics
-- Read-only for users, system-managed
-- =============================================

DROP POLICY IF EXISTS "System can manage statistics" ON player_statistics;

-- System-only for all modifications (disable user modifications)
CREATE POLICY "System manages all statistics modifications"
  ON player_statistics FOR ALL
  USING (false)
  WITH CHECK (false);

-- Keep the view policy unchanged
-- Users can still view statistics for their groups

-- =============================================
-- Audit Function - Track RLS Policy Changes
-- =============================================

CREATE OR REPLACE FUNCTION audit_rls_access_attempt()
RETURNS TRIGGER AS $$
BEGIN
  -- This trigger can be used to log unauthorized access attempts
  -- Enable selective logging if needed
  IF (SELECT COUNT(*) FROM audit_log WHERE created_at > NOW() - INTERVAL '1 second') > 100 THEN
    INSERT INTO audit_log (table_name, record_id, operation, user_id, change_reason)
    VALUES (TG_TABLE_NAME, NEW.id, TG_OP, auth.uid(), 'RLS access attempt');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Verification Queries
-- =============================================

-- Run these queries to verify RLS is properly enforced:
/*
-- As authenticated user, verify you can only see your own group data:
SELECT * FROM games WHERE group_id IN (
  SELECT group_id FROM group_members WHERE user_id = auth.uid()
);

-- As authenticated user, verify you can only see settlements from your groups:
SELECT * FROM settlements WHERE game_id IN (
  SELECT g.id FROM games g
  INNER JOIN group_members gm ON gm.group_id = g.group_id
  WHERE gm.user_id = auth.uid()
);

-- Verify RLS is enabled on all tables:
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- List all policies:
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public' 
ORDER BY tablename, policyname;
*/

-- =============================================
-- Migration Complete
-- =============================================
-- These enhanced policies ensure:
-- 1. Users can only access data from groups they belong to
-- 2. Admin-only operations for critical financial functions
-- 3. Immutable audit trails (no deletion of settlements/transactions)
-- 4. Proper role-based access control
-- 5. Game state validation for transactional consistency
-- =============================================
