import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/games_provider.dart';
import '../../presentation/providers/games_provider.dart' show UserTransactionsKey, userTransactionsProvider, gameParticipantsProvider, gameTransactionsProvider;

class BuyInDialog extends ConsumerStatefulWidget {
  final String gameId;
  final String userId;
  final String userName;
  final String currency;
  final List<double> additionalBuyins;
  final VoidCallback onBuyInAdded;

  const BuyInDialog({
    required this.gameId,
    required this.userId,
    required this.userName,
    required this.currency,
    required this.additionalBuyins,
    required this.onBuyInAdded,
    super.key,
  });

  @override
  ConsumerState<BuyInDialog> createState() => _BuyInDialogState();
}

class _BuyInDialogState extends ConsumerState<BuyInDialog> {
  late TextEditingController _amountController;
  String _selectedBuyin = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _selectedBuyin = '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _addBuyIn() async {
    double? amount;

    if (_selectedBuyin.isNotEmpty) {
      amount = double.tryParse(_selectedBuyin);
    } else if (_amountController.text.isNotEmpty) {
      amount = double.tryParse(_amountController.text);
    }

    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(gamesRepositoryProvider);
      final result = await repository.addTransaction(
        gameId: widget.gameId,
        userId: widget.userId,
        type: 'buyin',
        amount: amount,
        notes: 'Additional buy-in added by user',
      );

      if (!mounted) return;
      result.when(
        success: (_) {
          // refresh dependent providers
          ref.invalidate(gameParticipantsProvider(widget.gameId));
          ref.invalidate(userTransactionsProvider(
            UserTransactionsKey(gameId: widget.gameId, userId: widget.userId),
          ));
          ref.invalidate(gameTransactionsProvider(widget.gameId));

          widget.onBuyInAdded();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Buy-in added successfully')),
          );
        },
        failure: (message, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding buy-in: $message')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Buy-in for ${widget.userName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.additionalBuyins.isNotEmpty) ...[
              const Text(
                'Select from additional buy-in options:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Column(
                children: widget.additionalBuyins.map((amount) {
                  final symbol = Currencies.symbols[widget.currency] ?? widget.currency;
                  final key = '$symbol $amount';
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedBuyin = amount.toString());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          // ignore: deprecated_member_use
                          Radio<String>(
                            value: amount.toString(),
                            // ignore: deprecated_member_use
                            groupValue: _selectedBuyin,
                            // ignore: deprecated_member_use
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedBuyin = value);
                              }
                            },
                          ),
                          Text(key),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            const Text(
              'Or enter custom amount:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() => _selectedBuyin = '');
                }
              },
              decoration: InputDecoration(
                labelText: 'Amount (${Currencies.symbols[widget.currency] ?? widget.currency})',
                hintText: 'Enter amount',
                border: const OutlineInputBorder(),
                enabled: !_isLoading,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addBuyIn,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
