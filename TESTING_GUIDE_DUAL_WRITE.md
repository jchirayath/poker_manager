# Testing Guide: Dual-Write Implementation

## Quick Testing Checklist

This guide helps you verify that the dual-write implementation is working correctly.

---

## Prerequisites

Before testing:
- [ ] Migration `030_migrate_addresses_to_locations.sql` applied
- [ ] App rebuilt with latest code changes
- [ ] Access to Supabase database for verification queries

---

## Test 1: Verify Migrated Data

### Steps:
1. Log into the app
2. Go to Create Game screen
3. Select a group that has existing members

### Expected Results:
- ✅ Location dropdown shows addresses
- ✅ Addresses have labels like "FirstName's Address"
- ✅ Selecting players shows their personal locations

### Database Verification:
```sql
-- Should show migrated locations
SELECT COUNT(*) FROM locations WHERE profile_id IS NOT NULL AND is_primary = true;

-- Should match number of profiles with addresses
SELECT COUNT(*) FROM profiles WHERE street_address IS NOT NULL AND street_address != '';
```

### If It Fails:
- Check [LOCATION_FIX.md](LOCATION_FIX.md) - query may not be fetching correctly
- Verify migration ran: `SELECT * FROM locations LIMIT 5`

---

## Test 2: Update Existing User Address (Dual-Write Test)

### Steps:
1. Go to a user's profile (your own or edit another user)
2. Note the current address
3. Update the address fields:
   - Street: "123 New Street"
   - City: "New City"
   - State: "NY"
   - Postal: "12345"
   - Country: "USA"
4. Save the profile
5. Go to Create Game screen
6. Check location dropdown

### Expected Results:
- ✅ Profile saves successfully
- ✅ Updated address appears in location dropdown
- ✅ Label shows as "FirstName's Address"
- ✅ Old address is replaced (not duplicated)

### Database Verification:
```sql
-- Check profiles table was updated
SELECT id, first_name, street_address, city, primary_location_id
FROM profiles
WHERE id = 'your-user-id';

-- Check locations table was updated
SELECT id, profile_id, street_address, city, label, is_primary, updated_at
FROM locations
WHERE profile_id = 'your-user-id' AND is_primary = true;

-- Verify data matches
SELECT
  p.street_address as profile_street,
  l.street_address as location_street,
  p.city as profile_city,
  l.city as location_city,
  CASE WHEN p.street_address = l.street_address THEN 'MATCH' ELSE 'MISMATCH' END as street_match,
  CASE WHEN p.city = l.city THEN 'MATCH' ELSE 'MISMATCH' END as city_match
FROM profiles p
JOIN locations l ON l.id = p.primary_location_id
WHERE p.id = 'your-user-id';
```

### Debug Logs to Check:
Look for these in Flutter console:
```
🔵 Updating profile for user: [user-id] with updates: ...
📍 Updating existing primary location for user: [user-id]
✅ Profile update successful
```

### If It Fails:
- **Profile updated but not in dropdown**: Check debug logs for location sync errors
- **Data doesn't match**: Location sync may have failed, try saving profile again
- **No primary_location_id**: Dual-write didn't create location, check RLS policies

---

## Test 3: Create New Local User (Dual-Write Test)

### Steps:
1. Go to Groups → Select a group → Add Member → Create Local User
2. Fill in user details:
   - First Name: "Test"
   - Last Name: "User"
   - Street: "456 Test Ave"
   - City: "Test City"
   - State: "CA"
   - Postal: "90210"
3. Save the user
4. Go to Create Game screen
5. Select the new user as a player
6. Check location dropdown

### Expected Results:
- ✅ User created successfully
- ✅ User's address appears in location dropdown
- ✅ Label shows as "Test's Address"
- ✅ Location is marked as primary

### Database Verification:
```sql
-- Check user was created in profiles
SELECT id, first_name, last_name, street_address, city, primary_location_id, is_local_user
FROM profiles
WHERE first_name = 'Test' AND last_name = 'User'
ORDER BY created_at DESC
LIMIT 1;

-- Check location was created
SELECT l.*
FROM locations l
JOIN profiles p ON p.primary_location_id = l.id
WHERE p.first_name = 'Test' AND p.last_name = 'User'
ORDER BY l.created_at DESC
LIMIT 1;
```

### Debug Logs to Check:
```
📍 Creating new primary location for user: [user-id]
```

### If It Fails:
- **User created but no location**: Check if `_syncAddressToLocation()` was called
- **Location not visible**: Check RLS policies, verify user is in group_members
- **No primary_location_id**: Dual-write failed, check error logs

---

## Test 4: Verify No Duplication

### Steps:
1. Pick a user who already has an address
2. Edit their profile and update address
3. Save
4. Edit again and update address again
5. Save
6. Check location dropdown

### Expected Results:
- ✅ Only ONE address appears for the user
- ✅ Address is the most recent one
- ✅ No duplicate "FirstName's Address" entries

### Database Verification:
```sql
-- Should return 0 or 1 row per user
SELECT profile_id, COUNT(*) as primary_count
FROM locations
WHERE is_primary = true
GROUP BY profile_id
HAVING COUNT(*) > 1;

-- Check specific user has only one primary location
SELECT id, label, street_address, is_primary, updated_at
FROM locations
WHERE profile_id = 'your-user-id'
ORDER BY updated_at DESC;
```

### If It Fails:
- **Multiple primary locations**: Bug in `_syncAddressToLocation()`, manually set extras to `is_primary = false`
- **Duplicate entries**: Clear duplicates and test profile update again

---

## Test 5: Empty Address Handling

### Steps:
1. Edit a user's profile
2. Clear all address fields (leave them empty)
3. Save
4. Check location dropdown

### Expected Results:
- ✅ Profile saves successfully
- ✅ User's location does NOT appear in dropdown (or shows as removed)
- ✅ No errors in console

### Database Verification:
```sql
-- Check profile has NULL address
SELECT id, first_name, street_address, city, primary_location_id
FROM profiles
WHERE id = 'your-user-id';

-- Location should still exist but might be outdated
SELECT * FROM locations WHERE profile_id = 'your-user-id';
```

### If It Fails:
- **Error on save**: Check if dual-write handles empty addresses correctly
- **Old address still shows**: Location not cleared, may need manual cleanup

---

## Test 6: Group Location Query

### Steps:
1. Create Game screen
2. Don't select any players
3. Check location dropdown

### Expected Results:
- ✅ Shows only group-level locations (group_id set, profile_id NULL)
- ✅ Does NOT show personal locations

### Then:
4. Select 2-3 players
5. Check location dropdown again

### Expected Results:
- ✅ Shows group locations
- ✅ PLUS shows selected players' personal locations
- ✅ Does NOT show unselected players' locations

### Database Verification:
```sql
-- This is what the query should return (replace group-id)
SELECT l.id, l.label, l.street_address, l.group_id, l.profile_id
FROM locations l
WHERE l.group_id = 'your-group-id'
   OR l.profile_id IN (
     SELECT user_id FROM group_members WHERE group_id = 'your-group-id'
   )
ORDER BY l.is_primary DESC;
```

### If It Fails:
- **All locations showing**: Filtering logic broken in `_getFilteredLocations()`
- **No locations showing**: Query in `getGroupLocations()` not working

---

## Test 7: RLS Policy Verification

### Steps:
1. Log in as User A
2. Edit User A's profile, add address
3. Log in as User B (different user, same group)
4. Try to create a game
5. Check if User A's address appears in dropdown

### Expected Results:
- ✅ User A can see their own address
- ✅ User B (in same group) can see User A's address
- ✅ User C (not in group) cannot see User A's address

### Database Verification:
```sql
-- Check RLS policies exist
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'locations';

-- Test policy logic (run as specific user)
SET ROLE authenticated;
SET request.jwt.claims.sub TO 'user-id';
SELECT * FROM locations WHERE profile_id = 'another-user-id';
-- Should work if in same group
```

### If It Fails:
- **Can't see own locations**: RLS policy too restrictive
- **Can see others' locations outside group**: RLS policy too permissive
- **Can't create locations**: INSERT policy blocking

---

## Test 8: Performance Check

### Steps:
1. Add 50+ users to a group (use local users for testing)
2. Go to Create Game screen
3. Select all players
4. Check location dropdown load time

### Expected Results:
- ✅ Dropdown loads in < 2 seconds
- ✅ No duplicate queries in console
- ✅ No performance degradation

### Database Verification:
```sql
-- Check if indexes exist
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE tablename = 'locations';

-- Should include:
-- idx_locations_profile_id
-- idx_profiles_primary_location
```

### If It Fails:
- **Slow loading**: Add indexes, optimize query
- **Multiple queries**: Caching issue in provider

---

## Summary Checklist

After running all tests:

- [ ] Migrated addresses visible in dropdown
- [ ] Profile updates sync to locations table
- [ ] New users get locations created automatically
- [ ] No duplicate locations created
- [ ] Empty addresses handled correctly
- [ ] Location filtering by players works
- [ ] RLS policies enforce correct access
- [ ] Performance is acceptable

## Success Criteria

All tests should pass with:
- ✅ No errors in console
- ✅ Data consistent between profiles and locations tables
- ✅ All addresses visible in dropdowns
- ✅ Proper labels displayed
- ✅ No duplicates

## If Tests Fail

1. Check [MIGRATION_VERIFICATION.md](MIGRATION_VERIFICATION.md) for troubleshooting
2. Review [DUAL_WRITE_IMPLEMENTATION.md](DUAL_WRITE_IMPLEMENTATION.md) for implementation details
3. Verify debug logs for specific error messages
4. Run database verification queries to check data integrity

## Related Documentation

- [DUAL_WRITE_IMPLEMENTATION.md](DUAL_WRITE_IMPLEMENTATION.md) - Implementation details
- [LOCATION_FIX.md](LOCATION_FIX.md) - Query fix explanation
- [ADDRESS_STORAGE_ANALYSIS.md](ADDRESS_STORAGE_ANALYSIS.md) - Full analysis
- [MIGRATION_VERIFICATION.md](MIGRATION_VERIFICATION.md) - Complete verification guide
