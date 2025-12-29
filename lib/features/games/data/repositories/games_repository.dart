import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/result.dart';
import '../models/game_model.dart';
import '../models/game_participant_model.dart';
import '../models/transaction_model.dart';

class GamesRepository {
  final SupabaseClient _client = SupabaseService.instance;

  Future<Result<List<GameModel>>> getGroupGames(String groupId) async {
    try {
      final response = await _client
          .from('games')
          .select()
          .eq('group_id', groupId)
          .order('game_date', ascending: false);

      final games = (response as List)
          .map((json) => GameModel.fromJson(json))
          .toList();

      return Result.success(games);
    } catch (e) {
      return Result.failure('Failed to load games: ${e.toString()}');
    }
  }

  Future<Result<GameModel>> getGame(String gameId) async {
    try {
      final response = await _client
          .from('games')
          .select()
          .eq('id', gameId)
          .single();

      return Result.success(GameModel.fromJson(response));
    } catch (e) {
      return Result.failure('Failed to load game: ${e.toString()}');
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

      return Result.success(GameModel.fromJson(response));
    } catch (e) {
      return Result.failure('Failed to create game: ${e.toString()}');
    }
  }

  Future<Result<void>> updateGameStatus(String gameId, String status) async {
    try {
      await _client
          .from('games')
          .update({'status': status})
          .eq('id', gameId);

      return const Result.success(null);
    } catch (e) {
      return Result.failure('Failed to update game status: ${e.toString()}');
    }
  }

  // Participants
  Future<Result<List<GameParticipantModel>>> getGameParticipants(
      String gameId) async {
    try {
      final response = await _client
          .from('game_participants')
          .select('*, profile:profiles(*)')
          .eq('game_id', gameId);

      final participants = (response as List)
          .map((json) => GameParticipantModel.fromJson(json))
          .toList();

      return Result.success(participants);
    } catch (e) {
      return Result.failure('Failed to load participants: ${e.toString()}');
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

      return const Result.success(null);
    } catch (e) {
      return Result.failure('Failed to update RSVP: ${e.toString()}');
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
      // Insert transaction
      final txnResponse = await _client
          .from('transactions')
          .insert({
            'game_id': gameId,
            'user_id': userId,
            'type': type,
            'amount': amount,
            'notes': notes,
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
        currentBuyin = (participant['total_buyin'] ?? 0).toDouble();
        currentCashout = (participant['total_cashout'] ?? 0).toDouble();
      }

      if (type == 'buyin') {
        currentBuyin += amount;
      } else if (type == 'cashout') {
        currentCashout += amount;
      }

      await _client.from('game_participants').upsert({
        'game_id': gameId,
        'user_id': userId,
        'total_buyin': currentBuyin,
        'total_cashout': currentCashout,
      });

      return Result.success(TransactionModel.fromJson(txnResponse));
    } catch (e) {
      return Result.failure('Failed to add transaction: ${e.toString()}');
    }
  }

  Future<Result<List<TransactionModel>>> getGameTransactions(
      String gameId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('game_id', gameId)
          .order('timestamp', ascending: false);

      final transactions = (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();

      return Result.success(transactions);
    } catch (e) {
      return Result.failure('Failed to load transactions: ${e.toString()}');
    }
  }

  Future<Result<List<TransactionModel>>> getUserTransactions({
    required String gameId,
    required String userId,
  }) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('game_id', gameId)
          .eq('user_id', userId)
          .order('timestamp', ascending: true);

      final transactions = (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();

      return Result.success(transactions);
    } catch (e) {
      return Result.failure('Failed to load transactions: ${e.toString()}');
    }
  }
}
