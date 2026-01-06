import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../providers/games_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/game_model.dart';
import '../../data/models/game_participant_model.dart';
import '../../../../shared/models/result.dart';
import 'edit_game_screen.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final String gameId;

  const GameDetailScreen({required this.gameId, super.key});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  // Track settlement status: key = "from_id|to_id", value = {settled: bool, method: String?}
  final Map<String, Map<String, dynamic>> _settlementStatus = {};
  bool _settlementsLoaded = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _playerKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPlayer(String userId) {
    final key = _playerKeys[userId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildAvatarImage(String? url, String initials) {
    if ((url ?? '').isEmpty) {
      return Text(initials);
    }

    // Check if URL contains .svg (handles query parameters)
    if (url!.toLowerCase().contains('svg')) {
      return SvgPicture.network(
        url,
        width: 40,
        height: 40,
        placeholderBuilder: (_) => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Image.network(
      url,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Text(initials);
      },
    );
  }

  Widget _buildGroupAvatar(String? url, String fallback, {double size = 24}) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : 'G';
    if ((url ?? '').isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey.shade200,
        child: Text(letter),
      );
    }

    if (url!.toLowerCase().contains('svg')) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey.shade200,
        child: SvgPicture.network(
          url,
          width: size,
          height: size,
          placeholderBuilder: (_) => SizedBox(
            width: size / 2,
            height: size / 2,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundImage: NetworkImage(url),
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildZeroBuyinView(BuildContext context, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Initial buy-in: $currency 0.00',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Total cash: $currency 0.00',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _showAdditionalBuyinDialog(
    BuildContext context,
    WidgetRef ref,
    GameModel game,
    String userId,
  ) async {
    double amount = game.additionalBuyinValues.isNotEmpty
        ? game.additionalBuyinValues.first
        : game.buyinAmount;

    final controller = TextEditingController(text: amount.toStringAsFixed(2));

    if (!mounted) return;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Additional Buy-in'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (${game.currency})',
            hintText: amount.toStringAsFixed(2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final input = controller.text.trim();
              if (input.isEmpty) {
                Navigator.of(context).pop(amount);
                return;
              }
              final parsed = double.tryParse(input);
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      final repo = ref.read(gamesRepositoryProvider);
      final txnResult = await repo.addTransaction(
        gameId: game.id,
        userId: userId,
        type: 'buyin',
        amount: result,
        notes: 'Additional buy-in',
      );

      if (txnResult is Success) {
        if (!mounted) return;
        ref.invalidate(gameTransactionsProvider(game.id));
        ref.invalidate(
          userTransactionsProvider(
            UserTransactionsKey(gameId: game.id, userId: userId),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Additional buy-in of ${game.currency} ${result.toStringAsFixed(2)} added',
            ),
          ),
        );
      } else if (txnResult is Failure<TransactionModel>) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${(txnResult as Failure<TransactionModel>).message}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding buy-in: $e')));
    }
  }

  Future<void> _showCashoutDialog(
    BuildContext context,
    WidgetRef ref,
    GameModel game,
    String userId,
  ) async {
    final controller = TextEditingController();

    if (!mounted) return;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cash-out'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (${game.currency})',
            hintText: '0.00',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final input = controller.text.trim();
              if (input.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a cash-out amount'),
                  ),
                );
                return;
              }
              final parsed = double.tryParse(input);
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Cash-out'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      final repo = ref.read(gamesRepositoryProvider);
      final txnResult = await repo.addTransaction(
        gameId: game.id,
        userId: userId,
        type: 'cashout',
        amount: result,
        notes: 'Cash-out',
      );

      if (txnResult is Success) {
        if (!mounted) return;
        ref.invalidate(gameTransactionsProvider(game.id));
        ref.invalidate(
          userTransactionsProvider(
            UserTransactionsKey(gameId: game.id, userId: userId),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cash-out of ${game.currency} ${result.toStringAsFixed(2)} recorded',
            ),
          ),
        );
      } else if (txnResult is Failure<TransactionModel>) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${(txnResult as Failure<TransactionModel>).message}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error recording cash-out: $e')));
    }
  }

  Future<void> _showEditBuyinDialog(
    BuildContext context,
    WidgetRef ref,
    TransactionModel transaction,
    GameModel game,
    String userId,
  ) async {
    final controller = TextEditingController(
      text: transaction.amount.toStringAsFixed(2),
    );

    if (!mounted) return;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Buy-in'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (${game.currency})',
            hintText: transaction.amount.toStringAsFixed(2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final input = controller.text.trim();
              if (input.isEmpty) {
                Navigator.of(context).pop(transaction.amount);
                return;
              }
              final parsed = double.tryParse(input);
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      final repo = ref.read(gamesRepositoryProvider);
      final txnResult = await repo.updateTransaction(
        transactionId: transaction.id,
        amount: result,
      );

      if (txnResult is Success) {
        if (!mounted) return;
        ref.invalidate(gameTransactionsProvider(game.id));
        ref.invalidate(
          userTransactionsProvider(
            UserTransactionsKey(gameId: game.id, userId: userId),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Buy-in updated to ${game.currency} ${result.toStringAsFixed(2)}',
            ),
          ),
        );
      } else if (txnResult is Failure<TransactionModel>) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${(txnResult as Failure<TransactionModel>).message}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating buy-in: $e')));
    }
  }

  Future<void> _showEditCashoutDialog(
    BuildContext context,
    WidgetRef ref,
    TransactionModel transaction,
    GameModel game,
    String userId,
  ) async {
    final controller = TextEditingController(
      text: transaction.amount.toStringAsFixed(2),
    );

    if (!mounted) return;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Cash-out'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (${game.currency})',
            hintText: transaction.amount.toStringAsFixed(2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final input = controller.text.trim();
              if (input.isEmpty) {
                Navigator.of(context).pop(transaction.amount);
                return;
              }
              final parsed = double.tryParse(input);
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      final repo = ref.read(gamesRepositoryProvider);
      final txnResult = await repo.updateTransaction(
        transactionId: transaction.id,
        amount: result,
      );

      if (txnResult is Success) {
        if (!mounted) return;
        ref.invalidate(gameTransactionsProvider(game.id));
        ref.invalidate(
          userTransactionsProvider(
            UserTransactionsKey(gameId: game.id, userId: userId),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cash-out updated to ${game.currency} ${result.toStringAsFixed(2)}',
            ),
          ),
        );
      } else if (txnResult is Failure<TransactionModel>) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${(txnResult as Failure<TransactionModel>).message}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating cash-out: $e')));
    }
  }

  void _showPaymentOptionsDialog(
    BuildContext context,
    dynamic toParticipant,
    double amount,
    String currency,
  ) {
    final profile = toParticipant.profile;
    if (profile == null) return;

    final hasEmail = profile.email?.isNotEmpty ?? false;
    final hasPhone = profile.phoneNumber?.isNotEmpty ?? false;
    final hasUsername = profile.username?.isNotEmpty ?? false;

    // Debug logging
    debugPrint('=== Payment Options for ${profile.fullName} ===');
    debugPrint('Email: ${profile.email} (has: $hasEmail)');
    debugPrint('Username: ${profile.username} (has: $hasUsername)');
    debugPrint('Phone: ${profile.phoneNumber} (has: $hasPhone)');

    final paymentOptions = <Map<String, dynamic>>[];

    // PayPal options
    if (hasEmail) {
      debugPrint('Adding PayPal (email) option');
      paymentOptions.add({
        'label': 'PayPal (${profile.email})',
        'icon': Icons.payment,
        'onPressed': () {
          Navigator.of(context).pop();
          _launchPayPalEmail(profile, amount);
        },
      });
    }

    if (hasUsername) {
      debugPrint('Adding PayPal (username) option');
      paymentOptions.add({
        'label': 'PayPal (@${profile.username})',
        'icon': Icons.payment,
        'onPressed': () {
          Navigator.of(context).pop();
          _launchPayPalUsername(profile, amount);
        },
      });
    }

    // Venmo options
    if (hasEmail) {
      debugPrint('Adding Venmo (email) option');
      paymentOptions.add({
        'label': 'Venmo (${profile.email})',
        'icon': Icons.phone,
        'onPressed': () {
          Navigator.of(context).pop();
          _launchVenmoEmail(profile);
        },
      });
    }

    if (hasUsername) {
      debugPrint('Adding Venmo (username) option');
      paymentOptions.add({
        'label': 'Venmo (@${profile.username})',
        'icon': Icons.phone,
        'onPressed': () {
          Navigator.of(context).pop();
          _launchVenmoUsername(profile);
        },
      });
    }

    if (hasPhone) {
      debugPrint('Adding Venmo (phone) option');
      paymentOptions.add({
        'label': 'Venmo (${profile.phoneNumber})',
        'icon': Icons.phone,
        'onPressed': () {
          Navigator.of(context).pop();
          _launchVenmoPhone(profile);
        },
      });
    }

    debugPrint('=== Total payment options: ${paymentOptions.length} ===');

    if (paymentOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No payment information available for this user'),
        ),
      );
      return;
    }

    // If only one payment method available, launch it directly
    if (paymentOptions.length == 1) {
      final option = paymentOptions[0];
      final onPressed = option['onPressed'] as VoidCallback;
      onPressed();
      return;
    }

    // Multiple payment methods - show dialog
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 300,
            maxHeight: 500,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pay ${profile.fullName}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Send $currency ${amount.toStringAsFixed(2)} via:',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...paymentOptions.map(
                        (option) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ElevatedButton(
                            onPressed: option['onPressed'] as VoidCallback,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _getPaymentMethodImage(
                                  (option['label'] as String).toLowerCase().contains('paypal')
                                      ? 'paypal'
                                      : 'venmo',
                                  16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    option['label'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchPayPalEmail(dynamic profile, double amount) {
    final email = profile.email ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not found in profile')),
      );
      return;
    }

    final paypalUrl = 'https://paypal.me/${email.split('@')[0]}?amount=$amount';
    _launchUrl(paypalUrl);
  }

  void _launchPayPalUsername(dynamic profile, double amount) {
    final username = profile.username ?? '';
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PayPal username not found in profile')),
      );
      return;
    }

    final paypalUrl = 'https://paypal.me/$username?amount=$amount';
    _launchUrl(paypalUrl);
  }

  void _launchVenmoEmail(dynamic profile) {
    final email = profile.email ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not found in profile')),
      );
      return;
    }

    // Venmo via email - typically opens Venmo app or web
    final venmoUrl = 'https://venmo.com/email/$email';
    _launchUrl(venmoUrl);
  }

  void _launchVenmoUsername(dynamic profile) {
    final username = profile.username ?? '';

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venmo username not found in profile')),
      );
      return;
    }

    final venmoUrl = 'https://venmo.com/$username';
    _launchUrl(venmoUrl);
  }

  void _launchVenmoPhone(dynamic profile) {
    final phone = profile.phoneNumber ?? '';

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not found in profile')),
      );
      return;
    }

    // Venmo phone link - open Venmo app or web
    final venmoUrl = 'sms:$phone';
    _launchUrl(venmoUrl);
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      // For now, just copy to clipboard and show snackbar
      // In production, use url_launcher package:
      // if (await canLaunchUrl(Uri.parse(urlString))) {
      //   await launchUrl(Uri.parse(urlString));
      // } else {
      //   throw 'Could not launch $urlString';
      // }

      // Fallback: Show URL in snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Open: $urlString'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () {
              // In production: use clipboard package
              debugPrint('URL: $urlString');
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening URL: $e')));
    }
  }

  Widget _buildSettlementCell(dynamic from, dynamic to) {
    final key = '${from.id}|${to.id}';
    final status = _settlementStatus[key];
    final isSettled = status?['settled'] ?? false;
    final method = status?['method'] as String?;

    if (isSettled && method != null) {
      // Display the payment method with a checkmark - clickable to reset
      final methodLabel = method[0].toUpperCase() + method.substring(1);
      return GestureDetector(
        onTap: () {
          _showResetSettlementDialog(context, from, to, methodLabel);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            border: Border.all(color: Colors.green, width: 0.5),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 14, color: Colors.green),
              const SizedBox(width: 3),
              Text(
                methodLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Show "Mark Settled" button
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          border: Border.all(color: Colors.grey, width: 0.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          'Settle',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
                fontSize: 11,
              ),
        ),
      );
    }
  }

  void _showSettlementDialog(
    BuildContext context,
    dynamic from,
    dynamic to,
    double amount,
    dynamic game,
  ) {
    final settlementMethods = [
      {
        'label': 'Cash',
        'method': 'cash',
        'icon': Icons.payments,
        'color': const Color(0xFF4CAF50),
      },
      {
        'label': 'PayPal',
        'method': 'paypal',
        'icon': Icons.payment,
        'color': const Color(0xFF003087),
      },
      {
        'label': 'Venmo',
        'method': 'venmo',
        'icon': Icons.phone,
        'color': const Color(0xFF3D95CE),
      },
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Mark as Settled',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${from.profile?.fullName ?? "Unknown"} paid',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${to.profile?.fullName ?? "Unknown"}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${game.currency} ${amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How was it paid?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          ...settlementMethods.map((method) {
            final color = method['color'] as Color;
            return ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  final key = '${from.id}|${to.id}';
                  _settlementStatus[key] = {
                    'settled': true,
                    'method': method['method'],
                  };
                });
                _recordSettlement(
                  gameId: game.id,
                  fromUserId: from.id,
                  toUserId: to.id,
                  amount: amount,
                  method: method['method'] as String,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _getPaymentMethodImage(method['method'] as String, 16),
                  const SizedBox(width: 8),
                  Text(method['label'] as String),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _getPaymentMethodImage(String method, double size) {
    switch (method.toLowerCase()) {
      case 'paypal':
        return Image.network(
          'https://www.paypalobjects.com/webstatic/icon/pp258.png',
          height: size,
          width: size,
          color: Colors.white,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.payment, size: size);
          },
        );
      case 'venmo':
        return Image.network(
          'https://venmo.com/favicon.ico',
          height: size,
          width: size,
          color: Colors.white,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.phone, size: size);
          },
        );
      case 'cash':
        return Icon(Icons.payments, size: size);
      default:
        return Icon(Icons.payment, size: size);
    }
  }

  void _showResetSettlementDialog(
    BuildContext context,
    dynamic from,
    dynamic to,
    String method,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Settlement?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${from.profile?.fullName ?? "Unknown"} → ${to.profile?.fullName ?? "Unknown"}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 12,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          method,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will clear the settlement record. Are you sure?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteSettlement(
                gameId: widget.gameId,
                from: from,
                to: to,
              );
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Reset Settlement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerProfileDialog(GameParticipantModel participant) {
    final profile = participant.profile;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    (profile?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  profile?.fullName ?? 'Unknown Player',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Username
                if (profile?.username != null)
                  Text(
                    '@${profile!.username}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 20),
                // Contact Info
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (profile?.email != null && profile!.email.isNotEmpty)
                        _profileInfoRow(
                          context,
                          Icons.email,
                          'Email',
                          profile.email,
                        ),
                      if (profile?.phoneNumber != null && profile!.phoneNumber!.isNotEmpty)
                        _profileInfoRow(
                          context,
                          Icons.phone,
                          'Phone',
                          profile.phoneNumber!,
                        ),
                      if (profile?.fullAddress.isNotEmpty == true)
                        _profileInfoRow(
                          context,
                          Icons.location_on,
                          'Address',
                          profile!.fullAddress,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordSettlement({
    required String gameId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String method,
  }) async {
    try {
      final repository = ref.read(gamesRepositoryProvider);
      final result = await repository.recordSettlement(
        gameId: gameId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        paymentMethod: method,
      );

      result.when(
        success: (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Payment marked as settled via $method'),
                duration: const Duration(seconds: 2),
              ),
            );
            // Reload settlements from database to ensure sync
            _loadSettlementsFromDatabase(gameId);
          }
        },
        failure: (message, data) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Settlement recorded locally (database sync pending)'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording settlement: $e')),
        );
      }
    }
  }

  Future<void> _loadSettlementsFromDatabase(String gameId) async {
    try {
      final repository = ref.read(gamesRepositoryProvider);
      final result = await repository.getSettlementsForGame(gameId);

      result.when(
        success: (settlements) {
          if (mounted) {
            setState(() {
              for (final settlement in settlements) {
                final key =
                    '${settlement['from_user_id']}|${settlement['to_user_id']}';
                _settlementStatus[key] = {
                  'settled': true,
                  'method': settlement['payment_method'],
                };
              }
            });
          }
        },
        failure: (message, data) {
          debugPrint('Could not load settlements from database: $message');
        },
      );
    } catch (e) {
      debugPrint('Error loading settlements: $e');
    }
  }

  Future<void> _deleteSettlement({
    required String gameId,
    required dynamic from,
    required dynamic to,
  }) async {
    try {
      final repository = ref.read(gamesRepositoryProvider);
      final result = await repository.deleteSettlement(
        gameId: gameId,
        fromUserId: from.id,
        toUserId: to.id,
      );

      result.when(
        success: (_) {
          if (mounted) {
            setState(() {
              final key = '${from.id}|${to.id}';
              _settlementStatus.remove(key);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Settlement reset'),
                duration: Duration(seconds: 2),
              ),
            );
            // Reload settlements from database to ensure sync
            _loadSettlementsFromDatabase(gameId);
          }
        },
        failure: (message, data) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $message')),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting settlement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameWithParticipantsAsync = ref.watch(
      gameWithParticipantsProvider(widget.gameId),
    );

    return gameWithParticipantsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Game Details'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Game Details'), centerTitle: true),
        body: Center(child: Text('Error: $error')),
      ),
      data: (gameWithParticipants) {
        final game = gameWithParticipants.game;
        final participants = gameWithParticipants.participants;
        final groupAsync = ref.watch(groupProvider(game.groupId));

        // Load settlements from database only once
        if (!_settlementsLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadSettlementsFromDatabase(widget.gameId);
            _settlementsLoaded = true;
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Game Details'),
            centerTitle: true,
            actions: [
              // Show edit button for scheduled and active games
              if (game.status == 'scheduled' || game.status == 'in_progress')
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Game',
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            EditGameScreen(gameId: widget.gameId),
                      ),
                    );

                    // If game was updated, refresh the data
                    if (result == true && mounted) {
                      ref.invalidate(
                        gameWithParticipantsProvider(widget.gameId),
                      );
                      ref.invalidate(gameDetailProvider(widget.gameId));
                    }
                  },
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(gameWithParticipantsProvider(widget.gameId));
            },
            child: Column(
              children: [
                // Player quick access slider
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      final profile = participant.profile;
                      _playerKeys.putIfAbsent(
                        participant.userId,
                        () => GlobalKey(),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          avatar: CircleAvatar(
                            radius: 14,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: ClipOval(
                              child: _buildAvatarImage(
                                profile?.avatarUrl,
                                (profile?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                              ),
                            ),
                          ),
                          label: Text(
                            profile?.fullName ?? 'Unknown',
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () {
                            // Scroll to player's section in rankings
                            _scrollToPlayer(participant.userId);
                          },
                        ),
                      );
                    },
                  ),
                ),
                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // Group Name with Icon
                    groupAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (group) {
                        if (group == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildGroupAvatar(
                                  group.avatarUrl,
                                  group.name,
                                  size: 24,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  group.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Game Header Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    game.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(game.status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    game.status == 'in_progress'
                                        ? 'Active'
                                        : toBeginningOfSentenceCase(
                                            game.status,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              'Date',
                              DateFormat(
                                'MMM d, yyyy HH:mm',
                              ).format(game.gameDate),
                            ),
                            if (game.location != null)
                              _buildInfoRow('Location', game.location!),
                            _buildInfoRow(
                              'Buy-in',
                              '${game.currency} ${game.buyinAmount}${game.additionalBuyinValues.isNotEmpty ? ' (Additional: ${game.additionalBuyinValues.map((v) => '${game.currency} $v').join(', ')})' : ''}',
                            ),
                            _buildInfoRow(
                              'Current Players',
                              '${participants.length}',
                            ),
                            const SizedBox(height: 12),
                            ref
                                .watch(gameTransactionsProvider(widget.gameId))
                                .when(
                                  loading: () =>
                                      const Text('Loading totals...'),
                                  error: (_, __) =>
                                      const Text('Could not load totals'),
                                  data: (txns) {
                                    final byUser =
                                        <String, List<TransactionModel>>{};
                                    for (final txn in txns) {
                                      byUser
                                          .putIfAbsent(txn.userId, () => [])
                                          .add(txn);
                                    }

                                    double initialTotal = 0;
                                    double additionalTotal = 0;
                                    double cashOutTotal = 0;

                                    byUser.forEach((_, userTxns) {
                                      final buyins =
                                          userTxns
                                              .where((t) => t.type == 'buyin')
                                              .toList()
                                            ..sort(
                                              (a, b) => a.timestamp.compareTo(
                                                b.timestamp,
                                              ),
                                            );
                                      final cashouts = userTxns.where(
                                        (t) => t.type == 'cashout',
                                      );

                                      if (buyins.isNotEmpty) {
                                        initialTotal += buyins.first.amount;
                                        if (buyins.length > 1) {
                                          additionalTotal += buyins
                                              .skip(1)
                                              .map((b) => b.amount)
                                              .fold<double>(0, (a, b) => a + b);
                                        }
                                      }

                                      cashOutTotal += cashouts
                                          .map((c) => c.amount)
                                          .fold<double>(0, (a, b) => a + b);
                                    });

                                    final totalBalance =
                                        (initialTotal + additionalTotal) -
                                        cashOutTotal;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Totals',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(2),
                                            1: FlexColumnWidth(1),
                                          },
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: [
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    'Initial Buy-In Total',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    '${game.currency} ${initialTotal.toStringAsFixed(2)}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    'Additional Buy-In Total',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    '${game.currency} ${additionalTotal.toStringAsFixed(2)}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    'Cash Out Total',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    '${game.currency} ${cashOutTotal.toStringAsFixed(2)}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                      ),
                                                  child: Text(
                                                    'Total Balance',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                      ),
                                                  child: Text(
                                                    '${game.currency} ${totalBalance.toStringAsFixed(2)}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Completed Game Summary (only for completed games)
                    if (game.status == 'completed') ...[
                      // Settlement Summary (Splitwise-like view) - FIRST
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settlement Summary',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              ref
                                  .watch(
                                    gameTransactionsProvider(widget.gameId),
                                  )
                                  .when(
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (_, __) => const Text(
                                      'Could not load settlement data',
                                    ),
                                    data: (allTxns) {
                                      // Calculate net balance per player
                                      final balances = <String, double>{};
                                      final playerMap = <String, dynamic>{};

                                      for (final txn in allTxns) {
                                        balances[txn.userId] =
                                            (balances[txn.userId] ?? 0) +
                                            (txn.type == 'buyin'
                                                ? -txn.amount
                                                : txn.amount);
                                      }

                                      // Map users to participants
                                      for (final entry in balances.entries) {
                                        final participant = participants
                                            .firstWhere(
                                              (p) => p.userId == entry.key,
                                              orElse: () => participants.first,
                                            );
                                        playerMap[entry.key] = {
                                          'participant': participant,
                                          'balance': entry.value,
                                        };
                                      }

                                      // Separate debtors and creditors
                                      final debtors = balances.entries
                                          .where((e) => e.value < 0)
                                          .map((e) => MapEntry(e.key, e.value))
                                          .toList();
                                      final creditors = balances.entries
                                          .where((e) => e.value > 0)
                                          .map((e) => MapEntry(e.key, e.value))
                                          .toList();

                                      // Sort debtors (most owed first) and creditors (most owed first)
                                      debtors.sort(
                                        (a, b) => a.value.compareTo(b.value),
                                      );
                                      creditors.sort(
                                        (a, b) => b.value.compareTo(a.value),
                                      );

                                      // Create settlement list
                                      final settlements =
                                          <Map<String, dynamic>>[];
                                      var debtorIdx = 0;
                                      var creditorIdx = 0;
                                      var debtorRemaining = debtors.isNotEmpty
                                          ? debtors[0].value.abs()
                                          : 0.0;
                                      var creditorRemaining =
                                          creditors.isNotEmpty
                                          ? creditors[0].value
                                          : 0.0;

                                      while (debtorIdx < debtors.length &&
                                          creditorIdx < creditors.length) {
                                        final settleAmount =
                                            debtorRemaining < creditorRemaining
                                            ? debtorRemaining
                                            : creditorRemaining;

                                        settlements.add({
                                          'from':
                                              playerMap[debtors[debtorIdx]
                                                  .key]['participant'],
                                          'to':
                                              playerMap[creditors[creditorIdx]
                                                  .key]['participant'],
                                          'amount': settleAmount,
                                        });

                                        debtorRemaining -= settleAmount;
                                        creditorRemaining -= settleAmount;

                                        if (debtorRemaining < 0.01) {
                                          debtorIdx++;
                                          if (debtorIdx < debtors.length) {
                                            debtorRemaining = debtors[debtorIdx]
                                                .value
                                                .abs();
                                          }
                                        }
                                        if (creditorRemaining < 0.01) {
                                          creditorIdx++;
                                          if (creditorIdx < creditors.length) {
                                            creditorRemaining =
                                                creditors[creditorIdx].value;
                                          }
                                        }
                                      }

                                      if (settlements.isEmpty) {
                                        return const Text(
                                          'No settlements needed',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: settlements.map((settlement) {
                                          final from =
                                              settlement['from'] as dynamic;
                                          final to = settlement['to'] as dynamic;
                                          final amount =
                                              settlement['amount'] as double;

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline
                                                      .withValues(alpha: 0.3),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              padding: const EdgeInsets.all(8),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      from.profile?.fullName ??
                                                          'Unknown',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.arrow_forward,
                                                    size: 14,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    flex: 2,
                                                    child: TextButton(
                                                      onPressed: () {
                                                        _showPaymentOptionsDialog(
                                                          context,
                                                          to,
                                                          amount,
                                                          game.currency,
                                                        );
                                                      },
                                                      style: TextButton
                                                          .styleFrom(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                      child: Text(
                                                        to.profile?.fullName ??
                                                            'Unknown',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: Theme.of(
                                                                    context,
                                                                  )
                                                                  .colorScheme
                                                                  .primary,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 45,
                                                    child: Text(
                                                      '${game.currency} ${amount.toStringAsFixed(2)}',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Colors.green,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      _showSettlementDialog(
                                                        context,
                                                        from,
                                                        to,
                                                        amount,
                                                        game,
                                                      );
                                                    },
                                                    child: _buildSettlementCell(
                                                      from,
                                                      to,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Player Rankings (sorted by win/loss)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Player Rankings',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              ref
                                  .watch(
                                    gameTransactionsProvider(widget.gameId),
                                  )
                                  .when(
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (_, __) =>
                                        const Text('Could not load rankings'),
                                    data: (allTxns) {
                                      // Calculate win/loss per user
                                      final playerResults =
                                          <String, Map<String, dynamic>>{};

                                      for (final txn in allTxns) {
                                        playerResults.putIfAbsent(
                                          txn.userId,
                                          () => {
                                            'buyins': 0.0,
                                            'cashouts': 0.0,
                                            'participant': participants
                                                .firstWhere(
                                                  (p) => p.userId == txn.userId,
                                                  orElse: () =>
                                                      participants.first,
                                                ),
                                          },
                                        );

                                        if (txn.type == 'buyin') {
                                          playerResults[txn.userId]!['buyins'] =
                                              playerResults[txn
                                                  .userId]!['buyins'] +
                                              txn.amount;
                                        } else if (txn.type == 'cashout') {
                                          playerResults[txn
                                                  .userId]!['cashouts'] =
                                              playerResults[txn
                                                  .userId]!['cashouts'] +
                                              txn.amount;
                                        }
                                      }

                                      // Calculate net and sort
                                      final rankedPlayers =
                                          playerResults.entries.map((entry) {
                                            final buyins =
                                                entry.value['buyins'] as double;
                                            final cashouts =
                                                entry.value['cashouts']
                                                    as double;
                                            return {
                                              'userId': entry.key,
                                              'participant':
                                                  entry.value['participant'],
                                              'buyins': buyins,
                                              'cashouts': cashouts,
                                              'winLoss': cashouts - buyins,
                                            };
                                          }).toList()..sort(
                                            (a, b) => (b['winLoss'] as double)
                                                .compareTo(
                                                  a['winLoss'] as double,
                                                ),
                                          );

                                      return ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: rankedPlayers.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, index) {
                                          final player = rankedPlayers[index];
                                          final participant =
                                              player['participant'] as dynamic;
                                          final winLoss =
                                              player['winLoss'] as double;
                                          final rank = index + 1;

                                          return Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: rank == 1
                                                  ? Colors.amber.withValues(
                                                      alpha: 0.1,
                                                    )
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: rank == 1
                                                    ? Colors.amber
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .outline
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                width: rank == 1 ? 2 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                // Rank badge
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: rank == 1
                                                        ? Colors.amber
                                                        : rank == 2
                                                        ? Colors.grey[400]
                                                        : rank == 3
                                                        ? Colors.brown[300]
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .primaryContainer,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '$rank',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: rank <= 3
                                                                ? Colors.white
                                                                : null,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Avatar
                                                CircleAvatar(
                                                  radius: 20,
                                                  child: _buildAvatarImage(
                                                    participant
                                                        .profile
                                                        ?.avatarUrl,
                                                    (participant
                                                                .profile
                                                                ?.firstName ??
                                                            'U')[0]
                                                        .toUpperCase(),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Name
                                                Expanded(
                                                  child: Text(
                                                    participant
                                                            .profile
                                                            ?.fullName ??
                                                        'Unknown',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight: rank == 1
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                    .normal,
                                                        ),
                                                  ),
                                                ),
                                                // Win/Loss amount
                                                Text(
                                                  '${game.currency} ${winLoss.toStringAsFixed(2)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: winLoss >= 0
                                                            ? Colors.green
                                                            : Colors.red,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Player Transactions Details
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Player Transactions Details',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              ref
                                  .watch(
                                    gameTransactionsProvider(widget.gameId),
                                  )
                                  .when(
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (_, __) => const Text(
                                      'Could not load transaction details',
                                    ),
                                    data: (allTxns) {
                                      // Group by user
                                      final byUser =
                                          <String, List<TransactionModel>>{};
                                      for (final txn in allTxns) {
                                        byUser
                                            .putIfAbsent(txn.userId, () => [])
                                            .add(txn);
                                      }

                                      return Table(
                                        border: TableBorder.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: 0.3),
                                        ),
                                        columnWidths: const {
                                          0: FlexColumnWidth(3),
                                          1: FlexColumnWidth(2),
                                          2: FlexColumnWidth(2),
                                          3: FlexColumnWidth(2),
                                        },
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        children: [
                                          // Header
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primaryContainer,
                                            ),
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                child: Text(
                                                  'Player',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                child: Text(
                                                  'Buy-in',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                child: Text(
                                                  'Cash-out',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                child: Text(
                                                  'Win/Loss',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Data rows
                                          ...byUser.entries.map((entry) {
                                            final participant = participants
                                                .firstWhere(
                                                  (p) => p.userId == entry.key,
                                                  orElse: () =>
                                                      participants.first,
                                                );
                                            final txns = entry.value;
                                            final buyins = txns
                                                .where((t) => t.type == 'buyin')
                                                .map((t) => t.amount)
                                                .fold<double>(
                                                  0,
                                                  (a, b) => a + b,
                                                );
                                            final cashouts = txns
                                                .where(
                                                  (t) => t.type == 'cashout',
                                                )
                                                .map((t) => t.amount)
                                                .fold<double>(
                                                  0,
                                                  (a, b) => a + b,
                                                );
                                            final winLoss = cashouts - buyins;

                                            return TableRow(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  child: Text(
                                                    participant
                                                            .profile
                                                            ?.fullName ??
                                                        'Unknown',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodyMedium,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  child: Text(
                                                    '${game.currency} ${buyins.toStringAsFixed(2)}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodyMedium,
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  child: Text(
                                                    '${game.currency} ${cashouts.toStringAsFixed(2)}',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodyMedium,
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  child: Text(
                                                    '${game.currency} ${winLoss.toStringAsFixed(2)}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: winLoss >= 0
                                                              ? Colors.green
                                                              : Colors.red,
                                                        ),
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                              ],
                                            );
                                          }),
                                        ],
                                      );
                                    },
                                  ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Start Game Button (only for scheduled games)
                    if (game.status == 'scheduled')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                debugPrint(
                                  '🎮 Starting game: ${widget.gameId}',
                                );
                                final result = await ref
                                    .read(startGameProvider.notifier)
                                    .startExistingGame(widget.gameId);
                                debugPrint(
                                  '🎮 Game started successfully: $result',
                                );

                                if (!mounted) return;

                                ref.invalidate(
                                  gameDetailProvider(widget.gameId),
                                );
                                ref.invalidate(activeGamesProvider);
                                ref.invalidate(pastGamesProvider);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Game started successfully!'),
                                  ),
                                );
                              } catch (e, stackTrace) {
                                debugPrint('❌ Error starting game: $e');
                                debugPrint('Stack trace: $stackTrace');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error starting game: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Game'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Stop Game Button (only for active games)
                    if (game.status == 'in_progress')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final txns = await ref.read(
                                  gameTransactionsProvider(
                                    widget.gameId,
                                  ).future,
                                );
                                final totalBuyins = txns
                                    .where((t) => t.type == 'buyin')
                                    .fold<double>(
                                      0,
                                      (sum, t) => sum + t.amount,
                                    );
                                final totalCashouts = txns
                                    .where((t) => t.type == 'cashout')
                                    .fold<double>(
                                      0,
                                      (sum, t) => sum + t.amount,
                                    );
                                final balance = totalBuyins - totalCashouts;

                                if (balance.abs() > 0.01) {
                                  if (mounted) {
                                    await showDialog<void>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Cannot Stop Game'),
                                        content: const Text(
                                          'Total cash-in and cash-out are not equal. Please reconcile accounts before stopping the game.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return;
                                }

                                debugPrint(
                                  '🛑 Stopping game: ${widget.gameId}',
                                );
                                final repo = ref.read(gamesRepositoryProvider);
                                final result = await repo.updateGameStatus(
                                  widget.gameId,
                                  'completed',
                                );

                                if (result is Failure) {
                                  if (!mounted) return;
                                  final failure = result as Failure<GameModel>;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to stop game: ${failure.message}',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (!mounted) return;

                                ref.invalidate(
                                  gameDetailProvider(widget.gameId),
                                );
                                ref.invalidate(activeGamesProvider);
                                ref.invalidate(pastGamesProvider);
                                ref.invalidate(
                                  groupGamesProvider(game.groupId),
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Game stopped. Cash-outs now available.',
                                    ),
                                  ),
                                );
                              } catch (e, stackTrace) {
                                debugPrint('❌ Error stopping game: $e');
                                debugPrint('Stack trace: $stackTrace');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error stopping game: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.stop_circle),
                            label: const Text('Stop Game'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ),

                    // Summary Table for Active Games
                    if (game.status == 'in_progress')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Summary',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<List<TransactionModel>>(
                              future: ref.read(
                                gameTransactionsProvider(widget.gameId).future,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return const Text('No transactions yet');
                                }

                                final allTransactions = snapshot.data!;
                                final summaryData =
                                    <String, Map<String, double>>{};

                                // Calculate totals for each user
                                for (final txn in allTransactions) {
                                  if (!summaryData.containsKey(txn.userId)) {
                                    summaryData[txn.userId] = {
                                      'buyin': 0,
                                      'cashout': 0,
                                    };
                                  }

                                  if (txn.type == 'buyin') {
                                    summaryData[txn.userId]!['buyin'] =
                                        summaryData[txn.userId]!['buyin']! +
                                        txn.amount;
                                  } else if (txn.type == 'cashout') {
                                    summaryData[txn.userId]!['cashout'] =
                                        summaryData[txn.userId]!['cashout']! +
                                        txn.amount;
                                  }
                                }

                                // Add initial buy-in for each participant
                                for (final participant in participants) {
                                  if (!summaryData.containsKey(
                                    participant.userId,
                                  )) {
                                    summaryData[participant.userId] = {
                                      'buyin': 0,
                                      'cashout': 0,
                                    };
                                  }
                                  // Add initial buy-in to the total
                                  summaryData[participant.userId]!['buyin'] =
                                      summaryData[participant
                                          .userId]!['buyin']! +
                                      game.buyinAmount;
                                }

                                // Create rows with participant names
                                final rows = <TableRow>[];

                                // Header row
                                rows.add(
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          'Player',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelMedium,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          'Buy-in',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelMedium,
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          'Cash-out',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelMedium,
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          'Net',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelMedium,
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                // Data rows
                                for (final participant in participants) {
                                  final userSummary =
                                      summaryData[participant.userId];
                                  if (userSummary == null) continue;

                                  final buyin = userSummary['buyin'] ?? 0;
                                  final cashout = userSummary['cashout'] ?? 0;
                                  final net = buyin - cashout;

                                  final profileName =
                                      participant.profile?.fullName ??
                                      participant.profile?.email ??
                                      'Unknown';

                                  rows.add(
                                    TableRow(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            profileName,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            '${game.currency} ${buyin.toStringAsFixed(2)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            '${game.currency} ${cashout.toStringAsFixed(2)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            '${game.currency} ${net.toStringAsFixed(2)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: net > 0
                                                      ? Colors.green
                                                      : net < 0
                                                      ? Colors.red
                                                      : Colors.grey,
                                                ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                // Calculate totals row
                                double totalBuyin = 0;
                                double totalCashout = 0;
                                for (final participant in participants) {
                                  final userSummary =
                                      summaryData[participant.userId];
                                  if (userSummary != null) {
                                    totalBuyin += userSummary['buyin'] ?? 0;
                                    totalCashout += userSummary['cashout'] ?? 0;
                                  }
                                }
                                final totalNet = totalBuyin - totalCashout;

                                // Add totals row
                                rows.add(
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          'TOTALS',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          '${game.currency} ${totalBuyin.toStringAsFixed(2)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          '${game.currency} ${totalCashout.toStringAsFixed(2)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          '${game.currency} ${totalNet.toStringAsFixed(2)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: totalNet > 0
                                                    ? Colors.green
                                                    : totalNet < 0
                                                    ? Colors.red
                                                    : Colors.grey,
                                              ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                return Table(
                                  border: TableBorder.all(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.2),
                                  ),
                                  columnWidths: const {
                                    0: FlexColumnWidth(2),
                                    1: FlexColumnWidth(1.5),
                                    2: FlexColumnWidth(1.5),
                                    3: FlexColumnWidth(1.5),
                                  },
                                  children: rows,
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),

                    // Participants Section
                    Text(
                      'Participants',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (participants.isEmpty)
                      const Center(child: Text('No participants yet'))
                    else if (game.status == 'scheduled')
                      // Scheduled games: Show only Buy-in
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final participant = participants[index];
                          final profileName =
                              participant.profile?.fullName ??
                              participant.profile?.email ??
                              'Unknown';
                          final initialsText =
                              (participant.profile?.firstName ?? 'U')[0]
                                  .toUpperCase() +
                              (participant.profile?.lastName ?? '')[0]
                                  .toUpperCase();

                          return Card(
                            key: _playerKeys[participant.userId],
                            child: ListTile(
                              leading: CircleAvatar(
                                child: _buildAvatarImage(
                                  participant.profile?.avatarUrl,
                                  initialsText,
                                ),
                              ),
                              title: Text(profileName),
                              subtitle: Text(
                                'Buy-in: ${game.currency} ${game.buyinAmount.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          );
                        },
                      )
                    else if (game.status == 'in_progress')
                      // Active games: Show detailed tables with buy-in/cash-out buttons
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final participant = participants[index];
                          final profileName =
                              participant.profile?.fullName ??
                              participant.profile?.email ??
                              'Unknown';
                          final initialsText =
                              (participant.profile?.firstName ?? 'U')[0]
                                  .toUpperCase() +
                              (participant.profile?.lastName ?? '')[0]
                                  .toUpperCase();
                          final userTxnsAsync = ref.watch(
                            userTransactionsProvider(
                              UserTransactionsKey(
                                gameId: widget.gameId,
                                userId: participant.userId,
                              ),
                            ),
                          );

                          return Card(
                            key: _playerKeys[participant.userId],
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Player header with avatar
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        child: _buildAvatarImage(
                                          participant.profile?.avatarUrl,
                                          initialsText,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          profileName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Player Totals Summary
                                  FutureBuilder<List<TransactionModel>>(
                                    future: ref.read(
                                      gameTransactionsProvider(
                                        widget.gameId,
                                      ).future,
                                    ),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const SizedBox.shrink();
                                      }

                                      final allTransactions = snapshot.data!;
                                      double totalBuyin = game.buyinAmount;
                                      double totalCashout = 0;

                                      for (final txn in allTransactions) {
                                        if (txn.userId == participant.userId) {
                                          if (txn.type == 'buyin') {
                                            totalBuyin += txn.amount;
                                          } else if (txn.type == 'cashout') {
                                            totalCashout += txn.amount;
                                          }
                                        }
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surfaceContainer,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Total Buy-in',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.labelSmall,
                                                  ),
                                                  Text(
                                                    '${game.currency} ${totalBuyin.toStringAsFixed(2)}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Total Cash-out',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.labelSmall,
                                                  ),
                                                  Text(
                                                    '${game.currency} ${totalCashout.toStringAsFixed(2)}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  // Transactions table
                                  userTxnsAsync.when(
                                    loading: () =>
                                        const Text('Loading transactions...'),
                                    error: (_, __) => const Text(
                                      'Could not load transactions',
                                    ),
                                    data: (txns) {
                                      final buyins =
                                          txns
                                              .where((t) => t.type == 'buyin')
                                              .toList()
                                            ..sort(
                                              (a, b) => a.timestamp.compareTo(
                                                b.timestamp,
                                              ),
                                            );
                                      final cashouts =
                                          txns
                                              .where((t) => t.type == 'cashout')
                                              .toList()
                                            ..sort(
                                              (a, b) => a.timestamp.compareTo(
                                                b.timestamp,
                                              ),
                                            );

                                      // Build buy-ins table
                                      final buyinWidget = buyins.isEmpty
                                          ? const SizedBox.shrink()
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Buy-ins',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleSmall,
                                                ),
                                                const SizedBox(height: 8),
                                                Table(
                                                  border: TableBorder.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline
                                                        .withValues(alpha: 0.2),
                                                  ),
                                                  columnWidths: const {
                                                    0: FlexColumnWidth(1.5),
                                                    1: FlexColumnWidth(1.5),
                                                    2: FlexColumnWidth(1),
                                                  },
                                                  defaultVerticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  children: [
                                                    // Header
                                                    TableRow(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondaryContainer,
                                                      ),
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Count',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Time',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Amt',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    // Data rows
                                                    ...buyins.asMap().entries.map((
                                                      entry,
                                                    ) {
                                                      final count =
                                                          entry.key + 1;
                                                      final txn = entry.value;
                                                      return TableRow(
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Text(
                                                              '$count',
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Text(
                                                              DateFormat(
                                                                'HH:mm',
                                                              ).format(
                                                                txn.timestamp,
                                                              ),
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Text(
                                                              '${game.currency} ${txn.amount.toStringAsFixed(2)}',
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    }),
                                                    // Total
                                                    TableRow(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                      ),
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            '${buyins.length}',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.all(6),
                                                          child: Text(
                                                            'Total',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            '${game.currency} ${buyins.map((b) => b.amount).fold<double>(0, (a, b) => a + b).toStringAsFixed(2)}',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                              ],
                                            );

                                      // Build cash-outs table
                                      final cashoutWidget = cashouts.isEmpty
                                          ? const SizedBox.shrink()
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Cash-outs',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleSmall,
                                                ),
                                                const SizedBox(height: 8),
                                                Table(
                                                  border: TableBorder.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline
                                                        .withValues(alpha: 0.2),
                                                  ),
                                                  columnWidths: const {
                                                    0: FlexColumnWidth(1.5),
                                                    1: FlexColumnWidth(1.5),
                                                    2: FlexColumnWidth(1),
                                                  },
                                                  defaultVerticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  children: [
                                                    // Header
                                                    TableRow(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondaryContainer,
                                                      ),
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Count',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Time',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Amt',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    // Data rows
                                                    ...cashouts.asMap().entries.map((
                                                      entry,
                                                    ) {
                                                      final count =
                                                          entry.key + 1;
                                                      final txn = entry.value;
                                                      return TableRow(
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Text(
                                                              '$count',
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Text(
                                                              DateFormat(
                                                                'HH:mm',
                                                              ).format(
                                                                txn.timestamp,
                                                              ),
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    '${game.currency} ${txn.amount.toStringAsFixed(2)}',
                                                                    style: Theme.of(
                                                                      context,
                                                                    ).textTheme.bodySmall,
                                                                    textAlign:
                                                                        TextAlign
                                                                            .right,
                                                                  ),
                                                                ),
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    _showEditCashoutDialog(
                                                                      context,
                                                                      ref,
                                                                      txn,
                                                                      game,
                                                                      participant
                                                                          .userId,
                                                                    );
                                                                  },
                                                                  child: Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          left:
                                                                              4,
                                                                        ),
                                                                    child: Icon(
                                                                      Icons
                                                                          .edit,
                                                                      size: 14,
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.primary,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    }),
                                                    // Total
                                                    TableRow(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                      ),
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            '${cashouts.length}',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.all(6),
                                                          child: Text(
                                                            'Total',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            '${game.currency} ${cashouts.map((c) => c.amount).fold<double>(0, (a, b) => a + b).toStringAsFixed(2)}',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                              ],
                                            );

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          buyinWidget,
                                          cashoutWidget,
                                          // Action buttons
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () async {
                                                    await _showAdditionalBuyinDialog(
                                                      context,
                                                      ref,
                                                      game,
                                                      participant.userId,
                                                    );
                                                  },
                                                  icon: const Icon(Icons.add),
                                                  label: const Text('Buy-in'),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.blue,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () async {
                                                    await _showCashoutDialog(
                                                      context,
                                                      ref,
                                                      game,
                                                      participant.userId,
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.remove,
                                                  ),
                                                  label: const Text('Cash-out'),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.orange,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else if (game.status == 'completed')
                      // Completed games: Show detailed tables without action buttons
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final participant = participants[index];
                          final profileName =
                              participant.profile?.fullName ??
                              participant.profile?.email ??
                              'Unknown';
                          final initialsText =
                              (participant.profile?.firstName ?? 'U')[0]
                                  .toUpperCase() +
                              (participant.profile?.lastName ?? '')[0]
                                  .toUpperCase();
                          final userTxnsAsync = ref.watch(
                            userTransactionsProvider(
                              UserTransactionsKey(
                                gameId: widget.gameId,
                                userId: participant.userId,
                              ),
                            ),
                          );

                          return Card(
                            key: _playerKeys[participant.userId],
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Player header with avatar
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        child: _buildAvatarImage(
                                          participant.profile?.avatarUrl,
                                          initialsText,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          profileName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Transactions table
                                  userTxnsAsync.when(
                                    loading: () =>
                                        const Text('Loading transactions...'),
                                    error: (_, __) => const Text(
                                      'Could not load transactions',
                                    ),
                                    data: (txns) {
                                      final buyins =
                                          txns
                                              .where((t) => t.type == 'buyin')
                                              .toList()
                                            ..sort(
                                              (a, b) => a.timestamp.compareTo(
                                                b.timestamp,
                                              ),
                                            );
                                      final cashouts =
                                          txns
                                              .where((t) => t.type == 'cashout')
                                              .toList()
                                            ..sort(
                                              (a, b) => a.timestamp.compareTo(
                                                b.timestamp,
                                              ),
                                            );

                                      // Build buy-ins table
                                      final buyinWidget = buyins.isEmpty
                                          ? const SizedBox.shrink()
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Buy-ins',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleSmall,
                                                ),
                                                const SizedBox(height: 8),
                                                Table(
                                                  border: TableBorder.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline
                                                        .withValues(alpha: 0.2),
                                                  ),
                                                  columnWidths: const {
                                                    0: FlexColumnWidth(1.5),
                                                    1: FlexColumnWidth(1.5),
                                                    2: FlexColumnWidth(1),
                                                  },
                                                  defaultVerticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  children: [
                                                    // Header
                                                    TableRow(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondaryContainer,
                                                      ),
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Count',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Time',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Amt',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    // Data rows
                                                    ...buyins.asMap().entries.map((
                                                      entry,
                                                    ) {
                                                      final count =
                                                          entry.key + 1;
                                                      final txn = entry.value;
                                                      return TableRow(
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Text(
                                                              '$count',
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Text(
                                                              DateFormat(
                                                                'HH:mm',
                                                              ).format(
                                                                txn.timestamp,
                                                              ),
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Text(
                                                              '${game.currency} ${txn.amount.toStringAsFixed(2)}',
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    }),
                                                    // Total
                                                    TableRow(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                      ),
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            '${buyins.length}',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.all(6),
                                                          child: Text(
                                                            'Total',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            '${game.currency} ${buyins.map((b) => b.amount).fold<double>(0, (a, b) => a + b).toStringAsFixed(2)}',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                              ],
                                            );

                                      // Build cash-outs table
                                      final cashoutWidget = cashouts.isEmpty
                                          ? const SizedBox.shrink()
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Cash-outs',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleSmall,
                                                ),
                                                const SizedBox(height: 8),
                                                Table(
                                                  border: TableBorder.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline
                                                        .withValues(alpha: 0.2),
                                                  ),
                                                  columnWidths: const {
                                                    0: FlexColumnWidth(1.5),
                                                    1: FlexColumnWidth(1.5),
                                                    2: FlexColumnWidth(1),
                                                  },
                                                  defaultVerticalAlignment:
                                                      TableCellVerticalAlignment
                                                          .middle,
                                                  children: [
                                                    // Header
                                                    TableRow(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondaryContainer,
                                                      ),
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Count',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Time',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            'Amt',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelSmall,
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    // Data rows
                                                    ...cashouts.asMap().entries.map((
                                                      entry,
                                                    ) {
                                                      final count =
                                                          entry.key + 1;
                                                      final txn = entry.value;
                                                      return TableRow(
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Text(
                                                              '$count',
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Text(
                                                              DateFormat(
                                                                'HH:mm',
                                                              ).format(
                                                                txn.timestamp,
                                                              ),
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    '${game.currency} ${txn.amount.toStringAsFixed(2)}',
                                                                    style: Theme.of(
                                                                      context,
                                                                    ).textTheme.bodySmall,
                                                                    textAlign:
                                                                        TextAlign
                                                                            .right,
                                                                  ),
                                                                ),
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    _showEditCashoutDialog(
                                                                      context,
                                                                      ref,
                                                                      txn,
                                                                      game,
                                                                      participant
                                                                          .userId,
                                                                    );
                                                                  },
                                                                  child: Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          left:
                                                                              4,
                                                                        ),
                                                                    child: Icon(
                                                                      Icons
                                                                          .edit,
                                                                      size: 14,
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.primary,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    }),
                                                    // Total
                                                    TableRow(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                      ),
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            '${cashouts.length}',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.all(6),
                                                          child: Text(
                                                            'Total',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Text(
                                                            '${game.currency} ${cashouts.map((c) => c.amount).fold<double>(0, (a, b) => a + b).toStringAsFixed(2)}',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            textAlign:
                                                                TextAlign.right,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                              ],
                                            );

                                      final totalBuyins = buyins
                                          .map((b) => b.amount)
                                          .fold<double>(0, (a, b) => a + b);
                                      final totalCashouts = cashouts
                                          .map((c) => c.amount)
                                          .fold<double>(0, (a, b) => a + b);
                                      final netWinLoss =
                                          totalCashouts - totalBuyins;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          buyinWidget,
                                          cashoutWidget,
                                          // Net Win/Loss Summary Card
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: netWinLoss >= 0
                                                  ? Colors.green.withValues(
                                                      alpha: 0.1,
                                                    )
                                                  : Colors.red.withValues(
                                                      alpha: 0.1,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: netWinLoss >= 0
                                                    ? Colors.green
                                                    : Colors.red,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Net Win/Loss',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                Text(
                                                  '${game.currency} ${netWinLoss.toStringAsFixed(2)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: netWinLoss >= 0
                                                            ? Colors.green
                                                            : Colors.red,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      // For other statuses, show simple view
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final participant = participants[index];
                          final profileName =
                              participant.profile?.fullName ??
                              participant.profile?.email ??
                              'Unknown';
                          final initialsText =
                              (participant.profile?.firstName ?? 'U')[0]
                                  .toUpperCase() +
                              (participant.profile?.lastName ?? '')[0]
                                  .toUpperCase();

                          return Card(
                            key: _playerKeys[participant.userId],
                            child: ListTile(
                              leading: CircleAvatar(
                                child: _buildAvatarImage(
                                  participant.profile?.avatarUrl,
                                  initialsText,
                                ),
                              ),
                              title: Text(profileName),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 32),

                    // Cancel Game Button
                    if (game.status == 'scheduled' ||
                        game.status == 'in_progress')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final confirmed =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Cancel Game'),
                                      content: const Text(
                                        'Are you sure you want to cancel this game? This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('No'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('Yes, Cancel Game'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;

                              if (!confirmed) return;

                              try {
                                debugPrint(
                                  '❌ Cancelling game: ${widget.gameId}',
                                );
                                final repo = ref.read(gamesRepositoryProvider);
                                await repo.updateGameStatus(
                                  widget.gameId,
                                  'cancelled',
                                );
                                if (!mounted) return;

                                ref.invalidate(
                                  gameDetailProvider(widget.gameId),
                                );
                                ref.invalidate(activeGamesProvider);
                                ref.invalidate(pastGamesProvider);
                                ref.invalidate(
                                  groupGamesProvider(game.groupId),
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Game cancelled successfully.',
                                    ),
                                  ),
                                );
                              } catch (e, stackTrace) {
                                debugPrint('❌ Error cancelling game: $e');
                                debugPrint('Stack trace: $stackTrace');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error cancelling game: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancel Game'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                            ),
                          ),
                        ),
                      ),

                    // Delete Game Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Game'),
                              content: const Text(
                                'Are you sure you want to delete this game? '
                                'This will permanently remove the game and all '
                                'related records (participants, transactions, settlements). '
                                'This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && mounted) {
                            try {
                              final repository = ref.read(
                                gamesRepositoryProvider,
                              );
                              final result = await repository.deleteGame(
                                widget.gameId,
                              );

                              result.when(
                                success: (_) {
                                  if (mounted) {
                                    ref.invalidate(activeGamesProvider);
                                    ref.invalidate(pastGamesProvider);
                                    ref.invalidate(
                                      groupGamesProvider(game.groupId),
                                    );
                                    ref.invalidate(
                                      gameDetailProvider(widget.gameId),
                                    );

                                    Navigator.of(context).pop();

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Game deleted successfully!',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                failure: (message, _) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $message'),
                                      ),
                                    );
                                  }
                                },
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error deleting game: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete Game'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, softWrap: true)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue.withValues(alpha: 0.3);
      case 'in_progress':
        return Colors.green.withValues(alpha: 0.3);
      case 'completed':
        return Colors.green.withValues(alpha: 0.3);
      case 'cancelled':
        return Colors.red.withValues(alpha: 0.3);
      default:
        return Colors.grey.withValues(alpha: 0.3);
    }
  }
}
