import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/currencies.dart';
import '../../../../../core/utils/avatar_utils.dart';
import '../../../data/models/game_model.dart';

class GameHeaderCard extends StatelessWidget {
  final GameModel game;
  final String groupName;
  final String? groupAvatarUrl;
  final String groupPrivacy;

  const GameHeaderCard({
    required this.game,
    required this.groupName,
    this.groupAvatarUrl,
    required this.groupPrivacy,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group row
            Row(
              children: [
                _buildGroupAvatar(context),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    groupName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildPrivacyIcon(context),
              ],
            ),
            const SizedBox(height: 12),

            // Game name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    game.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(context),
              ],
            ),
            const SizedBox(height: 8),

            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(game.gameDate),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),

            // Location
            if (game.location != null && game.location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      game.location!,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            // Buy-in info
            Row(
              children: [
                Icon(Icons.attach_money, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Text(
                  'Buy-in: ${Currencies.symbols[game.currency] ?? game.currency} '
                  '${game.buyinAmount.toStringAsFixed(0)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (game.additionalBuyinValues.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(+${game.additionalBuyinValues.length} add-ons)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(BuildContext context) {
    if (groupAvatarUrl == null || groupAvatarUrl!.isEmpty) {
      return Icon(
        Icons.group,
        size: 24,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    if (groupAvatarUrl!.toLowerCase().contains('svg')) {
      return SizedBox(
        width: 24,
        height: 24,
        child: SvgPicture.network(
          fixDiceBearUrl(groupAvatarUrl)!,
          placeholderBuilder: (_) => const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 12,
      backgroundImage: NetworkImage(groupAvatarUrl!),
    );
  }

  Widget _buildPrivacyIcon(BuildContext context) {
    final isPrivate = groupPrivacy == 'private';
    return Icon(
      isPrivate ? Icons.lock : Icons.public,
      size: 18,
      color: isPrivate
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final statusColor = AppColors.getGameStatusColor(game.status);
    final label = AppColors.getGameStatusLabel(game.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.withAlpha15(statusColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
