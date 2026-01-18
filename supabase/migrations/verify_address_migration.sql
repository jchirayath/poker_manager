-- Verification script for address migration from profiles to locations
-- Run this BEFORE executing migration 031 to ensure data was properly migrated

-- 1. Check profiles with addresses
SELECT
  'Profiles with addresses (before migration 030)' as check_description,
  COUNT(*) as count
FROM profiles
WHERE street_address IS NOT NULL AND street_address != '';

-- 2. Check locations created from profile addresses
SELECT
  'Locations created from profile addresses' as check_description,
  COUNT(*) as count
FROM locations
WHERE profile_id IS NOT NULL
  AND is_primary = true;

-- 3. Check profiles that have a primary_location_id set
SELECT
  'Profiles with primary_location_id' as check_description,
  COUNT(*) as count
FROM profiles
WHERE primary_location_id IS NOT NULL;

-- 4. Check for profiles with addresses but no primary location (data loss risk)
SELECT
  'Profiles with address but NO primary location (RISK!)' as check_description,
  COUNT(*) as count
FROM profiles
WHERE (street_address IS NOT NULL AND street_address != '')
  AND primary_location_id IS NULL;

-- 5. Sample comparison: Show first 5 profiles with their addresses in both tables
SELECT
  p.id,
  p.first_name || ' ' || p.last_name as profile_name,
  p.email,
  '--- Profile Address ---' as separator1,
  p.street_address as profile_street,
  p.city as profile_city,
  p.state_province as profile_state,
  p.postal_code as profile_postal,
  p.country as profile_country,
  '--- Location Address ---' as separator2,
  l.street_address as location_street,
  l.city as location_city,
  l.state_province as location_state,
  l.postal_code as location_postal,
  l.country as location_country,
  l.label as location_label,
  l.is_primary as is_primary_location,
  '--- Match Status ---' as separator3,
  CASE
    WHEN p.street_address = l.street_address THEN 'MATCH'
    ELSE 'MISMATCH'
  END as address_match
FROM profiles p
LEFT JOIN locations l ON l.id = p.primary_location_id
WHERE p.street_address IS NOT NULL AND p.street_address != ''
LIMIT 5;

-- 6. Check for any orphaned locations (locations without valid profile_id)
SELECT
  'Orphaned locations (no valid profile)' as check_description,
  COUNT(*) as count
FROM locations l
WHERE l.profile_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM profiles p WHERE p.id = l.profile_id);

-- 7. Summary statistics
SELECT
  COUNT(*) as total_profiles,
  COUNT(street_address) FILTER (WHERE street_address IS NOT NULL AND street_address != '') as profiles_with_address,
  COUNT(primary_location_id) as profiles_with_primary_location,
  COUNT(CASE WHEN street_address IS NOT NULL AND street_address != '' AND primary_location_id IS NULL THEN 1 END) as unmigrated_addresses
FROM profiles;

-- Final recommendation
SELECT
  CASE
    WHEN (
      SELECT COUNT(*)
      FROM profiles
      WHERE (street_address IS NOT NULL AND street_address != '')
        AND primary_location_id IS NULL
    ) = 0 THEN
      '✅ SAFE TO DROP: All profile addresses have been migrated to locations table'
    ELSE
      '⚠️  WARNING: Some profiles have addresses but no primary_location_id. DO NOT DROP COLUMNS YET!'
  END as migration_status;
