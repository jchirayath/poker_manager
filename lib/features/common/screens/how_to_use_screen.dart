import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Use'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header section with gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.3),
                    colorScheme.surface,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.help_outline,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome to ${AppConstants.appNameWithBeta}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your complete poker game management solution',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Help sections
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHelpCard(
                    context: context,
                    icon: Icons.group_add,
                    title: 'Getting Started',
                    stepNumber: '1',
                    content: [
                      _HelpItem(
                        title: 'Create a Group',
                        description:
                            'Start by creating a poker group for your friends. Tap the "+" button or go to Groups tab and select "Create Group". Give your group a name and optionally add a description.',
                      ),
                      _HelpItem(
                        title: 'Invite Players',
                        description:
                            'Invite friends to your group by sharing the group invite link or adding them directly by email. Group members can view games, RSVP, and track their stats.',
                      ),
                      _HelpItem(
                        title: 'Join Existing Groups',
                        description:
                            'Accept invitations from friends to join their poker groups. You can be a member of multiple groups simultaneously.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHelpCard(
                    context: context,
                    icon: Icons.casino,
                    title: 'Managing Games',
                    stepNumber: '2',
                    content: [
                      _HelpItem(
                        title: 'Schedule a Game',
                        description:
                            'Create a new game by selecting a date, time, and location. Set the buy-in amount and maximum players. Group members will be notified about the upcoming game.',
                      ),
                      _HelpItem(
                        title: 'RSVP to Games',
                        description:
                            'Let others know if you\'re attending by RSVPing to scheduled games. You can change your response anytime before the game starts.',
                      ),
                      _HelpItem(
                        title: 'Start a Game',
                        description:
                            'When it\'s time to play, the game host can start the game. This enables buy-in tracking and allows players to join the active session.',
                      ),
                      _HelpItem(
                        title: 'Game Status',
                        description:
                            'Games progress through stages: Scheduled → In Progress → Completed. Cancelled games are kept for reference but don\'t affect stats.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHelpCard(
                    context: context,
                    icon: Icons.payments,
                    title: 'Tracking Buy-ins & Cash-outs',
                    stepNumber: '3',
                    content: [
                      _HelpItem(
                        title: 'Record Buy-ins',
                        description:
                            'When a player buys in, record the amount in the game. Players can buy in multiple times during a session (rebuys). All transactions are tracked with timestamps.',
                      ),
                      _HelpItem(
                        title: 'Record Cash-outs',
                        description:
                            'At the end of the game, record each player\'s final chip count as their cash-out. The app automatically calculates each player\'s profit or loss.',
                      ),
                      _HelpItem(
                        title: 'Financial Balance',
                        description:
                            'The total buy-ins must equal total cash-outs for the game to be completed. This ensures accurate record-keeping and prevents errors.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHelpCard(
                    context: context,
                    icon: Icons.handshake,
                    title: 'Settlements',
                    stepNumber: '4',
                    content: [
                      _HelpItem(
                        title: 'Automatic Calculation',
                        description:
                            'After a game ends, the app automatically calculates who owes whom. The settlement algorithm minimizes the number of transactions needed.',
                      ),
                      _HelpItem(
                        title: 'Payment Methods',
                        description:
                            'Mark settlements as paid via cash, Venmo, PayPal, or other methods. Both parties can see the settlement status.',
                      ),
                      _HelpItem(
                        title: 'Settlement History',
                        description:
                            'View all past settlements in the game details. Track pending and completed payments to ensure everyone gets paid.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHelpCard(
                    context: context,
                    icon: Icons.bar_chart,
                    title: 'Statistics & Leaderboards',
                    stepNumber: '5',
                    content: [
                      _HelpItem(
                        title: 'Personal Stats',
                        description:
                            'Track your performance over time including total games played, net profit/loss, biggest win, and win rate. Stats are calculated per group.',
                      ),
                      _HelpItem(
                        title: 'Group Leaderboard',
                        description:
                            'See how you rank against other players in your group. Leaderboards show total earnings, games played, and other metrics.',
                      ),
                      _HelpItem(
                        title: 'Game History',
                        description:
                            'Browse through past games to see detailed results, including all participants, transactions, and settlements.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHelpCard(
                    context: context,
                    icon: Icons.admin_panel_settings,
                    title: 'Group Administration',
                    stepNumber: '6',
                    content: [
                      _HelpItem(
                        title: 'Admin Roles',
                        description:
                            'Group creators are automatically admins. Admins can invite/remove members, create/edit games, and manage group settings.',
                      ),
                      _HelpItem(
                        title: 'Member Management',
                        description:
                            'Admins can promote members to admin status or remove them from the group. Regular members can view games and their own stats.',
                      ),
                      _HelpItem(
                        title: 'Group Settings',
                        description:
                            'Customize your group with a name, description, default buy-in amounts, and preferred currency.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHelpCard(
                    context: context,
                    icon: Icons.tips_and_updates,
                    title: 'Tips & Best Practices',
                    stepNumber: '',
                    isNumbered: false,
                    content: [
                      _HelpItem(
                        title: 'Record Transactions Promptly',
                        description:
                            'Enter buy-ins and cash-outs as they happen to avoid confusion later. Real-time tracking ensures accuracy.',
                      ),
                      _HelpItem(
                        title: 'Complete Games Properly',
                        description:
                            'Always mark games as completed after entering all cash-outs. This triggers settlement calculations and updates stats.',
                      ),
                      _HelpItem(
                        title: 'Keep Your Profile Updated',
                        description:
                            'Add your Venmo/PayPal username to make settlements easier. Other players can quickly find your payment info.',
                      ),
                      _HelpItem(
                        title: 'Use Locations',
                        description:
                            'Save frequently used game locations for quick selection when scheduling games. Hosts can share their address with the group.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Support section
                  Card(
                    elevation: 0,
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.support_agent,
                            size: 40,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Need More Help?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'If you have questions or need assistance, use the feedback option in the menu to reach our support team.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String stepNumber,
    required List<_HelpItem> content,
    bool isNumbered = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: stepNumber == '1',
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 24,
              color: colorScheme.primary,
            ),
          ),
          title: Row(
            children: [
              if (isNumbered && stepNumber.isNotEmpty) ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stepNumber,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: content.map((item) {
                  return _buildHelpItem(context, item);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(BuildContext context, _HelpItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpItem {
  final String title;
  final String description;

  _HelpItem({
    required this.title,
    required this.description,
  });
}
