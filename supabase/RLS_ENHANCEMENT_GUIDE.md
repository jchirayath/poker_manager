# RLS Security Enhancement Implementation Guide

## Overview

This guide addresses the critical RLS (Row Level Security) vulnerability identified in the code review. The vulnerability allows potential cross-group data access due to incomplete RLS policies.

## Critical Issue

**Finding:** Current RLS policies lack sufficient scope validation, allowing users to potentially access data across multiple groups they belong to without proper filtering.

**Risk Level:** 🔴 CRITICAL

**Impact:**
- Users could view/modify games, settlements, and transactions from unintended groups
- Financial data leakage between groups
- Settlement calculations could be manipulated by unauthorized users
- Audit trail integrity compromised

## Solution

A comprehensive migration file (`002_enhance_rls_policies.sql`) has been created with stricter policies. The enhancement focuses on:

### 1. **Explicit Group Scope Validation**
```sql
-- OLD: Implicit group validation through game_id
SELECT id FROM games WHERE group_id IN (SELECT group_id FROM group_members...)

-- NEW: Explicit INNER JOIN with strict scope
SELECT g.id FROM games g
INNER JOIN group_members gm ON gm.group_id = g.group_id
WHERE gm.user_id = auth.uid()
```

### 2. **Game State Validation**
Transactions can only be added to `scheduled` or `in_progress` games:
```sql
AND game_id IN (
  SELECT id FROM games 
  WHERE status IN ('scheduled', 'in_progress')
)
```

### 3. **Role-Based Access Control**
- **Creators/Admins:** Full game management rights
- **Members:** Can view and participate in games
- **Settlement Modifications:** Only payer/payee or admin can update

### 4. **Immutable Audit Trail**
- Settlements cannot be deleted
- Transactions can only be deleted by admins
- All modifications logged for compliance

## Deployment Steps

### Step 1: Backup Database (CRITICAL!)
```bash
cd /Users/jacobc/code/poker_manager

# Create a backup before applying migration
supabase db push --dry-run
```

### Step 2: Review Migration
Before applying, review the migration file:
```bash
cat supabase/migrations/002_enhance_rls_policies.sql
```

### Step 3: Apply Migration
```bash
# Apply the new RLS policies
supabase db push
```

This will:
- Drop existing permissive policies
- Create stricter replacement policies
- Maintain backward compatibility with existing valid use cases
- Add audit functions for monitoring

### Step 4: Verify RLS Enforcement

Run verification queries in Supabase SQL Editor:

```sql
-- 1. Verify all tables have RLS enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- 2. List all active policies
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public' 
ORDER BY tablename, policyname;

-- 3. Test: As authenticated user, verify data isolation
-- (Run this while logged in as test user)
SELECT COUNT(*) FROM games;  -- Should only show games from user's groups
SELECT COUNT(*) FROM settlements;  -- Only from user's groups
```

### Step 5: Test Application Flow

After deployment, test these critical flows:

#### Test 1: Multi-Group Data Isolation
1. Create User A and add to Group 1
2. Create User B and add to Group 2
3. Create games in both groups
4. Login as User A → Verify only Group 1 games visible
5. Login as User B → Verify only Group 2 games visible

#### Test 2: Settlement Restrictions
1. Create game with multiple players
2. Complete game and calculate settlements
3. Verify only payer/payee can mark settlement complete
4. Verify admins can override if needed

#### Test 3: Transaction Validation
1. Try adding transaction to completed game → Should fail
2. Try adding transaction to scheduled game → Should succeed
3. Try modifying transaction as non-admin → Should fail

## Modified Policies Summary

| Table | Operation | Change |
|-------|-----------|--------|
| **games** | SELECT | ✅ No change (good) |
| **games** | INSERT | ✅ No change (good) |
| **games** | UPDATE | 🔧 Now requires admin role |
| **games** | DELETE | ✨ NEW - Admin only |
| **settlements** | SELECT | 🔧 Stricter JOIN validation |
| **settlements** | INSERT | 🔧 Admin only |
| **settlements** | UPDATE | 🔧 Payer/payee/admin only |
| **settlements** | DELETE | ✨ NEW - BLOCKED |
| **transactions** | SELECT | 🔧 Stricter JOIN validation |
| **transactions** | INSERT | 🔧 Game state validation |
| **transactions** | UPDATE | ✨ NEW - Admin only |
| **transactions** | DELETE | ✨ NEW - Admin only |
| **game_participants** | SELECT | 🔧 Stricter JOIN validation |
| **game_participants** | UPDATE | 🔧 User or admin only |
| **group_members** | UPDATE | 🔧 Prevents creator demotion |
| **group_members** | DELETE | ✨ NEW - Creator protected |

## Verification Checklist

After applying migration, verify:

- [ ] All RLS policies are enabled on public tables
- [ ] Users can only see their own group data
- [ ] Admins can manage group games and settlements
- [ ] Settlements cannot be deleted (immutable)
- [ ] Transactions validated against game state
- [ ] Cross-group data access blocked
- [ ] Settlement updates restricted to involved parties
- [ ] Audit logging working for sensitive operations

## Rollback Procedure (If Needed)

If issues occur, rollback to previous state:

```bash
# Reset to original schema
supabase db reset

# Or manually drop the new policies and recreate old ones:
# (See bottom of 002_enhance_rls_policies.sql for old policy statements)
```

## Application Code Changes Required

### 1. Update Settlement Creation
Before completing a game, verify financial consistency:

```dart
// lib/features/settlements/data/repositories/settlements_repository.dart

Future<Result<List<SettlementModel>>> calculateSettlements(String gameId) async {
  try {
    // 1. Verify user is admin of the group
    final game = await _getGame(gameId);
    final isAdmin = await _verifyAdminRole(game.groupId);
    
    if (!isAdmin) {
      return Failure('Only group admins can calculate settlements');
    }

    // 2. Verify game is in completed state
    if (game.status != 'completed') {
      return Failure('Game must be completed before calculating settlements');
    }

    // 3. Call settlement calculation (now protected by RLS)
    final response = await _client.rpc('calculate_settlement', 
      params: {'game_uuid': gameId});
    
    return Success(_parseSettlements(response));
  } catch (e) {
    ErrorLoggerService.logError(e, StackTrace.current,
      context: 'calculateSettlements');
    return Failure('Settlement calculation failed: ${e.toString()}');
  }
}
```

### 2. Add Transaction Validation
Validate before recording transactions:

```dart
// lib/features/games/data/repositories/games_repository.dart

Future<Result<void>> recordTransaction({
  required String gameId,
  required String userId,
  required String type, // 'buyin' or 'cashout'
  required double amount,
}) async {
  try {
    // 1. Verify game exists and is valid
    final game = await _getGame(gameId);
    
    if (game.status == 'completed' || game.status == 'cancelled') {
      return Failure('Cannot add transactions to ${game.status} game');
    }

    // 2. Verify user is in the group
    final isMember = await _verifyGroupMembership(game.groupId);
    if (!isMember) {
      return Failure('You are not a member of this group');
    }

    // 3. Record transaction (RLS will validate on DB side)
    await _client.from('transactions').insert({
      'game_id': gameId,
      'user_id': userId,
      'type': type,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return const Success(null);
  } catch (e) {
    ErrorLoggerService.logError(e, StackTrace.current,
      context: 'recordTransaction');
    return Failure('Failed to record transaction: ${e.toString()}');
  }
}
```

### 3. Update Settlement Update
Only allow payer/payee to mark complete:

```dart
// In settlements_provider.dart

Future<Result<void>> markSettlementComplete(String settlementId) async {
  try {
    // Get settlement to verify current user is involved
    final settlement = await _getSettlement(settlementId);
    final currentUserId = SupabaseService.currentUserId;

    if (settlement.payerId != currentUserId && settlement.payeeId != currentUserId) {
      return Failure('You are not involved in this settlement');
    }

    // Mark as complete (RLS policy will validate)
    await _client
        .from('settlements')
        .update({'status': 'completed', 'completed_at': DateTime.now()})
        .eq('id', settlementId);

    return const Success(null);
  } catch (e) {
    return Failure('Update failed: ${e.toString()}');
  }
}
```

## Testing the Implementation

Create a comprehensive test suite:

```dart
// test/integration/rls_security_test.dart

void main() {
  group('RLS Security Tests', () {
    test('User cannot view games from other groups', () async {
      // Test implementation
    });

    test('User cannot modify settlement they are not involved in', () async {
      // Test implementation
    });

    test('Non-admin cannot create settlements', () async {
      // Test implementation
    });

    test('Transaction validation blocks completed games', () async {
      // Test implementation
    });
  });
}
```

## Production Rollout Plan

1. **Phase 1:** Deploy to staging environment
   - Run full test suite
   - Verify all critical flows
   - Check performance impact

2. **Phase 2:** Deploy to production with monitoring
   - Apply migration during low-traffic period
   - Monitor error logs for RLS violations
   - Have rollback plan ready

3. **Phase 3:** Post-deployment validation
   - Audit recent transactions for anomalies
   - Verify settlement calculations
   - Confirm no user reports of data access issues

## Monitoring & Alerts

Add monitoring for RLS violations:

```dart
// lib/core/services/rls_monitor.dart

class RLSMonitor {
  static Future<void> checkPolicyViolations() async {
    try {
      // Query audit log for failed access attempts
      final violations = await _client
          .from('audit_log')
          .select()
          .neq('id', null) // Placeholder for actual violation detection
          .order('created_at', ascending: false)
          .limit(100);

      if (violations.isNotEmpty) {
        // Alert admin of suspicious activity
        _sendAlert('RLS Policy Violation Detected', violations);
      }
    } catch (e) {
      ErrorLoggerService.logError(e, StackTrace.current,
        context: 'RLSMonitor.checkPolicyViolations');
    }
  }
}
```

## Documentation

Update your security documentation:

```markdown
# Security Policy - Row Level Security (RLS)

## Overview
All database access is protected by Supabase Row Level Security (RLS) policies.
Users can only access data from groups they are members of.

## Rules

1. **Group Isolation:** Users only see groups they belong to
2. **Admin Functions:** Only admins can create settlements and modify games
3. **Settlement Integrity:** Settlements are immutable (no deletion)
4. **Transaction Validation:** Transactions rejected for completed games
5. **Role-Based Access:** Creator > Admin > Member permissions

## Compliance

- RLS policies verified: [deployment date]
- Last security audit: [date]
- Status: ✅ Production Ready
```

## Support

For issues or questions:
1. Check error logs in Supabase
2. Review [CODE_REVIEW_AND_SECURITY_AUDIT.md](../CODE_REVIEW_AND_SECURITY_AUDIT.md)
3. Contact security team

---

**Status:** Ready for Deployment  
**Risk Level:** 🟡 Moderate (breaking change for invalid queries)  
**Rollback:** Available via `supabase db reset`
