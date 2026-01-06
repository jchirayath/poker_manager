# Security Risk 1.4: Race Conditions - Quick Deployment Guide

## Status
✅ **Implementation Complete** - Ready for deployment
- Database migration: `/supabase/migrations/017_add_atomic_settlement_calculation.sql` (396 lines)
- Dart code: `lib/features/settlements/data/repositories/settlements_repository.dart` (updated)
- Build status: ✅ 0 errors (97 analysis issues, none critical)

## What Was Fixed

| Aspect | Problem | Solution |
|--------|---------|----------|
| **Race Condition** | Multiple clients calculate settlements concurrently with stale data | Database row-level locking (FOR UPDATE) |
| **Money Inconsistency** | Participants added/removed during calculation | Atomic transaction at DB level |
| **Lock Management** | No mechanism to prevent concurrent calculations | settlement_calculation_locks table + RPC functions |
| **Idempotency** | Repeated calls could duplicate settlements | DB function returns existing if already calculated |
| **Audit Trail** | No record of calculation attempts | settlement_calculation_log table tracks all attempts |

## Pre-Deployment Checklist

```bash
# 1. Verify migration file exists
ls -la supabase/migrations/017_*.sql

# 2. Check build compiles
cd /Users/jacobc/code/poker_manager
flutter analyze 2>&1 | grep -i "settlement"
# Should show: 0 errors in settlements_repository.dart

# 3. Verify migration syntax (Supabase CLI)
supabase db pull --linked

# 4. Review migration dependencies
grep -E "CREATE FUNCTION|CREATE TABLE|CREATE INDEX" \
  supabase/migrations/017_*.sql | wc -l
# Should create ~6-7 objects
```

## Deployment Steps

### 1. Push Migration to Supabase

```bash
cd /Users/jacobc/code/poker_manager

# Push migration to linked Supabase project
supabase db push

# Expected output:
# Creating migration...
# Applying migration...
# ✓ Migration applied successfully
```

### 2. Verify RPC Functions Exist

Run in Supabase dashboard SQL editor:

```sql
-- Test 1: Check functions exist
SELECT proname FROM pg_proc 
WHERE proname LIKE 'calculate_settlement%' 
  OR proname LIKE 'acquire_settlement%' 
  OR proname LIKE 'release_settlement%'
  OR proname LIKE 'get_or_calculate%'
  OR proname LIKE 'cleanup_expired%';

-- Expected: 6 functions returned
--  - calculate_settlement_atomic
--  - acquire_settlement_lock
--  - release_settlement_lock
--  - get_or_calculate_settlements
--  - cleanup_expired_settlement_locks
--  - (trigger function: settlement_creation_log_trigger)

-- Test 2: Check tables exist
SELECT tablename FROM pg_tables 
WHERE tablename IN ('settlement_calculation_locks', 'settlement_calculation_log');

-- Expected: 2 tables returned
```

### 3. Test Lock Functions

```sql
-- Test lock acquisition
SELECT * FROM acquire_settlement_lock(
  '12345678-1234-5678-1234-567812345678'::UUID,
  '87654321-4321-8765-4321-876543218765'::UUID
);

-- Test lock release  
SELECT * FROM release_settlement_lock(
  '12345678-1234-5678-1234-567812345678'::UUID,
  '87654321-4321-8765-4321-876543218765'::UUID
);
```

### 4. Deploy App Update

```bash
# Build new version with updated code
flutter build apk --release
flutter build ios --release

# Deploy to app stores
# App will automatically use new atomic settlement calculation
```

### 5. Monitor Audit Trail

```sql
-- After deployment, monitor calculation attempts
SELECT game_id, status, COUNT(*) as count
FROM settlement_calculation_log
WHERE calculation_started_at > NOW() - INTERVAL '1 hour'
GROUP BY game_id, status;

-- Check for failures
SELECT * FROM settlement_calculation_log
WHERE status = 'failed'
ORDER BY calculation_started_at DESC
LIMIT 10;
```

## How It Works (Flow Diagram)

```
User marks game as complete
         ↓
   calculateSettlement(gameId)
         ↓
   Try to acquire lock
         ├─→ Lock obtained
         │    ├─→ Call: get_or_calculate_settlements()
         │    │    ├─→ Database locks game & participants (FOR UPDATE)
         │    │    ├─→ Check: settlements already exist?
         │    │    │   ├─→ YES: Return existing settlements (idempotent)
         │    │    │   └─→ NO: Calculate new settlements
         │    │    └─→ Log attempt to settlement_calculation_log
         │    │
         │    ├─→ Validate settlements (no self-payment, positive amount)
         │    ├─→ Return Success
         │    └─→ Finally: Release lock
         │
         └─→ Lock not obtained (already calculating)
              ├─→ Log warning
              └─→ Return: "Settlement calculation already in progress"
```

## Key Files Updated

### 1. Database Migration
**File:** `supabase/migrations/017_add_atomic_settlement_calculation.sql`
- 396 lines of SQL
- Creates: 6 functions, 2 tables, 3 constraints, 1 trigger
- No data loss, idempotent (safe to run multiple times)

**Key Functions:**
```sql
-- Main calculation function (atomic, with locking)
calculate_settlement_atomic(game_id)

-- Lock management
acquire_settlement_lock(game_id, user_id)
release_settlement_lock(game_id, user_id)

-- Idempotent retrieval
get_or_calculate_settlements(game_id)

-- Maintenance
cleanup_expired_settlement_locks()
```

### 2. Dart Repository
**File:** `lib/features/settlements/data/repositories/settlements_repository.dart`
- Updated `calculateSettlement()` method (lines 174-290)
- Added lock acquisition/release logic
- Structured error logging via ErrorLoggerService
- Finally block ensures lock always released

**Key Changes:**
```dart
// Before: Local calculation, no locks, race conditions possible
// After:
1. Acquire exclusive lock
2. Call atomic DB function (with row-level locking)
3. Validate results
4. Release lock in finally block
5. Structured logging at each step
```

## Troubleshooting

### Issue: Migration Fails to Apply

```bash
# Check migration syntax
cd /Users/jacobc/code/poker_manager
supabase db push --dry-run

# If error, check:
# 1. Does settlements table exist?
SELECT * FROM information_schema.tables WHERE table_name = 'settlements';

# 2. Are settlement columns correct?
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'settlements';
```

### Issue: Lock Functions Not Found

```bash
# Verify RPC functions in Supabase dashboard
# Settings → Database → Public Schema → Functions

# If missing, reapply migration:
supabase db push --linked
```

### Issue: Settlements Not Calculating

```bash
# Check audit trail for errors
SELECT * FROM settlement_calculation_log 
WHERE status = 'failed'
ORDER BY calculation_started_at DESC LIMIT 5;

# Check if locks are stuck
SELECT * FROM settlement_calculation_locks
WHERE acquired_at < NOW() - INTERVAL '5 minutes';
# These should be automatically replaced, but if stuck:
DELETE FROM settlement_calculation_locks 
WHERE acquired_at < NOW() - INTERVAL '10 minutes';
```

### Issue: Locks Timing Out

```bash
# Run cleanup manually (normally automatic)
SELECT cleanup_expired_settlement_locks();

# Increase timeout if needed (modify migration):
-- Change: v_lock_timeout INTERVAL := '5 minutes'
-- To: v_lock_timeout INTERVAL := '10 minutes'
-- Then: supabase db push
```

## Rollback Plan

### If Critical Issue Discovered

**Option 1: Disable Atomic Calculation (Quick)**
```dart
// In settlements_repository.dart, comment out lock logic:
// final lockAcquired = ...;
// if (!lockAcquired) { ... }

// Just use basic RPC:
final result = await _client.rpc('get_or_calculate_settlements', ...);
```

**Option 2: Full Rollback (if data corruption)**
```bash
# Create rollback migration that:
# 1. Removes atomic functions
# 2. Keeps settlement_calculation_log (audit trail)
# 3. Keeps all settlement data intact

supabase db push  # with rollback migration
```

**Note:** No data loss risk—settlements records are never deleted, only new calculations affected.

## Success Metrics

After deployment, verify:

```sql
-- 1. All functions callable
SELECT COUNT(*) FROM settlement_calculation_log;

-- 2. No orphaned locks (>5 min old)
SELECT COUNT(*) FROM settlement_calculation_locks 
WHERE acquired_at < NOW() - INTERVAL '5 minutes';
-- Should return: 0

-- 3. Successful calculations recorded
SELECT status, COUNT(*) FROM settlement_calculation_log 
GROUP BY status;
-- Should show: mostly 'success' and 'already_calculated'

-- 4. No constraint violations
SELECT constraint_name, COUNT(*) 
FROM information_schema.table_constraints 
WHERE table_name = 'settlements'
GROUP BY constraint_name;
```

## Monitoring Commands

Add these to your monitoring dashboard:

```bash
# Check latest settlement calculations
supabase functions invoke settlement-status

# Monitor lock contention
SELECT game_id, COUNT(*) as attempts
FROM settlement_calculation_log
WHERE calculation_started_at > NOW() - INTERVAL '1 hour'
GROUP BY game_id ORDER BY attempts DESC;

# Check performance
SELECT 
  AVG(EXTRACT(EPOCH FROM (calculation_completed_at - calculation_started_at))) as avg_duration_sec,
  MAX(EXTRACT(EPOCH FROM (calculation_completed_at - calculation_started_at))) as max_duration_sec
FROM settlement_calculation_log
WHERE calculation_completed_at IS NOT NULL
AND calculation_started_at > NOW() - INTERVAL '24 hours';
```

## Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| Code Review | Complete | ✅ |
| Build Verification | Complete | ✅ 0 errors |
| Migration Creation | Complete | ✅ 396 lines |
| Documentation | Complete | ✅ 3 docs |
| Supabase Deployment | Ready | ⏳ ~2 min |
| App Update Build | Ready | ⏳ ~10 min |
| App Store Deploy | Ready | ⏳ Depends on store |
| Monitoring Setup | Ready | ⏳ Optional |

**Total Deployment Time:** ~30 minutes (end-to-end)

---

**Questions?** See: `RACE_CONDITIONS_FIX.md` for detailed technical documentation
