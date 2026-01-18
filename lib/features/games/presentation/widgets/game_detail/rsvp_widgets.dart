import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/game_participant_model.dart';
import '../../providers/games_provider.dart';

/// RSVP status badge that displays the current RSVP status with an icon
class RsvpStatusBadge extends StatelessWidget {
  final String rsvpStatus;
  final bool compact;

  const RsvpStatusBadge({
    required this.rsvpStatus,
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _getRsvpIcon(rsvpStatus);
    final color = _getRsvpColor(rsvpStatus);
    final text = _getRsvpText(rsvpStatus);

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          icon,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getRsvpIcon(String status) {
    switch (status) {
      case GameParticipantModel.rsvpGoing:
        return '👍';
      case GameParticipantModel.rsvpNotGoing:
        return '👎';
      case GameParticipantModel.rsvpMaybe:
      default:
        return '👌';
    }
  }

  Color _getRsvpColor(String status) {
    switch (status) {
      case GameParticipantModel.rsvpGoing:
        return Colors.green;
      case GameParticipantModel.rsvpNotGoing:
        return Colors.red;
      case GameParticipantModel.rsvpMaybe:
      default:
        return Colors.orange;
    }
  }

  String _getRsvpText(String status) {
    switch (status) {
      case GameParticipantModel.rsvpGoing:
        return 'Going';
      case GameParticipantModel.rsvpNotGoing:
        return 'Not Going';
      case GameParticipantModel.rsvpMaybe:
      default:
        return 'Maybe';
    }
  }
}

/// RSVP selector button that opens a dialog to change RSVP status
class RsvpSelectorButton extends ConsumerStatefulWidget {
  final String gameId;
  final String userId;
  final String currentStatus;
  final VoidCallback onChanged;

  const RsvpSelectorButton({
    required this.gameId,
    required this.userId,
    required this.currentStatus,
    required this.onChanged,
    super.key,
  });

  @override
  ConsumerState<RsvpSelectorButton> createState() => _RsvpSelectorButtonState();
}

class _RsvpSelectorButtonState extends ConsumerState<RsvpSelectorButton> {
  bool _isUpdating = false;

  Future<void> _updateRsvp(String newStatus) async {
    if (newStatus == widget.currentStatus) return;

    setState(() => _isUpdating = true);

    final repository = ref.read(gamesRepositoryProvider);
    final result = await repository.updateRSVP(
      gameId: widget.gameId,
      userId: widget.userId,
      rsvpStatus: newStatus,
    );

    if (mounted) {
      setState(() => _isUpdating = false);

      result.when(
        success: (_) {
          widget.onChanged();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('RSVP updated successfully')),
          );
        },
        failure: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update RSVP: $error')),
          );
        },
      );
    }
  }

  void _showRsvpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update RSVP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RsvpOption(
              icon: '👍',
              label: 'I\'m Going',
              status: GameParticipantModel.rsvpGoing,
              isSelected: widget.currentStatus == GameParticipantModel.rsvpGoing,
              onTap: () {
                Navigator.of(context).pop();
                _updateRsvp(GameParticipantModel.rsvpGoing);
              },
            ),
            const SizedBox(height: 8),
            _RsvpOption(
              icon: '👌',
              label: 'Maybe',
              status: GameParticipantModel.rsvpMaybe,
              isSelected: widget.currentStatus == GameParticipantModel.rsvpMaybe,
              onTap: () {
                Navigator.of(context).pop();
                _updateRsvp(GameParticipantModel.rsvpMaybe);
              },
            ),
            const SizedBox(height: 8),
            _RsvpOption(
              icon: '👎',
              label: 'Can\'t Make It',
              status: GameParticipantModel.rsvpNotGoing,
              isSelected: widget.currentStatus == GameParticipantModel.rsvpNotGoing,
              onTap: () {
                Navigator.of(context).pop();
                _updateRsvp(GameParticipantModel.rsvpNotGoing);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isUpdating ? null : _showRsvpDialog,
      borderRadius: BorderRadius.circular(12),
      child: _isUpdating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : RsvpStatusBadge(rsvpStatus: widget.currentStatus),
    );
  }
}

class _RsvpOption extends StatelessWidget {
  final String icon;
  final String label;
  final String status;
  final bool isSelected;
  final VoidCallback onTap;

  const _RsvpOption({
    required this.icon,
    required this.label,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  Color _getColor() {
    switch (status) {
      case GameParticipantModel.rsvpGoing:
        return Colors.green;
      case GameParticipantModel.rsvpNotGoing:
        return Colors.red;
      case GameParticipantModel.rsvpMaybe:
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Summary card showing RSVP counts
class RsvpSummaryCard extends StatelessWidget {
  final List<GameParticipantModel> participants;
  final VoidCallback? onSendEmails;
  final bool canSendEmails;

  const RsvpSummaryCard({
    required this.participants,
    this.onSendEmails,
    this.canSendEmails = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goingCount = participants.where((p) => p.isGoing).length;
    final maybeCount = participants.where((p) => p.isMaybe).length;
    final notGoingCount = participants.where((p) => p.isNotGoing).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RSVP',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (canSendEmails && onSendEmails != null)
                  OutlinedButton.icon(
                    onPressed: onSendEmails,
                    icon: const Icon(Icons.email, size: 14),
                    label: const Text('Send', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _RsvpCountChip(
                    icon: '👍',
                    count: goingCount,
                    label: 'Going',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _RsvpCountChip(
                    icon: '👌',
                    count: maybeCount,
                    label: 'Maybe',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _RsvpCountChip(
                    icon: '👎',
                    count: notGoingCount,
                    label: 'Not Going',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RsvpCountChip extends StatelessWidget {
  final String icon;
  final int count;
  final String label;
  final Color color;

  const _RsvpCountChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 18),
          ),
          Text(
            count.toString(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
