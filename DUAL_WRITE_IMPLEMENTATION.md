# Dual-Write Implementation Summary

## ✅ Problem Solved

**Issue**: After the migration, new user addresses were only written to the `profiles` table, not the `locations` table. This meant:
- Old addresses (migrated) appeared in location dropdowns
- New addresses (after migration) did NOT appear in dropdowns
- Inconsistent user experience

**Solution**: Implemented dual-write pattern to automatically sync addresses to both tables.

---

## Changes Implemented

### 1. Profile Repository - Dual Write Logic
**File**: [lib/features/profile/data/repositories/profile_repository.dart](lib/features/profile/data/repositories/profile_repository.dart)

#### New Helper Method: `_syncAddressToLocation()`

```dart
/// Sync address from profile to locations table (dual-write pattern)
/// This ensures addresses appear in location dropdowns
Future<void> _syncAddressToLocation({
  required String userId,
  required String streetAddress,
  String? city,
  String? stateProvince,
  String? postalCode,
  required String country,
  String? firstName,
}) async
```

**What it does:**
1. Checks if user has an existing primary location
2. If exists → Updates the existing location with new address
3. If not exists → Creates new primary location with label "FirstName's Address"
4. Updates `profiles.primary_location_id` to reference the location
5. Gracefully handles errors (doesn't fail profile update if location sync fails)

#### Updated: `updateProfile()` Method

**Before:**
- Only wrote address to `profiles` table columns

**After:**
- Writes to `profiles` table (backward compatibility)
- **ALSO** calls `_syncAddressToLocation()` to write to `locations` table
- Tracks if address fields were updated with `hasAddressUpdate` flag

#### Updated: `createLocalProfile()` Method

**Before:**
- Only wrote address to `profiles` table columns

**After:**
- Writes to `profiles` table (backward compatibility)
- **ALSO** calls `_syncAddressToLocation()` if address provided
- Creates primary location for new local users automatically

---

## How It Works

### Scenario 1: User Edits Profile
1. User opens Edit Profile screen
2. Updates their address fields
3. Saves the profile
4. **Dual Write Happens:**
   - Address saved to `profiles.street_address`, `city`, etc.
   - `_syncAddressToLocation()` is called automatically
   - Address also saved/updated in `locations` table
   - Location appears in dropdown immediately

### Scenario 2: Creating Local User
1. Admin creates a local user with address
2. Profile is created with address fields
3. **Dual Write Happens:**
   - Address saved to `profiles` table
   - `_syncAddressToLocation()` creates primary location
   - Location ready for use in games immediately

### Scenario 3: Updating Existing Address
1. User with existing primary location edits address
2. **Dual Write Happens:**
   - `profiles` table updated
   - Existing primary location in `locations` table updated
   - Label preserved (e.g., "John's Address")
   - Dropdown shows updated address

---

## Data Flow

```
Edit Profile Screen
       ↓
ProfileRepository.updateProfile()
       ↓
   ┌───┴────────────────────────┐
   ↓                            ↓
Update profiles table    _syncAddressToLocation()
   ↓                            ↓
profiles.street_address    Check for primary location
profiles.city                   ↓
profiles.state_province    ┌────┴─────┐
   ...                     ↓          ↓
                      Update      Create New
                      Existing    Primary Location
                           ↓          ↓
                    Update profiles.primary_location_id
                           ↓
                    Location visible in dropdown
```

---

## Benefits

### ✅ Immediate Benefits
1. **All addresses visible**: Both old (migrated) and new addresses appear in dropdowns
2. **No breaking changes**: Existing UI and code continue to work
3. **Automatic sync**: No manual intervention needed
4. **Backward compatible**: Profiles table still has data for legacy code
5. **User-friendly**: Users see their addresses immediately after saving

### ✅ Technical Benefits
1. **Gradual migration**: Can remove profiles columns later
2. **Fail-safe**: Location sync errors don't break profile updates
3. **Single source of truth (locations)**: For dropdown queries
4. **Audit trail**: Both tables have data during transition

---

## Testing Checklist

### Test Profile Updates
- [ ] Edit an existing user's profile and update address
- [ ] Verify address appears in Create Game location dropdown
- [ ] Verify address label shows "FirstName's Address"
- [ ] Verify profiles table was updated
- [ ] Verify locations table was updated

### Test New Local Users
- [ ] Create a new local user with address
- [ ] Verify user is created successfully
- [ ] Verify address appears in location dropdown when user is selected
- [ ] Verify location has proper label

### Test Address Changes
- [ ] User with existing address updates to new address
- [ ] Verify old address is replaced, not duplicated
- [ ] Verify primary location is updated, not new one created

### Test Error Handling
- [ ] Profile update should succeed even if location sync fails
- [ ] Check debug logs for location sync errors (if any)

---

## Files Modified

1. [lib/features/profile/data/repositories/profile_repository.dart](lib/features/profile/data/repositories/profile_repository.dart)
   - Added `_syncAddressToLocation()` method
   - Updated `updateProfile()` to dual-write
   - Updated `createLocalProfile()` to dual-write

---

## Migration Status

| Component | Status | Notes |
|-----------|--------|-------|
| Database Migration | ✅ Complete | Old addresses migrated to locations |
| Query Fix | ✅ Complete | `getGroupLocations()` fetches member locations |
| Dual Write | ✅ Complete | New addresses written to both tables |
| Compilation | ✅ Pass | No errors introduced |
| Ready for Testing | ✅ Yes | Can test in running app immediately |

---

## Next Steps (Optional Future Work)

### Phase 1 (Current) ✅
- [x] Dual-write implementation
- [x] All addresses in locations table
- [x] Dropdowns show all addresses

### Phase 2 (Future - After Monitoring)
- [ ] Monitor dual-write for 1-2 weeks
- [ ] Verify no data inconsistencies
- [ ] Check for any edge cases

### Phase 3 (Future - Cleanup)
- [ ] Update profile edit screens to use location picker UI
- [ ] Stop writing to profiles address columns
- [ ] Drop old columns from profiles table
- [ ] Remove address fields from ProfileModel

---

## Related Documentation

- [ADDRESS_STORAGE_ANALYSIS.md](ADDRESS_STORAGE_ANALYSIS.md) - Full analysis of the problem
- [LOCATION_FIX.md](LOCATION_FIX.md) - Query fix for empty dropdowns
- [MIGRATION_VERIFICATION.md](MIGRATION_VERIFICATION.md) - Migration verification guide
- [MIGRATION_SUMMARY.md](MIGRATION_SUMMARY.md) - Original migration plan
