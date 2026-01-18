import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/games_provider.dart'
  show gamesRepositoryProvider, UserTransactionsKey, userTransactionsProvider, gameParticipantsProvider, gameTransactionsProvider;
import '../../../../core/constants/currencies.dart';

class CashOutDialog extends ConsumerStatefulWidget {
  final String gameId;
  final String userId;
  final String userName;
  final String currency;
  final double suggestedAmount;
  final VoidCallback onCashOut;

  const CashOutDialog({
    required this.gameId,
    required this.userId,
    required this.userName,
    required this.currency,
    required this.suggestedAmount,
    required this.onCashOut,
    super.key,
  });

  @override
  ConsumerState<CashOutDialog> createState() => _CashOutDialogState();
}

class _CashOutDialogState extends ConsumerState<CashOutDialog> {
  late TextEditingController _amountController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.suggestedAmount > 0 ? widget.suggestedAmount.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if cash-outs would exceed buy-ins
      final transactionsAsync = ref.read(gameTransactionsProvider(widget.gameId));
      await transactionsAsync.when(
        data: (transactions) async {
          // Calculate current totals
          double totalBuyins = 0;
          double totalCashouts = 0;

          for (final txn in transactions) {
            if (txn.type == 'buyin') {
              totalBuyins += txn.amount;
            } else if (txn.type == 'cashout') {
              totalCashouts += txn.amount;
            }
          }

          // Calculate new total with this cash-out
          final newTotalCashouts = totalCashouts + amount;

          // Warn if cash-outs exceed buy-ins
          if (newTotalCashouts > totalBuyins) {
            final difference = newTotalCashouts - totalBuyins;
            final shouldContinue = await _showExcessWarning(
              totalBuyins: totalBuyins,
              totalCashouts: newTotalCashouts,
              difference: difference,
            );

            if (!shouldContinue) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
              return;
            }
          }

          // Proceed with adding the cash-out
          await _addCashOut(amount);
        },
        loading: () async {
          // If still loading transactions, proceed without check
          await _addCashOut(amount);
        },
        error: (_, __) async {
          // If error loading transactions, proceed without check
          await _addCashOut(amount);
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showExcessWarning({
    required double totalBuyins,
    required double totalCashouts,
    required double difference,
  }) async {
    final currencySymbol = Currencies.symbols[widget.currency] ?? widget.currency;

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Cash-outs Exceed Buy-ins',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The total cash-outs will exceed total buy-ins by:',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Total Buy-ins:',
                            style: TextStyle(color: Colors.grey[800], fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$currencySymbol${totalBuyins.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Total Cash-outs:',
                            style: TextStyle(color: Colors.grey[800], fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$currencySymbol${totalCashouts.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Excess:',
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$currencySymbol${difference.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This might indicate a data entry error. Do you want to continue?',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _addCashOut(double amount) async {
    final repository = ref.read(gamesRepositoryProvider);
    final result = await repository.addTransaction(
      gameId: widget.gameId,
      userId: widget.userId,
      type: 'cashout',
      amount: amount,
      notes: 'Cash-out recorded',
    );

    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(gameParticipantsProvider(widget.gameId));
        ref.invalidate(
          userTransactionsProvider(
            UserTransactionsKey(gameId: widget.gameId, userId: widget.userId),
          ),
        );
        ref.invalidate(gameTransactionsProvider(widget.gameId));

        widget.onCashOut();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash-out saved')),
        );
      },
      failure: (message, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving cash-out: $message')),
        );
      },
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cash-out for ${widget.userName}'),
      content: TextField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Amount (${Currencies.symbols[widget.currency] ?? widget.currency})',
          hintText: 'Enter cash-out amount',
          border: const OutlineInputBorder(),
        ),
        enabled: !_isLoading,
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
