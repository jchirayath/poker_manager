import 'package:flutter/material.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/transaction_model.dart';

class GameActionButtons extends StatelessWidget {
  final GameModel game;
  final List<TransactionModel> transactions;
  final bool isStartingGame;
  final VoidCallback onStartGame;
  final VoidCallback onStopGame;
  final VoidCallback onCancelGame;
  final VoidCallback onDeleteGame;

  const GameActionButtons({
    required this.game,
    required this.transactions,
    required this.isStartingGame,
    required this.onStartGame,
    required this.onStopGame,
    required this.onCancelGame,
    required this.onDeleteGame,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Start Game button (scheduled only)
        if (game.status == 'scheduled')
          ElevatedButton.icon(
            onPressed: isStartingGame ? null : onStartGame,
            icon: isStartingGame
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(isStartingGame ? 'Starting...' : 'Start Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

        // Stop Game button (in_progress only)
        if (game.status == 'in_progress') ...[
          ElevatedButton.icon(
            onPressed: onStopGame,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 8),
          _buildBalanceHint(context),
        ],

        // Cancel button (scheduled and in_progress)
        if (game.status == 'scheduled' || game.status == 'in_progress') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCancelGame,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel Game'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],

        // Delete button (all statuses)
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onDeleteGame,
          icon: const Icon(Icons.delete_forever),
          label: const Text('Delete Game'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceHint(BuildContext context) {
    double totalBuyins = 0;
    double totalCashouts = 0;

    for (final txn in transactions) {
      if (txn.type == 'buyin') {
        totalBuyins += txn.amount;
      } else {
        totalCashouts += txn.amount;
      }
    }

    final balance = totalBuyins - totalCashouts;
    final isBalanced = balance.abs() < 0.01;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBalanced
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBalanced ? Colors.green : Colors.orange,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isBalanced ? Icons.check_circle : Icons.warning,
            color: isBalanced ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isBalanced
                  ? 'Ready to stop! Buy-ins equal cash-outs.'
                  : 'Balance: \$${balance.toStringAsFixed(2)} remaining. '
                      'All players must cash out before stopping.',
              style: TextStyle(
                color: isBalanced ? Colors.green : Colors.orange,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
