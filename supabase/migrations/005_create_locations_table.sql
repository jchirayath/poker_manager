-- =============================================
-- Poker Manager Database Schema
-- Migration 005: Add Locations Table
-- =============================================

-- =============================================
-- TABLE: locations
-- =============================================
-- This table stores address locations that are bound to a group.
-- A location can be:
-- 1. A group location (group_id set, profile_id NULL) - e.g., a regular meeting place
-- 2. A member location (both group_id and profile_id set) - e.g., a member's address in context of a group
-- 3. A general member location (group_id NULL, profile_id set) - e.g., stored for reference

CREATE TABLE IF NOT EXISTS public.locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  street_address TEXT NOT NULL,
  city TEXT,
  state_province TEXT,
  postal_code TEXT,
  country TEXT NOT NULL,
  label TEXT,
  is_primary BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- At least one of group_id or profile_id must be set
  CONSTRAINT has_group_or_profile CHECK (group_id IS NOT NULL OR profile_id IS NOT NULL)
);

CREATE TRIGGER update_locations_updated_at
  BEFORE UPDATE ON locations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Create index for efficient lookups
CREATE INDEX idx_locations_group_id ON locations(group_id);
CREATE INDEX idx_locations_profile_id ON locations(profile_id);
CREATE INDEX idx_locations_group_profile ON locations(group_id, profile_id);

-- =============================================
-- ROW LEVEL SECURITY POLICIES: locations
-- =============================================

ALTER TABLE locations ENABLE ROW LEVEL SECURITY;

-- Users can view locations for groups they're members of
CREATE POLICY "Users can view group locations"
  ON locations FOR SELECT
  USING (
    group_id IS NULL OR
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- Users can view their own locations
CREATE POLICY "Users can view own locations"
  ON locations FOR SELECT
  USING (profile_id = auth.uid());

-- Users can insert locations for their profile (for group context)
CREATE POLICY "Users can insert own locations"
  ON locations FOR INSERT
  WITH CHECK (
    profile_id = auth.uid() OR
    (group_id IS NOT NULL AND 
     group_id IN (
       SELECT group_id FROM group_members 
       WHERE user_id = auth.uid()
     ) AND
     created_by = auth.uid()
    )
  );

-- Users can only update their own locations or group locations they have access to
CREATE POLICY "Users can update own locations"
  ON locations FOR UPDATE
  USING (
    profile_id = auth.uid() OR
    (group_id IS NOT NULL AND 
     group_id IN (
       SELECT group_id FROM group_members 
       WHERE user_id = auth.uid() AND role = 'admin'
     )
    )
  );

-- Users can only delete their own locations or group locations they manage
CREATE POLICY "Users can delete own locations"
  ON locations FOR DELETE
  USING (
    profile_id = auth.uid() OR
    (group_id IS NOT NULL AND 
     group_id IN (
       SELECT group_id FROM group_members 
       WHERE user_id = auth.uid() AND role = 'admin'
     )
    )
  );

-- =============================================
-- TRIGGER: Auto-create/update locations from profile updates
-- =============================================
-- When a user updates their profile address, also update their location record

CREATE OR REPLACE FUNCTION sync_profile_to_locations()
RETURNS TRIGGER AS $$
BEGIN
  -- Only process if address fields have changed
  IF (
    OLD.street_address IS DISTINCT FROM NEW.street_address OR
    OLD.city IS DISTINCT FROM NEW.city OR
    OLD.state_province IS DISTINCT FROM NEW.state_province OR
    OLD.postal_code IS DISTINCT FROM NEW.postal_code OR
    OLD.country IS DISTINCT FROM NEW.country
  ) THEN
    -- Update or insert location record for this profile (without group context)
    INSERT INTO public.locations (
      profile_id,
      group_id,
      street_address,
      city,
      state_province,
      postal_code,
      country,
      label,
      is_primary,
      created_by
    ) VALUES (
      NEW.id,
      NULL,
      COALESCE(NEW.street_address, ''),
      NEW.city,
      NEW.state_province,
      NEW.postal_code,
      NEW.country,
      'Primary Address',
      TRUE,
      NEW.id
    )
    ON CONFLICT (profile_id) WHERE group_id IS NULL
    DO UPDATE SET
      street_address = COALESCE(NEW.street_address, ''),
      city = COALESCE(EXCLUDED.city, NEW.city),
      state_province = COALESCE(EXCLUDED.state_province, NEW.state_province),
      postal_code = COALESCE(EXCLUDED.postal_code, NEW.postal_code),
      country = EXCLUDED.country,
      updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_profile_address_to_locations ON profiles;
CREATE TRIGGER sync_profile_address_to_locations
  AFTER UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_profile_to_locations();

-- =============================================
-- HELPER FUNCTION: Get full address from location
-- =============================================

CREATE OR REPLACE FUNCTION get_location_full_address(loc locations)
RETURNS TEXT AS $$
BEGIN
  RETURN CONCAT_WS(', ',
    NULLIF(loc.street_address, ''),
    NULLIF(loc.city, ''),
    NULLIF(loc.state_province, ''),
    NULLIF(loc.postal_code, ''),
    NULLIF(loc.country, '')
  );
END;
$$ LANGUAGE plpgsql STABLE;
