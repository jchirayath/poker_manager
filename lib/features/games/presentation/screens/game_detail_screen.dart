import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../providers/games_pagination_provider.dart';
import '../providers/games_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/game_model.dart';
import '../../data/models/game_participant_model.dart';
import '../../../../shared/models/result.dart';
import 'edit_game_screen.dart';

import '../../../../core/constants/currencies.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final String gameId;

  const GameDetailScreen({required this.gameId, super.key});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
        Widget _buildPrivacyIcon(String privacy) {
          if (privacy == 'private') {
            return Icon(Icons.lock, color: Theme.of(context).colorScheme.error, size: 18);
          } else {
            return Icon(Icons.public, color: Theme.of(context).colorScheme.primary, size: 18);
          }
        }
      bool _shouldRefreshTransactions = true;
    bool _isStartingGame = false;
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
        fixDiceBearUrl(url)!,
        width: 40,
        height: 40,
        placeholderBuilder: (_) => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorBuilder: (context, error, stackTrace) {
          debugPrint('SVG load error for URL: ${fixDiceBearUrl(url)}');
          debugPrint('Error: $error');
          return Text(initials);
        },
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
          fixDiceBearUrl(url)!,
          width: size,
          height: size,
          placeholderBuilder: (_) => SizedBox(
            width: size / 2,
            height: size / 2,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          errorBuilder: (context, error, stackTrace) {
            debugPrint('SVG load error for URL: ${fixDiceBearUrl(url)}');
            debugPrint('Error: $error');
            return Text(letter);
          },
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundImage: NetworkImage(url),
      backgroundColor: Colors.transparent,
    );
  }

  /// Consistent amount text widget for all monetary displays
  /// [size] can be 'small' (12), 'medium' (14), or 'large' (16)
  Widget _buildAmountText(
    String currency,
    double amount, {
    String size = 'medium',
    bool showSign = false,
    bool bold = true,
    Color? color,
  }) {
    final isPositive = amount >= 0;
    final displayColor = color ?? (isPositive ? Colors.green[700] : Colors.red[700]);
    final sign = showSign ? (isPositive ? '+' : '') : '';
    final fontSize = size == 'small' ? 12.0 : (size == 'large' ? 15.0 : 13.0);

    final symbol = Currencies.symbols[currency] ?? currency;
    return Text(
      '$sign$symbol ${amount.abs().toStringAsFixed(2)}',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        color: displayColor,
      ),
    );
  }

  /// Amount badge widget for highlighted amounts (like in settlement cards)
  Widget _buildAmountBadge(String currency, double amount, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
      ),
      child: Text(
        '${Currencies.symbols[currency] ?? currency} ${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.green[700],
          fontSize: compact ? 12 : 13,
        ),
      ),
    );
  }

  Widget _buildZeroBuyinView(BuildContext context, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Initial buy-in: ${Currencies.symbols[currency] ?? currency} 0.00',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Total cash: ${Currencies.symbols[currency] ?? currency} 0.00',
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
            labelText: 'Amount (${Currencies.symbols[game.currency] ?? game.currency})',
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
              'Additional buy-in of ${Currencies.symbols[game.currency] ?? game.currency} ${result.toStringAsFixed(2)} added',
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
            labelText: 'Amount (${Currencies.symbols[game.currency] ?? game.currency})',
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
              'Cash-out of ${Currencies.symbols[game.currency] ?? game.currency} ${result.toStringAsFixed(2)} recorded',
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
            labelText: 'Amount (${Currencies.symbols[game.currency] ?? game.currency})',
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
              'Buy-in updated to ${Currencies.symbols[game.currency] ?? game.currency} ${result.toStringAsFixed(2)}',
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
            labelText: 'Amount (${Currencies.symbols[game.currency] ?? game.currency})',
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
              'Cash-out updated to ${Currencies.symbols[game.currency] ?? game.currency} ${result.toStringAsFixed(2)}',
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

    final hasUsername = profile.username?.isNotEmpty ?? false;
    final hasEmail = profile.email?.isNotEmpty ?? false;
    final hasPhone = profile.phoneNumber?.isNotEmpty ?? false;

    if (!hasUsername && !hasEmail && !hasPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No payment information available for this user. Ask them to add their Venmo/PayPal info to their profile.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) => _PaymentOptionsSheet(
        profile: profile,
        amount: amount,
        currency: currency,
        theme: theme,
        onLaunchVenmo: (identifier, type) {
          Navigator.of(dialogContext).pop();
          _launchVenmoPayment(identifier, type, amount, profile.fullName);
        },
        onLaunchPayPal: (identifier, type) {
          Navigator.of(dialogContext).pop();
          _launchPayPalPayment(identifier, type, amount);
        },
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// Launch Venmo payment using deep link
  Future<void> _launchVenmoPayment(String identifier, String type, double amount, String? recipientName) async {
    final note = Uri.encodeComponent('Poker game settlement${recipientName != null ? ' - $recipientName' : ''}');
    String venmoDeepLink;
    String venmoWebUrl;

    switch (type) {
      case 'username':
        final cleanUsername = identifier.startsWith('@') ? identifier.substring(1) : identifier;
        venmoDeepLink = 'venmo://paycharge?txn=pay&recipients=$cleanUsername&amount=${amount.toStringAsFixed(2)}&note=$note';
        venmoWebUrl = 'https://venmo.com/$cleanUsername?txn=pay&amount=${amount.toStringAsFixed(2)}&note=$note';
        break;
      case 'phone':
        final cleanPhone = identifier.replaceAll(RegExp(r'[^\d]'), '');
        venmoDeepLink = 'venmo://paycharge?txn=pay&recipients=$cleanPhone&amount=${amount.toStringAsFixed(2)}&note=$note';
        venmoWebUrl = 'https://venmo.com/';
        break;
      case 'email':
      default:
        venmoDeepLink = 'venmo://paycharge?txn=pay&recipients=${Uri.encodeComponent(identifier)}&amount=${amount.toStringAsFixed(2)}&note=$note';
        venmoWebUrl = 'https://venmo.com/';
        break;
    }

    await _launchPaymentUrl(venmoDeepLink, venmoWebUrl, 'Venmo');
  }

  /// Launch PayPal payment
  Future<void> _launchPayPalPayment(String identifier, String type, double amount) async {
    String paypalUrl;
    String paypalDeepLink;

    switch (type) {
      case 'username':
        final cleanUsername = identifier.startsWith('@') ? identifier.substring(1) : identifier;
        paypalUrl = 'https://paypal.me/$cleanUsername/${amount.toStringAsFixed(2)}';
        paypalDeepLink = 'paypal://paypalme/$cleanUsername/${amount.toStringAsFixed(2)}';
        break;
      case 'email':
        // PayPal can use email for payment
        paypalUrl = 'https://www.paypal.com/paypalme/my/profile?email=${Uri.encodeComponent(identifier)}';
        paypalDeepLink = 'paypal://send?recipient=${Uri.encodeComponent(identifier)}&amount=${amount.toStringAsFixed(2)}';
        break;
      case 'phone':
      default:
        // PayPal mobile payments
        final cleanPhone = identifier.replaceAll(RegExp(r'[^\d]'), '');
        paypalUrl = 'https://www.paypal.com/';
        paypalDeepLink = 'paypal://send?recipient=$cleanPhone&amount=${amount.toStringAsFixed(2)}';
        break;
    }

    await _launchPaymentUrl(paypalDeepLink, paypalUrl, 'PayPal');
  }

  /// Helper to launch payment URL with deep link fallback
  Future<void> _launchPaymentUrl(String deepLink, String webUrl, String appName) async {
    try {
      final deepLinkUri = Uri.parse(deepLink);
      final webUri = Uri.parse(webUrl);

      // Try deep link first (opens app directly)
      bool launched = await launchUrl(
        deepLinkUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fall back to web URL
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched) {
        // Copy URL to clipboard as last resort
        await Clipboard.setData(ClipboardData(text: webUrl));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$appName link copied to clipboard'),
              action: SnackBarAction(
                label: 'Open Browser',
                onPressed: () {
                  launchUrl(webUri, mode: LaunchMode.platformDefault);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      // If deep link fails, try web URL
      try {
        final webUri = Uri.parse(webUrl);
        final launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          await Clipboard.setData(ClipboardData(text: webUrl));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$appName link copied to clipboard'),
              ),
            );
          }
        }
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open $appName: $e2')),
          );
        }
      }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final settlementMethods = [
      {
        'label': 'Cash',
        'method': 'cash',
        'icon': Icons.payments_rounded,
        'color': const Color(0xFF4CAF50),
      },
      {
        'label': 'Venmo',
        'method': 'venmo',
        'icon': Icons.phone_iphone,
        'color': const Color(0xFF3D95CE),
      },
      {
        'label': 'PayPal',
        'method': 'paypal',
        'icon': Icons.payment,
        'color': const Color(0xFF003087),
      },
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Checkmark icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Mark as Settled',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Payment info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      // From user
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            child: Text(
                              _getInitials(from.profile?.fullName ?? 'U'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              from.profile?.fullName ?? 'Unknown',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Arrow with amount
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            const SizedBox(width: 18),
                            Container(
                              width: 2,
                              height: 20,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_downward,
                                    size: 14,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 4),
                                  _buildAmountText(
                                    game.currency,
                                    amount,
                                    size: 'medium',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // To user
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.green.withValues(alpha: 0.1),
                            child: Text(
                              _getInitials(to.profile?.fullName ?? 'U'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              to.profile?.fullName ?? 'Unknown',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Payment method label
                Text(
                  'How was it paid?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment method buttons
                ...settlementMethods.map((method) {
                  final color = method['color'] as Color;
                  final icon = method['icon'] as IconData;
                  final label = method['label'] as String;
                  final methodName = method['method'] as String;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          setState(() {
                            final key = '${from.id}|${to.id}';
                            _settlementStatus[key] = {
                              'settled': true,
                              'method': methodName,
                            };
                          });
                          _recordSettlement(
                            gameId: game.id,
                            fromUserId: from.id,
                            toUserId: to.id,
                            amount: amount,
                            method: methodName,
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getPaymentMethodImage(String method, double size, {Color? color}) {
    final iconColor = color ?? Colors.white;
    switch (method.toLowerCase()) {
      case 'paypal':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF003087),
            borderRadius: BorderRadius.circular(size / 4),
          ),
          child: Center(
            child: Text(
              'P',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.6,
              ),
            ),
          ),
        );
      case 'venmo':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF3D95CE),
            borderRadius: BorderRadius.circular(size / 4),
          ),
          child: Center(
            child: Text(
              'V',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.6,
              ),
            ),
          ),
        );
      case 'cash':
        return Icon(Icons.payments, size: size, color: iconColor);
      default:
        return Icon(Icons.payment, size: size, color: iconColor);
    }
  }

  void _showResetSettlementDialog(
    BuildContext context,
    dynamic from,
    dynamic to,
    String method,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Warning icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.undo_rounded,
                    color: Colors.orange,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Reset Settlement?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will clear the settlement record',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Settlement info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      // From avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Text(
                          _getInitials(from.profile?.fullName ?? 'U'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Arrow
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              from.profile?.fullName ?? 'Unknown',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    method,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              to.profile?.fullName ?? 'Unknown',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),
                      // To avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                        child: Text(
                          _getInitials(to.profile?.fullName ?? 'U'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _deleteSettlement(
                            gameId: widget.gameId,
                            from: from,
                            to: to,
                          );
                        },
                        icon: const Icon(Icons.undo_rounded, size: 20),
                        label: const Text('Reset'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
        },
      );
    } catch (e) {
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
    // Only refresh transactions once on initial load to avoid refresh loop
    if (_shouldRefreshTransactions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.refresh(gameTransactionsProvider(widget.gameId));
        setState(() {
          _shouldRefreshTransactions = false;
        });
      });
    }

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
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating button to scroll to top (left of title)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Game Details'),
                const SizedBox(width: 8),
                // Floating button to scroll to bottom (right of title)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_downward, size: 20),
                    ),
                  ),
                ),
              ],
            ),
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
                              const SizedBox(width: 8),
                              _buildPrivacyIcon(group.privacy),
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
                              '${Currencies.symbols[game.currency] ?? game.currency} ${game.buyinAmount.toStringAsFixed(2)}',
                            ),
                            _buildInfoRow(
                              'Additional Buy-in',
                              game.additionalBuyinValues.isNotEmpty
                                  ? game.additionalBuyinValues.map((v) => '${Currencies.symbols[game.currency] ?? game.currency} ${v.toStringAsFixed(2)}').join(', ')
                                  : '-',
                            ),
                            _buildInfoRow(
                              'Group Privacy',
                              groupAsync.hasValue && groupAsync.value != null && groupAsync.value!.privacy == 'private' ? 'Private' : 'Public',
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
                                    final byUser = <String, List<TransactionModel>>{};
                                    for (final txn in txns) {
                                      byUser.putIfAbsent(txn.userId, () => []).add(txn);
                                    }

                                    double initialTotal = 0;
                                    double additionalTotal = 0;
                                    double cashOutTotal = 0;

                                    byUser.forEach((userId, userTxns) {
                                      final buyins = userTxns
                                          .where((t) => t.type == 'buyin')
                                          .toList()
                                        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                                      final cashouts = userTxns.where((t) => t.type == 'cashout');

                                      if (buyins.isNotEmpty) {
                                        final firstBuyinAmount = buyins.first.amount;
                                        initialTotal += firstBuyinAmount;
                                        if (buyins.length > 1) {
                                          final addtl = buyins
                                              .skip(1)
                                              .map((b) => b.amount)
                                              .fold<double>(0, (a, b) => a + b);
                                          additionalTotal += addtl;
                                        }
                                      }

                                      final userCashout = cashouts
                                          .map((c) => c.amount)
                                          .fold<double>(0, (a, b) => a + b);
                                      cashOutTotal += userCashout;
                                    });

                                    final totalBalance = (initialTotal + additionalTotal) - cashOutTotal;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Totals',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(2),
                                            1: FlexColumnWidth(1),
                                          },
                                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                          children: [
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  child: Text(
                                                    'Initial Buy-In Total',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  child: Text(
                                                    '${Currencies.symbols[game.currency] ?? game.currency} ${initialTotal.toStringAsFixed(2)}',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  child: Text(
                                                    'Additional Buy-In Total',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  child: Text(
                                                    '${Currencies.symbols[game.currency] ?? game.currency} ${additionalTotal.toStringAsFixed(2)}',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  child: Text(
                                                    'Cash Out Total',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  child: Text(
                                                    '${Currencies.symbols[game.currency] ?? game.currency} ${cashOutTotal.toStringAsFixed(2)}',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            TableRow(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  child: Text(
                                                    'Total Balance',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  child: Text(
                                                    '${Currencies.symbols[game.currency] ?? game.currency} ${totalBalance.toStringAsFixed(2)}',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
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
                                          final theme = Theme.of(context);
                                          final isDark = theme.brightness == Brightness.dark;
                                          final key = '${from.id}|${to.id}';
                                          final status = _settlementStatus[key];
                                          final isSettled = status?['settled'] ?? false;
                                          final settlementMethod = status?['method'] as String?;

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isSettled
                                                    ? Colors.green.withValues(alpha: 0.05)
                                                    : (isDark ? Colors.grey[850] : Colors.grey[50]),
                                                border: Border.all(
                                                  color: isSettled
                                                      ? Colors.green.withValues(alpha: 0.3)
                                                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                children: [
                                                  // Main settlement info row
                                                  Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: Row(
                                                      children: [
                                                        // From avatar
                                                        CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                                          child: Text(
                                                            _getInitials(from.profile?.fullName ?? 'U'),
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: theme.colorScheme.primary,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        // From name and arrow
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
                                                                  const SizedBox(width: 8),
                                                                  _buildPrivacyIcon(group.privacy),
                                                                ],
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Action buttons row
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        top: BorderSide(
                                                          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                                        ),
                                                      ),
                                                    ),
                                                    child: isSettled
                                                        ? // Settled state - show settled badge with reset option
                                                          InkWell(
                                                            onTap: () {
                                                              _showResetSettlementDialog(
                                                                context,
                                                                from,
                                                                to,
                                                                settlementMethod ?? 'Unknown',
                                                              );
                                                            },
                                                            borderRadius: const BorderRadius.vertical(
                                                              bottom: Radius.circular(12),
                                                            ),
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 10,
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  const Icon(
                                                                    Icons.check_circle,
                                                                    size: 16,
                                                                    color: Colors.green,
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                  Text(
                                                                    'Settled via ${settlementMethod ?? "Unknown"}',
                                                                    style: const TextStyle(
                                                                      color: Colors.green,
                                                                      fontWeight: FontWeight.w600,
                                                                      fontSize: 13,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 8),
                                                                  Icon(
                                                                    Icons.edit_outlined,
                                                                    size: 14,
                                                                    color: Colors.grey[500],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          )
                                                        : // Not settled - show action buttons
                                                          Row(
                                                            children: [
                                                              // Pay button
                                                              Expanded(
                                                                child: InkWell(
                                                                  onTap: () {
                                                                    _showPaymentOptionsDialog(
                                                                      context,
                                                                      to,
                                                                      amount,
                                                                      game.currency,
                                                                    );
                                                                  },
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                                    decoration: BoxDecoration(
                                                                      borderRadius: const BorderRadius.only(
                                                                        bottomLeft: Radius.circular(11),
                                                                      ),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                      children: [
                                                                        Icon(
                                                                          Icons.send_rounded,
                                                                          size: 16,
                                                                          color: theme.colorScheme.primary,
                                                                        ),
                                                                        const SizedBox(width: 6),
                                                                        Text(
                                                                          'Pay Now',
                                                                          style: TextStyle(
                                                                            color: theme.colorScheme.primary,
                                                                            fontWeight: FontWeight.w600,
                                                                            fontSize: 13,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              // Divider
                                                              Container(
                                                                width: 1,
                                                                height: 36,
                                                                color: isDark ? Colors.grey[700] : Colors.grey[200],
                                                              ),
                                                              // Mark Settled button
                                                              Expanded(
                                                                child: InkWell(
                                                                  onTap: () {
                                                                    _showSettlementDialog(
                                                                      context,
                                                                      from,
                                                                      to,
                                                                      amount,
                                                                      game,
                                                                    );
                                                                  },
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                                    decoration: BoxDecoration(
                                                                      borderRadius: const BorderRadius.only(
                                                                        bottomRight: Radius.circular(11),
                                                                      ),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                      children: [
                                                                        Icon(
                                                                          Icons.check_circle_outline,
                                                                          size: 16,
                                                                          color: Colors.green[600],
                                                                        ),
                                                                        const SizedBox(width: 6),
                                                                        Text(
                                                                          'Mark Settled',
                                                                          style: TextStyle(
                                                                            color: Colors.green[600],
                                                                            fontWeight: FontWeight.w600,
                                                                            fontSize: 13,
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
                                                _buildAmountText(
                                                  game.currency,
                                                  winLoss,
                                                  size: 'medium',
                                                  showSign: true,
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
                                                  padding: const EdgeInsets.all(8),
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: _buildAmountText(
                                                      game.currency,
                                                      buyins,
                                                      size: 'small',
                                                      bold: false,
                                                      color: Theme.of(context).textTheme.bodyMedium?.color,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: _buildAmountText(
                                                      game.currency,
                                                      cashouts,
                                                      size: 'small',
                                                      bold: false,
                                                      color: Theme.of(context).textTheme.bodyMedium?.color,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: _buildAmountText(
                                                      game.currency,
                                                      winLoss,
                                                      size: 'small',
                                                      showSign: true,
                                                    ),
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
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isStartingGame
                                      ? null
                                      : () async {
                                          setState(() {
                                            _isStartingGame = true;
                                          });
                                          try {
                                            await ref
                                                .read(startGameProvider.notifier)
                                                .startExistingGame(widget.gameId);
                                            if (!mounted) return;
                                            ref.invalidate(
                                              gameDetailProvider(widget.gameId),
                                            );
                                            ref.invalidate(activeGamesProvider);
                                            ref.invalidate(pastGamesProvider);
                                            ref.invalidate(
                                              groupGamesProvider(game.groupId),
                                            );
                                            // Refresh game details and transactions after starting
                                            ref.invalidate(gameWithParticipantsProvider(widget.gameId));
                                            ref.invalidate(gameTransactionsProvider(widget.gameId));
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
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _isStartingGame = false;
                                              });
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.play_arrow),
                                  label: _isStartingGame
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Loading transactions - please wait...',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text('Start Game'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    foregroundColor: Colors.green,
                                    side: const BorderSide(color: Colors.green),
                                  ),
                                ),
                              ),
                              if (_isStartingGame)
                                const Positioned.fill(
                                  child: ColoredBox(
                                    color: Color.fromRGBO(255, 255, 255, 0.6),
                                    child: Center(
                                      child: SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
                                // Refresh game details and transactions after stopping
                                ref.invalidate(gameWithParticipantsProvider(widget.gameId));
                                ref.invalidate(gameTransactionsProvider(widget.gameId));
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

                                // Ensure all participants have entries (even if no transactions yet)
                                for (final participant in participants) {
                                  if (!summaryData.containsKey(
                                    participant.userId,
                                  )) {
                                    summaryData[participant.userId] = {
                                      'buyin': 0,
                                      'cashout': 0,
                                    };
                                  }
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
                                            '${Currencies.symbols[game.currency] ?? game.currency} ${buyin.toStringAsFixed(2)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            '${Currencies.symbols[game.currency] ?? game.currency} ${cashout.toStringAsFixed(2)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            '${Currencies.symbols[game.currency] ?? game.currency} ${net.toStringAsFixed(2)}',
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
                                          '${Currencies.symbols[game.currency] ?? game.currency} ${totalBuyin.toStringAsFixed(2)}',
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
                                          '${Currencies.symbols[game.currency] ?? game.currency} ${totalCashout.toStringAsFixed(2)}',
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
                                          '${Currencies.symbols[game.currency] ?? game.currency} ${totalNet.toStringAsFixed(2)}',
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
                                'Buy-in: ${Currencies.symbols[game.currency] ?? game.currency} ${game.buyinAmount.toStringAsFixed(2)}',
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
                                      double totalBuyin = 0;
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
                                                    '${Currencies.symbols[game.currency] ?? game.currency} ${totalBuyin.toStringAsFixed(2)}',
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
                                                    '${Currencies.symbols[game.currency] ?? game.currency} ${totalCashout.toStringAsFixed(2)}',
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
                                                              '${Currencies.symbols[game.currency] ?? game.currency} ${txn.amount.toStringAsFixed(2)}',
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
                                                            '${Currencies.symbols[game.currency] ?? game.currency} ${buyins.map((b) => b.amount).fold<double>(0, (a, b) => a + b).toStringAsFixed(2)}',
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
                                                                    '${Currencies.symbols[game.currency] ?? game.currency} ${txn.amount.toStringAsFixed(2)}',
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
                                                            '${Currencies.symbols[game.currency] ?? game.currency} ${cashouts.map((c) => c.amount).fold<double>(0, (a, b) => a + b).toStringAsFixed(2)}',
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
                                                child: SizedBox(
                                                  height: 36,
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      await _showAdditionalBuyinDialog(
                                                        context,
                                                        ref,
                                                        game,
                                                        participant.userId,
                                                      );
                                                    },
                                                    icon: const Icon(Icons.add, size: 18),
                                                    label: const Text('Buy-in', style: TextStyle(fontSize: 13)),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.blue,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: SizedBox(
                                                  height: 36,
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      await _showCashoutDialog(
                                                        context,
                                                        ref,
                                                        game,
                                                        participant.userId,
                                                      );
                                                    },
                                                    icon: const Icon(Icons.remove, size: 18),
                                                    label: const Text('Cash-out', style: TextStyle(fontSize: 13)),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.orange,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                                        ),
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
                                                              '${Currencies.symbols[game.currency] ?? game.currency} ${txn.amount.toStringAsFixed(2)}',
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
                                                            '${Currencies.symbols[game.currency] ?? game.currency} ${buyins.map((b) => b.amount).fold<double>(0, (a, b) => a + b).toStringAsFixed(2)}',
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
                                                                    '${Currencies.symbols[game.currency] ?? game.currency} ${txn.amount.toStringAsFixed(2)}',
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
                                                            '${Currencies.symbols[game.currency] ?? game.currency} ${cashouts.map((c) => c.amount).fold<double>(0, (a, b) => a + b).toStringAsFixed(2)}',
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
                                                  '${Currencies.symbols[game.currency] ?? game.currency} ${netWinLoss.toStringAsFixed(2)}',
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

                                ref.invalidate(paginatedGamesProvider);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Game cancelled successfully.',
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop(true); // <-- Return true to trigger refresh
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

                                    ref.invalidate(paginatedGamesProvider);
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

/// Payment options bottom sheet with editable fields
class _PaymentOptionsSheet extends StatefulWidget {
  final dynamic profile;
  final double amount;
  final String currency;
  final ThemeData theme;
  final void Function(String identifier, String type) onLaunchVenmo;
  final void Function(String identifier, String type) onLaunchPayPal;

  const _PaymentOptionsSheet({
    required this.profile,
    required this.amount,
    required this.currency,
    required this.theme,
    required this.onLaunchVenmo,
    required this.onLaunchPayPal,
  });

  @override
  State<_PaymentOptionsSheet> createState() => _PaymentOptionsSheetState();
}

class _PaymentOptionsSheetState extends State<_PaymentOptionsSheet> {
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  String _selectedPaymentApp = 'venmo'; // 'venmo' or 'paypal'
  String _selectedIdentifierType = 'username'; // 'username', 'email', or 'phone'

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.profile.username ?? '');
    _emailController = TextEditingController(text: widget.profile.email ?? '');
    _phoneController = TextEditingController(text: widget.profile.phoneNumber ?? '');

    // Set default identifier type based on available data
    if (widget.profile.username?.isNotEmpty ?? false) {
      _selectedIdentifierType = 'username';
    } else if (widget.profile.email?.isNotEmpty ?? false) {
      _selectedIdentifierType = 'email';
    } else if (widget.profile.phoneNumber?.isNotEmpty ?? false) {
      _selectedIdentifierType = 'phone';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  void _launchPayment() {
    String identifier;
    switch (_selectedIdentifierType) {
      case 'username':
        identifier = _usernameController.text.trim();
        break;
      case 'email':
        identifier = _emailController.text.trim();
        break;
      case 'phone':
        identifier = _phoneController.text.trim();
        break;
      default:
        identifier = '';
    }

    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid identifier')),
      );
      return;
    }

    if (_selectedPaymentApp == 'venmo') {
      widget.onLaunchVenmo(identifier, _selectedIdentifierType);
    } else {
      widget.onLaunchPayPal(identifier, _selectedIdentifierType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isDark = theme.brightness == Brightness.dark;
    final hasUsername = widget.profile.username?.isNotEmpty ?? false;
    final hasEmail = widget.profile.email?.isNotEmpty ?? false;
    final hasPhone = widget.profile.phoneNumber?.isNotEmpty ?? false;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Avatar and name
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    _getInitials(widget.profile.fullName ?? 'U'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pay ${widget.profile.fullName ?? 'User'}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Amount
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.currency} ${widget.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment App Selection
                Text(
                  'Choose Payment App',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PaymentAppButton(
                        label: 'Venmo',
                        color: const Color(0xFF3D95CE),
                        isSelected: _selectedPaymentApp == 'venmo',
                        onTap: () => setState(() => _selectedPaymentApp = 'venmo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PaymentAppButton(
                        label: 'PayPal',
                        color: const Color(0xFF003087),
                        isSelected: _selectedPaymentApp == 'paypal',
                        onTap: () => setState(() => _selectedPaymentApp = 'paypal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Identifier Selection & Editing
                Text(
                  'Payment Identifier',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),

                // Show only available identifier options
                if (hasUsername)
                  _IdentifierOption(
                    type: 'username',
                    label: 'Username',
                    icon: Icons.alternate_email,
                    controller: _usernameController,
                    isSelected: _selectedIdentifierType == 'username',
                    onSelect: () => setState(() => _selectedIdentifierType = 'username'),
                    theme: theme,
                  ),
                if (hasEmail)
                  _IdentifierOption(
                    type: 'email',
                    label: 'Email',
                    icon: Icons.email_outlined,
                    controller: _emailController,
                    isSelected: _selectedIdentifierType == 'email',
                    onSelect: () => setState(() => _selectedIdentifierType = 'email'),
                    theme: theme,
                  ),
                if (hasPhone)
                  _IdentifierOption(
                    type: 'phone',
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    controller: _phoneController,
                    isSelected: _selectedIdentifierType == 'phone',
                    onSelect: () => setState(() => _selectedIdentifierType = 'phone'),
                    theme: theme,
                  ),

                const SizedBox(height: 24),

                // Launch Payment Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _launchPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPaymentApp == 'venmo'
                          ? const Color(0xFF3D95CE)
                          : const Color(0xFF003087),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              _selectedPaymentApp == 'venmo' ? 'V' : 'P',
                              style: TextStyle(
                                color: _selectedPaymentApp == 'venmo'
                                    ? const Color(0xFF3D95CE)
                                    : const Color(0xFF003087),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Open ${_selectedPaymentApp == 'venmo' ? 'Venmo' : 'PayPal'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Payment app selection button
class _PaymentAppButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentAppButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.grey[400]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    label[0],
                    style: TextStyle(
                      color: isSelected ? color : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Identifier option with editable text field
class _IdentifierOption extends StatelessWidget {
  final String type;
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool isSelected;
  final VoidCallback onSelect;
  final ThemeData theme;

  const _IdentifierOption({
    required this.type,
    required this.label,
    required this.icon,
    required this.controller,
    required this.isSelected,
    required this.onSelect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : (isDark ? Colors.grey[800] : Colors.grey[100]),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Radio-style indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    width: 2,
                  ),
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Text(
                '$label:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  onTap: onSelect,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[900] : Colors.white,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
