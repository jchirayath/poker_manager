# Migration Verification Guide

## ✅ Migration Applied Successfully + Query Fix

The database migration `030_migrate_addresses_to_locations.sql` has been applied to your Supabase database.

**Important Fixes Applied:**
1. Query logic fixed to make migrated locations visible - See [LOCATION_FIX.md](LOCATION_FIX.md)
2. Dual-write implemented to sync new addresses to locations table - See [DUAL_WRITE_IMPLEMENTATION.md](DUAL_WRITE_IMPLEMENTATION.md)

## What Changed

### Database Changes:
1. ✅ Profile addresses migrated to `locations` table
2. ✅ `primary_location_id` column added to `profiles` table
3. ✅ RLS policies created for location access control
4. ✅ Indexes created for performance

### Code Changes:
1. ✅ ProfileModel updated with `primaryLocationId` field
2. ✅ create_game_screen simplified (removed ~80 lines of complex logic)
3. ✅ edit_game_screen fixed for proper location handling
4. ✅ Location dropdown now shows labels when available
5. ✅ LocationsRepository query fixed to show personal + group locations
6. ✅ ProfileRepository implements dual-write to keep both tables in sync

## Testing Checklist

Run the app and verify the following:

### 1. Test Migrated Addresses (Old Data)
- [ ] Open Create Game screen for a group
- [ ] Check location dropdown shows existing addresses
- [ ] Verify labels show as "FirstName's Address" (from migration)
- [ ] Verify addresses are visible when selecting players
- [ ] Create a game with a migrated location
- [ ] Verify game saves correctly

### 2. Test Profile Address Update (Dual-Write)
- [ ] Open a user's profile for editing
- [ ] Update the address fields (street, city, state, postal, country)
- [ ] Save the profile
- [ ] **Verify in profiles table**: Address fields updated
- [ ] **Verify in locations table**: Primary location created/updated
- [ ] Go to Create Game screen
- [ ] **Verify**: Updated address appears in location dropdown
- [ ] **Verify**: Label shows as "FirstName's Address"

### 3. Test New Local User Creation (Dual-Write)
- [ ] Create a new local user with address
- [ ] Fill in all address fields
- [ ] Save the user
- [ ] **Verify in profiles table**: User created with address
- [ ] **Verify in locations table**: Primary location created
- [ ] Go to Create Game screen
- [ ] Add the new user to a group
- [ ] **Verify**: New user's address appears in dropdown
- [ ] **Verify**: Label shows as "FirstName's Address"

### 4. Test Create New Game
- [ ] Go to create game screen
- [ ] Select players
- [ ] Check the location dropdown shows:
  - Group-specific locations (if any)
  - Personal locations of selected players
- [ ] Try creating a game with a location
- [ ] Verify the game saves with the correct location
- [ ] Verify location displays with label or full address

### 5. Test Edit Existing Game
- [ ] Open an existing game
- [ ] Verify the location is displayed correctly
- [ ] Edit the game and change the location
- [ ] Select a different location from dropdown
- [ ] Save and verify the location updated
- [ ] Verify label displays correctly

### 6. Test Add Manual Location
- [ ] Click the "+" icon in location dropdown
- [ ] Fill in all address fields
- [ ] Add a custom label (e.g., "John's House")
- [ ] Save and verify it appears in the dropdown
- [ ] **Verify**: Shows custom label, not full address
- [ ] **Verify in locations table**: Location created with group_id

### 7. Test Location Display Logic
- [ ] Locations with labels should show: "John's House"
- [ ] Locations without labels should show: "123 Main St, City, State, ZIP, Country"
- [ ] Primary locations should show with is_primary = true in database
- [ ] No empty or broken dropdowns

### 8. Test Database Consistency (Dual-Write Verification)
- [ ] Query profiles table: `SELECT id, first_name, street_address, city, primary_location_id FROM profiles WHERE street_address IS NOT NULL LIMIT 10`
- [ ] Query locations table: `SELECT id, profile_id, label, street_address, city, is_primary FROM locations WHERE profile_id IS NOT NULL LIMIT 10`
- [ ] **Verify**: Each profile with address has matching location record
- [ ] **Verify**: profiles.primary_location_id points to locations.id
- [ ] **Verify**: Address data matches between both tables
- [ ] **Verify**: All locations have proper labels

### 9. Test Location Filtering by Selected Players
- [ ] Create game screen with NO players selected
- [ ] **Verify**: Dropdown shows only group-level locations
- [ ] Select specific players
- [ ] **Verify**: Dropdown shows group locations + selected players' locations
- [ ] Deselect all players
- [ ] **Verify**: Dropdown reverts to group-level locations only

### 10. Test RLS Policies
- [ ] Login as different users
- [ ] **Verify**: Users can see their own locations
- [ ] **Verify**: Users can see group members' locations
- [ ] **Verify**: Users cannot see locations of non-group members
- [ ] **Verify**: Users can create/update/delete their own locations
- [ ] **Verify**: Users cannot modify other users' locations

## Expected Behavior

### Location Dropdown Logic:
- **Group locations** (`group_id` set, `profile_id` may be null): Available to all group members
- **Personal locations** (`profile_id` set, `group_id` null): Available when that profile is a group member
- **Member-in-group locations** (both `group_id` and `profile_id` set): Scoped to specific group
- **Display**: Label if exists, otherwise full address

### Migration Data:
- All profile addresses should now have corresponding records in `locations` table
- Each migrated location has label like "FirstName's Address"
- `is_primary` is set to `true` for migrated locations
- Profiles now reference their primary location via `primary_location_id`

### Dual-Write Behavior:
- **Profile updates**: Addresses written to BOTH `profiles` and `locations` tables
- **New users**: Locations created automatically when address provided
- **Primary locations**: Automatically updated when profile address changes
- **Synchronization**: `_syncAddressToLocation()` keeps tables in sync

## Database Verification Queries

Use these queries to verify the migration and dual-write are working correctly:

### 1. Check Migration Success
```sql
-- Count profiles with addresses
SELECT COUNT(*) as profiles_with_addresses
FROM profiles
WHERE street_address IS NOT NULL AND street_address != '';

-- Count migrated locations (should match above)
SELECT COUNT(*) as migrated_locations
FROM locations
WHERE profile_id IS NOT NULL AND is_primary = true;

-- Verify they match
SELECT
  (SELECT COUNT(*) FROM profiles WHERE street_address IS NOT NULL) as profiles_count,
  (SELECT COUNT(*) FROM locations WHERE profile_id IS NOT NULL AND is_primary = true) as locations_count;
```

### 2. Check Dual-Write Integrity
```sql
-- Check for profiles with addresses but no primary location
SELECT p.id, p.first_name, p.last_name, p.street_address, p.primary_location_id
FROM profiles p
WHERE p.street_address IS NOT NULL
  AND p.street_address != ''
  AND p.primary_location_id IS NULL;
-- Should return 0 rows after dual-write implementation

-- Verify address data matches between tables
SELECT
  p.id,
  p.first_name,
  p.street_address as profile_street,
  p.city as profile_city,
  l.street_address as location_street,
  l.city as location_city,
  l.label,
  l.is_primary
FROM profiles p
LEFT JOIN locations l ON l.id = p.primary_location_id
WHERE p.street_address IS NOT NULL
LIMIT 10;
```

### 3. Check Location Visibility for Groups
```sql
-- Get all locations available to a specific group
-- Replace 'your-group-id' with actual group ID
SELECT
  l.id,
  l.label,
  l.street_address,
  l.city,
  l.profile_id,
  l.group_id,
  l.is_primary,
  p.first_name,
  p.last_name
FROM locations l
LEFT JOIN profiles p ON p.id = l.profile_id
WHERE l.group_id = 'your-group-id'
   OR l.profile_id IN (
     SELECT user_id FROM group_members WHERE group_id = 'your-group-id'
   )
ORDER BY l.is_primary DESC, l.created_at DESC;
```

### 4. Check RLS Policies
```sql
-- List all policies on locations table
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'locations';

-- Should show 4 policies:
-- 1. Users can view their own locations
-- 2. Users can insert their own locations
-- 3. Users can update their own locations
-- 4. Users can delete their own locations
```

### 5. Check for Data Inconsistencies
```sql
-- Find locations with no label and no address
SELECT id, profile_id, group_id, street_address, label
FROM locations
WHERE (label IS NULL OR label = '')
  AND (street_address IS NULL OR street_address = '');
-- Should return 0 rows

-- Find orphaned primary_location_id references
SELECT p.id, p.first_name, p.primary_location_id
FROM profiles p
WHERE p.primary_location_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM locations l WHERE l.id = p.primary_location_id
  );
-- Should return 0 rows
```

## If Something Goes Wrong

### Rollback Plan:
The old address fields are still in the `profiles` table (not dropped yet) for safety.

If you encounter issues:
1. The legacy address fields (`street_address`, `city`, etc.) are still in profiles table
2. The code still reads these fields as fallback
3. You can revert the code changes if needed

### Common Issues:

**Issue**: Location dropdown is empty after migration
- **Root Cause**: The migration created locations with `profile_id` set but `group_id` NULL, while the query was filtering by `group_id`
- **Solution**: ✅ FIXED - Updated `getGroupLocations()` to fetch both group-specific and member personal locations
- **Check**: Locations should now appear with labels like "FirstName's Address"
- **Verification**: Run query: `SELECT COUNT(*) FROM locations WHERE profile_id IS NOT NULL`

**Issue**: Updated profile address doesn't appear in dropdown
- **Root Cause**: Dual-write may have failed silently
- **Solution**: Check debug logs for "📍 Updating existing primary location" or "📍 Creating new primary location"
- **Check**: Query locations table: `SELECT * FROM locations WHERE profile_id = 'user-id'`
- **Fix**: If location not created, update profile again (dual-write will trigger)

**Issue**: Profile has address but no primary_location_id
- **Root Cause**: Profile was created/updated before dual-write implementation
- **Solution**: Edit and save the profile again to trigger dual-write
- **Check**: Query: `SELECT id, first_name, street_address, primary_location_id FROM profiles WHERE street_address IS NOT NULL AND primary_location_id IS NULL`

**Issue**: Location data doesn't match between tables
- **Root Cause**: Profile was updated before dual-write, or sync failed
- **Solution**: Edit profile and save to resync
- **Check**: Run integrity query from "Database Verification Queries" section
- **Manual Fix**: Update location directly or update profile to trigger sync

**Issue**: Can't see member addresses in group
- **Root Cause**: RLS policies blocking access or profile not in group_members
- **Check**: Verify `profile_id` is set correctly in locations
- **Check**: Verify user is in group_members table: `SELECT * FROM group_members WHERE group_id = 'group-id'`
- **Solution**: Check RLS policies are allowing access with `auth.uid() = profile_id::uuid`

**Issue**: Duplicate addresses for same user
- **Root Cause**: Multiple locations created instead of updating existing primary
- **Check**: Query: `SELECT profile_id, COUNT(*) FROM locations WHERE is_primary = true GROUP BY profile_id HAVING COUNT(*) > 1`
- **Solution**: Migration has deduplication logic, but manual cleanup may be needed
- **Manual Fix**: Keep one, set others to `is_primary = false`

**Issue**: Dual-write sync errors in logs
- **Root Cause**: Database permissions, RLS policy violations, or invalid data
- **Check**: Look for "⚠️ Failed to sync address to location" in debug logs
- **Solution**: Check error details, verify RLS policies allow user to create/update locations
- **Note**: Profile update will still succeed even if location sync fails

**Issue**: Old addresses show but new ones don't
- **Root Cause**: Dual-write not active or failed
- **Verification**: Check if `_syncAddressToLocation()` method exists in profile_repository.dart
- **Check**: Flutter app rebuild may be needed if code was updated
- **Solution**: Rebuild app and test again

## Next Steps

After verifying everything works:

1. **Monitor for a few days** to ensure stability
2. **Uncomment Step 4** in migration file to drop old address columns (when confident)
3. **Remove legacy fields** from ProfileModel
4. **Update profile edit screens** to use location picker

## Support

If you encounter issues:
1. Check Supabase logs for RLS policy violations
2. Verify data in `locations` table
3. Check that `primary_location_id` is set correctly in profiles
4. Review [MIGRATION_SUMMARY.md](MIGRATION_SUMMARY.md) for architecture details
