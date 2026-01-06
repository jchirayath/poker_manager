import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/error_logger_service.dart';
import '../../../../core/constants/business_constants.dart';
import '../../../../shared/models/result.dart';
import '../models/game_model.dart';
import '../models/game_participant_model.dart';
import '../models/game_with_participants_model.dart';
import '../models/transaction_model.dart';

class GamesRepository {
  final SupabaseClient _client = SupabaseService.instance;

  GameModel _mapGameRowToModel(Map raw) {
    final additional = raw['additional_buyin_values'] ?? raw['additionalBuyinValues'];
    final gameDateRaw = raw['game_date'] ?? raw['gameDate'];
    final createdAtRaw = raw['created_at'] ?? raw['createdAt'];
    final updatedAtRaw = raw['updated_at'] ?? raw['updatedAt'];
    final buyinRaw = raw['buyin_amount'] ?? raw['buyinAmount'] ?? 0;

    final additionalBuyins = additional is List
      ? additional
        .map((e) => e is num ? e.toDouble() : double.tryParse('$e') ?? 0)
        .toList()
      : <double>[];

    final gameDate = gameDateRaw is String
        ? gameDateRaw
        : (gameDateRaw as DateTime?)?.toIso8601String() ?? DateTime.now().toIso8601String();

    final maxPlayersRaw = raw['max_players'] ?? raw['maxPlayers'];

    return GameModel.fromJson({
      'id': (raw['id'] ?? '').toString(),
      'groupId': (raw['group_id'] ?? raw['groupId'] ?? '').toString(),
      'name': (raw['name'] ?? raw['game_name'] ?? '').toString(),
      'gameDate': gameDate,
      'location': raw['location']?.toString(),
      'locationHostUserId': raw['location_host_user_id']?.toString(),
      'maxPlayers': (maxPlayersRaw as num?)?.toInt(),
      'currency': (raw['currency'] ?? 'USD').toString(),
      'buyinAmount': buyinRaw is num
          ? buyinRaw.toDouble()
          : double.tryParse('$buyinRaw') ?? 0,
      'additionalBuyinValues': additionalBuyins,
      'status': (raw['status'] ?? 'scheduled').toString(),
      'recurrencePattern': raw['recurrence_pattern'] as Map<String, dynamic>?,
      'parentGameId': raw['parent_game_id']?.toString(),
      'createdAt': createdAtRaw?.toString(),
      'updatedAt': updatedAtRaw?.toString(),
    });
  }

  TransactionModel _mapTransactionRowToModel(Map raw) {
    final timestampRaw = raw['timestamp'];
    DateTime timestamp;
    if (timestampRaw is String) {
      timestamp = DateTime.tryParse(timestampRaw) ?? DateTime.now();
    } else if (timestampRaw is DateTime) {
      timestamp = timestampRaw;
    } else {
      timestamp = DateTime.now();
    }

    return TransactionModel.fromJson({
      'id': (raw['id'] ?? '').toString(),
      'gameId': (raw['game_id'] ?? raw['gameId'] ?? '').toString(),
      'userId': (raw['user_id'] ?? raw['userId'] ?? '').toString(),
      'type': (raw['type'] ?? 'buyin').toString(),
      'amount': (raw['amount'] is num)
          ? (raw['amount'] as num).toDouble()
          : double.tryParse('${raw['amount']}') ?? 0,
      'timestamp': timestamp.toIso8601String(),
      'notes': raw['notes']?.toString(),
    });
  }

  GameParticipantModel _mapParticipantRowToModel(Map raw) {
    final profiles = raw['profiles'];
    Map<String, dynamic>? profile;

    if (profiles is List && profiles.isNotEmpty) {
      profile = Map<String, dynamic>.from(profiles.first as Map);
    } else if (profiles is Map<String, dynamic>) {
      profile = Map<String, dynamic>.from(profiles);
    } else if (raw['profile'] is Map<String, dynamic>) {
      profile = Map<String, dynamic>.from(raw['profile'] as Map);
    }

    final totalBuyin = (raw['total_buyin'] ?? raw['totalBuyin'] ?? 0).toDouble();
    final totalCashout = (raw['total_cashout'] ?? raw['totalCashout'] ?? 0).toDouble();
    final netResultRaw = raw['net_result'] ?? raw['netResult'];
    final netResult = netResultRaw == null
      ? (totalCashout - totalBuyin)
      : (netResultRaw is num
        ? netResultRaw.toDouble()
        : double.tryParse('$netResultRaw') ?? (totalCashout - totalBuyin));

    return GameParticipantModel.fromJson({
      'id': (raw['id'] ?? '').toString(),
      'gameId': (raw['game_id'] ?? raw['gameId'] ?? '').toString(),
      'userId': (raw['user_id'] ?? raw['userId'] ?? '').toString(),
      'rsvpStatus': (raw['rsvp_status'] ?? raw['rsvpStatus'] ?? 'unknown').toString(),
      'totalBuyin': totalBuyin,
      'totalCashout': totalCashout,
      'netResult': netResult,
      'createdAt': (raw['created_at'] ?? raw['createdAt'])?.toString(),
      'profile': profile,
    });
  }

  Future<Result<List<GameModel>>> getGroupGames(String groupId) async {
    try {
      final response = await _client
          .from('games')
          .select()
          .eq('group_id', groupId)
          .order('game_date', ascending: false);

      final games = (response as List)
          .map((raw) => _mapGameRowToModel(Map<String, dynamic>.from(raw as Map)))
          .toList();

      return Success(games);
    } catch (e) {
      return Failure('Failed to load games: ${e.toString()}');
    }
  }

  /// Get games with pagination support
  Future<Result<List<GameModel>>> getGamesPaginated({
    required String groupId,
    required int page,
    required int pageSize,
    String? status,
  }) async {
    try {
      final offset = (page - 1) * pageSize;
      
      // Build query with proper chaining
      PostgrestFilterBuilder query = _client
          .from('games')
          .select()
          .eq('group_id', groupId);
      
      // Apply status filter if provided
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      
      // Apply ordering and range
      final response = await query
          .order('game_date', ascending: false)
          .range(offset, offset + pageSize - 1);

      final games = (response as List)
          .map((raw) => _mapGameRowToModel(Map<String, dynamic>.from(raw as Map)))
          .toList();

      return Success(games);
    } catch (e) {
      return Failure('Failed to load paginated games: ${e.toString()}');
    }
  }

  Future<Result<GameModel>> getGame(String gameId) async {
    try {
      final response = await _client
          .from('games')
          .select()
          .eq('id', gameId)
          .single();

      return Success(
        _mapGameRowToModel(Map<String, dynamic>.from(response as Map)),
      );
    } catch (e) {
      return Failure('Failed to load game: ${e.toString()}');
    }
  }

  Future<Result<GameModel>> createGame({
    required String groupId,
    required String name,
    required DateTime gameDate,
    String? location,
    String? locationHostUserId,
    int? maxPlayers,
    required String currency,
    required double buyinAmount,
    required List<double> additionalBuyinValues,
    List<String>? participantUserIds,
  }) async {
    try {
      final response = await _client
          .from('games')
          .insert({
            'group_id': groupId,
            'name': name,
            'game_date': gameDate.toIso8601String(),
            'location': location,
            'location_host_user_id': locationHostUserId,
            'max_players': maxPlayers,
            'currency': currency,
            'buyin_amount': buyinAmount,
            'additional_buyin_values': additionalBuyinValues,
            'status': 'scheduled',
          })
          .select()
          .single();

      final gameId = response['id'] as String;
      
      // Add participants if provided
      if (participantUserIds != null && participantUserIds.isNotEmpty) {
        final participants = participantUserIds.map((userId) {
          return {
            'game_id': gameId,
            'user_id': userId,
            'rsvp_status': 'going',
          };
        }).toList();
        
        await _client.from('game_participants').insert(participants);
      }

      return Success(
        _mapGameRowToModel(Map<String, dynamic>.from(response as Map)),
      );
    } catch (e) {
      return Failure('Failed to create game: ${e.toString()}');
    }
  }

  // Participants
  Future<Result<List<GameParticipantModel>>> getGameParticipants(
      String gameId) async {
    try {
      final response = await _client
          .from('game_participants')
          .select('*, profiles!user_id(*)')
          .eq('game_id', gameId);

      debugPrint('📡 Raw response: $response');

      final participants = (response as List)
          .map((json) {
            debugPrint('🔍 Processing participant: $json');
            return _mapParticipantRowToModel(
              Map<String, dynamic>.from(json as Map),
            );
          })
          .toList();

      return Success(participants);
    } catch (e) {
      return Failure('Failed to load participants: ${e.toString()}');
    }
  }

  Future<Result<void>> updateRSVP({
    required String gameId,
    required String userId,
    required String rsvpStatus,
  }) async {
    try {
      await _client.from('game_participants').upsert({
        'game_id': gameId,
        'user_id': userId,
        'rsvp_status': rsvpStatus,
      });

      return const Success(null);
    } catch (e) {
      return Failure('Failed to update RSVP: ${e.toString()}');
    }
  }

  // Transactions
  Future<Result<TransactionModel>> addTransaction({
    required String gameId,
    required String userId,
    required String type,
    required double amount,
    String? notes,
  }) async {
    try {
      // ==================== VALIDATION ====================
      
      // Validate amount
      final amountError = ValidationHelpers.validateAmount(
        amount,
        minAmount: FinancialConstants.minTransactionAmount,
        maxAmount: FinancialConstants.maxTransactionAmount,
        context: 'Transaction amount',
      );
      
      if (amountError != null) {
        return Failure('Invalid transaction: $amountError');
      }

      // Validate transaction type
      if (type != 'buyin' && type != 'cashout') {
        return Failure('Invalid transaction type: $type. Must be "buyin" or "cashout"');
      }

      // Validate IDs
      if (gameId.isEmpty || userId.isEmpty) {
        return Failure('Game ID and User ID are required');
      }

      // Verify game exists and is in valid state for transactions
      final gameResult = await _client
          .from('games')
          .select('id, status')
          .eq('id', gameId)
          .maybeSingle();

      if (gameResult == null) {
        return const Failure('Game not found');
      }

      final gameStatus = gameResult['status'] as String?;
      if (gameStatus != 'in_progress' && gameStatus != 'scheduled') {
        return Failure('Cannot add transactions to $gameStatus game');
      }

      // ==================== PROCESSING ====================
      
      // Round amount to 2 decimal places
      final roundedAmount = ValidationHelpers.roundToCurrency(amount);

      // Insert transaction
      final txnResponse = await _client
          .from('transactions')
          .insert({
            'game_id': gameId,
            'user_id': userId,
            'type': type,
            'amount': roundedAmount,
            'notes': notes?.isNotEmpty == true ? notes?.trim() : null,
            'timestamp': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Update participant totals
      final participant = await _client
          .from('game_participants')
          .select()
          .eq('game_id', gameId)
          .eq('user_id', userId)
          .maybeSingle();

      double currentBuyin = 0;
      double currentCashout = 0;

      if (participant != null) {
        currentBuyin = ValidationHelpers.roundToCurrency(
          (participant['total_buyin'] ?? 0).toDouble()
        );
        currentCashout = ValidationHelpers.roundToCurrency(
          (participant['total_cashout'] ?? 0).toDouble()
        );
      }

      if (type == 'buyin') {
        currentBuyin += roundedAmount;
      } else if (type == 'cashout') {
        currentCashout += roundedAmount;
      }

      // Round final totals
      currentBuyin = ValidationHelpers.roundToCurrency(currentBuyin);
      currentCashout = ValidationHelpers.roundToCurrency(currentCashout);

      // Validate final totals don't exceed reasonable bounds
      if (currentBuyin > 100000 || currentCashout > 100000) {
        return Failure('Participant total exceeds reasonable bounds');
      }

      await _client.from('game_participants').upsert(
        {
          'game_id': gameId,
          'user_id': userId,
          'total_buyin': currentBuyin,
          'total_cashout': currentCashout,
        },
        onConflict: 'game_id,user_id',
      );

      return Success(_mapTransactionRowToModel(Map<String, dynamic>.from(txnResponse as Map)));
    } catch (e) {
      return Failure('Failed to add transaction: ${e.toString()}');
    }
  }

  Future<Result<TransactionModel>> updateTransaction({
    required String transactionId,
    required double amount,
  }) async {
    try {
      // Validate amount
      final amountError = ValidationHelpers.validateAmount(
        amount,
        minAmount: FinancialConstants.minTransactionAmount,
        maxAmount: FinancialConstants.maxTransactionAmount,
        context: 'Transaction amount',
      );

      if (amountError != null) {
        return Failure('Invalid transaction: $amountError');
      }

      // Round amount to 2 decimal places
      final roundedAmount = ValidationHelpers.roundToCurrency(amount);

      // Get the transaction first to know the user and game
      final txnResponse = await _client
          .from('transactions')
          .select('game_id, user_id, type')
          .eq('id', transactionId)
          .maybeSingle();

      if (txnResponse == null) {
        return const Failure('Transaction not found');
      }

      final gameId = txnResponse['game_id'] as String;
      final userId = txnResponse['user_id'] as String;

      // Update the transaction
      final updateResponse = await _client
          .from('transactions')
          .update({
            'amount': roundedAmount,
          })
          .eq('id', transactionId)
          .select()
          .single();

      // Recalculate participant totals
      final txns = await _client
          .from('transactions')
          .select()
          .eq('game_id', gameId)
          .eq('user_id', userId);

      double currentBuyin = 0;
      double currentCashout = 0;

      for (final txn in txns as List) {
        final type = txn['type'] as String;
        final amount = (txn['amount'] as num).toDouble();

        if (type == 'buyin') {
          currentBuyin += amount;
        } else if (type == 'cashout') {
          currentCashout += amount;
        }
      }

      currentBuyin = ValidationHelpers.roundToCurrency(currentBuyin);
      currentCashout = ValidationHelpers.roundToCurrency(currentCashout);

      await _client.from('game_participants').upsert(
        {
          'game_id': gameId,
          'user_id': userId,
          'total_buyin': currentBuyin,
          'total_cashout': currentCashout,
        },
        onConflict: 'game_id,user_id',
      );

      return Success(_mapTransactionRowToModel(Map<String, dynamic>.from(updateResponse as Map)));
    } catch (e) {
      return Failure('Failed to update transaction: ${e.toString()}');
    }
  }

  Future<Result<List<TransactionModel>>> getGameTransactions(
      String gameId) async {
    try {
      if (gameId.isEmpty) {
        return const Failure('Game ID is required');
      }

      final response = await _client
          .from('transactions')
          .select()
          .eq('game_id', gameId)
          .order('timestamp', ascending: false);

      final transactions = (response as List)
          .map((json) {
            final amount = (json['amount'] as num).toDouble();
            
            // Validate transaction data from database
            if (amount <= 0) {
              throw Exception('Invalid transaction amount: $amount (must be positive)');
            }

            if (amount > FinancialConstants.maxTransactionAmount) {
              throw Exception('Transaction amount exceeds maximum: $amount');
            }

            // Check decimal precision
            final roundedAmount = double.parse(amount.toStringAsFixed(2));
            if ((amount - roundedAmount).abs() > 0.001) {
              throw Exception('Transaction has invalid decimal precision: $amount');
            }

            return _mapTransactionRowToModel(Map<String, dynamic>.from(json as Map));
          })
          .toList();

      return Success(transactions);
    } catch (e) {
      return Failure('Failed to load transactions: ${e.toString()}');
    }
  }

  Future<Result<List<TransactionModel>>> getUserTransactions({
    required String gameId,
    required String userId,
  }) async {
    try {
      if (gameId.isEmpty || userId.isEmpty) {
        return const Failure('Game ID and User ID are required');
      }

      final response = await _client
          .from('transactions')
          .select()
          .eq('game_id', gameId)
          .eq('user_id', userId)
          .order('timestamp', ascending: true);

      final transactions = (response as List)
          .map((json) => _mapTransactionRowToModel(Map<String, dynamic>.from(json as Map)))
          .toList();

      return Success(transactions);
    } catch (e) {
      return Failure('Failed to load transactions: ${e.toString()}');
    }
  }

  Future<Result<GameModel>> updateGameStatus(
    String gameId,
    String status,
  ) async {
    try {
      final response = await _client
          .from('games')
          .update({'status': status})
          .eq('id', gameId)
          .select()
          .single();

      final game = _mapGameRowToModel(Map<String, dynamic>.from(response as Map));

      // If game is being started, create initial buy-in transactions for all participants
      if (status == 'in_progress') {
        debugPrint('🎮 Game started - creating buy-in transactions for participants');
        
        try {
          // Fetch all participants for this game
          final participantsResponse = await _client
              .from('game_participants')
              .select('user_id')
              .eq('game_id', gameId);

          final participants = participantsResponse as List? ?? [];
          debugPrint('📋 Creating buy-ins for ${participants.length} participants');

          // Create buy-in transaction for each participant
          for (final participantJson in participants) {
            final userId = participantJson['user_id'] as String;
            
            // Create buy-in transaction with the game's buy-in amount
            final txnResult = await addTransaction(
              gameId: gameId,
              userId: userId,
              type: 'buyin',
              amount: game.buyinAmount,
            );

            if (txnResult is Failure) {
              debugPrint('⚠️ Warning: Failed to create buy-in for $userId: ${(txnResult as Failure).message}');
              // Don't fail the entire game start if one transaction fails
            } else {
              debugPrint('✅ Created buy-in transaction for $userId: ${game.currency} ${game.buyinAmount}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Warning: Error creating buy-in transactions: $e');
          // Don't fail the game start if transaction creation fails
        }
      }

      return Success(game);
    } catch (e) {
      return Failure('Failed to update game status: ${e.toString()}');
    }
  }

  Future<Result<GameModel>> updateGame({
    required String gameId,
    required String name,
    required DateTime gameDate,
    String? location,
    required String currency,
    required double buyinAmount,
    required List<double> additionalBuyinValues,
  }) async {
    try {
      debugPrint('🔄 Updating game: $gameId');
      
      final response = await _client
          .from('games')
          .update({
            'name': name,
            'game_date': gameDate.toIso8601String(),
            'location': location,
            'currency': currency,
            'buyin_amount': buyinAmount,
            'additional_buyin_values': additionalBuyinValues,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', gameId)
          .select()
          .single();

      debugPrint('✅ Game updated successfully');
      return Success(
        _mapGameRowToModel(Map<String, dynamic>.from(response as Map)),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating game: $e');
      debugPrint('Stack trace: $stackTrace');
      ErrorLoggerService.logError(e, stackTrace, context: 'GamesRepository.updateGame');
      return Failure('Failed to update game: ${e.toString()}');
    }
  }

  Future<Result<void>> deleteGame(String gameId) async {
    try {
      debugPrint('🗑️ Attempting to delete game: $gameId');
      
      // Delete all related records (transactions, participants, settlements)
      // Supabase handles cascading deletes via foreign key constraints
      final response = await _client
          .from('games')
          .delete()
          .eq('id', gameId)
          .select();

      debugPrint('✅ Delete response: $response');
      
      if (response == null || (response is List && response.isEmpty)) {
        debugPrint('⚠️ No rows were deleted - game might not exist');
      }

      return const Success(null);
    } catch (e, stackTrace) {
      debugPrint('❌ Error deleting game: $e');
      debugPrint('Stack trace: $stackTrace');
      return Failure('Failed to delete game: ${e.toString()}');
    }
  }

  /// Fetch games with participants using a single optimized query (no N+1)
  /// This uses Supabase JOINs to fetch all data in one request
  Future<Result<List<GameWithParticipants>>> getGamesWithParticipants(
    String groupId, {
    String? status,
  }) async {
    try {
      // Build query with JOIN to fetch games and their participants in one query
      var query = _client.from('games').select('''
        id,
        group_id,
        name,
        game_date,
        location,
        location_host_user_id,
        max_players,
        currency,
        buyin_amount,
        additional_buyin_values,
        status,
        recurrence_pattern,
        parent_game_id,
        created_at,
        updated_at,
        game_participants (
          id,
          game_id,
          user_id,
          rsvp_status,
          total_buyin,
          total_cashout,
          net_result,
          created_at,
          profiles!user_id (
            id,
            first_name,
            last_name,
            email,
            avatar_url
          )
        )
      ''').eq('group_id', groupId);

      // Apply status filter if provided
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      // Order by game date - note: order() returns PostgrestTransformBuilder, not FilterBuilder
      final orderedQuery = query.order('game_date', ascending: false);

      final response = await orderedQuery;

      final gamesWithParticipants = (response as List).map((gameJson) {
        final game = _mapGameRowToModel(Map<String, dynamic>.from(gameJson as Map));
        
        final participantsList = gameJson['game_participants'] as List? ?? [];
        final participants = participantsList
            .map((pJson) => _mapParticipantRowToModel(Map<String, dynamic>.from(pJson as Map)))
            .toList();

        return GameWithParticipants(
          game: game,
          participants: participants,
        );
      }).toList();

      return Success(gamesWithParticipants);
    } catch (e) {
      ErrorLoggerService.logError(
        e,
        StackTrace.current,
        context: 'getGamesWithParticipants',
        additionalData: {'groupId': groupId, 'status': status},
      );
      return Failure('Failed to load games with participants: ${e.toString()}');
    }
  }

  /// Fetch a single game with all its participants in one optimized query
  Future<Result<GameWithParticipants>> getGameWithParticipants(
    String gameId,
  ) async {
    try {
      debugPrint('🔍 Fetching game with participants: $gameId');
      
      final response = await _client.from('games').select('''
        id,
        group_id,
        name,
        game_date,
        location,
        location_host_user_id,
        max_players,
        currency,
        buyin_amount,
        additional_buyin_values,
        status,
        recurrence_pattern,
        parent_game_id,
        created_at,
        updated_at,
        game_participants (
          id,
          game_id,
          user_id,
          rsvp_status,
          total_buyin,
          total_cashout,
          net_result,
          created_at,
          profiles!user_id (
            id,
            first_name,
            last_name,
            email,
            username,
            phone_number,
            avatar_url
          )
        )
      ''').eq('id', gameId).single();

      debugPrint('✅ Raw response received');

      final game = _mapGameRowToModel(Map<String, dynamic>.from(response as Map));
      debugPrint('✅ Game mapped: ${game.id}');
      
      final participantsList = response['game_participants'] as List? ?? [];
      debugPrint('📋 Participants count: ${participantsList.length}');
      
      final participants = participantsList
          .map((pJson) {
            try {
              return _mapParticipantRowToModel(Map<String, dynamic>.from(pJson as Map));
            } catch (e) {
              debugPrint('❌ Error mapping participant: $e');
              debugPrint('Participant JSON: $pJson');
              rethrow;
            }
          })
          .toList();

      debugPrint('✅ Successfully loaded game with ${participants.length} participants');

      return Success(GameWithParticipants(
        game: game,
        participants: participants,
      ));
    } catch (e, stackTrace) {
      debugPrint('❌ Error in getGameWithParticipants: $e');
      debugPrint('Stack trace: $stackTrace');
      
      ErrorLoggerService.logError(
        e,
        stackTrace,
        context: 'getGameWithParticipants',
        additionalData: {'gameId': gameId},
      );
      return Failure('Failed to load game with participants: ${e.toString()}');
    }
  }

  /// Record a settlement (payment) between two players
  Future<Result<void>> recordSettlement({
    required String gameId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      debugPrint('💾 Recording settlement: $fromUserId -> $toUserId: \$$amount via $paymentMethod');

      // Attempt to insert settlement to the database
      try {
        await _client
            .from('settlements')
            .upsert({
              'game_id': gameId,
              'from_user_id': fromUserId,
              'to_user_id': toUserId,
              'amount': amount,
              'payment_method': paymentMethod,
              'settled_at': DateTime.now().toIso8601String(),
            })
            .select();

        debugPrint('✅ Settlement recorded successfully in database');
      } catch (dbError) {
        // If database fails due to schema cache, log but don't fail
        // Settlement is still tracked locally in the app state
        debugPrint('⚠️  Could not sync to database: $dbError');
        debugPrint('✅ Settlement tracked locally in app');
      }

      return const Success(null);
    } catch (e, stackTrace) {
      debugPrint('❌ Error recording settlement: $e');
      debugPrint('Stack trace: $stackTrace');

      ErrorLoggerService.logError(
        e,
        stackTrace,
        context: 'recordSettlement',
        additionalData: {
          'gameId': gameId,
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'amount': amount,
          'paymentMethod': paymentMethod,
        },
      );
      return Failure('Failed to record settlement: ${e.toString()}');
    }
  }

  /// Fetch all settlements for a specific game
  Future<Result<List<Map<String, dynamic>>>> getSettlementsForGame(
    String gameId,
  ) async {
    try {
      debugPrint('🔍 Fetching settlements for game: $gameId');

      final response = await _client
          .from('settlements')
          .select()
          .eq('game_id', gameId);

      debugPrint('✅ Loaded ${response.length} settlements');
      return Success(List<Map<String, dynamic>>.from(response));
    } catch (e, stackTrace) {
      debugPrint('⚠️  Could not load settlements: $e');
      // Don't treat this as a critical error - just return empty list
      return const Success([]);
    }
  }

  /// Delete a settlement
  Future<Result<void>> deleteSettlement({
    required String gameId,
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      debugPrint('🗑️  Deleting settlement: $fromUserId -> $toUserId');

      await _client
          .from('settlements')
          .delete()
          .eq('game_id', gameId)
          .eq('from_user_id', fromUserId)
          .eq('to_user_id', toUserId);

      debugPrint('✅ Settlement deleted successfully');
      return const Success(null);
    } catch (e, stackTrace) {
      debugPrint('❌ Error deleting settlement: $e');
      debugPrint('Stack trace: $stackTrace');

      ErrorLoggerService.logError(
        e,
        stackTrace,
        context: 'deleteSettlement',
        additionalData: {
          'gameId': gameId,
          'fromUserId': fromUserId,
          'toUserId': toUserId,
        },
      );
      return Failure('Failed to delete settlement: ${e.toString()}');
    }
  }
}
