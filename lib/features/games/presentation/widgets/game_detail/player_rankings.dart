import 'package:flutter/material.dart';
import '../../../../../core/constants/currencies.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/game_participant_model.dart';
import '../../../data/models/transaction_model.dart';

class PlayerRankings extends StatelessWidget {
  final GameModel game;
  final List<GameParticipantModel> participants;
  final List<TransactionModel> transactions;

  const PlayerRankings({
    required this.game,
    required this.participants,
    required this.transactions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = Currencies.symbols[game.currency] ?? game.currency;
    final rankings = _calculateRankings();

    if (rankings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Player Rankings',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rankings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final player = rankings[index];
                final rank = index + 1;
                final winLoss = player['winLoss'] as double;
                final name = player['name'] as String;

                return _RankingRow(
                  rank: rank,
                  name: name,
                  winLoss: winLoss,
                  currency: currency,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _calculateRankings() {
    final playerResults = <String, Map<String, dynamic>>{};

    for (final txn in transactions) {
      playerResults.putIfAbsent(txn.userId, () => {
        'buyins': 0.0,
        'cashouts': 0.0,
        'name': participants
            .firstWhere(
              (p) => p.userId == txn.userId,
              orElse: () => participants.first,
            )
            .profile?.fullName ?? 'Unknown',
      });

      if (txn.type == 'buyin') {
        playerResults[txn.userId]!['buyins'] =
            (playerResults[txn.userId]!['buyins'] as double) + txn.amount;
      } else {
        playerResults[txn.userId]!['cashouts'] =
            (playerResults[txn.userId]!['cashouts'] as double) + txn.amount;
      }
    }

    final rankings = playerResults.entries.map((entry) {
      final buyins = entry.value['buyins'] as double;
      final cashouts = entry.value['cashouts'] as double;
      return {
        'userId': entry.key,
        'name': entry.value['name'],
        'buyins': buyins,
        'cashouts': cashouts,
        'winLoss': cashouts - buyins,
      };
    }).toList();

    rankings.sort((a, b) => (b['winLoss'] as double).compareTo(a['winLoss'] as double));

    return rankings;
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final String name;
  final double winLoss;
  final String currency;

  const _RankingRow({
    required this.rank,
    required this.name,
    required this.winLoss,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWinner = winLoss > 0;
    final isLoser = winLoss < 0;

    Color backgroundColor;
    Color? borderColor;
    Widget rankWidget;

    if (rank == 1) {
      backgroundColor = Colors.amber.withValues(alpha: 0.15);
      borderColor = Colors.amber;
      rankWidget = const Icon(Icons.emoji_events, color: Colors.amber, size: 24);
    } else if (rank == 2) {
      backgroundColor = Colors.grey.shade300.withValues(alpha: 0.3);
      borderColor = Colors.grey.shade400;
      rankWidget = Icon(Icons.emoji_events, color: Colors.grey.shade500, size: 22);
    } else if (rank == 3) {
      backgroundColor = Colors.brown.withValues(alpha: 0.15);
      borderColor = Colors.brown.shade300;
      rankWidget = Icon(Icons.emoji_events, color: Colors.brown.shade400, size: 20);
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      borderColor = null;
      rankWidget = CircleAvatar(
        radius: 12,
        backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 32, child: Center(child: rankWidget)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${winLoss >= 0 ? '+' : ''}$currency ${winLoss.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isWinner ? Colors.green : (isLoser ? Colors.red : theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
