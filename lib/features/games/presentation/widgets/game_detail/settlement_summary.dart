import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/constants/currencies.dart';
import '../../../../../core/utils/avatar_utils.dart';
import '../../../../profile/data/models/profile_model.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/game_participant_model.dart';
import '../../../data/models/transaction_model.dart';

/// Configurable payment methods for flexibility
class PaymentMethod {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final bool supportsDeepLink;
  final String? Function(String identifier, double amount)? buildUrl;

  const PaymentMethod({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.supportsDeepLink = false,
    this.buildUrl,
  });

  static const cash = PaymentMethod(
    id: 'cash',
    label: 'Cash',
    icon: Icons.money,
    color: Colors.green,
  );

  static const venmo = PaymentMethod(
    id: 'venmo',
    label: 'Venmo',
    icon: Icons.mobile_friendly,
    color: Color(0xFF3D95CE),
    supportsDeepLink: true,
  );

  static const paypal = PaymentMethod(
    id: 'paypal',
    label: 'PayPal',
    icon: Icons.account_balance_wallet,
    color: Color(0xFF003087),
    supportsDeepLink: true,
  );

  static const zelle = PaymentMethod(
    id: 'zelle',
    label: 'Zelle',
    icon: Icons.send_to_mobile,
    color: Color(0xFF6D1ED4),
  );

  /// All available payment methods for settlement
  static const List<PaymentMethod> settleMethods = [cash, venmo, paypal, zelle];

  /// Payment methods that support Pay Now deep linking
  static const List<PaymentMethod> payNowMethods = [venmo, paypal];

  /// Get payment method by label (for displaying settled status)
  static PaymentMethod? fromLabel(String? label) {
    if (label == null) return null;
    final lowerLabel = label.toLowerCase();
    for (final method in settleMethods) {
      if (method.label.toLowerCase() == lowerLabel) {
        return method;
      }
    }
    return null;
  }
}

/// Identifier types for payment apps
enum IdentifierType { email, phone, username }

class SettlementSummary extends StatelessWidget {
  final GameModel game;
  final List<GameParticipantModel> participants;
  final List<TransactionModel> transactions;
  final Map<String, Map<String, dynamic>> settlementStatus;
  final Future<void> Function(String fromUserId, String toUserId, double amount, String method) onMarkSettled;
  final Future<void> Function(String fromUserId, String toUserId) onResetSettlement;

  const SettlementSummary({
    required this.game,
    required this.participants,
    required this.transactions,
    required this.settlementStatus,
    required this.onMarkSettled,
    required this.onResetSettlement,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = Currencies.symbols[game.currency] ?? game.currency;
    final settlements = _calculateSettlements();

    if (settlements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.check_circle, size: 48, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                'All Settled!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No settlements needed',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Settlement Summary Section
            Text(
              'Settlement Summary',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...settlements.map((settlement) {
              final fromParticipant = participants.firstWhere(
                (p) => p.userId == settlement['fromUserId'],
                orElse: () => participants.first,
              );
              final toParticipant = participants.firstWhere(
                (p) => p.userId == settlement['toUserId'],
                orElse: () => participants.first,
              );
              return _SettlementCard(
                fromName: settlement['fromName'] as String,
                fromUserId: settlement['fromUserId'] as String,
                fromProfile: fromParticipant.profile,
                toName: settlement['toName'] as String,
                toUserId: settlement['toUserId'] as String,
                toProfile: toParticipant.profile,
                amount: settlement['amount'] as double,
                currency: currency,
                isSettled: _isSettled(settlement['fromUserId'] as String, settlement['toUserId'] as String),
                settlementMethod: _getSettlementMethod(settlement['fromUserId'] as String, settlement['toUserId'] as String),
                onMarkSettled: onMarkSettled,
                onResetSettlement: onResetSettlement,
              );
            }),
          ],
        ),
      ),
    );
  }

  bool _isSettled(String fromUserId, String toUserId) {
    final key = '$fromUserId|$toUserId';
    return settlementStatus[key]?['settled'] == true;
  }

  String? _getSettlementMethod(String fromUserId, String toUserId) {
    final key = '$fromUserId|$toUserId';
    return settlementStatus[key]?['method'] as String?;
  }

  List<Map<String, dynamic>> _calculateSettlements() {
    // Calculate net balance per player
    final balances = <String, double>{};
    final playerNames = <String, String>{};

    for (final txn in transactions) {
      balances[txn.userId] = (balances[txn.userId] ?? 0) +
          (txn.type == 'buyin' ? -txn.amount : txn.amount);
    }

    for (final p in participants) {
      playerNames[p.userId] = p.profile?.fullName ?? 'Unknown';
    }

    // Separate debtors and creditors
    final debtors = <MapEntry<String, double>>[];
    final creditors = <MapEntry<String, double>>[];

    for (final entry in balances.entries) {
      if (entry.value < -0.01) {
        debtors.add(entry);
      } else if (entry.value > 0.01) {
        creditors.add(entry);
      }
    }

    debtors.sort((a, b) => a.value.compareTo(b.value)); // Most negative first
    creditors.sort((a, b) => b.value.compareTo(a.value)); // Most positive first

    // Generate settlements
    final settlements = <Map<String, dynamic>>[];
    var i = 0;
    var j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];

      final debtAmount = debtor.value.abs();
      final creditAmount = creditor.value;
      final settlementAmount = debtAmount < creditAmount ? debtAmount : creditAmount;

      if (settlementAmount > 0.01) {
        settlements.add({
          'fromUserId': debtor.key,
          'fromName': playerNames[debtor.key] ?? 'Unknown',
          'toUserId': creditor.key,
          'toName': playerNames[creditor.key] ?? 'Unknown',
          'amount': settlementAmount,
        });
      }

      // Adjust remaining balances
      if (debtAmount < creditAmount) {
        creditors[j] = MapEntry(creditor.key, creditAmount - debtAmount);
        i++;
      } else if (debtAmount > creditAmount) {
        debtors[i] = MapEntry(debtor.key, -(debtAmount - creditAmount));
        j++;
      } else {
        i++;
        j++;
      }
    }

    return settlements;
  }
}

class _SettlementCard extends StatelessWidget {
  final String fromName;
  final String fromUserId;
  final ProfileModel? fromProfile;
  final String toName;
  final String toUserId;
  final ProfileModel? toProfile;
  final double amount;
  final String currency;
  final bool isSettled;
  final String? settlementMethod;
  final Future<void> Function(String, String, double, String) onMarkSettled;
  final Future<void> Function(String, String) onResetSettlement;

  const _SettlementCard({
    required this.fromName,
    required this.fromUserId,
    this.fromProfile,
    required this.toName,
    required this.toUserId,
    this.toProfile,
    required this.amount,
    required this.currency,
    required this.isSettled,
    this.settlementMethod,
    required this.onMarkSettled,
    required this.onResetSettlement,
  });

  String _getInitials(ProfileModel? profile, String name) {
    if (profile != null) {
      final first = profile.firstName?.isNotEmpty == true ? profile.firstName![0] : '';
      final last = profile.lastName?.isNotEmpty == true ? profile.lastName![0] : '';
      if (first.isNotEmpty || last.isNotEmpty) {
        return '$first$last'.toUpperCase();
      }
    }
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  Widget _buildAvatar(BuildContext context, ProfileModel? profile, String name) {
    final theme = Theme.of(context);
    final initials = _getInitials(profile, name);
    final avatarUrl = profile?.avatarUrl;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    if (avatarUrl.toLowerCase().contains('svg')) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: ClipOval(
          child: SvgPicture.network(
            fixDiceBearUrl(avatarUrl)!,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            placeholderBuilder: (_) => Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (e, s) {},
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  void _showPayNowSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PayNowSheet(
        toName: toName,
        toUserId: toUserId,
        toProfile: toProfile,
        amount: amount,
        currency: currency,
      ),
    );
  }

  void _showSettleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SettleSheet(
        fromUserId: fromUserId,
        toUserId: toUserId,
        toName: toName,
        toProfile: toProfile,
        amount: amount,
        currency: currency,
        onMarkSettled: onMarkSettled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSettled
            ? Colors.green.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSettled ? Colors.green : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // From -> To row with avatars
          Row(
            children: [
              // From user with avatar
              Expanded(
                child: Row(
                  children: [
                    _buildAvatar(context, fromProfile, fromName),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fromName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Owes',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow and amount
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      color: isSettled ? Colors.green : Colors.orange,
                    ),
                    Text(
                      '$currency ${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSettled ? Colors.green : Colors.orange,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // To user with avatar
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            toName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                          Text(
                            'Receives',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAvatar(context, toProfile, toName),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status or action buttons
          if (isSettled)
            _SettledStatusRow(
              settlementMethod: settlementMethod,
              onReset: () => onResetSettlement(fromUserId, toUserId),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPayNowSheet(context),
                    icon: const Icon(Icons.send, size: 14),
                    label: const Text('Pay Now', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () => _showSettleSheet(context),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text('Settle', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Displays the settled status with payment method icon
class _SettledStatusRow extends StatelessWidget {
  final String? settlementMethod;
  final VoidCallback onReset;

  const _SettledStatusRow({
    required this.settlementMethod,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final method = PaymentMethod.fromLabel(settlementMethod);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Settled via',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          // Payment method badge with icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: method?.color ?? theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  method?.icon ?? Icons.payments,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  settlementMethod ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onReset,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Reset', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for Pay Now - launches payment apps with pre-filled info
class _PayNowSheet extends StatefulWidget {
  final String toName;
  final String toUserId;
  final ProfileModel? toProfile;
  final double amount;
  final String currency;

  const _PayNowSheet({
    required this.toName,
    required this.toUserId,
    this.toProfile,
    required this.amount,
    required this.currency,
  });

  @override
  State<_PayNowSheet> createState() => _PayNowSheetState();
}

class _PayNowSheetState extends State<_PayNowSheet> {
  PaymentMethod _selectedMethod = PaymentMethod.venmo;
  IdentifierType _selectedIdentifierType = IdentifierType.username;
  final Map<IdentifierType, TextEditingController> _controllers = {};
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final profile = widget.toProfile;

    // Initialize controllers for each available identifier type
    for (final type in _availableIdentifierTypes) {
      _controllers[type] = TextEditingController();

      if (profile != null) {
        switch (type) {
          case IdentifierType.username:
            _controllers[type]!.text = profile.username ?? '';
            break;
          case IdentifierType.email:
            _controllers[type]!.text = profile.email;
            break;
          case IdentifierType.phone:
            _controllers[type]!.text = profile.phoneNumber ?? '';
            break;
        }
      }
    }

    // Set initial selection based on available data
    if (profile != null) {
      if (profile.username != null && profile.username!.isNotEmpty) {
        _selectedIdentifierType = IdentifierType.username;
      } else if (profile.email.isNotEmpty) {
        _selectedIdentifierType = IdentifierType.email;
      } else if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) {
        _selectedIdentifierType = IdentifierType.phone;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Get available identifier types based on profile data
  List<IdentifierType> get _availableIdentifierTypes {
    final types = <IdentifierType>[];
    final profile = widget.toProfile;

    if (profile?.username != null && profile!.username!.isNotEmpty) {
      types.add(IdentifierType.username);
    }
    if (profile != null && profile.email.isNotEmpty) {
      types.add(IdentifierType.email);
    }
    if (profile?.phoneNumber != null && profile!.phoneNumber!.isNotEmpty) {
      types.add(IdentifierType.phone);
    }

    return types;
  }

  String _getIdentifierLabel(IdentifierType type) {
    switch (type) {
      case IdentifierType.email:
        return 'Email';
      case IdentifierType.phone:
        return 'Phone';
      case IdentifierType.username:
        return 'Username';
    }
  }

  IconData _getIdentifierIcon(IdentifierType type) {
    switch (type) {
      case IdentifierType.email:
        return Icons.email_outlined;
      case IdentifierType.phone:
        return Icons.phone_outlined;
      case IdentifierType.username:
        return Icons.alternate_email;
    }
  }

  String get _initials {
    final profile = widget.toProfile;
    if (profile != null) {
      final first = profile.firstName?.isNotEmpty == true ? profile.firstName![0] : '';
      final last = profile.lastName?.isNotEmpty == true ? profile.lastName![0] : '';
      if (first.isNotEmpty || last.isNotEmpty) {
        return '$first$last'.toUpperCase();
      }
    }
    // Fallback to first two letters of name
    final parts = widget.toName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.toName.substring(0, widget.toName.length.clamp(0, 2)).toUpperCase();
  }

  Future<void> _launchPaymentApp() async {
    setState(() => _isLaunching = true);

    final formattedAmount = widget.amount.toStringAsFixed(2);
    final identifier = _controllers[_selectedIdentifierType]?.text.trim() ?? '';
    final note = Uri.encodeComponent('Poker Settlement');

    String url;
    String fallbackUrl;

    if (_selectedMethod.id == 'venmo') {
      if (identifier.isNotEmpty) {
        url = 'venmo://paycharge?txn=pay&recipients=$identifier&amount=$formattedAmount&note=$note';
      } else {
        url = 'venmo://paycharge?txn=pay&amount=$formattedAmount&note=$note';
      }
      fallbackUrl = 'https://venmo.com/';
    } else {
      if (identifier.isNotEmpty) {
        url = 'https://www.paypal.me/$identifier/$formattedAmount';
      } else {
        url = 'https://www.paypal.com/paypalme';
      }
      fallbackUrl = url;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${_selectedMethod.label}')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLaunching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableTypes = _availableIdentifierTypes;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Avatar
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Pay ${widget.toName}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Amount badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.currency} ${widget.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Choose Payment App label
            Text(
              'Choose Payment App',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Payment app buttons (side by side)
            Row(
              children: PaymentMethod.payNowMethods.map((method) {
                final isSelected = _selectedMethod.id == method.id;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: method == PaymentMethod.payNowMethods.first ? 0 : 6,
                      right: method == PaymentMethod.payNowMethods.last ? 0 : 6,
                    ),
                    child: _PaymentAppButton(
                      method: method,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedMethod = method),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Payment Identifier section (only show if profile has data)
            if (availableTypes.isNotEmpty) ...[
              Text(
                'Payment Identifier',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Identifier options as radio-style cards
              ...availableTypes.map((type) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _IdentifierCard(
                  type: type,
                  label: _getIdentifierLabel(type),
                  icon: _getIdentifierIcon(type),
                  controller: _controllers[type]!,
                  isSelected: _selectedIdentifierType == type,
                  onTap: () => setState(() => _selectedIdentifierType = type),
                ),
              )),
              const SizedBox(height: 16),
            ],

            // Action button
            ElevatedButton(
              onPressed: _isLaunching ? null : _launchPaymentApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedMethod.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLaunching)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _selectedMethod.id == 'venmo' ? 'V' : 'P',
                        style: TextStyle(
                          color: _selectedMethod.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Open ${_selectedMethod.label}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Payment app selection button
class _PaymentAppButton extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentAppButton({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected ? method.color : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? null
                : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : method.color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  method.id == 'venmo' ? 'V' : 'P',
                  style: TextStyle(
                    color: isSelected ? method.color : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                method.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
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

/// Identifier selection card with radio-style selection
class _IdentifierCard extends StatelessWidget {
  final IdentifierType type;
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool isSelected;
  final VoidCallback onTap;

  const _IdentifierCard({
    required this.type,
    required this.label,
    required this.icon,
    required this.controller,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? Colors.green.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.green : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Radio indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.green : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Icon and label
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.green : theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                '$label:',
                style: TextStyle(
                  color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),

              // Editable text field
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: isSelected,
                  style: TextStyle(
                    color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    filled: true,
                    fillColor: isSelected
                        ? theme.colorScheme.surface
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  keyboardType: type == IdentifierType.phone
                      ? TextInputType.phone
                      : type == IdentifierType.email
                          ? TextInputType.emailAddress
                          : TextInputType.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for Settle - mark payment as complete with method selection
class _SettleSheet extends StatefulWidget {
  final String fromUserId;
  final String toUserId;
  final String toName;
  final ProfileModel? toProfile;
  final double amount;
  final String currency;
  final Future<void> Function(String, String, double, String) onMarkSettled;

  const _SettleSheet({
    required this.fromUserId,
    required this.toUserId,
    required this.toName,
    this.toProfile,
    required this.amount,
    required this.currency,
    required this.onMarkSettled,
  });

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  PaymentMethod? _selectedMethod;
  bool _isSettling = false;

  String get _initials {
    final profile = widget.toProfile;
    if (profile != null) {
      final first = profile.firstName?.isNotEmpty == true ? profile.firstName![0] : '';
      final last = profile.lastName?.isNotEmpty == true ? profile.lastName![0] : '';
      if (first.isNotEmpty || last.isNotEmpty) {
        return '$first$last'.toUpperCase();
      }
    }
    final parts = widget.toName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.toName.substring(0, widget.toName.length.clamp(0, 2)).toUpperCase();
  }

  Future<void> _markAsSettled() async {
    if (_selectedMethod == null) return;

    setState(() => _isSettling = true);

    await widget.onMarkSettled(
      widget.fromUserId,
      widget.toUserId,
      widget.amount,
      _selectedMethod!.id,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Avatar
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Settle Payment',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'to ${widget.toName}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Amount badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.currency} ${widget.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Payment method selection label
            Text(
              'How was this paid?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Payment method options as radio-style cards
            ...PaymentMethod.settleMethods.map((method) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SettleMethodCard(
                method: method,
                isSelected: _selectedMethod?.id == method.id,
                onTap: () => setState(() => _selectedMethod = method),
              ),
            )),
            const SizedBox(height: 16),

            // Confirm button
            ElevatedButton(
              onPressed: _selectedMethod == null || _isSettling ? null : _markAsSettled,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSettling)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else ...[
                    const Icon(Icons.check_circle, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Mark as Settled',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settlement method selection card with radio-style selection
class _SettleMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettleMethodCard({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? method.color.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? method.color : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Radio indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? method.color : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: method.color,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? method.color : method.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  method.icon,
                  size: 20,
                  color: isSelected ? Colors.white : method.color,
                ),
              ),
              const SizedBox(width: 12),

              // Label
              Text(
                method.label,
                style: TextStyle(
                  color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
