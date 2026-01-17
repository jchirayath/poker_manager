-- =============================================
-- Game Settings and Enhanced Admin Controls
-- Adds game-level permission settings and ensures at least one admin per group
-- =============================================

-- =============================================
-- Add allow_member_transactions to games table
-- =============================================
ALTER TABLE public.games
ADD COLUMN IF NOT EXISTS allow_member_transactions BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN public.games.allow_member_transactions IS
  'When FALSE, only admins can create/update transactions. When TRUE, all group members can create transactions.';

-- =============================================
-- Helper function: Check if user is admin in game's group
-- =============================================
CREATE OR REPLACE FUNCTION public.is_game_admin(gid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group_id UUID;
BEGIN
  -- Get the group_id for this game
  SELECT group_id INTO v_group_id FROM public.games WHERE id = gid;

  IF v_group_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Check if user is admin or creator of the group
  RETURN public.is_group_admin(v_group_id);
END;
$$;

-- =============================================
-- Helper function: Check if group has at least one admin
-- =============================================
CREATE OR REPLACE FUNCTION public.group_has_admin(gid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = gid AND role = 'admin'
  );
END;
$$;

-- =============================================
-- Helper function: Count admins in a group
-- =============================================
CREATE OR REPLACE FUNCTION public.count_group_admins(gid UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  admin_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO admin_count
  FROM public.group_members
  WHERE group_id = gid AND role = 'admin';

  RETURN admin_count;
END;
$$;

-- =============================================
-- Trigger: Ensure at least one admin remains in group
-- =============================================
CREATE OR REPLACE FUNCTION public.ensure_group_has_admin()
RETURNS TRIGGER AS $$
BEGIN
  -- On DELETE: Check if this is the last admin
  IF TG_OP = 'DELETE' THEN
    IF OLD.role = 'admin' THEN
      IF (SELECT count_group_admins(OLD.group_id)) <= 1 THEN
        RAISE EXCEPTION 'Cannot remove the last admin from the group. At least one admin must remain.';
      END IF;
    END IF;
    RETURN OLD;
  END IF;

  -- On UPDATE: Check if changing admin to member would leave no admins
  IF TG_OP = 'UPDATE' THEN
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

    -- Creator must always be admin (enforced by existing trigger, but adding check here too)
    IF NEW.is_creator = TRUE AND NEW.role != 'admin' THEN
      NEW.role := 'admin';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists and create new one
DROP TRIGGER IF EXISTS check_group_admin_count ON public.group_members;
CREATE TRIGGER check_group_admin_count
  BEFORE UPDATE OR DELETE ON public.group_members
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_group_has_admin();

-- =============================================
-- Update RLS Policy: Transaction creation with game settings check
-- =============================================

-- Drop the existing policy
DROP POLICY IF EXISTS "Users can create transactions" ON public.transactions;

-- Create new policy that checks both group membership AND game settings
CREATE POLICY "Users can create transactions based on game settings"
  ON transactions FOR INSERT
  WITH CHECK (
    -- Game must be in active status
    game_id IN (
      SELECT id FROM games
      WHERE status IN ('scheduled', 'in_progress')
    )
    AND (
      -- Case 1: User is admin (always allowed)
      game_id IN (
        SELECT g.id FROM games g
        INNER JOIN group_members gm ON gm.group_id = g.group_id
        WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
      )
      OR
      -- Case 2: User is group creator (always allowed)
      game_id IN (
        SELECT g.id FROM games g
        INNER JOIN groups gr ON gr.id = g.group_id
        WHERE gr.created_by = auth.uid()
      )
      OR
      -- Case 3: User is regular member AND game allows member transactions
      (
        game_id IN (
          SELECT g.id FROM games g
          WHERE g.allow_member_transactions = TRUE
          AND g.group_id IN (
            SELECT group_id FROM group_members
            WHERE user_id = auth.uid()
          )
        )
      )
    )
  );

-- =============================================
-- Update existing data: Set default for existing games
-- =============================================
-- Set allow_member_transactions to FALSE for all existing games
-- This maintains the current behavior where only admins can create transactions
UPDATE public.games
SET allow_member_transactions = FALSE
WHERE allow_member_transactions IS NULL;

-- =============================================
-- Ensure all groups have at least one admin
-- =============================================
-- For any groups without admins, promote the creator to admin if they exist as a member
UPDATE public.group_members gm
SET role = 'admin'
WHERE gm.is_creator = TRUE
  AND gm.role != 'admin'
  AND NOT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = gm.group_id AND role = 'admin'
  );

-- For groups where creator is not a member, promote the earliest joined member to admin
WITH groups_without_admins AS (
  SELECT DISTINCT gm.group_id
  FROM public.group_members gm
  WHERE NOT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = gm.group_id AND role = 'admin'
  )
),
first_members AS (
  SELECT DISTINCT ON (group_id) id, group_id
  FROM public.group_members
  WHERE group_id IN (SELECT group_id FROM groups_without_admins)
  ORDER BY group_id, joined_at ASC
)
UPDATE public.group_members
SET role = 'admin'
WHERE id IN (SELECT id FROM first_members);
