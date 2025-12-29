import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settlements_repository.dart';
import '../../data/models/settlement_model.dart';
import '../../../games/data/repositories/games_repository.dart';

final settlementsRepositoryProvider = Provider((ref) => SettlementsRepository());

final settlementValidationProvider =
    FutureProvider.family<SettlementValidation, String>((ref, gameId) async {
  final repository = ref.watch(settlementsRepositoryProvider);
  final result = await repository.validateSettlement(gameId);
  return result is Success<SettlementValidation>
      ? result.data
      : const SettlementValidation(
          isValid: false,
          totalBuyins: 0,
          totalCashouts: 0,
          difference: 0,
          message: 'Failed to validate',
        );
});

final gameSettlementsProvider =
    FutureProvider.family<List<SettlementModel>, String>((ref, gameId) async {
  final repository = ref.watch(settlementsRepositoryProvider);
  final result = await repository.getGameSettlements(gameId);
  return result is Success<List<SettlementModel>> ? result.data : [];
});

class SettlementScreen extends ConsumerStatefulWidget {
  final String gameId;

  const SettlementScreen({super.key, required this.gameId});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  bool _isCalculating = false;

  Future<void> _calculateSettlement() async {
    // Validate first
    final validationAsync = ref.read(settlementValidationProvider(widget.gameId));
    final validation = await validationAsync.future;

    if (!mounted) return;

    if (!validation.isValid) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Settlement Warning'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(validation.message),
              const SizedBox(height: 16),
              const Text('Do you want to proceed with settlement anyway?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    setState(() => _isCalculating = true);

    final repository = ref.read(settlementsRepositoryProvider);
    final result = await repository.calculateSettlement(widget.gameId);

    if (!mounted) return;

    setState(() => _isCalculating = false);

    if (result is Success) {
      // Update game status to completed
      final gamesRepo = ref.read(Provider((ref) => GamesRepository()));
      await gamesRepo.updateGameStatus(widget.gameId, 'completed');

      ref.invalidate(gameSettlementsProvider(widget.gameId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement calculated successfully')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to calculate settlement')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validationAsync = ref.watch(settlementValidationProvider(widget.gameId));
    final settlementsAsync = ref.watch(gameSettlementsProvider(widget.gameId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement'),
      ),
      body: Column(
        children: [
          // Validation Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: validationAsync.when(
                data: (validation) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            validation.isValid ? Icons.check_circle : Icons.warning,
                            color: validation.isValid ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Validation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Total Buy-ins: \${validation.totalBuyins.toStringAsFixed(2)}'),
                      Text('Total Cash-outs: \${validation.totalCashouts.toStringAsFixed(2)}'),
                      if (!validation.isValid) ...[
                        const SizedBox(height: 8),
                        Text(
                          validation.message,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('Error: $e'),
              ),
            ),
          ),

          // Settlements List
          Expanded(
            child: settlementsAsync.when(
              data: (settlements) {
                if (settlements.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text('No settlement calculated yet'),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isCalculating ? null : _calculateSettlement,
                          icon: _isCalculating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.calculate),
                          label: const Text('Calculate Settlement'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${settlements.length} payment${settlements.length == 1 ? '' : 's'} needed',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: settlements.length,
                        itemBuilder: (context, index) {
                          final settlement = settlements[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: settlement.status == 'completed'
                                    ? Colors.green
                                    : Colors.orange,
                                child: Icon(
                                  settlement.status == 'completed'
                                      ? Icons.check
                                      : Icons.payment,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                '${settlement.payerName} → ${settlement.payeeName}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                settlement.status == 'completed'
                                    ? 'Completed'
                                    : 'Pending',
                              ),
                              trailing: Text(
                                '\${settlement.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              onTap: settlement.status == 'pending'
                                  ? () => _markComplete(settlement.id)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markComplete(String settlementId) async {
    final repository = ref.read(settlementsRepositoryProvider);
    final result = await repository.markSettlementComplete(settlementId);

    if (!mounted) return;

    if (result is Success) {
      ref.invalidate(gameSettlementsProvider(widget.gameId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment marked as complete')),
      );
    }
  }
}
