import 'package:flutter/material.dart';
import '../../../../../core/constants/currencies.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/transaction_model.dart';

class GameTotalsCard extends StatelessWidget {
  final GameModel game;
  final List<TransactionModel> transactions;
  final int participantCount;

  const GameTotalsCard({
    required this.game,
    required this.transactions,
    required this.participantCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = Currencies.symbols[game.currency] ?? game.currency;

    // Calculate totals
    double initialBuyins = 0;
    double additionalBuyins = 0;
    double cashouts = 0;

    for (final txn in transactions) {
      if (txn.type == 'buyin') {
        if (txn.amount == game.buyinAmount) {
          initialBuyins += txn.amount;
        } else {
          additionalBuyins += txn.amount;
        }
      } else if (txn.type == 'cashout') {
        cashouts += txn.amount;
      }
    }

    final totalBuyins = initialBuyins + additionalBuyins;
    final balance = totalBuyins - cashouts;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Game Totals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '$participantCount players',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTotalRow(
              context,
              'Initial Buy-ins',
              '$currency ${initialBuyins.toStringAsFixed(2)}',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildTotalRow(
              context,
              'Additional Buy-ins',
              '$currency ${additionalBuyins.toStringAsFixed(2)}',
              Colors.orange,
            ),
            const Divider(height: 24),
            _buildTotalRow(
              context,
              'Total Buy-ins',
              '$currency ${totalBuyins.toStringAsFixed(2)}',
              theme.colorScheme.primary,
              isBold: true,
            ),
            const SizedBox(height: 8),
            _buildTotalRow(
              context,
              'Total Cash-outs',
              '$currency ${cashouts.toStringAsFixed(2)}',
              Colors.green,
              isBold: true,
            ),
            const Divider(height: 24),
            _buildTotalRow(
              context,
              'Balance',
              '${balance >= 0 ? '+' : ''}$currency ${balance.toStringAsFixed(2)}',
              balance.abs() < 0.01
                  ? Colors.green
                  : (balance > 0 ? Colors.orange : Colors.red),
              isBold: true,
              showIcon: true,
              isBalanced: balance.abs() < 0.01,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
    bool showIcon = false,
    bool isBalanced = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  isBalanced ? Icons.check_circle : Icons.warning,
                  size: 16,
                  color: valueColor,
                ),
              ),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
