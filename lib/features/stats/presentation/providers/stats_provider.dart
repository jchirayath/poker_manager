import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/error_logger_service.dart';
import '../../../../core/constants/business_constants.dart';
import '../../../../shared/models/result.dart';
import '../../../games/data/models/game_model.dart';
import '../../../games/data/models/game_participant_model.dart';
import '../../../games/data/repositories/games_repository.dart';
import '../../../games/presentation/providers/games_provider.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../groups/data/repositories/groups_repository.dart';
import '../../../groups/presentation/providers/groups_provider.dart';

class RankingRow {
  final String userId;
  final String name;
  final double net;
  final List<GameBreakdown> breakdown;
  final int wins;
  final int losses;

  RankingRow({
    required this.userId,
    required this.name,
    required this.net,
    this.breakdown = const [],
    this.wins = 0,
    this.losses = 0,
  });
}

class GameBreakdown {
  final String gameId;
  final String gameName;
  final DateTime gameDate;
  final double net;

  GameBreakdown({
    required this.gameId,
    required this.gameName,
    required this.gameDate,
    required this.net,
  });
}

class RecentGameStats {
  final GameModel game;
  final String groupName;
  final String? groupAvatarUrl;
  final List<RankingRow> ranking;

  RecentGameStats({
    required this.game,
    required this.groupName,
    required this.groupAvatarUrl,
    required this.ranking,
  });
}

class GroupStatsSummary {
  final String groupId;
  final String groupName;
  final String? groupAvatarUrl;
  final String currency;
  final int gameCount;
  final List<RankingRow> ranking;

  GroupStatsSummary({
    required this.groupId,
    required this.groupName,
    required this.groupAvatarUrl,
    required this.currency,
    required this.gameCount,
    required this.ranking,
  });
}

String _displayName(GameParticipantModel participant) {
  final profile = participant.profile;
  if (profile == null) return participant.userId;
  final fullName = profile.fullName.trim();
  if (fullName.isNotEmpty) return fullName;
  if (profile.username != null && profile.username!.isNotEmpty) {
    return profile.username!;
  }
  return profile.email;
}

RankingRow _toRankingRow(GameParticipantModel p, GameModel game) {
  final wins = p.netResult > 0 ? 1 : 0;
  final losses = p.netResult < 0 ? 1 : 0;
  return RankingRow(
    userId: p.userId,
    name: _displayName(p),
    net: p.netResult,
    breakdown: [
      GameBreakdown(
        gameId: game.id,
        gameName: game.name,
        gameDate: game.gameDate,
        net: p.netResult,
      ),
    ],
    wins: wins,
    losses: losses,
  );
}

final recentGameStatsProvider = FutureProvider<RecentGameStats>((ref) async {
  final gamesRepo = ref.watch(gamesRepositoryProvider);
  final groupsRepo = ref.watch(groupsRepositoryProvider);

  final groupsResult = await groupsRepo.getUserGroups();
  final groups = groupsResult is Success<List<GroupModel>>
      ? groupsResult.data
      : <GroupModel>[];

  GameModel? latestGame;
  GroupModel? latestGroup;

  for (final group in groups) {
    final gamesResult = await gamesRepo.getGroupGames(group.id);
    final games = gamesResult is Success<List<GameModel>>
        ? gamesResult.data
        : <GameModel>[];

    final completedGames = games
        .where((g) => g.status == GameConstants.statusCompleted || g.status == GameConstants.statusInProgress)
        .toList();

    if (completedGames.isEmpty) continue;
    completedGames.sort((a, b) => b.gameDate.compareTo(a.gameDate));
    final candidate = completedGames.first;

    if (latestGame == null || candidate.gameDate.isAfter(latestGame!.gameDate)) {
      latestGame = candidate;
      latestGroup = group;
    }
  }

  if (latestGame == null || latestGroup == null) {
    throw Exception('No recent games found');
  }

  final participantsResult = await gamesRepo.getGameParticipants(latestGame.id);
  final participants = participantsResult is Success<List<GameParticipantModel>>
      ? participantsResult.data
      : <GameParticipantModel>[];

  final ranking = participants
      .map((p) => _toRankingRow(p, latestGame!))
      .toList()
    ..sort((a, b) => b.net.compareTo(a.net));

  return RecentGameStats(
    game: latestGame!,
    groupName: latestGroup.name,
    groupAvatarUrl: latestGroup.avatarUrl,
    ranking: ranking,
  );
});

final recentGamesStatsProvider = FutureProvider<List<RecentGameStats>>((ref) async {
  final gamesRepo = ref.watch(gamesRepositoryProvider);
  final groupsRepo = ref.watch(groupsRepositoryProvider);

  final groupsResult = await groupsRepo.getUserGroups();
  final groups = groupsResult is Success<List<GroupModel>>
      ? groupsResult.data
      : <GroupModel>[];

  final stats = <RecentGameStats>[];

  for (final group in groups) {
    final gamesResult = await gamesRepo.getGroupGames(group.id);
    final games = gamesResult is Success<List<GameModel>>
        ? gamesResult.data
        : <GameModel>[];

    final completedGames = games
        .where((g) => g.status == GameConstants.statusCompleted || g.status == GameConstants.statusInProgress)
        .toList();

    for (final game in completedGames) {
      final participantsResult = await gamesRepo.getGameParticipants(game.id);
      final participants = participantsResult is Success<List<GameParticipantModel>>
          ? participantsResult.data
          : <GameParticipantModel>[];

      final ranking = participants
          .map((p) => _toRankingRow(p, game))
          .toList()
        ..sort((a, b) => b.net.compareTo(a.net));

      stats.add(
        RecentGameStats(
          game: game,
          groupName: group.name,
          groupAvatarUrl: group.avatarUrl,
          ranking: ranking,
        ),
      );
    }
  }

  stats.sort((a, b) => b.game.gameDate.compareTo(a.game.gameDate));
  return stats;
});

class _MutableAggregate {
  final String userId;
  final String name;
  double net;
  final List<GameBreakdown> breakdown;
  int wins;
  int losses;

  _MutableAggregate({
    required this.userId,
    required this.name,
    required this.net,
    required this.breakdown,
    this.wins = 0,
    this.losses = 0,
  });
}

final groupStatsProvider = FutureProvider.family<GroupStatsSummary, String>((ref, groupId) async {
  final gamesRepo = ref.watch(gamesRepositoryProvider);
  final groupsRepo = ref.watch(groupsRepositoryProvider);

  // Fetch group for metadata (name, currency)
  final groupResult = await groupsRepo.getGroup(groupId);
  final group = groupResult is Success<GroupModel> ? groupResult.data : null;

  final gamesResult = await gamesRepo.getGroupGames(groupId);
  final games = gamesResult is Success<List<GameModel>>
      ? gamesResult.data
      : <GameModel>[];

  final completedGames = games.where((g) => g.status == 'completed').toList();
  if (completedGames.isEmpty) {
    return GroupStatsSummary(
      groupId: groupId,
      groupName: group?.name ?? 'Group',
      groupAvatarUrl: group?.avatarUrl,
      currency: group?.defaultCurrency ?? 'USD',
      gameCount: 0,
      ranking: const [],
    );
  }

  final aggregates = <String, _MutableAggregate>{};

  for (final game in completedGames) {
    final participantsResult = await gamesRepo.getGameParticipants(game.id);
    final participants = participantsResult is Success<List<GameParticipantModel>>
        ? participantsResult.data
        : <GameParticipantModel>[];

    for (final p in participants) {
      final name = _displayName(p);
      final current = aggregates[p.userId];
      final breakdownEntry = GameBreakdown(
        gameId: game.id,
        gameName: game.name,
        gameDate: game.gameDate,
        net: p.netResult,
      );

      if (current == null) {
        aggregates[p.userId] = _MutableAggregate(
          userId: p.userId,
          name: name,
          net: p.netResult,
          breakdown: [breakdownEntry],
          wins: p.netResult > 0 ? 1 : 0,
          losses: p.netResult < 0 ? 1 : 0,
        );
      } else {
        current.net += p.netResult;
        current.breakdown.add(breakdownEntry);
        if (p.netResult > 0) current.wins += 1;
        if (p.netResult < 0) current.losses += 1;
      }
    }
  }

  final ranking = aggregates.values
      .map((agg) => RankingRow(
            userId: agg.userId,
            name: agg.name,
            net: agg.net,
            breakdown: List<GameBreakdown>.from(agg.breakdown)
              ..sort((a, b) => b.gameDate.compareTo(a.gameDate)),
            wins: agg.wins,
            losses: agg.losses,
          ))
      .toList()
    ..sort((a, b) => b.net.compareTo(a.net));

  return GroupStatsSummary(
    groupId: groupId,
    groupName: group?.name ?? 'Group',
    groupAvatarUrl: group?.avatarUrl,
    currency: completedGames.first.currency,
    gameCount: completedGames.length,
    ranking: ranking,
  );
});
