import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/utils/avatar_utils.dart';
import '../../../data/models/game_participant_model.dart';

class PlayerQuickAccess extends StatelessWidget {
  final List<GameParticipantModel> participants;
  final void Function(String userId) onPlayerTap;

  const PlayerQuickAccess({
    required this.participants,
    required this.onPlayerTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Quick Jump',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: participants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final participant = participants[index];
              final profile = participant.profile;
              final name = profile?.fullName ?? 'Unknown';
              final initials = participant.initials;

              return ActionChip(
                avatar: CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: _buildAvatar(profile?.avatarUrl, initials),
                ),
                label: Text(
                  name,
                  style: const TextStyle(fontSize: 13),
                ),
                onPressed: () => onPlayerTap(participant.userId),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String? avatarUrl, String initials) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Text(
        initials,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      );
    }

    if (avatarUrl.toLowerCase().contains('svg')) {
      return ClipOval(
        child: SvgPicture.network(
          fixDiceBearUrl(avatarUrl)!,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Text(
          initials,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
