# Address Migration: From Profiles to Locations Table

## Overview
This migration consolidates all address storage to use only the `locations` table, removing redundant address fields from the `profiles` table.

## Migration Timeline

### ✅ Completed Migrations

#### Migration 030: Migrate Addresses to Locations (COMPLETED)
- **File**: `030_migrate_addresses_to_locations.sql`
- **Status**: Should be already applied
- **What it did**:
  - Copied all profile addresses to the `locations` table
  - Added `primary_location_id` column to profiles
  - Updated profiles to reference their migrated locations
  - Created RLS policies for location access
  - **Did NOT drop** the old address columns (kept for rollback safety)

### 🔄 Pending Migration

#### Migration 031: Drop Profile Address Columns (TO BE RUN)
- **File**: `031_drop_profile_address_columns.sql`
- **Status**: Ready to apply (after verification)
- **What it will do**:
  - Verify migration success with counts
  - Drop the `get_full_address()` function
  - Drop address columns: `street_address`, `city`, `state_province`, `postal_code`, `country`
  - Add documentation comment

## Pre-Migration Verification Steps

### Step 1: Run Verification Script
```bash
cd /Users/jacobc/code/poker_manager/supabase
psql <your-database-connection-string> -f migrations/verify_address_migration.sql
```

Or run via Supabase SQL Editor:
```sql
-- Copy and paste contents of verify_address_migration.sql
```

### Step 2: Review Verification Results
Check the output for:
- ✅ `migration_status` = "SAFE TO DROP"
- ✅ `unmigrated_addresses` = 0
- ✅ `profiles_with_address` = `profiles_with_primary_location`
- ⚠️  Any mismatches in the sample comparison

### Step 3: Backup Your Database
**CRITICAL: Always backup before dropping columns!**

```bash
# Via Supabase Dashboard: Settings > Database > Backups
# Or via pg_dump:
pg_dump <connection-string> > backup_before_address_migration_$(date +%Y%m%d).sql
```

## Running Migration 031

### Option 1: Via Supabase CLI (Recommended)
```bash
cd /Users/jacobc/code/poker_manager
supabase db push
```

### Option 2: Via SQL Editor
1. Go to Supabase Dashboard > SQL Editor
2. Open `031_drop_profile_address_columns.sql`
3. Review the SQL
4. Click "Run"

### Option 3: Direct psql
```bash
psql <your-connection-string> -f supabase/migrations/031_drop_profile_address_columns.sql
```

## Post-Migration Verification

Run these queries to confirm success:

```sql
-- 1. Verify columns are dropped
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'profiles'
  AND column_name IN ('street_address', 'city', 'state_province', 'postal_code', 'country');
-- Should return: 0 rows

-- 2. Verify primary_location_id still exists
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'profiles'
  AND column_name = 'primary_location_id';
-- Should return: 1 row

-- 3. Check locations table integrity
SELECT COUNT(*) as location_count FROM locations;

-- 4. Sample query joining profiles with locations
SELECT
  p.id,
  p.first_name,
  p.last_name,
  l.street_address,
  l.city,
  l.state_province
FROM profiles p
LEFT JOIN locations l ON l.id = p.primary_location_id
LIMIT 5;
```

## Rollback Plan (Emergency Only)

If something goes wrong IMMEDIATELY after running migration 031:

### Option 1: Restore from Backup
```bash
psql <connection-string> < backup_before_address_migration_YYYYMMDD.sql
```

### Option 2: Manual Column Recreation (Data Loss)
⚠️ **WARNING**: This will NOT restore the data!

```sql
-- Recreate columns (empty)
ALTER TABLE profiles
  ADD COLUMN street_address TEXT,
  ADD COLUMN city TEXT,
  ADD COLUMN state_province TEXT,
  ADD COLUMN postal_code TEXT,
  ADD COLUMN country TEXT DEFAULT 'United States';

-- Optionally copy data back from locations
UPDATE profiles p
SET
  street_address = l.street_address,
  city = l.city,
  state_province = l.state_province,
  postal_code = l.postal_code,
  country = l.country
FROM locations l
WHERE l.id = p.primary_location_id;
```

## Code Changes Already Completed

The Dart/Flutter code has already been updated to not use profile address fields:

### Updated Models
- ✅ `ProfileModel` - removed address fields
- ✅ `UserModel` - removed address fields
- ✅ `LocationModel` - contains all address fields

### Updated Repositories
- ✅ `ProfileRepository` - removed address parameters
- ✅ `AuthRepository` - removed country references

### Updated UI
- ✅ `edit_profile_screen.dart` - removed address form section
- ✅ `local_user_form_screen.dart` - removed address form section
- ✅ `profile_screen.dart` - removed address display
- ✅ `group_detail_screen.dart` - removed address row

### Updated Tests
- ✅ `setup_dummy_data_test.dart` - creates only location records
- ✅ `test_data_factory.dart` - removed address parameters

## Expected Behavior After Migration

### Profile Creation
- New profiles are created **without** address fields
- Addresses are created separately in the `locations` table
- `primary_location_id` links profiles to their primary address

### Address Management
- All addresses are managed via the `locations` table
- Users can have multiple locations (home, work, venue, etc.)
- One location can be marked as primary
- Locations can be shared (e.g., group venues)

### Data Access
```dart
// OLD way (removed):
final address = profile.fullAddress;

// NEW way (via locations):
final location = await locationsRepo.getLocation(profile.primaryLocationId);
final address = location.fullAddress;
```

## Support

If you encounter issues:
1. Check verification results before running migration
2. Ensure migration 030 ran successfully
3. Always have a backup before dropping columns
4. Review Supabase logs for errors

## Questions to Answer Before Dropping Columns

- [ ] Has migration 030 been applied successfully?
- [ ] Does the verification script show "SAFE TO DROP"?
- [ ] Do you have a recent database backup?
- [ ] Have you tested the application with the updated code?
- [ ] Are all team members aware of this change?
- [ ] Is this being run on production? (If yes, test on staging first!)

## Summary

This migration completes the address consolidation by removing redundant columns. The Dart code is already updated and ready. Just ensure migration 030 ran successfully and verify the data before dropping the columns.
