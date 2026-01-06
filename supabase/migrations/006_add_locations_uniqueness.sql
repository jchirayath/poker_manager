-- =============================================
-- Migration 006: Locations uniqueness support
-- Adds a partial unique index so the profile-address upsert in
-- sync_profile_to_locations works when group_id IS NULL.
-- =============================================

-- Create partial unique index for profile-only locations (group_id IS NULL)
-- This allows the ON CONFLICT (profile_id) WHERE group_id IS NULL clause
-- in sync_profile_to_locations to execute without error and enforces
-- a single primary profile-level location per user.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'idx_locations_profile_id_no_group_unique'
  ) THEN
    CREATE UNIQUE INDEX idx_locations_profile_id_no_group_unique
      ON public.locations (profile_id)
      WHERE group_id IS NULL;
  END IF;
END;
$$;
