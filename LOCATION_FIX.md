# Location Dropdown Fix

## Problem

After running the migration `030_migrate_addresses_to_locations.sql`, the location dropdown in the "Create Game" screen was empty and not showing any address labels.

## Root Cause

The issue was a mismatch between how the migration created locations and how the code queried them:

1. **Migration behavior**: The migration created locations with `profile_id` set (personal locations for each user) but `group_id` was NULL.

2. **Query behavior**: The `getGroupLocations()` method in [locations_repository.dart](lib/features/locations/data/repositories/locations_repository.dart) was filtering by `group_id = groupId`, which would never match NULL values.

3. **Result**: The query returned 0 locations even though the migration successfully created location records.

## Solution

Updated the `getGroupLocations()` method to fetch BOTH:
1. Group-specific locations (where `group_id = groupId`)
2. Personal locations of all group members (where `profile_id IN (member IDs)`)

### Changes Made

**File**: [lib/features/locations/data/repositories/locations_repository.dart](lib/features/locations/data/repositories/locations_repository.dart:10-47)

The method now:
1. First queries `group_members` table to get all profile IDs of group members
2. Then queries `locations` table with an OR condition:
   - `group_id = groupId` (group-specific locations)
   - `profile_id IN (member profile IDs)` (personal locations)

```dart
/// Get all locations for a group
/// Returns both group-specific locations and personal locations of group members
Future<Result<List<LocationModel>>> getGroupLocations(String groupId) async {
  try {
    // Get all group members' profile IDs
    final membersResponse = await _client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);

    final memberProfileIds = (membersResponse as List)
        .map((m) => m['user_id'] as String)
        .toList();

    // Build the OR condition for querying locations
    String orCondition;
    if (memberProfileIds.isEmpty) {
      // If no members, just get group-specific locations
      orCondition = 'group_id.eq.$groupId';
    } else {
      // Get locations where:
      // 1. group_id matches (group-specific locations), OR
      // 2. profile_id is in the list of group members (personal locations of members)
      orCondition = 'group_id.eq.$groupId,profile_id.in.(${memberProfileIds.join(',')})';
    }

    final response = await _client
        .from('locations')
        .select()
        .or(orCondition)
        .order('is_primary', ascending: false)
        .order('created_at', ascending: false);

    final locations = (response as List)
        .map((json) => LocationModel.fromJson(json))
        .toList();

    return Success(locations);
  } catch (e) {
    return Failure('Failed to load group locations: ${e.toString()}');
  }
}
```

## Expected Behavior After Fix

When creating a game:
1. The location dropdown should now show all locations available to the group:
   - Group-specific locations (shared venues)
   - Personal locations of all group members (migrated from profile addresses)
2. Each location displays its label if available, otherwise shows the full address
3. The `_getFilteredLocations()` method in [create_game_screen.dart](lib/features/games/presentation/screens/create_game_screen.dart:530-562) filters these based on selected players

## Location Types Supported

1. **Group Locations** (`group_id` set, `profile_id` NULL)
   - Shared venue for the entire group
   - Always visible in dropdown

2. **Personal Locations** (`profile_id` set, `group_id` NULL)
   - Personal address of a user (created by migration)
   - Visible when that user is a member of the group

3. **Member-in-Group Locations** (both `group_id` AND `profile_id` set)
   - User's location scoped to a specific group
   - Visible when viewing that specific group

## Testing

To verify the fix works:

1. **Open Create Game screen**
   - Select a group
   - Check that the location dropdown is populated

2. **Verify migrated locations appear**
   - You should see locations with labels like "FirstName's Address"
   - These are the addresses migrated from the profiles table

3. **Test filtering by selected players**
   - Select specific players
   - Verify only their personal locations + group locations are shown
   - Deselect all players → only group locations should show

4. **Add a new location**
   - Use the "+" icon to add a location
   - Verify it appears immediately in the dropdown

## Migration Status

✅ Migration applied successfully
✅ Profile addresses migrated to locations table
✅ Query logic fixed to fetch personal + group locations
✅ No compilation errors

Next step: Test in the running app to confirm dropdown is populated.
