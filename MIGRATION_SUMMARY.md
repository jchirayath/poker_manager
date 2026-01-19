# Location Architecture Migration Summary

## Overview
This migration consolidates address storage to use only the `locations` table as the single source of truth, removing duplicate address fields from the `profiles` table.

## Changes Made

### 1. Database Migration (`supabase/migrations/030_migrate_addresses_to_locations.sql`)
- **Migrates** existing profile addresses to the `locations` table
- **Adds** `primary_location_id` column to `profiles` table
- **Creates** RLS policies for location access control
- **Preserves** old address columns temporarily for rollback safety

### 2. ProfileModel Updates
- **Added** `primaryLocationId` field to link profiles to their primary location
- **Kept** legacy address fields temporarily (marked for removal after migration validation)
- **Regenerated** Freezed models with new schema

### 3. Game Screen Simplifications

#### create_game_screen.dart
- **Simplified** `_getFilteredLocations()` method - no more virtual locations
  - Now queries only the `locations` table
  - Returns group locations + member locations
  - No duplicate address merging needed
- **Simplified** `_createGame()` method
  - Removed virtual location ID handling
  - All locations come from database with real IDs
- **Improved** location display
  - Shows label if available, otherwise full address
  - Clean, single source of truth

#### edit_game_screen.dart
- **Fixed** location lookup to use try-catch instead of null casting
- **Simplified** to use label ?? fullAddress pattern

### 4. Location Dialog (Already Modern)
- Add Location dialog already creates proper locations in the locations table
- Labels are optional
- All fields properly validated

## Migration Steps

### To Apply This Migration:

1. **Run the migration script:**
   ```bash
   # Connect to Supabase and run:
   cd supabase
   supabase db push
   ```

2. **Verify the migration:**
   - Check that all profile addresses were migrated to `locations` table
   - Verify `primary_location_id` is set correctly for existing profiles
   - Test creating games and selecting locations

3. **After validation, clean up:**
   - Uncomment Step 4 in migration script to drop old address columns from profiles
   - Remove legacy address fields from ProfileModel
   - Update profile edit screens to use location picker

## Architecture Benefits

### Before:
- ❌ Addresses duplicated in both `profiles` and `locations` tables
- ❌ Complex merging logic in game screens
- ❌ Virtual location IDs (`profile_xxxxx`)
- ❌ Confusing UX - which address to use?

### After:
- ✅ Single source of truth: `locations` table only
- ✅ Simple queries - just filter by group_id and profile_id
- ✅ Real database IDs for all locations
- ✅ Clear UX - labels show intent, addresses show details
- ✅ Easier to maintain and extend

## Data Model

```
locations table:
├── id (UUID) - Primary key
├── group_id (UUID) - NULL for personal locations
├── profile_id (UUID) - Owner of the location
├── street_address (TEXT)
├── city (TEXT)
├── state_province (TEXT)
├── postal_code (TEXT)
├── country (TEXT)
├── label (TEXT) - Optional friendly name
└── is_primary (BOOLEAN) - Primary location for this profile

profiles table:
├── id (UUID)
├── primary_location_id (UUID) - References locations(id)
└── ... other fields
```

## Location Types

1. **Personal Locations** (`profile_id` set, `group_id` null)
   - Belongs to a specific user
   - Can be used across all their groups

2. **Group Locations** (`group_id` set, `profile_id` null)
   - Shared venue for the entire group
   - Anyone in the group can select it

3. **Member Location in Group** (both `group_id` and `profile_id` set)
   - User's location within a specific group context
   - Scoped to that group only

## Rollback Plan

If issues arise:
1. The old address columns are still in the `profiles` table
2. Simply revert the ProfileModel changes
3. Revert the game screen simplifications
4. Drop the `primary_location_id` column
5. Delete migrated records from `locations` table where `created_at` matches migration time

## Testing Checklist

- [x] Migration script syntax validated
- [x] ProfileModel updated and regenerated
- [x] create_game_screen simplified and compiles
- [x] edit_game_screen fixed and compiles
- [ ] Run migration on test database
- [ ] Verify existing games still show locations correctly
- [ ] Create new game with location selection
- [ ] Edit existing game and change location
- [ ] Add new location through dialog
- [ ] Profile screens updated to use location picker

## Next Steps

1. **Apply migration** to test database
2. **Test thoroughly** with existing data
3. **Update profile edit screens** to use location picker instead of address fields
4. **Remove legacy fields** after validation period
5. **Update documentation** for location management

## Files Modified

- `supabase/migrations/030_migrate_addresses_to_locations.sql` (NEW)
- `lib/features/profile/data/models/profile_model.dart`
- `lib/features/games/presentation/screens/create_game_screen.dart`
- `lib/features/games/presentation/screens/edit_game_screen.dart`

## Compilation Status

✅ No errors related to location changes
✅ Only pre-existing errors in safe_svg_network.dart (unrelated)
✅ Ready for testing
