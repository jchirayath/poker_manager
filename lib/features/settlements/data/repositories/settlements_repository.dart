import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/error_logger_service.dart';
import '../../../../core/constants/business_constants.dart';
import '../../../../shared/models/result.dart';
import '../models/settlement_model.dart';

class SettlementsRepository {
  final SupabaseClient _client = SupabaseService.instance;

  /// Validates that an amount is properly formatted and within bounds
  /// Returns error message if invalid, null if valid
  static String? validateAmount(
    double amount, {
    double minAmount = FinancialConstants.minSettlementAmount,
    double maxAmount = FinancialConstants.maxSettlementAmount,
    String context = 'Amount',
  }) {
    return ValidationHelpers.validateAmount(amount, minAmount: minAmount, maxAmount: maxAmount, context: context);
  }

  /// Rounds amount to 2 decimal places safely
  static double roundToCurrency(double amount) {
    return ValidationHelpers.roundToCurrency(amount);
  }

  /// Validates transaction data before creation
  static String? validateTransactionData({
    required double amount,
    required String type,
    required String gameId,
  }) {
    // Validate type
    if (type != 'buyin' && type != 'cashout') {
      return 'Transaction type must be "buyin" or "cashout"';
    }

    // Validate amount
    final amountError = validateAmount(
      amount,
      minAmount: FinancialConstants.minTransactionAmount,
      maxAmount: FinancialConstants.maxTransactionAmount,
      context: 'Transaction amount',
    );
    
    if (amountError != null) {
      return amountError;
    }

    // Validate gameId is not empty
    if (gameId.isEmpty) {
      return 'Game ID is required';
    }

    return null;
  }

  /// Validates settlement data before creation
  static String? validateSettlementData({
    required double amount,
    required String payerId,
    required String payeeId,
    required String gameId,
  }) {
    // Check payer and payee are different
    if (payerId == payeeId) {
      return 'Payer and payee must be different people';
    }

    // Validate amount
    final amountError = validateAmount(
      amount,
      minAmount: FinancialConstants.minSettlementAmount,
      maxAmount: FinancialConstants.maxSettlementAmount,
      context: 'Settlement amount',
    );
    
    if (amountError != null) {
      return amountError;
    }

    // Validate IDs are not empty
    if (payerId.isEmpty || payeeId.isEmpty) {
      return 'Payer and payee IDs are required';
    }

    if (gameId.isEmpty) {
      return 'Game ID is required';
    }

    return null;
  }

  Future<Result<SettlementValidation>> validateSettlement(String gameId) async {
    try {
      // Validate game exists and is in valid state
      final gameResult = await _client
          .from('games')
          .select('id, status')
          .eq('id', gameId)
          .maybeSingle();

      if (gameResult == null) {
        return const Failure('Game not found');
      }

      final gameStatus = gameResult['status'] as String?;
      if (gameStatus != 'completed' && gameStatus != 'in_progress') {
        return Failure('Cannot validate settlements for $gameStatus game');
      }

      final response = await _client
          .from('game_participants')
          .select('id, total_buyin, total_cashout')
          .eq('game_id', gameId);

      if (response.isEmpty) {
        return const Failure('No participants found for this game');
      }

      double totalBuyins = 0;
      double totalCashouts = 0;

      // Validate and sum all participant amounts
      for (var p in response) {
        final buyin = (p['total_buyin'] ?? 0.0).toDouble();
        final cashout = (p['total_cashout'] ?? 0.0).toDouble();

        // Validate individual amounts
        if (buyin < 0) {
          return Failure('Invalid buy-in amount for participant ${p['id']}: negative value');
        }
        if (cashout < 0) {
          return Failure('Invalid cash-out amount for participant ${p['id']}: negative value');
        }

        // Check decimal precision
        final buyinPrecision = double.parse(buyin.toStringAsFixed(2));
        final cashoutPrecision = double.parse(cashout.toStringAsFixed(2));
        
        if ((buyin - buyinPrecision).abs() > 0.001) {
          return Failure('Buy-in for participant ${p['id']} has too many decimal places');
        }
        if ((cashout - cashoutPrecision).abs() > 0.001) {
          return Failure('Cash-out for participant ${p['id']} has too many decimal places');
        }

        totalBuyins += buyin;
        totalCashouts += cashout;
      }

      final difference = totalBuyins - totalCashouts;

      final validation = SettlementValidation(
        isValid: difference.abs() <= FinancialConstants.buyinCashoutTolerance,
        totalBuyins: roundToCurrency(totalBuyins),
        totalCashouts: roundToCurrency(totalCashouts),
        difference: roundToCurrency(difference),
        message: difference.abs() <= FinancialConstants.buyinCashoutTolerance
            ? 'Buy-ins and cash-outs match!'
            : 'Warning: Buy-ins (\$${totalBuyins.toStringAsFixed(2)}) '
                'do not match cash-outs (\$${totalCashouts.toStringAsFixed(2)}). '
                'Difference: \$${difference.abs().toStringAsFixed(2)}',
      );

      return Success(validation);
    } catch (e) {
      return Failure('Settlement validation failed: ${e.toString()}');
    }
  }

  /// Calculate settlements using atomic database transaction
  /// Prevents race conditions by locking game and participants during calculation
  /// Returns existing settlements if already calculated (idempotent)
  Future<Result<List<SettlementModel>>> calculateSettlement(
      String gameId) async {
    final userId = SupabaseService.currentUserId;
    
    try {
      ErrorLoggerService.logDebug(
        'Starting atomic settlement calculation for game: $gameId',
        context: 'calculateSettlement',
      );

      // Step 1: Acquire lock to prevent concurrent calculations
      try {
        final lockAcquired = await _client.rpc('acquire_settlement_lock', 
          params: {
            'p_game_id': gameId,
            'p_user_id': userId,
          });

        if (!lockAcquired) {
          ErrorLoggerService.logWarning(
            'Settlement calculation already in progress for game $gameId',
            context: 'calculateSettlement',
          );
          return const Failure(
            'Settlement calculation already in progress. Please wait and try again.'
          );
        }
      } catch (e) {
        ErrorLoggerService.logError(
          e,
          StackTrace.current,
          context: 'calculateSettlement.acquireLock',
          additionalData: {'gameId': gameId},
        );
        return Failure('Failed to acquire settlement lock: ${e.toString()}');
      }

      try {
        // Step 2: Call atomic settlement calculation function
        // This function:
        // - Locks game and game_participants rows
        // - Validates game is completed
        // - Checks if settlements already exist (idempotent)
        // - Validates buyin/cashout totals match
        // - Calculates and creates settlements atomically
        final result = await _client.rpc('get_or_calculate_settlements', 
          params: {'p_game_id': gameId});

        ErrorLoggerService.logDebug(
          'Settlement calculation result: ${(result as List).length} settlements',
          context: 'calculateSettlement',
        );

        // Step 3: Parse results into SettlementModels
        final settlements = (result)
            .map((json) => SettlementModel.fromJson(json))
            .toList();

        // Step 4: Validate settlements
        for (final settlement in settlements) {
          final error = validateSettlementData(
            amount: settlement.amount,
            payerId: settlement.payerId,
            payeeId: settlement.payeeId,
            gameId: gameId,
          );

          if (error != null) {
            ErrorLoggerService.logWarning(
              'Settlement validation failed: $error',
              context: 'calculateSettlement.validate',
            );
            return Failure('Settlement validation failed: $error');
          }
        }

        ErrorLoggerService.logInfo(
          'Settlements calculated successfully: ${settlements.length} settlements for game: $gameId',
          context: 'calculateSettlement',
        );

        return Success(settlements);
      } catch (e, st) {
        ErrorLoggerService.logError(
          e,
          st,
          context: 'calculateSettlement.atomic',
          additionalData: {'gameId': gameId},
        );
        return Failure('Settlement calculation failed: ${e.toString()}');
      }
    } finally {
      // Step 5: Always release lock, even if calculation failed
      try {
        await _client.rpc('release_settlement_lock', 
          params: {
            'p_game_id': gameId,
            'p_user_id': userId,
          });
        
        ErrorLoggerService.logDebug(
          'Settlement lock released for game: $gameId',
          context: 'calculateSettlement',
        );
      } catch (e) {
        ErrorLoggerService.logWarning(
          'Failed to release settlement lock: ${e.toString()}',
          context: 'calculateSettlement.releaseLock',
        );
        // Don't fail the whole operation if lock release fails
      }
    }
  }

  Future<Result<List<SettlementModel>>> getGameSettlements(
      String gameId) async {
    try {
      // Validate gameId
      if (gameId.isEmpty) {
        return const Failure('Game ID is required');
      }

      final response = await _client
          .from('settlements')
          .select('''
            *,
            payer_profile:payer_id(first_name, last_name),
            payee_profile:payee_id(first_name, last_name)
          ''')
          .eq('game_id', gameId);

      if ((response as List).isEmpty) {
        return const Success([]);
      }

      final settlements = (response as List).map((json) {
        final amount = (json['amount'] as num).toDouble();
        
        // Validate settlement data from database
        if (amount <= 0) {
          throw Exception('Invalid settlement amount: $amount (must be positive)');
        }

        if (amount > FinancialConstants.maxSettlementAmount) {
          throw Exception('Settlement amount $amount exceeds maximum');
        }

        // Check decimal precision
        final roundedAmount = double.parse(amount.toStringAsFixed(2));
        if ((amount - roundedAmount).abs() > 0.001) {
          throw Exception('Settlement has invalid decimal precision: $amount');
        }
        
        return SettlementModel.fromJson({
          'id': json['id'] as String,
          'gameId': json['game_id'] as String,
          'payerId': json['payer_id'] as String,
          'payeeId': json['payee_id'] as String,
          'amount': amount,
          'status': json['status'] as String,
          'completedAt': json['completed_at'] as String?,
          'payerName': json['payer_profile'] != null
              ? '${json['payer_profile']['first_name']} ${json['payer_profile']['last_name']}'
              : null,
          'payeeName': json['payee_profile'] != null
              ? '${json['payee_profile']['first_name']} ${json['payee_profile']['last_name']}'
              : null,
        });
      }).toList();

      return Success(settlements);
    } catch (e) {
      return Failure('Failed to load settlements: ${e.toString()}');
    }
  }

  Future<Result<void>> markSettlementComplete(String settlementId) async {
    try {
      if (settlementId.isEmpty) {
        return const Failure('Settlement ID is required');
      }

      // Verify settlement exists and get current amount
      final settlement = await _client
          .from('settlements')
          .select('id, amount, status')
          .eq('id', settlementId)
          .maybeSingle();

      if (settlement == null) {
        return const Failure('Settlement not found');
      }

      final amount = (settlement['amount'] as num).toDouble();
      final status = settlement['status'] as String?;

      // Validate settlement can be marked complete
      if (status == 'completed') {
        return const Failure('Settlement is already completed');
      }

      // Validate amount one final time before update
      final amountError = validateAmount(
        amount,
        minAmount: FinancialConstants.minSettlementAmount,
        maxAmount: FinancialConstants.maxSettlementAmount,
        context: 'Settlement',
      );

      if (amountError != null) {
        return Failure('Cannot complete settlement: $amountError');
      }

      // Update settlement status
      await _client.from('settlements').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', settlementId);

      return const Success(null);
    } catch (e) {
      return Failure('Failed to mark settlement complete: ${e.toString()}');
    }
  }

  // ====================
  // Audit Trail Methods
  // ====================

  /// Get audit history for a specific settlement
  Future<Result<List<Map<String, dynamic>>>> getSettlementAuditHistory(
    String settlementId,
  ) async {
    try {
      ErrorLoggerService.logDebug(
        'Fetching audit history for settlement',
        context: 'SettlementsRepository.getSettlementAuditHistory',
      );

      final response = await _client.rpc(
        'get_financial_audit_history',
        params: {
          'p_table_name': 'settlements',
          'p_record_id': settlementId,
        },
      );

      final history = (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      ErrorLoggerService.logInfo(
        'Loaded ${history.length} audit entries',
        context: 'SettlementsRepository.getSettlementAuditHistory',
      );

      return Success(history);
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'SettlementsRepository.getSettlementAuditHistory',
        additionalData: {'settlementId': settlementId},
      );
      return Failure('Failed to load audit history: ${e.toString()}');
    }
  }

  /// Get audit history for a specific transaction
  Future<Result<List<Map<String, dynamic>>>> getTransactionAuditHistory(
    String transactionId,
  ) async {
    try {
      ErrorLoggerService.logDebug(
        'Fetching audit history for transaction',
        context: 'SettlementsRepository.getTransactionAuditHistory',
      );

      final response = await _client.rpc(
        'get_financial_audit_history',
        params: {
          'p_table_name': 'transactions',
          'p_record_id': transactionId,
        },
      );

      final history = (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      ErrorLoggerService.logInfo(
        'Loaded ${history.length} audit entries',
        context: 'SettlementsRepository.getTransactionAuditHistory',
      );

      return Success(history);
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'SettlementsRepository.getTransactionAuditHistory',
        additionalData: {'transactionId': transactionId},
      );
      return Failure('Failed to load audit history: ${e.toString()}');
    }
  }

  /// Get user's financial audit trail
  Future<Result<List<Map<String, dynamic>>>> getUserAuditHistory(
    String userId, {
    int limit = 50,
  }) async {
    try {
      ErrorLoggerService.logDebug(
        'Fetching audit history for user',
        context: 'SettlementsRepository.getUserAuditHistory',
      );

      final response = await _client.rpc(
        'get_user_financial_audit',
        params: {
          'p_user_id': userId,
          'p_limit': limit,
        },
      );

      final history = (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      ErrorLoggerService.logInfo(
        'Loaded ${history.length} audit entries',
        context: 'SettlementsRepository.getUserAuditHistory',
      );

      return Success(history);
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'SettlementsRepository.getUserAuditHistory',
        additionalData: {'userId': userId, 'limit': limit},
      );
      return Failure('Failed to load audit history: ${e.toString()}');
    }
  }

  /// Get game's financial audit summary
  Future<Result<List<Map<String, dynamic>>>> getGameAuditSummary(
    String gameId,
  ) async {
    try {
      ErrorLoggerService.logDebug(
        'Fetching audit summary for game',
        context: 'SettlementsRepository.getGameAuditSummary',
      );

      final response = await _client.rpc(
        'get_game_financial_audit_summary',
        params: {
          'p_game_id': gameId,
        },
      );

      final summary = (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      ErrorLoggerService.logInfo(
        'Loaded audit summary with ${summary.length} entries',
        context: 'SettlementsRepository.getGameAuditSummary',
      );

      return Success(summary);
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'SettlementsRepository.getGameAuditSummary',
        additionalData: {'gameId': gameId},
      );
      return Failure('Failed to load audit summary: ${e.toString()}');
    }
  }
}
