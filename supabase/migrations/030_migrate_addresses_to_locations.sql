-- Migration: Move profile addresses to locations table
-- This migration consolidates address storage to use only the locations table

-- Step 1: Migrate existing profile addresses to locations table
INSERT INTO locations (
  id,
  profile_id,
  street_address,
  city,
  state_province,
  postal_code,
  country,
  label,
  is_primary,
  created_by,
  created_at,
  updated_at
)
SELECT
  gen_random_uuid(),
  p.id,
  p.street_address,
  p.city,
  p.state_province,
  p.postal_code,
  COALESCE(p.country, 'USA'),
  p.first_name || '''s Address',  -- Default label: "John's Address"
  true,  -- Set as primary location
  p.id,  -- User created their own location
  NOW(),
  NOW()
FROM profiles p
WHERE p.street_address IS NOT NULL
  AND p.street_address != ''
  AND NOT EXISTS (
    -- Don't create duplicate if location already exists for this profile
    SELECT 1 FROM locations l
    WHERE l.profile_id = p.id
    AND l.street_address = p.street_address
  );

-- Step 2: Add primary_location_id column to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS primary_location_id UUID REFERENCES locations(id) ON DELETE SET NULL;

-- Step 3: Update profiles to point to their migrated location
UPDATE profiles p
SET primary_location_id = (
  SELECT l.id
  FROM locations l
  WHERE l.profile_id = p.id
    AND l.is_primary = true
  LIMIT 1
)
WHERE p.street_address IS NOT NULL
  AND p.street_address != '';

-- Step 4: Drop address columns from profiles (commented out for safety - uncomment after validation)
-- ALTER TABLE profiles DROP COLUMN IF EXISTS street_address;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS city;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS state_province;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS postal_code;
-- ALTER TABLE profiles DROP COLUMN IF EXISTS country;

-- Step 5: Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_primary_location ON profiles(primary_location_id);
CREATE INDEX IF NOT EXISTS idx_locations_profile_id ON locations(profile_id);

-- Step 6: Add RLS policies for profile locations
DO $$
BEGIN
  -- Policy: Users can view their own locations
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'locations'
    AND policyname = 'Users can view their own locations'
  ) THEN
    CREATE POLICY "Users can view their own locations"
      ON locations FOR SELECT
      USING (
        auth.uid() = profile_id::uuid OR
        auth.uid() = created_by::uuid
      );
  END IF;

  -- Policy: Users can insert their own locations
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'locations'
    AND policyname = 'Users can insert their own locations'
  ) THEN
    CREATE POLICY "Users can insert their own locations"
      ON locations FOR INSERT
      WITH CHECK (
        auth.uid() = profile_id::uuid OR
        auth.uid() = created_by::uuid
      );
  END IF;

  -- Policy: Users can update their own locations
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'locations'
    AND policyname = 'Users can update their own locations'
  ) THEN
    CREATE POLICY "Users can update their own locations"
      ON locations FOR UPDATE
      USING (
        auth.uid() = profile_id::uuid OR
        auth.uid() = created_by::uuid
      );
  END IF;

  -- Policy: Users can delete their own locations
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'locations'
    AND policyname = 'Users can delete their own locations'
  ) THEN
    CREATE POLICY "Users can delete their own locations"
      ON locations FOR DELETE
      USING (
        auth.uid() = profile_id::uuid OR
        auth.uid() = created_by::uuid
      );
  END IF;
END $$;

-- Note: Keep the old address columns for now to allow for rollback
-- After validating the migration works correctly, uncomment Step 4 to drop the columns
