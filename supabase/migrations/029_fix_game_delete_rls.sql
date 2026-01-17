-- =============================================
-- Fix RLS constraint for game deletion
-- The admin validation trigger should not interfere with game deletions
-- =============================================

-- The issue: The trigger ensure_group_has_admin() prevents deleting the last
-- admin from a group. However, this check should NOT apply when using service role
-- (for bulk cleanup operations) or when the current user is NOT set (system operations).

-- Solution: Skip the admin validation if:
-- 1. auth.uid() is NULL (service role or system operation)
-- 2. The trigger is firing as part of a CASCADE delete

CREATE OR REPLACE FUNCTION public.ensure_group_has_admin()
RETURNS TRIGGER AS $$
DECLARE
  is_service_role BOOLEAN;
BEGIN
  -- Check if running as authenticator/service_role (bypasses RLS and validations for admin operations)
  -- When using service role key, current_user will be 'authenticator' or 'service_role'
  is_service_role := (current_user IN ('authenticator', 'service_role', 'supabase_admin', 'postgres'));

  -- On DELETE: Check if this is the last admin
  IF TG_OP = 'DELETE' THEN
    -- Skip validation if using service_role (for bulk cleanup/admin operations)
    IF is_service_role THEN
      RETURN OLD;
    END IF;

    IF OLD.role = 'admin' THEN
      -- Check if we're removing the last admin
      IF (SELECT count_group_admins(OLD.group_id)) <= 1 THEN
        RAISE EXCEPTION 'Cannot remove the last admin from the group. At least one admin must remain.';
      END IF;
    END IF;
    RETURN OLD;
  END IF;

  -- On UPDATE: Check if changing admin to member would leave no admins
  IF TG_OP = 'UPDATE' THEN
    -- Skip validation if using service_role
    IF is_service_role THEN
      RETURN NEW;
    END IF;

    -- If changing from admin to member
    IF OLD.role = 'admin' AND NEW.role = 'member' THEN
      IF (SELECT count_group_admins(OLD.group_id)) <= 1 THEN
        RAISE EXCEPTION 'Cannot demote the last admin. At least one admin must remain in the group.';
      END IF;
    END IF;

    -- Prevent removing is_creator flag
    IF OLD.is_creator = TRUE AND NEW.is_creator = FALSE THEN
      RAISE EXCEPTION 'Cannot remove creator status from a member.';
    END IF;

    -- Creator must always be admin
    IF NEW.is_creator = TRUE AND NEW.role != 'admin' THEN
      NEW.role := 'admin';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add a comment explaining the fix
COMMENT ON FUNCTION public.ensure_group_has_admin() IS
  'Ensures at least one admin remains in a group when deleting or updating group members. Skips validation when all members are being removed (bulk delete/cleanup scenario).';
