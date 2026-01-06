import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/game_model.dart';
import '../../data/models/game_participant_model.dart';
import '../../data/models/game_with_participants_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/games_repository.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../../shared/models/result.dart';
import '../../../../core/services/error_logger_service.dart';
import '../../../../core/constants/business_constants.dart';

final gamesRepositoryProvider = Provider((ref) => GamesRepository());

class GameWithGroup {
  final GameModel game;
  final String groupId;
  final String groupName;
  final String? groupAvatarUrl;

  GameWithGroup({
    required this.game,
    required this.groupId,
    required this.groupName,
    this.groupAvatarUrl,
  });
}

class UserTransactionsKey {
  final String gameId;
  final String userId;

  const UserTransactionsKey({required this.gameId, required this.userId});

  @override
  bool operator ==(Object other) {
    return other is UserTransactionsKey &&
        other.gameId == gameId &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(gameId, userId);
}

final activeGamesProvider = FutureProvider<List<GameWithGroup>>((ref) async {
  final gamesRepo = ref.watch(gamesRepositoryProvider);
  final groupsRepo = ref.watch(groupsRepositoryProvider);

  final groupsResult = await groupsRepo.getUserGroups();
  final groups =
      groupsResult is Success<List<GroupModel>> ? groupsResult.data : <GroupModel>[];

  final activeGames = <GameWithGroup>[];

  for (final group in groups) {
    try {
      ErrorLoggerService.logDebug(
        'Loading active games for group: ${group.name}',
        context: 'activeGamesProvider',
      );

      final result = await gamesRepo
          .getGroupGames(group.id)
          .timeout(const Duration(seconds: 8), onTimeout: () {
        return const Failure('Timeout loading games');
      });

      result.when(
        success: (games) {
          for (final game in games) {
            if (game.status == GameConstants.statusInProgress || game.status == GameConstants.statusScheduled) {
              activeGames.add(
                GameWithGroup(
                  game: game,
                  groupId: group.id,
                  groupName: group.name,
                  groupAvatarUrl: group.avatarUrl,
                ),
              );
            }
          }
          ErrorLoggerService.logDebug(
            'Loaded ${games.length} games from group ${group.name}',
            context: 'activeGamesProvider',
          );
        },
        failure: (message, _) {
          // Log and continue; do not block other groups
          ErrorLoggerService.logWarning(
            'Failed to load games for group ${group.id}: $message',
            context: 'activeGamesProvider',
          );
        },
      );
    } catch (e, st) {
      // Log error with stack trace and continue
      ErrorLoggerService.logError(
        e,
        st,
        context: 'activeGamesProvider',
        additionalData: {'groupId': group.id, 'groupName': group.name},
      );
    }
  }

  activeGames.sort(
    (a, b) => b.game.gameDate.compareTo(a.game.gameDate),
  );

  ErrorLoggerService.logInfo(
    'Active games loaded: ${activeGames.length} games',
    context: 'activeGamesProvider',
  );

  return activeGames;
});

final pastGamesProvider = FutureProvider<List<GameWithGroup>>((ref) async {
  final gamesRepo = ref.watch(gamesRepositoryProvider);
  final groupsRepo = ref.watch(groupsRepositoryProvider);

  ErrorLoggerService.logDebug(
    'Starting to load past games...',
    context: 'pastGamesProvider',
  );

  final groupsResult = await groupsRepo.getUserGroups();
  final groups =
      groupsResult is Success<List<GroupModel>> ? groupsResult.data : <GroupModel>[];

  ErrorLoggerService.logDebug(
    'Found ${groups.length} groups',
    context: 'pastGamesProvider',
  );

  final pastGames = <GameWithGroup>[];

  for (final group in groups) {
    ErrorLoggerService.logDebug(
      'Loading games for group: ${group.name}',
      context: 'pastGamesProvider',
    );

    try {
      final result = await gamesRepo
          .getGroupGames(group.id)
          .timeout(const Duration(seconds: 8), onTimeout: () {
        return const Failure('Timeout loading games');
      });

      result.when(
        success: (games) {
          ErrorLoggerService.logDebug(
            'Group ${group.name} has ${games.length} total games',
            context: 'pastGamesProvider',
          );

          for (final game in games) {
            if (game.status == GameConstants.statusCompleted || game.status == GameConstants.statusCancelled) {
              pastGames.add(
                GameWithGroup(
                  game: game,
                  groupId: group.id,
                  groupName: group.name,
                  groupAvatarUrl: group.avatarUrl,
                ),
              );
              ErrorLoggerService.logDebug(
                'Added ${game.name} (${game.status}) to past games',
                context: 'pastGamesProvider',
              );
            }
          }
        },
        failure: (message, _) {
          // Log and continue; do not block other groups
          ErrorLoggerService.logWarning(
            'Failed to load games for group ${group.id}: $message',
            context: 'pastGamesProvider',
          );
        },
      );
    } catch (e, st) {
      // Log error with full stack trace
      ErrorLoggerService.logError(
        e,
        st,
        context: 'pastGamesProvider',
        additionalData: {'groupId': group.id, 'groupName': group.name},
      );
    }
  }

  ErrorLoggerService.logInfo(
    'Past games loaded: ${pastGames.length} games',
    context: 'pastGamesProvider',
  );

  pastGames.sort(
    (a, b) => b.game.gameDate.compareTo(a.game.gameDate),
  );

  return pastGames;
});

final groupGamesProvider = FutureProvider.family<List<GameModel>, String>(
  (ref, groupId) async {
    try {
      final repository = ref.watch(gamesRepositoryProvider);
      final result = await repository.getGroupGames(groupId);
      return result.maybeWhen(
        success: (games) => games,
        orElse: () {
          ErrorLoggerService.logWarning(
            'Failed to load games for group',
            context: 'groupGamesProvider',
          );
          throw Exception('Failed to load games');
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'groupGamesProvider',
        additionalData: {'groupId': groupId},
      );
      rethrow;
    }
  },
);

/// Provides default/available games for a group (scheduled games that can be started)
final defaultGroupGamesProvider =
    FutureProvider.family<List<GameModel>, String>(
  (ref, groupId) async {
    try {
      final repository = ref.watch(gamesRepositoryProvider);
      final result = await repository.getGroupGames(groupId);
      return result.maybeWhen(
        success: (games) => games
            .where((game) => game.status == GameConstants.statusScheduled)
            .toList(),
        orElse: () {
          ErrorLoggerService.logWarning(
            'Failed to load default games for group',
            context: 'defaultGroupGamesProvider',
          );
          throw Exception('Failed to load games');
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'defaultGroupGamesProvider',
        additionalData: {'groupId': groupId},
      );
      rethrow;
    }
  },
);

final gameDetailProvider = FutureProvider.family<GameModel, String>(
  (ref, gameId) async {
    try {
      final repository = ref.watch(gamesRepositoryProvider);
      final result = await repository.getGame(gameId);
      return result.maybeWhen(
        success: (game) => game,
        orElse: () {
          ErrorLoggerService.logWarning(
            'Failed to load game',
            context: 'gameDetailProvider',
          );
          throw Exception('Failed to load game');
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'gameDetailProvider',
        additionalData: {'gameId': gameId},
      );
      rethrow;
    }
  },
);

/// OPTIMIZED: Fetch a single game with all participants in ONE query (no N+1)
/// Replaces the need to call gameDetailProvider + gameParticipantsProvider separately
final gameWithParticipantsProvider =
    FutureProvider.family<GameWithParticipants, String>(
  (ref, gameId) async {
    try {
      final repository = ref.watch(gamesRepositoryProvider);
      final result = await repository.getGameWithParticipants(gameId);
      return result.when(
        success: (gameWithParticipants) => gameWithParticipants,
        failure: (errorMessage, errorData) {
          ErrorLoggerService.logWarning(
            'Failed to load game with participants (gameId: $gameId): $errorMessage',
            context: 'gameWithParticipantsProvider',
          );
          throw Exception('Failed to load game with participants: $errorMessage');
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'gameWithParticipantsProvider',
        additionalData: {'gameId': gameId},
      );
      rethrow;
    }
  },
);

/// OPTIMIZED: Fetch all games for a group with their participants in ONE query (no N+1)
/// Parameters: groupId, optional status filter
final groupGamesWithParticipantsProvider = FutureProvider.family<
    List<GameWithParticipants>,
    ({String groupId, String? status})>(
  (ref, params) async {
    try {
      final repository = ref.watch(gamesRepositoryProvider);
      final result = await repository.getGamesWithParticipants(
        params.groupId,
        status: params.status,
      );
      return result.maybeWhen(
        success: (games) => games,
        orElse: () {
          ErrorLoggerService.logWarning(
            'Failed to load group games with participants',
            context: 'groupGamesWithParticipantsProvider',
          );
          throw Exception('Failed to load group games with participants');
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'groupGamesWithParticipantsProvider',
        additionalData: {'groupId': params.groupId, 'status': params.status},
      );
      rethrow;
    }
  },
);

final gameParticipantsProvider =
    FutureProvider.family<List<GameParticipantModel>, String>(
  (ref, gameId) async {
    try {
      final repository = ref.watch(gamesRepositoryProvider);
      final result = await repository.getGameParticipants(gameId);
      return result.maybeWhen(
        success: (participants) => participants,
        orElse: () {
          ErrorLoggerService.logWarning(
            'Failed to load game participants',
            context: 'gameParticipantsProvider',
          );
          throw Exception('Failed to load participants');
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'gameParticipantsProvider',
        additionalData: {'gameId': gameId},
      );
      rethrow;
    }
  },
);

final gameTransactionsProvider = FutureProvider.family<List<TransactionModel>, String>(
  (ref, gameId) async {
    final repository = ref.watch(gamesRepositoryProvider);
    final result = await repository.getGameTransactions(gameId);
    return result.maybeWhen(
      success: (txns) => txns,
      orElse: () => <TransactionModel>[],
    );
  },
);

final userTransactionsProvider = FutureProvider.family<List<TransactionModel>, UserTransactionsKey>(
  (ref, key) async {
    final repository = ref.watch(gamesRepositoryProvider);
    final result = await repository.getUserTransactions(
      gameId: key.gameId,
      userId: key.userId,
    );
    return result.maybeWhen(
      success: (txns) => txns,
      orElse: () => <TransactionModel>[],
    );
  },
);

final createGameProvider =
    NotifierProvider<CreateGameNotifier, AsyncValue<GameModel?>>(() {
  return CreateGameNotifier();
});

final startGameProvider =
    NotifierProvider<StartGameNotifier, AsyncValue<GameModel?>>(() {
  return StartGameNotifier();
});

final updateGameProvider =
    NotifierProvider<UpdateGameNotifier, AsyncValue<GameModel?>>(() {
  return UpdateGameNotifier();
});

class CreateGameNotifier extends Notifier<AsyncValue<GameModel?>> {
  @override
  build() => const AsyncValue.data(null);

  Future<void> createGame({
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
    state = const AsyncValue.loading();
    try {
      final repository = ref.watch(gamesRepositoryProvider);
      
      ErrorLoggerService.logDebug(
        'Creating game: $name',
        context: 'CreateGameNotifier',
      );

      final result = await repository.createGame(
        groupId: groupId,
        name: name,
        gameDate: gameDate,
        location: location,
        locationHostUserId: locationHostUserId,
        maxPlayers: maxPlayers,
        currency: currency,
        buyinAmount: buyinAmount,
        additionalBuyinValues: additionalBuyinValues,
        participantUserIds: participantUserIds,
      );

      state = result.when(
        success: (game) {
          ErrorLoggerService.logInfo(
            'Game created successfully: ${game.name}',
            context: 'CreateGameNotifier',
          );
          return AsyncValue.data(game);
        },
        failure: (error, _) {
          ErrorLoggerService.logWarning(
            'Game creation failed: $error',
            context: 'CreateGameNotifier',
          );
          return AsyncValue.error(Exception(error), StackTrace.current);
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'CreateGameNotifier',
        additionalData: {'gameName': name, 'groupId': groupId},
      );
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

class StartGameNotifier extends Notifier<AsyncValue<GameModel?>> {
  @override
  build() => const AsyncValue.data(null);

  /// Start an existing game by changing its status to 'in_progress'
  Future<GameModel?> startExistingGame(String gameId) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.watch(gamesRepositoryProvider);
      
      ErrorLoggerService.logDebug(
        'Starting game: $gameId',
        context: 'StartGameNotifier',
      );

      final result = await repository.updateGameStatus(gameId, GameConstants.statusInProgress);
      
      state = result.when(
        success: (game) {
          ErrorLoggerService.logInfo(
            'Game started successfully: ${game.name}',
            context: 'StartGameNotifier',
          );
          return AsyncValue.data(game);
        },
        failure: (error, _) {
          ErrorLoggerService.logWarning(
            'Game start failed: $error',
            context: 'StartGameNotifier',
          );
          return AsyncValue.error(Exception(error), StackTrace.current);
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'StartGameNotifier',
        additionalData: {'gameId': gameId, 'action': 'startExistingGame'},
      );
      state = AsyncValue.error(e, st);
    }

    return state.maybeWhen(
      data: (game) => game,
      orElse: () => null,
    );
  }

  /// Create a new game and start it immediately
  Future<GameModel?> createAndStartGame({
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
    state = const AsyncValue.loading();
    try {
      final repository = ref.watch(gamesRepositoryProvider);
      
      ErrorLoggerService.logDebug(
        'Creating and starting game: $name',
        context: 'StartGameNotifier',
      );

      final result = await repository.createGame(
        groupId: groupId,
        name: name,
        gameDate: gameDate,
        location: location,
        locationHostUserId: locationHostUserId,
        maxPlayers: maxPlayers,
        currency: currency,
        buyinAmount: buyinAmount,
        additionalBuyinValues: additionalBuyinValues,
        participantUserIds: participantUserIds,
      );

      state = result.when(
        success: (game) {
          ErrorLoggerService.logInfo(
            'Game created and started: ${game.name}',
            context: 'StartGameNotifier',
          );
          return AsyncValue.data(game);
        },
        failure: (error, _) {
          ErrorLoggerService.logWarning(
            'Game creation/start failed: $error',
            context: 'StartGameNotifier',
          );
          return AsyncValue.error(Exception(error), StackTrace.current);
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'StartGameNotifier',
        additionalData: {'gameName': name, 'groupId': groupId, 'action': 'createAndStartGame'},
      );
      state = AsyncValue.error(e, st);
    }

    return state.maybeWhen(
      data: (game) => game,
      orElse: () => null,
    );
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

class UpdateGameNotifier extends Notifier<AsyncValue<GameModel?>> {
  @override
  build() => const AsyncValue.data(null);

  Future<void> updateGame({
    required String gameId,
    required String name,
    required DateTime gameDate,
    String? location,
    required String currency,
    required double buyinAmount,
    required List<double> additionalBuyinValues,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.watch(gamesRepositoryProvider);
      
      ErrorLoggerService.logDebug(
        'Updating game: $gameId',
        context: 'UpdateGameNotifier',
      );

      final result = await repository.updateGame(
        gameId: gameId,
        name: name,
        gameDate: gameDate,
        location: location,
        currency: currency,
        buyinAmount: buyinAmount,
        additionalBuyinValues: additionalBuyinValues,
      );

      state = result.when(
        success: (game) {
          ErrorLoggerService.logInfo(
            'Game updated successfully: ${game.name}',
            context: 'UpdateGameNotifier',
          );
          
          // Invalidate related providers to refresh the UI
          ref.invalidate(gameDetailProvider(gameId));
          ref.invalidate(gameWithParticipantsProvider(gameId));
          ref.invalidate(groupGamesProvider(game.groupId));
          
          return AsyncValue.data(game);
        },
        failure: (error, _) {
          ErrorLoggerService.logWarning(
            'Game update failed: $error',
            context: 'UpdateGameNotifier',
          );
          return AsyncValue.error(Exception(error), StackTrace.current);
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'UpdateGameNotifier',
        additionalData: {'gameId': gameId},
      );
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
