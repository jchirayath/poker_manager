import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/currencies.dart';
import '../../../../../core/utils/avatar_utils.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/game_participant_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/games_provider.dart';
import '../../providers/games_provider.dart' show gameWithParticipantsProvider;
import '../../../../groups/presentation/providers/groups_provider.dart';

class ParticipantList extends ConsumerWidget {
  final GameModel game;
  final List<GameParticipantModel> participants;
  final Map<String, GlobalKey> playerKeys;
  final VoidCallback onRefresh;

  const ParticipantList({
    required this.game,
    required this.participants,
    required this.playerKeys,
    required this.onRefresh,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participants',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (participants.isEmpty)
          const Center(child: Text('No participants yet'))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: participants.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final participant = participants[index];
              return _ParticipantCard(
                key: playerKeys[participant.userId],
                game: game,
                participant: participant,
                onRefresh: onRefresh,
              );
            },
          ),
      ],
    );
  }
}

class _ParticipantCard extends ConsumerWidget {
  final GameModel game;
  final GameParticipantModel participant;
  final VoidCallback onRefresh;

  const _ParticipantCard({
    super.key,
    required this.game,
    required this.participant,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = Currencies.symbols[game.currency] ?? game.currency;
    final profile = participant.profile;
    final name = profile?.fullName ?? 'Unknown';
    final initials = participant.initials;

    final transactionsAsync = ref.watch(
      userTransactionsProvider(
        UserTransactionsKey(gameId: game.id, userId: participant.userId),
      ),
    );

    // Fetch group members to check if participant is admin
    final groupMembersAsync = ref.watch(groupMembersProvider(game.groupId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with avatar and name
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: _buildAvatar(profile?.avatarUrl, initials),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Show admin badge if participant is admin
                          groupMembersAsync.when(
                            data: (members) {
                              final member = members.firstWhere(
                                (m) => m.userId == participant.userId,
                                orElse: () => members.first,
                              );
                              if (member.userId == participant.userId && member.role == 'admin') {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red[700],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red[900]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified_user,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ADMIN',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      if (profile?.email != null)
                        Text(
                          profile!.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Transactions
            transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading transactions'),
              data: (transactions) {
                final buyins = transactions.where((t) => t.type == 'buyin').toList();
                final cashouts = transactions.where((t) => t.type == 'cashout').toList();
                final totalBuyin = buyins.fold<double>(0, (sum, t) => sum + t.amount);
                final totalCashout = cashouts.fold<double>(0, (sum, t) => sum + t.amount);
                final netResult = totalCashout - totalBuyin;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          label: 'Buy-ins',
                          value: '$currency ${totalBuyin.toStringAsFixed(2)}',
                          color: theme.colorScheme.primary,
                        ),
                        _SummaryItem(
                          label: 'Cash-outs',
                          value: '$currency ${totalCashout.toStringAsFixed(2)}',
                          color: theme.colorScheme.tertiary,
                        ),
                        _SummaryItem(
                          label: 'Net',
                          value: '${netResult >= 0 ? '+' : ''}$currency ${netResult.toStringAsFixed(2)}',
                          color: netResult >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
                        ),
                      ],
                    ),

                    // Transaction details for in-progress games
                    if (game.status == 'in_progress') ...[
                      const SizedBox(height: 16),
                      _TransactionTable(
                        title: 'Buy-ins',
                        transactions: buyins,
                        currency: currency,
                        game: game,
                        participant: participant,
                        onRefresh: onRefresh,
                      ),
                      const SizedBox(height: 12),
                      _TransactionTable(
                        title: 'Cash-outs',
                        transactions: cashouts,
                        currency: currency,
                        game: game,
                        participant: participant,
                        onRefresh: onRefresh,
                      ),
                      const SizedBox(height: 16),
                      _ActionButtons(
                        game: game,
                        participant: participant,
                        onRefresh: onRefresh,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String initials) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Text(
        initials,
        style: const TextStyle(fontWeight: FontWeight.bold),
      );
    }

    if (avatarUrl.toLowerCase().contains('svg')) {
      return ClipOval(
        child: SvgPicture.network(
          fixDiceBearUrl(avatarUrl)!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Text(
          initials,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TransactionTable extends ConsumerWidget {
  final String title;
  final List<TransactionModel> transactions;
  final String currency;
  final GameModel game;
  final GameParticipantModel participant;
  final VoidCallback onRefresh;

  const _TransactionTable({
    required this.title,
    required this.transactions,
    required this.currency,
    required this.game,
    required this.participant,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('h:mm a');

    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 32, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                    const Expanded(child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                    const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              // Rows
              ...transactions.asMap().entries.map((entry) {
                final index = entry.key;
                final txn = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: index < transactions.length - 1
                        ? Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)))
                        : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 32, child: Text('${index + 1}')),
                      Expanded(child: Text(timeFormat.format(txn.timestamp))),
                      Text('$currency ${txn.amount.toStringAsFixed(2)}'),
                      SizedBox(
                        width: 32,
                        child: IconButton(
                          icon: Icon(Icons.edit, size: 16, color: theme.colorScheme.primary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showEditDialog(context, ref, txn),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, TransactionModel txn) {
    final controller = TextEditingController(text: txn.amount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${txn.isBuyin ? 'Buy-in' : 'Cash-out'}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '$currency ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(ctx);
                final repository = ref.read(gamesRepositoryProvider);
                await repository.updateTransaction(transactionId: txn.id, amount: amount);
                ref.invalidate(gameWithParticipantsProvider(game.id));
                ref.invalidate(userTransactionsProvider(
                  UserTransactionsKey(gameId: game.id, userId: participant.userId),
                ));
                ref.invalidate(gameTransactionsProvider(game.id));
                onRefresh();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final GameModel game;
  final GameParticipantModel participant;
  final VoidCallback onRefresh;

  const _ActionButtons({
    required this.game,
    required this.participant,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = Currencies.symbols[game.currency] ?? game.currency;
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showBuyinDialog(context, ref, currency),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Buy-in'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showCashoutDialog(context, ref, currency),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.attach_money),
            label: const Text('Cash-out'),
          ),
        ),
      ],
    );
  }

  void _showBuyinDialog(BuildContext context, WidgetRef ref, String currency) {
    final defaultAmount = game.additionalBuyinValues.isNotEmpty
        ? game.additionalBuyinValues.first
        : game.buyinAmount;
    final controller = TextEditingController(text: defaultAmount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Additional Buy-in'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '$currency ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final repository = ref.read(gamesRepositoryProvider);
                final result = await repository.addTransaction(
                  gameId: game.id,
                  userId: participant.userId,
                  type: 'buyin',
                  amount: amount,
                );
                result.when(
                  success: (_) {
                    ref.invalidate(gameWithParticipantsProvider(game.id));
                    ref.invalidate(userTransactionsProvider(
                      UserTransactionsKey(gameId: game.id, userId: participant.userId),
                    ));
                    ref.invalidate(gameTransactionsProvider(game.id));
                    onRefresh();
                  },
                  failure: (message, _) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red),
                    );
                  },
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showCashoutDialog(BuildContext context, WidgetRef ref, String currency) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cash-out'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '$currency ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final repository = ref.read(gamesRepositoryProvider);
                final result = await repository.addTransaction(
                  gameId: game.id,
                  userId: participant.userId,
                  type: 'cashout',
                  amount: amount,
                );
                result.when(
                  success: (_) {
                    ref.invalidate(gameWithParticipantsProvider(game.id));
                    ref.invalidate(userTransactionsProvider(
                      UserTransactionsKey(gameId: game.id, userId: participant.userId),
                    ));
                    ref.invalidate(gameTransactionsProvider(game.id));
                    onRefresh();
                  },
                  failure: (message, _) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red),
                    );
                  },
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
