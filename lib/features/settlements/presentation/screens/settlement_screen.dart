import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/error_logger_service.dart';
import '../../../../shared/models/result.dart';
import '../../../games/data/repositories/games_repository.dart';
import '../../data/models/settlement_model.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/settlements_repository.dart';

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

/// REALTIME: Automatically updates settlements when they change in Supabase
/// This replaces the manual invalidation pattern with live updates
final gameSettlementsRealtimeProvider =
    StreamProvider.family<List<SettlementModel>, String>((ref, gameId) {
  final client = SupabaseService.instance;
  
  return client
      .from('settlements')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .map((List<Map<String, dynamic>> data) {
        try {
          return data.map((json) {
            final amount = (json['amount'] as num).toDouble();
            
            // Validate settlement data from database
            if (amount <= 0) {
              throw Exception('Invalid settlement amount: $amount (must be positive)');
            }

            if (amount > 10000) { // FinancialConstants.maxSettlementAmount
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
        } catch (e, st) {
          ErrorLoggerService.logError(
            e,
            st,
            context: 'gameSettlementsRealtimeProvider.map',
            additionalData: {'gameId': gameId, 'dataCount': data.length},
          );
          return [];
        }
      });
});

class SettlementScreen extends ConsumerStatefulWidget {
  final String gameId;

  const SettlementScreen({super.key, required this.gameId});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
    Future<void> _launchPaymentApp({required String method, required double amount, required String? payeeName}) async {
      String url = '';
      final formattedAmount = amount.toStringAsFixed(2);
      // You may want to map payeeName to an email/username/phone in real app
      // For demo, just use the name as a placeholder
      if (method == 'paypal') {
        // PayPal.me link (replace with real username if available)
        url = 'https://www.paypal.me/${payeeName ?? ''}/$formattedAmount';
      } else if (method == 'venmo') {
        // Venmo deep link (replace with real username if available)
        url = 'venmo://paycharge?txn=pay&amount=$formattedAmount&note=Poker%20Settlement';
      }
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // Fallback: open in browser
        await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      }
    }
  bool _isCalculating = false;

  Future<void> _calculateSettlement() async {
    final validation =
        await ref.read(settlementValidationProvider(widget.gameId).future);

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
      final gamesRepo = ref.read(Provider((ref) => GamesRepository()));
      await gamesRepo.updateGameStatus(widget.gameId, 'completed');

      // No need to invalidate - realtime provider will automatically update!
      // ref.invalidate(gameSettlementsProvider(widget.gameId));

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
    // Use the realtime provider instead of the future provider for automatic updates
    final settlementsAsync = ref.watch(gameSettlementsRealtimeProvider(widget.gameId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement'),
      ),
      body: Column(
        children: [
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
                      Text('Total Buy-ins: ${validation.totalBuyins.toStringAsFixed(2)}'),
                      Text('Total Cash-outs: ${validation.totalCashouts.toStringAsFixed(2)}'),
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('Error: $e'),
              ),
            ),
          ),

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

                // Filter settlements for current user
                final currentUserId = SupabaseService.currentUser?.id;
                if (currentUserId == null) {
                  return const Center(child: Text('User not authenticated'));
                }

                print('\n💰💰💰 SETTLEMENT SCREEN DEBUG 💰💰💰');
                print('Current User ID: $currentUserId');
                print('Total settlements loaded: ${settlements.length}');
                
                final userSettlements = settlements.where((s) =>
                  s.payerId == currentUserId || s.payeeId == currentUserId
                ).toList();
                
                print('Settlements involving current user: ${userSettlements.length}');
                for (final s in userSettlements) {
                  final isPayer = s.payerId == currentUserId;
                  print('  - ${isPayer ? "PAY" : "RECEIVE"} \$${s.amount} ${isPayer ? "to" : "from"} ${isPayer ? s.payeeName : s.payerName}');
                }
                print('💰💰💰 END DEBUG 💰💰💰\n');

                if (userSettlements.isEmpty) {
                  return const Center(
                    child: Text('No payments needed for you'),
                  );
                }

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Settlements',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Table(
                          border: TableBorder.all(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                              ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Action',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Amount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            ...userSettlements.map((settlement) {
                              final isPayer = settlement.payerId == currentUserId;
                              final otherUserName = isPayer 
                                ? settlement.payeeName 
                                : settlement.payerName;
                              final action = isPayer
                                ? 'Pay $otherUserName'
                                : 'Get Paid from $otherUserName';
                              final amountColor = isPayer ? Colors.red : Colors.green;
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isPayer ? Icons.arrow_upward : Icons.arrow_downward,
                                          color: amountColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            action,
                                            style: const TextStyle(fontSize: 15),
                                          ),
                                        ),
                                        if (settlement.status == 'completed')
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 20,
                                          ),
                                        if (isPayer && settlement.status != 'completed') ...[
                                          IconButton(
                                            icon: const Icon(Icons.account_balance_wallet, color: Colors.blue, size: 20),
                                            tooltip: 'Pay with PayPal',
                                            onPressed: () => _launchPaymentApp(
                                              method: 'paypal',
                                              amount: settlement.amount,
                                              payeeName: settlement.payeeName,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.mobile_friendly, color: Colors.green, size: 20),
                                            tooltip: 'Pay with Venmo',
                                            onPressed: () => _launchPaymentApp(
                                              method: 'venmo',
                                              amount: settlement.amount,
                                              payeeName: settlement.payeeName,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      '\$${settlement.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: amountColor,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (userSettlements.any((s) => s.status == 'pending'))
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Pending payments shown',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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
      // No need to invalidate - realtime provider will automatically update!
      // ref.invalidate(gameSettlementsProvider(widget.gameId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment marked as complete')),
      );
    }
  }
}
