import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/game_model.dart';
import '../../data/repositories/games_repository.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../../shared/models/result.dart';
import '../../../../core/services/error_logger_service.dart';
import 'games_provider.dart';

/// Pagination key for games list
class GamePageKey {
  final int page;
  final int pageSize;
  final String? groupFilter;
  final String? statusFilter;

  const GamePageKey({
    required this.page,
    required this.pageSize,
    this.groupFilter,
    this.statusFilter,
  });

  @override
  bool operator ==(Object other) {
    return other is GamePageKey &&
        other.page == page &&
        other.pageSize == pageSize &&
        other.groupFilter == groupFilter &&
        other.statusFilter == statusFilter;
  }

  @override
  int get hashCode => Object.hash(page, pageSize, groupFilter, statusFilter);
}

/// Simple paginated games provider using FutureProvider
/// 
/// This provides a simplified pagination approach where each page
/// is loaded independently. For more complex use cases with infinite
/// scroll and state accumulation, consider using a StateNotifier.
/// 
/// Example usage:
/// ```dart
/// final pageKey = GamePageKey(page: 1, pageSize: 20);
/// final games = ref.watch(paginatedGamesProvider(pageKey));
/// ```
final paginatedGamesProvider = FutureProvider.family<List<GameWithGroup>, GamePageKey>(
  (ref, pageKey) async {
    try {
      final gamesRepo = ref.watch(gamesRepositoryProvider);
      final groupsRepo = ref.watch(groupsRepositoryProvider);

      final groupsResult = await groupsRepo.getUserGroups();
      final groups = groupsResult is Success<List<GroupModel>>
          ? groupsResult.data
          : <GroupModel>[];

      if (groups.isEmpty) {
        return <GameWithGroup>[];
      }

      final allGames = <GameWithGroup>[];

      // Filter groups if specific group requested
      final targetGroups = pageKey.groupFilter != null
          ? groups.where((g) => g.id == pageKey.groupFilter).toList()
          : groups;

      // Load games from each group
      for (final group in targetGroups) {
        try {
          final result = await gamesRepo.getGamesPaginated(
            groupId: group.id,
            page: pageKey.page,
            pageSize: pageKey.pageSize,
            status: pageKey.statusFilter,
          );

          result.when(
            success: (games) {
              for (final game in games) {
                allGames.add(
                  GameWithGroup(
                    game: game,
                    groupId: group.id,
                    groupName: group.name,
                  ),
                );
              }
            },
            failure: (message, _) {
              ErrorLoggerService.logWarning(
                'Failed to load games for group ${group.id}: $message',
                context: 'paginatedGamesProvider',
              );
            },
          );
        } catch (e, st) {
          ErrorLoggerService.logError(
            e,
            st,
            context: 'paginatedGamesProvider',
            additionalData: {'groupId': group.id},
          );
        }
      }

      // Sort by date (most recent first)
      allGames.sort((a, b) => b.game.gameDate.compareTo(a.game.gameDate));

      ErrorLoggerService.logInfo(
        'Loaded page ${pageKey.page}: ${allGames.length} games',
        context: 'paginatedGamesProvider',
      );

      return allGames;
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'paginatedGamesProvider',
        additionalData: {'pageKey': pageKey},
      );
      rethrow;
    }
  },
);
