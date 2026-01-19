-- Migration: Drop unused address columns from profiles table
-- After migration 030, all addresses are stored in the locations table
-- This migration removes the redundant columns from profiles

-- Step 1: Verify data migration (optional safety check)
-- Count profiles with addresses vs locations with those addresses
DO $$
DECLARE
  profiles_with_addresses INTEGER;
  migrated_locations INTEGER;
BEGIN
  SELECT COUNT(*) INTO profiles_with_addresses
  FROM profiles
  WHERE street_address IS NOT NULL AND street_address != '';

  SELECT COUNT(*) INTO migrated_locations
  FROM locations
  WHERE profile_id IS NOT NULL AND is_primary = true;

  RAISE NOTICE 'Profiles with addresses: %', profiles_with_addresses;
  RAISE NOTICE 'Migrated primary locations: %', migrated_locations;

  IF profiles_with_addresses > 0 AND migrated_locations = 0 THEN
    RAISE WARNING 'No locations found but profiles have addresses! Check migration 030 ran successfully.';
  END IF;
END $$;

-- Step 2: Drop the legacy get_full_address() function if it exists
DROP FUNCTION IF EXISTS get_full_address();
DROP FUNCTION IF EXISTS get_full_address(TEXT, TEXT, TEXT, TEXT, TEXT);

-- Step 3: Drop address columns from profiles table
ALTER TABLE profiles
  DROP COLUMN IF EXISTS street_address,
  DROP COLUMN IF EXISTS city,
  DROP COLUMN IF EXISTS state_province,
  DROP COLUMN IF EXISTS postal_code,
  DROP COLUMN IF EXISTS country;

-- Step 4: Add comment to document the change
COMMENT ON COLUMN profiles.primary_location_id IS 'Reference to the user''s primary location in the locations table. All address information is now stored in the locations table.';

-- Verification query (run manually to verify migration success)
-- SELECT
--   COUNT(*) as total_profiles,
--   COUNT(primary_location_id) as profiles_with_primary_location
-- FROM profiles;
