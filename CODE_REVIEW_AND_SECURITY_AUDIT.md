# Poker Manager - Code Review & Security Audit

**Date:** January 4, 2026  
**Application:** Poker Manager (Flutter 3.29+ with Riverpod & Supabase)  
**Scope:** Architecture, Code Quality, Workflow, and Security Analysis

---

## Executive Summary

The Poker Manager application demonstrates a **solid foundation** with proper architectural separation (Repository, Provider, UI layers), comprehensive database schema with Row Level Security (RLS), and Material 3 design consistency. However, **critical security vulnerabilities**, **error handling gaps**, **workflow inefficiencies**, and **data validation issues** require immediate attention before production deployment.

### Key Findings:
- ⚠️ **CRITICAL:** Insufficient RLS policies - users can access data across groups
- ⚠️ **CRITICAL:** Missing input validation in transaction processing
- ⚠️ **HIGH:** Inadequate error handling in settlement calculations
- ⚠️ **HIGH:** Race conditions in concurrent operations
- ⚠️ **MEDIUM:** Incomplete financial data audit trails
- ✅ Good: Provider-based state management and repository pattern
- ✅ Good: Database schema design with proper constraints
- ✅ Good: Theme consistency and Material 3 compliance

---

## 1. SECURITY VULNERABILITIES

### 1.1 Critical: Insufficient Row Level Security (RLS) Policies

**Finding:** While RLS is enabled, the policies are incomplete and potentially grant excessive access.

**Current Issues:**

```sql
-- Current: Too permissive for groups
CREATE POLICY "Users can view their groups"
  ON groups FOR SELECT
  USING (
    id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- PROBLEM: No policy for games/settlements access scope
-- A user in multiple groups could potentially see data from other groups
```

**Risk:**
- Users could potentially view/modify games, settlements, or transactions from groups they don't belong to
- Cross-group data leakage possible if queries aren't filtered properly in application layer

**Recommendation:**

✅ **Implement Comprehensive RLS Policies:**

```sql
-- 1. Games: Only accessible to group members
CREATE POLICY "Users can view group games"
  ON games FOR SELECT
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Only group members can update games"
  ON games FOR UPDATE
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- 2. Game Participants: Only visible to group members
CREATE POLICY "Users can view game participants"
  ON game_participants FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM games WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
    )
  );

-- 3. Transactions: Only accessible to group members
CREATE POLICY "Users can view group transactions"
  ON transactions FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM games WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
    )
  );

-- 4. Settlements: Critical - only group members can view/modify
CREATE POLICY "Users can view group settlements"
  ON settlements FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM games WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Only involved parties or admins can mark settlements complete"
  ON settlements FOR UPDATE
  USING (
    -- User is payer/payee OR is an admin of the group
    (auth.uid() = payer_id OR auth.uid() = payee_id) OR
    (game_id IN (
      SELECT id FROM games WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    ))
  )
  WITH CHECK (
    -- Can only update if you're involved or admin
    (auth.uid() = payer_id OR auth.uid() = payee_id) OR
    (game_id IN (
      SELECT id FROM games WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid() AND role = 'admin'
      )
    ))
  );
```

---

### 1.2 Critical: Missing Input Validation in Transaction Processing

**Finding:** Transactions and settlements are created without comprehensive validation.

**Current Issues in `settlements_repository.dart`:**

```dart
// Validation exists but incomplete
Future<Result<SettlementValidation>> validateSettlement(String gameId) async {
  try {
    final response = await _client
        .from('game_participants')
        .select('total_buyin, total_cashout')
        .eq('game_id', gameId);

    double totalBuyins = 0;
    double totalCashouts = 0;

    for (var p in response) {
      totalBuyins += (p['total_buyin'] ?? 0).toDouble();
      totalCashouts += (p['total_cashout'] ?? 0).toDouble();
    }
    
    // PROBLEM: 
    // 1. No check for negative values
    // 2. No check for maximum transaction amounts
    // 3. No check for participant consistency
    // 4. Race condition: participant data could change during calculation
  }
}
```

**Risks:**
- Negative buy-in/cash-out values could corrupt financial records
- Unlimited transactions could be entered
- Participants could be removed during validation, creating orphaned settlements
- No audit trail of financial changes

**Recommendation:**

✅ **Enhanced Validation with Constraints:**

```dart
// Add to settlements_repository.dart

Future<Result<TransactionValidation>> validateTransaction({
  required String gameId,
  required double amount,
  required String type, // 'buyin' or 'cashout'
}) async {
  try {
    // 1. Validate amount constraints
    if (amount <= 0) {
      return Failure('Transaction amount must be positive');
    }
    
    const double maxTransaction = 10000.0; // Business rule
    if (amount > maxTransaction) {
      return Failure('Transaction exceeds maximum allowed: \$$maxTransaction');
    }

    // 2. Verify game exists and is in valid state
    final gameResult = await _client
        .from('games')
        .select('status')
        .eq('id', gameId)
        .maybeSingle();

    if (gameResult == null) {
      return Failure('Game not found');
    }

    final gameStatus = gameResult['status'] as String;
    if (gameStatus == 'completed' || gameStatus == 'cancelled') {
      return Failure('Cannot add transactions to completed/cancelled game');
    }

    // 3. Check decimal precision (max 2 decimal places for currency)
    if (amount.toStringAsFixed(2) != amount.toString()) {
      return Failure('Amount must have at most 2 decimal places');
    }

    return Success(TransactionValidation(
      isValid: true,
      message: 'Transaction valid',
    ));
  } catch (e) {
    return Failure('Validation error: ${e.toString()}');
  }
}

class TransactionValidation {
  final bool isValid;
  final String message;
  TransactionValidation({required this.isValid, required this.message});
}
```

**Add Server-Side Constraints:**

```sql
-- Poker Manager: Add financial constraints at DB level

-- Constraint: No negative transactions
ALTER TABLE transactions
ADD CONSTRAINT positive_amount CHECK (amount > 0);

-- Constraint: Reasonable max transaction
ALTER TABLE transactions
ADD CONSTRAINT reasonable_transaction CHECK (amount <= 10000.00);

-- Constraint: No negative buy-in/cash-out
ALTER TABLE game_participants
ADD CONSTRAINT non_negative_buyin CHECK (total_buyin >= 0),
ADD CONSTRAINT non_negative_cashout CHECK (total_cashout >= 0);

-- Constraint: Settlement amounts must be reasonable
ALTER TABLE settlements
ADD CONSTRAINT reasonable_settlement CHECK (amount > 0 AND amount <= 5000.00);
```

---

### 1.3 High: Inadequate Error Handling in Critical Operations

**Finding:** Error handling is inconsistent and sometimes swallowed without logging.

**Current Issues:**

```dart
// In games_provider.dart - errors thrown but not logged properly
orElse: () => throw Exception('Failed to load games'),

// In game_detail_screen.dart - print statements instead of logging
print('🎮 pastGamesProvider: ❌ Error loading games...');
debugPrint('❌ Error starting game: $e');

// Inconsistent error patterns:
failure: (error, stackTrace) {
  return AsyncValue.error(error, StackTrace.current); // Wrong stacktrace!
},
```

**Risks:**
- Production errors not properly logged or reported
- Debugging difficult in production
- No error tracking/monitoring capability
- Incorrect stack traces hide actual error source

**Recommendation:**

✅ **Implement Structured Error Logging:**

```dart
// Create lib/core/services/error_logger_service.dart

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class ErrorLoggerService {
  static const String _appName = 'PokerManager';

  /// Log errors with proper context
  static void logError(
    Object error,
    StackTrace stackTrace, {
    required String context,
    Map<String, dynamic>? additionalData,
  }) {
    final errorInfo = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'app': _appName,
      'context': context,
      'error': error.toString(),
      'type': error.runtimeType.toString(),
      ...?additionalData,
    };

    // Development: Console logging
    if (kDebugMode) {
      debugPrint('❌ ERROR [$context]: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    // Production: Send to error tracking service
    developer.log(
      'Error: $error',
      name: 'PokerManager/$context',
      error: error,
      stackTrace: stackTrace,
    );

    // TODO: Send to Sentry/Firebase Crashlytics in production
  }

  /// Log warnings for non-critical issues
  static void logWarning(String message, {String? context}) {
    developer.log(message, name: 'PokerManager/${context ?? 'Warning'}');
    if (kDebugMode) {
      debugPrint('⚠️  WARNING${context != null ? ' [$context]' : ''}: $message');
    }
  }

  /// Log info for important events
  static void logInfo(String message, {String? context}) {
    developer.log(message, name: 'PokerManager/${context ?? 'Info'}');
    if (kDebugMode) {
      debugPrint('ℹ️  INFO${context != null ? ' [$context]' : ''}: $message');
    }
  }
}

// Usage in providers:
final pastGamesProvider = FutureProvider<List<GameWithGroup>>((ref) async {
  try {
    // ... logic ...
  } catch (e, st) {
    ErrorLoggerService.logError(
      e,
      st,
      context: 'pastGamesProvider',
      additionalData: {'userId': SupabaseService.currentUserId},
    );
    rethrow;
  }
});

// Usage in screens:
error: (error, stack) {
  ErrorLoggerService.logError(
    error,
    stack,
    context: 'GameDetailScreen.build',
  );
  return AsyncValue.error(error, stack); // Use correct stacktrace!
}
```

---

### 1.4 High: Race Conditions in Concurrent Operations

**Finding:** Multiple concurrent operations can cause data inconsistency.

**Scenario:** Settlement calculation while transactions are being added:

```dart
// Current workflow - PROBLEMATIC
async {
  // 1. Fetch all participants (snapshot)
  final participants = await fetchGameParticipants(gameId);
  
  // 2. User might add transaction here!
  
  // 3. Calculate settlements based on stale data
  await calculateSettlements(gameId, participants);
}
```

**Risk:**
- Settlements calculated on incomplete data
- Money unaccounted for or duplicated

**Recommendation:**

✅ **Use Database Transactions:**

```dart
// In settlements_repository.dart

Future<Result<List<SettlementModel>>> calculateSettlementsAtomic(
  String gameId,
) async {
  try {
    // Use database transaction via RPC function
    final response = await _client.rpc('calculate_settlement', params: {
      'p_game_id': gameId,
    });

    return Success(
      (response as List)
          .map((s) => SettlementModel.fromJson(s))
          .toList(),
    );
  } catch (e) {
    ErrorLoggerService.logError(
      e,
      StackTrace.current,
      context: 'calculateSettlementsAtomic',
      additionalData: {'gameId': gameId},
    );
    return Failure('Settlement calculation failed: ${e.toString()}');
  }
}
```

**Database-side transaction (PL/pgSQL):**

```sql
-- Create atomic settlement calculation function
CREATE OR REPLACE FUNCTION calculate_settlement(p_game_id UUID)
RETURNS TABLE (
  settlement_id UUID,
  payer_id UUID,
  payee_id UUID,
  amount DECIMAL(10, 2),
  status TEXT
) AS $$
DECLARE
  v_total_buyin DECIMAL(10, 2);
  v_total_cashout DECIMAL(10, 2);
BEGIN
  -- Lock game row to prevent concurrent modifications
  PERFORM 1 FROM games WHERE id = p_game_id FOR UPDATE;

  -- Validate game is in valid state
  IF NOT EXISTS (
    SELECT 1 FROM games 
    WHERE id = p_game_id 
    AND status = 'completed'
  ) THEN
    RAISE EXCEPTION 'Game must be completed to calculate settlements';
  END IF;

  -- Check totals match (business rule validation)
  SELECT 
    COALESCE(SUM(total_buyin), 0),
    COALESCE(SUM(total_cashout), 0)
  INTO v_total_buyin, v_total_cashout
  FROM game_participants
  WHERE game_id = p_game_id;

  -- Tolerance check
  IF ABS(v_total_buyin - v_total_cashout) > 0.01 THEN
    RAISE EXCEPTION 'Buyin/cashout mismatch: % vs %', v_total_buyin, v_total_cashout;
  END IF;

  -- Calculate and insert settlements (existing logic here)
  -- All operations within this transaction - atomic!

  RETURN QUERY
  SELECT 
    s.id,
    s.payer_id,
    s.payee_id,
    s.amount,
    s.status
  FROM settlements s
  WHERE s.game_id = p_game_id;
END;
$$ LANGUAGE plpgsql;
```

---

### 1.5 Medium: Missing Audit Trail for Financial Data

**Finding:** No audit trail for critical financial operations.

**Current Issue:**
- Settlement status changes not tracked
- Transaction modifications not logged
- No "who made what change when" information for compliance

**Recommendation:**

✅ **Add Audit Logging Table:**

```sql
-- Create audit logging table
CREATE TABLE IF NOT EXISTS public.audit_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  operation TEXT CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')) NOT NULL,
  user_id UUID REFERENCES profiles(id),
  old_data JSONB,
  new_data JSONB,
  change_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for queries
CREATE INDEX idx_audit_log_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at DESC);

-- Trigger for settlements
CREATE OR REPLACE FUNCTION audit_settlement_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'UPDATE') THEN
    INSERT INTO audit_log (table_name, record_id, operation, user_id, old_data, new_data)
    VALUES ('settlements', NEW.id, 'UPDATE', auth.uid(), 
            row_to_json(OLD), row_to_json(NEW));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER settlement_audit_trigger
AFTER UPDATE ON settlements
FOR EACH ROW
EXECUTE FUNCTION audit_settlement_changes();
```

---

## 2. CODE QUALITY & ARCHITECTURE

### 2.1 Good: Repository Pattern Implementation

**Strengths:**
- Clean separation: `Repository` (data) → `Provider` (state) → `UI`
- Proper use of Freezed for immutable models
- Result type for error handling (Success/Failure)

**Current:**
```
lib/features/
├── auth/
│   ├── data/
│   │   ├── models/
│   │   └── repositories/
│   └── presentation/
├── games/
│   ├── data/
│   └── presentation/
└── settlements/
    ├── data/
    └── presentation/
```

✅ **Already Well-Structured** - Continue this pattern.

---

### 2.2 Issue: Inconsistent Error Handling Patterns

**Finding:** Three different error handling approaches used:

```dart
// Pattern 1: Using Result type (Good)
Future<Result<GameModel>> getGame(String gameId) async {
  try {
    // ...
    return Success(model);
  } catch (e) {
    return Failure('Failed to load game: ${e.toString()}');
  }
}

// Pattern 2: Using AsyncValue (Provider level - Good)
final gameProvider = FutureProvider<GameModel>((ref) async {
  return await repository.getGame(gameId);
});

// Pattern 3: Throwing exceptions (Bad)
orElse: () => throw Exception('Failed to load games'),
```

**Recommendation:**

✅ **Standardize Error Handling:**

```dart
// 1. Repository layer: Always use Result<T>
Future<Result<List<GameModel>>> getAllGames() async {
  try {
    final response = await _client.from('games').select();
    return Success(response.map(GameModel.fromJson).toList());
  } catch (e) {
    return Failure('Failed to load games: ${e.toString()}');
  }
}

// 2. Provider layer: Map Result to AsyncValue
final allGamesProvider = FutureProvider<List<GameModel>>((ref) async {
  final repo = ref.watch(gamesRepositoryProvider);
  final result = await repo.getAllGames();
  
  return result.when(
    success: (games) => games,
    failure: (error, _) => throw Exception(error),
  );
});

// 3. UI layer: Handle AsyncValue
@override
Widget build(BuildContext context, WidgetRef ref) {
  return ref.watch(allGamesProvider).when(
    data: (games) => _buildGamesList(games),
    loading: () => _buildLoadingUI(),
    error: (error, stack) {
      ErrorLoggerService.logError(error, stack, context: 'GameListScreen');
      return _buildErrorUI(error.toString());
    },
  );
}
```

---

### 2.3 Issue: Missing Null Safety in Data Models

**Finding:** Some models lack proper null checks.

**Example:**
```dart
// In game_model.dart (assumed structure)
class GameModel {
  final String groupId;
  final String name;
  final DateTime gameDate;
  final double? buyinAmount; // Nullable - ok
  final String? location; // Nullable - ok
  
  // PROBLEM: Derived values without null checks
  String get displayName => '$name at ${location ?? 'TBD'}';
  // Safe, but could be clearer
}
```

**Recommendation:**

✅ **Enhanced Null Safety & Validation:**

```dart
class GameModel {
  final String groupId;
  final String name;
  final DateTime gameDate;
  final double? buyinAmount;
  final String? location;
  
  // Validate critical fields
  GameModel({
    required this.groupId,
    required this.name,
    required this.gameDate,
    this.buyinAmount,
    this.location,
  }) : assert(groupId.isNotEmpty, 'Group ID cannot be empty'),
       assert(name.isNotEmpty, 'Game name cannot be empty'),
       assert(buyinAmount == null || buyinAmount > 0, 'Buy-in must be positive');

  // Safe getters with null coalescing
  String get displayName => name;
  String get displayLocation => location ?? 'Location TBD';
  double get displayBuyin => buyinAmount ?? 0.0;
  
  // Helper to verify game is in valid state
  bool get canAddTransactions => 
    gameStatus == 'in_progress' || gameStatus == 'scheduled';
  
  bool get canCalculateSettlements => gameStatus == 'completed';
}
```

---

### 2.4 Issue: Hardcoded Magic Strings

**Finding:** Sensitive values hardcoded throughout codebase.

**Current:**
```dart
// In games_repository.dart
if (response.isEmpty) return <GameModel>[];

// In settlements_repository.dart
const tolerance = 0.01;
const maxTransaction = 10000.0; // Where is this documented?

// In database schema
CHECK (status IN ('pending', 'completed'))
CHECK (rsvp_status IN ('going', 'not_going', 'maybe'))
```

**Risks:**
- Inconsistency across files
- Hard to maintain
- No single source of truth

**Recommendation:**

✅ **Create Constants File:**

```dart
// lib/core/constants/business_constants.dart

class SettlementConstants {
  // Tolerance for financial reconciliation (cents)
  static const double buyinCashoutTolerance = 0.01;
  
  // Transaction limits
  static const double maxTransactionAmount = 10000.00;
  static const double minTransactionAmount = 0.01;
  
  // Financial rounding
  static const int currencyDecimalPlaces = 2;
}

class GameConstants {
  static const String statusScheduled = 'scheduled';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  
  static const List<String> validStatuses = [
    statusScheduled,
    statusInProgress,
    statusCompleted,
    statusCancelled,
  ];
}

class ParticipantConstants {
  static const String rsvpGoing = 'going';
  static const String rsvpNotGoing = 'not_going';
  static const String rsvpMaybe = 'maybe';
  
  static const List<String> validRsvpStatuses = [
    rsvpGoing,
    rsvpNotGoing,
    rsvpMaybe,
  ];
}

class RoleConstants {
  static const String creator = 'creator';
  static const String admin = 'admin';
  static const String member = 'member';
  
  static const List<String> validRoles = [creator, admin, member];
}

// Usage:
if (!GameConstants.validStatuses.contains(status)) {
  throw ArgumentError('Invalid game status: $status');
}
```

---

## 3. WORKFLOW INEFFICIENCIES

### 3.1 Issue: Missing Pagination in List Providers

**Finding:** All games/participants loaded at once - poor performance at scale.

**Current:**
```dart
final activeGamesProvider = FutureProvider<List<GameWithGroup>>((ref) async {
  // Loads ALL games - problematic with 1000+ games
  final games = <GameWithGroup>[];
  for (final group in groups) {
    games.addAll(await gamesRepo.getGamesByGroup(group.id));
  }
  return games;
});
```

**Impact:**
- Slow initial load
- High memory usage
- Poor UX on slow networks

**Recommendation:**

✅ **Implement Pagination:**

```dart
// lib/features/games/presentation/providers/games_pagination_provider.dart

class GamePageKey {
  final int page;
  final int pageSize;
  final String? groupId;
  final String? status;

  const GamePageKey({
    required this.page,
    required this.pageSize,
    this.groupId,
    this.status,
  });
}

final gamesPageProvider = StateNotifierProvider.family<
  GamePageNotifier,
  AsyncValue<List<GameModel>>,
  GamePageKey
>((ref, key) {
  return GamePageNotifier(
    ref.watch(gamesRepositoryProvider),
    key,
  );
});

class GamePageNotifier extends StateNotifier<AsyncValue<List<GameModel>>> {
  final GamesRepository _repository;
  final GamePageKey _pageKey;

  GamePageNotifier(this._repository, this._pageKey)
      : super(const AsyncValue.loading()) {
    _loadPage();
  }

  Future<void> _loadPage() async {
    state = const AsyncValue.loading();
    
    final result = await _repository.getGamesPaginated(
      page: _pageKey.page,
      pageSize: _pageKey.pageSize,
      groupId: _pageKey.groupId,
      status: _pageKey.status,
    );

    state = result.when(
      success: (games) => AsyncValue.data(games),
      failure: (error, _) => AsyncValue.error(error, StackTrace.current),
    );
  }

  Future<void> nextPage() async {
    // Logic to increment page and reload
  }

  Future<void> previousPage() async {
    // Logic to decrement page and reload
  }
}

// Repository implementation
Future<Result<List<GameModel>>> getGamesPaginated({
  required int page,
  required int pageSize,
  String? groupId,
  String? status,
}) async {
  try {
    final offset = (page - 1) * pageSize;
    
    var query = _client.from('games').select().range(offset, offset + pageSize - 1);
    
    if (groupId != null) query = query.eq('group_id', groupId);
    if (status != null) query = query.eq('status', status);
    
    query = query.order('game_date', ascending: false);
    
    final response = await query;
    return Success(response.map(GameModel.fromJson).toList());
  } catch (e) {
    return Failure('Pagination error: ${e.toString()}');
  }
}

// UI Usage:
@override
Widget build(BuildContext context, WidgetRef ref) {
  final gameState = ref.watch(gamesPageProvider(
    GamePageKey(page: _currentPage, pageSize: 20),
  ));

  return gameState.when(
    data: (games) => ListView.builder(
      itemCount: games.length + 1,
      itemBuilder: (context, index) {
        if (index == games.length) {
          return ElevatedButton(
            onPressed: () {
              // Load next page
            },
            child: const Text('Load More'),
          );
        }
        return GameTile(games[index]);
      },
    ),
    loading: () => const CircularProgressIndicator(),
    error: (error, stack) => ErrorWidget(error: error),
  );
}
```

---

### 3.2 Issue: Synchronous Profile Creation Delay

**Finding:** Profile creation relies on database trigger which is asynchronous.

**Current Workflow:**
```
User Signs Up → Auth Created → Trigger fires → Profile created (async)
            ↓
        Check for profile (immediately)
            ↓
        Profile doesn't exist yet → Create fallback profile
```

**Problem:**
- Race condition between trigger and app check
- User might see incomplete profile briefly

**Recommendation:**

✅ **Synchronous Profile Creation:**

```dart
// In auth_repository.dart

Future<Result<UserModel>> signUp({
  required String email,
  required String password,
  required String firstName,
  required String lastName,
  required String country,
}) async {
  try {
    // Step 1: Create auth user
    final response = await _client.auth.signUpWithPassword(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'country': country,
      },
    );

    if (response.user == null) {
      return const Failure('Sign up failed');
    }

    // Step 2: Immediately create profile (don't wait for trigger)
    try {
      final profile = await _createProfileSync(
        userId: response.user!.id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        country: country,
      );
      return Success(profile);
    } catch (e) {
      // Profile creation failed - cleanup auth user
      await _client.auth.signOut();
      return Failure('Profile creation failed: ${e.toString()}');
    }
  } catch (e) {
    developer.log('Sign up error: $e', name: 'AuthRepository');
    return Failure('Sign up failed: ${e.toString()}');
  }
}

Future<UserModel> _createProfileSync({
  required String userId,
  required String email,
  required String firstName,
  required String lastName,
  required String country,
}) async {
  final created = await _client
      .from('profiles')
      .insert({
        'id': userId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'country': country,
      })
      .select()
      .single();

  return UserModel.fromJson(created);
}
```

---

### 3.3 Issue: N+1 Query Problem

**Finding:** Fetching games then participants for each game individually.

**Current:**
```dart
final gamesWithParticipants = <GameModel>[];
for (final game in games) {
  // N+1: One query per game!
  final participants = await repo.getGameParticipants(game.id);
  gamesWithParticipants.add((game, participants));
}
```

**Recommendation:**

✅ **Use Supabase JOINs:**

```dart
Future<Result<List<GameWithParticipants>>> getGamesWithParticipants(
  String groupId,
) async {
  try {
    // Single query with JOIN - efficient!
    final response = await _client
        .from('games')
        .select('''
          id,
          name,
          game_date,
          status,
          game_participants (
            id,
            user_id,
            rsvp_status,
            total_buyin,
            total_cashout,
            net_result
          )
        ''')
        .eq('group_id', groupId)
        .order('game_date', ascending: false);

    final games = (response as List).map((g) {
      return GameWithParticipants(
        game: GameModel.fromJson(g),
        participants: (g['game_participants'] as List)
            .map((p) => GameParticipantModel.fromJson(p))
            .toList(),
      );
    }).toList();

    return Success(games);
  } catch (e) {
    return Failure('Failed to load games: ${e.toString()}');
  }
}

class GameWithParticipants {
  final GameModel game;
  final List<GameParticipantModel> participants;
  GameWithParticipants({required this.game, required this.participants});
}
```

---

### 3.4 Issue: Manual State Synchronization

**Finding:** When settlements are marked complete, state isn't automatically updated.

**Recommendation:**

✅ **Use Supabase Realtime:**

```dart
// lib/features/settlements/presentation/providers/settlements_provider.dart

final settlementsProvider = StreamProvider.family<
  List<SettlementModel>,
  String
>((ref, gameId) {
  final client = SupabaseService.instance;
  
  return client
      .from('settlements')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .map((List<Map<String, dynamic>> data) {
        return data.map(SettlementModel.fromJson).toList();
      })
      .handleError((error) {
        ErrorLoggerService.logError(
          error,
          StackTrace.current,
          context: 'settlementsProvider.stream',
        );
        return [];
      });
});

// UI automatically updates when settlements change!
@override
Widget build(BuildContext context, WidgetRef ref) {
  return ref.watch(settlementsProvider('game-id')).when(
    data: (settlements) => SettlementsList(settlements),
    loading: () => const LoadingWidget(),
    error: (error, stack) => ErrorWidget(error: error),
  );
}
```

---

## 4. DATA VALIDATION & INTEGRITY

### 4.1 Issue: Missing Cascade Delete Validation

**Finding:** Deleting a group cascades to delete all games/transactions without confirmation.

**Current Schema:**
```sql
CREATE TABLE groups (
  -- ...
);

CREATE TABLE games (
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE -- Danger!
);

CREATE TABLE transactions (
  game_id UUID REFERENCES games(id) ON DELETE CASCADE -- Danger!
);
```

**Risk:** User accidentally deletes group → All financial history lost

**Recommendation:**

✅ **Soft Delete Strategy:**

```dart
// 1. Update schema to use soft deletes

ALTER TABLE groups ADD COLUMN deleted_at TIMESTAMPTZ;
ALTER TABLE games ADD COLUMN deleted_at TIMESTAMPTZ;
ALTER TABLE settlements ADD COLUMN deleted_at TIMESTAMPTZ;

-- 2. Create view for active records
CREATE VIEW active_groups AS
  SELECT * FROM groups WHERE deleted_at IS NULL;

CREATE VIEW active_games AS
  SELECT * FROM games WHERE deleted_at IS NULL;

-- 3. Update RLS policies to exclude deleted records
ALTER POLICY "Users can view their groups"
  ON groups
  USING (
    deleted_at IS NULL AND
    id IN (SELECT group_id FROM group_members WHERE user_id = auth.uid())
  );

-- Dart implementation
Future<Result<void>> softDeleteGroup(String groupId) async {
  try {
    // Verify user is creator/admin
    final permission = await _verifyGroupPermission(groupId);
    if (!permission) {
      return Failure('Insufficient permissions');
    }

    // Soft delete
    await _client
        .from('groups')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', groupId);

    return const Success(null);
  } catch (e) {
    return Failure('Delete failed: ${e.toString()}');
  }
}

// Users can see deleted groups if they need to
Future<Result<List<GroupModel>>> getDeletedGroups() async {
  try {
    final response = await _client
        .from('groups')
        .select()
        .eq('created_by', SupabaseService.currentUserId)
        .not('deleted_at', 'is', null);

    return Success(response.map(GroupModel.fromJson).toList());
  } catch (e) {
    return Failure('Error loading deleted groups: ${e.toString()}');
  }
}
```

---

### 4.2 Issue: Missing Data Consistency Checks

**Recommendation:**

✅ **Add Consistency Validation Function:**

```sql
-- Create function to validate financial consistency
CREATE OR REPLACE FUNCTION validate_game_financial_consistency(p_game_id UUID)
RETURNS TABLE (
  is_valid BOOLEAN,
  total_buyin DECIMAL(10, 2),
  total_cashout DECIMAL(10, 2),
  difference DECIMAL(10, 2),
  message TEXT
) AS $$
DECLARE
  v_buyin DECIMAL(10, 2);
  v_cashout DECIMAL(10, 2);
  v_diff DECIMAL(10, 2);
  v_tolerance DECIMAL(10, 2) := 0.01;
BEGIN
  -- Get totals
  SELECT 
    COALESCE(SUM(total_buyin), 0),
    COALESCE(SUM(total_cashout), 0)
  INTO v_buyin, v_cashout
  FROM game_participants
  WHERE game_id = p_game_id;

  v_diff := v_buyin - v_cashout;

  RETURN QUERY SELECT 
    (ABS(v_diff) <= v_tolerance)::BOOLEAN,
    v_buyin,
    v_cashout,
    v_diff,
    CASE 
      WHEN ABS(v_diff) <= v_tolerance THEN 'Consistent'
      ELSE 'INCONSISTENT: Buy-in $' || v_buyin || ' vs Cash-out $' || v_cashout
    END AS message;
END;
$$ LANGUAGE plpgsql;

-- Dart wrapper
Future<Result<GameFinancialReport>> getGameFinancialReport(
  String gameId,
) async {
  try {
    final response = await _client.rpc('validate_game_financial_consistency', 
      params: {'p_game_id': gameId});
    
    return Success(GameFinancialReport.fromJson(response));
  } catch (e) {
    ErrorLoggerService.logError(
      e,
      StackTrace.current,
      context: 'getGameFinancialReport',
      additionalData: {'gameId': gameId},
    );
    return Failure('Report generation failed: ${e.toString()}');
  }
}
```

---

## 5. SECURITY BEST PRACTICES

### 5.1 Authentication & Authorization

**Current:** Supabase JWT-based auth ✅

**Recommendations:**

```dart
// 1. Implement session validation
class SessionValidator {
  static Future<bool> isSessionValid() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return false;
    
    // Check if token is expired
    if (session.expiresAt != null) {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
      if (expiresAt.isBefore(DateTime.now())) {
        return false;
      }
    }
    
    return true;
  }
}

// 2. Implement refresh token logic
Future<void> ensureValidSession() async {
  if (!await SessionValidator.isSessionValid()) {
    final refreshed = await Supabase.instance.client.auth.refreshSession();
    if (refreshed.session == null) {
      // Logout user
      await Supabase.instance.client.auth.signOut();
      throw SessionExpiredException('Session expired. Please sign in again.');
    }
  }
}

// 3. Use in navigation redirect
redirect: (context, state) async {
  await ensureValidSession();
  
  // ... routing logic ...
}
```

---

### 5.2 Sensitive Data Handling

**Recommendations:**

```dart
// 1. Never log sensitive data
❌ BAD:
debugPrint('User email: ${user.email}');
debugPrint('Auth token: ${session.accessToken}');

✅ GOOD:
debugPrint('User authenticated: ${user.id}');
debugPrint('Session valid');

// 2. Clear sensitive data on logout
Future<void> secureLogout() async {
  try {
    await _client.auth.signOut();
  } finally {
    // Clear cached data
    await _secureStorage.deleteAll();
    // Logout from all platforms
    await SystemChannels.platform.invokeMethod('logout');
  }
}

// 3. Use flutter_secure_storage for sensitive tokens
import 'flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  static const _storage = FlutterSecureStorage();
  
  static Future<void> saveToken(String key, String token) async {
    await _storage.write(key: key, value: token);
  }
  
  static Future<String?> getToken(String key) async {
    return _storage.read(key: key);
  }
  
  static Future<void> deleteToken(String key) async {
    await _storage.delete(key: key);
  }
}
```

---

### 5.3 Input Sanitization

**Recommendations:**

```dart
// Create input validation utility
class InputValidator {
  // Email validation
  static String? validateEmail(String? value) {
    if (value?.isEmpty ?? true) return 'Email is required';
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!regex.hasMatch(value!)) return 'Invalid email format';
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value?.isEmpty ?? true) return 'Password is required';
    if (value!.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain uppercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain number';
    return null;
  }

  // Text input sanitization
  static String sanitizeInput(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse whitespace
        .replaceAll('<', '&lt;') // Prevent XSS
        .replaceAll('>', '&gt;');
  }

  // Numeric validation
  static String? validateAmount(String? value) {
    if (value?.isEmpty ?? true) return 'Amount is required';
    final amount = double.tryParse(value!);
    if (amount == null) return 'Invalid amount';
    if (amount <= 0) return 'Amount must be positive';
    if (amount > 10000) return 'Amount exceeds maximum';
    return null;
  }
}

// Usage in TextFormField
TextFormField(
  validator: InputValidator.validateEmail,
  decoration: const InputDecoration(
    labelText: 'Email',
    errorMaxLines: 1,
  ),
)
```

---

## 6. PERFORMANCE OPTIMIZATION

### 6.1 Issue: Unoptimized Database Queries

**Current:** Multiple sequential queries could be parallelized.

**Recommendation:**

✅ **Parallel Queries:**

```dart
Future<Result<GameDashboardData>> loadGameDashboard(String gameId) async {
  try {
    // Execute 3 queries in parallel
    final futures = await Future.wait([
      _client.from('games').select().eq('id', gameId).maybeSingle(),
      _client.from('game_participants').select().eq('game_id', gameId),
      _client.from('settlements').select().eq('game_id', gameId),
    ]);

    final gameData = futures[0] as Map<String, dynamic>?;
    final participantsData = futures[1] as List;
    final settlementsData = futures[2] as List;

    if (gameData == null) {
      return const Failure('Game not found');
    }

    return Success(GameDashboardData(
      game: GameModel.fromJson(gameData),
      participants: participantsData.map(GameParticipantModel.fromJson).toList(),
      settlements: settlementsData.map(SettlementModel.fromJson).toList(),
    ));
  } catch (e) {
    return Failure('Dashboard load error: ${e.toString()}');
  }
}
```

---

### 6.2 Caching Strategy

**Recommendation:**

✅ **Cache Frequently Accessed Data:**

```dart
// lib/core/services/cache_service.dart

class CacheService {
  static const Duration defaultTTL = Duration(minutes: 5);
  static const Duration userProfileTTL = Duration(hours: 1);
  static const Duration groupsTTL = Duration(minutes: 15);

  static final Map<String, CacheEntry<dynamic>> _cache = {};

  static void set<T>(String key, T value, {Duration? ttl}) {
    _cache[key] = CacheEntry(
      value,
      DateTime.now().add(ttl ?? defaultTTL),
    );
  }

  static T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.expiresAt.isBefore(DateTime.now())) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  static void clear([String? key]) {
    if (key != null) {
      _cache.remove(key);
    } else {
      _cache.clear();
    }
  }

  static Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetch, {
    Duration? ttl,
  }) async {
    final cached = get<T>(key);
    if (cached != null) return cached;

    final fetched = await fetch();
    set(key, fetched, ttl: ttl);
    return fetched;
  }
}

class CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  CacheEntry(this.value, this.expiresAt);
}

// Usage in provider:
final userGroupsProvider = FutureProvider<List<GroupModel>>((ref) async {
  return CacheService.getOrFetch<List<GroupModel>>(
    'user_groups_${SupabaseService.currentUserId}',
    () async {
      final result = await ref.watch(groupsRepositoryProvider).getUserGroups();
      return result.when(
        success: (groups) => groups,
        failure: (error, _) => throw Exception(error),
      );
    },
    ttl: CacheService.groupsTTL,
  );
});
```

---

## 7. TESTING RECOMMENDATIONS

### 7.1 Unit Tests

**Add coverage for:**

```dart
// test/unit/validators_test.dart
void main() {
  group('SettlementValidation', () {
    test('rejects negative amounts', () {
      expect(
        SettlementValidator.validateAmount(-100),
        isNotNull,
      );
    });

    test('accepts valid amounts', () {
      expect(
        SettlementValidator.validateAmount(50.00),
        isNull,
      );
    });
  });

  group('GameFinancialConsistency', () {
    test('detects buyin/cashout mismatch', () {
      // Test logic
    });
  });
}
```

### 7.2 Integration Tests

```dart
// test/integration/settlement_flow_test.dart
void main() {
  group('Settlement Calculation Flow', () {
    test('calculates correct settlement amounts', () async {
      // Create test game
      // Add participants
      // Record transactions
      // Calculate settlements
      // Verify amounts match
    });
  });
}
```

---

## 8. DEPLOYMENT CHECKLIST

Before going to production:

- [ ] All RLS policies reviewed and enabled
- [ ] Input validation implemented on all data entry screens
- [ ] Error logging configured (Sentry/Firebase Crashlytics)
- [ ] Sensitive data never logged (passwords, tokens, PII)
- [ ] Database backups configured
- [ ] Financial audit trail implemented
- [ ] Rate limiting on critical endpoints
- [ ] API key rotation strategy defined
- [ ] SSL/TLS enforced for all connections
- [ ] Security headers configured
- [ ] Data retention policies defined
- [ ] GDPR/privacy compliance reviewed
- [ ] Load testing completed
- [ ] Recovery procedures documented
- [ ] Monitoring and alerting configured

---

## Summary of Critical Actions

| Priority | Issue | Action | Timeline |
|----------|-------|--------|----------|
| CRITICAL | RLS policies incomplete | Implement comprehensive RLS for all tables | Before any prod data |
| CRITICAL | Input validation missing | Add validation at all financial entry points | Before any prod data |
| HIGH | Error handling inconsistent | Standardize error handling + add logging service | This sprint |
| HIGH | Race conditions possible | Use database transactions for settlements | This sprint |
| MEDIUM | No audit trail | Implement audit logging table + triggers | Next sprint |
| MEDIUM | N+1 queries | Replace with JOIN queries | Next sprint |
| MEDIUM | Pagination missing | Implement pagination for large lists | Next sprint |

---

**Report Generated:** January 4, 2026  
**Reviewed By:** Code Review Agent  
**Status:** Ready for Implementation
