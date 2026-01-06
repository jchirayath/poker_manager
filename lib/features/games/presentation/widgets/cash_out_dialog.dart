import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/games_provider.dart';
import '../../presentation/providers/games_provider.dart'
  show UserTransactionsKey, userTransactionsProvider, gameParticipantsProvider, gameTransactionsProvider;

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
      title: Text('Cash-out for ${widget.userName}'),
      content: TextField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Amount (${widget.currency})',
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
