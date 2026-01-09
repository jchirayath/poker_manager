import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../providers/groups_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../games/presentation/screens/games_list_screen.dart';
import '../../../games/presentation/screens/game_detail_screen.dart';
import '../../../games/presentation/providers/games_provider.dart';
import '../../../games/data/models/game_model.dart';
import '../../data/models/group_member_model.dart';
import '../../../profile/data/models/profile_model.dart';

/// Group Detail Screen - Comprehensive poker group information display
/// 
/// Displays:
/// - Group information (name, description, settings)
/// - Member list with clickable names for detailed profiles
/// - "Manage Games" button to view/manage all group games
/// - "Manage Members" button for member administration
/// 
/// Features:
/// - Member detail popup with Email, Phone, Address, Role, Status, Join Date
/// - Role-based admin controls (toggle admin role, remove members)
/// - Local user indicators and management
/// - Member status tracking (Creator/Admin/Member)
/// 
/// Navigation:
/// - Manage Games: Navigates to GamesListScreen with groupId
/// - Manage Members: Goes to members management screen
class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
    late final ScrollController _scrollController;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initAdminStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initAdminStatus() async {
    final controller = ref.read(groupControllerProvider);
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _isAdmin = await controller.isUserAdmin(widget.groupId, uid);
    if (mounted) setState(() {});
  }

  Future<void> _refreshMembers() async {
    ref.invalidate(groupMembersProvider(widget.groupId));
    await ref.read(groupMembersProvider(widget.groupId).future);
  }

  Future<void> _removeUser(String userId) async {
    // Removed group debug info
    try {
      final controller = ref.read(groupControllerProvider);
      final ok = await controller.removeMember(widget.groupId, userId);
      if (ok) {
        // Removed group debug info
        await _refreshMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member removed')),
          );
        }
      } else {
        // Removed group debug info
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove member')),
          );
        }
      }
    } catch (e, stack) {
      // Removed group debug info
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateRole(String userId, String role) async {
    // Removed group debug info
    try {
      final controller = ref.read(groupControllerProvider);
      final ok = await controller.updateMemberRole(
        groupId: widget.groupId,
        userId: userId,
        role: role,
      );
      if (ok) {
        // Removed group debug info
        await _refreshMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Role updated to $role')),
          );
        }
      } else {
        // Removed group debug info
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update role')),
          );
        }
      }
    } catch (e, stack) {
      // Removed group debug info
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showMemberDetails(BuildContext context, GroupMemberModel member, ProfileModel? profile) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              _avatar(profile?.avatarUrl, profile?.firstName ?? '?'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?.fullName ?? 'Unknown Member'),
                    Text(
                      member.isCreator
                          ? 'Creator'
                          : (member.role == 'admin' ? 'Admin' : 'Member'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: member.isCreator
                            ? Colors.orange
                            : (member.role == 'admin' ? Colors.blue : Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile != null) ...[
                  _detailRow('Email', profile.email ?? 'Not provided'),
                  _detailRow('Phone', profile.phoneNumber ?? 'Not provided'),
                  _detailRow('Address', profile.fullAddress.isNotEmpty ? profile.fullAddress : 'Not provided'),
                  _detailRow('User ID', member.userId),
                  const Divider(),
                  _detailRow('Role', member.role.toUpperCase()),
                  _detailRow(
                    'Status',
                    profile.isLocalUser ? 'Local Player' : 'Registered Player',
                    valueColor: profile.isLocalUser ? Colors.orange : Colors.green,
                  ),
                  _detailRow(
                    'Joined',
                    member.joinedAt != null
                        ? _formatDate(member.joinedAt)
                        : 'Unknown',
                  ),
                ] else ...[
                  const Text('No profile information available'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _showDeleteConfirmation(BuildContext context, dynamic group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Group?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${group.name}"?'),
            const SizedBox(height: 16),
            const Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• All games in this group'),
            const Text('• All member records'),
            const Text('• All game transactions'),
            const Text('• All statistics'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Group'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final controller = ref.read(groupControllerProvider);
        final success = await controller.deleteGroup(widget.groupId);
        
        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group deleted successfully')),
          );
          // Navigate back to groups list
          context.go('/groups');
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete group')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting group: $e')),
          );
        }
      }
    }
  }

  Widget _avatar(String? url, String fallback) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : '?';
    if ((url ?? '').isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Text(letter),
      );
    }
    
    if (url!.toLowerCase().contains('svg')) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: SvgPicture.network(
          fixDiceBearUrl(url)!,
          width: 40,
          height: 40,
          placeholderBuilder: (_) => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(url),
      child: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: groupAsync.whenOrNull(
          data: (group) => Text(group?.name ?? 'Group Details'),
        ) ?? const Text('Group Details'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/groups');
            }
          },
        ),
        actions: [
          groupAsync.whenOrNull(
            data: (group) => group != null
                ? IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit Group',
                    onPressed: () {
                      context.push(
                        '/groups/${widget.groupId}/edit',
                        extra: {
                          'name': group.name,
                          'description': group.description,
                          'avatarUrl': group.avatarUrl,
                          'privacy': group.privacy,
                          'currency': group.defaultCurrency,
                          'defaultBuyin': group.defaultBuyin,
                          'additionalBuyins': group.additionalBuyinValues,
                        },
                      );
                    },
                  )
                : null,
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Group Info Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildGroupAvatar(group.avatarUrl, group.name, 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (group.description?.isNotEmpty == true)
                                  Text(
                                    group.description!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatColumn(
                              icon: Icons.attach_money,
                              value: '${group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(0)}',
                              label: 'Buy-in',
                              colorScheme: colorScheme,
                            ),
                            Container(
                              height: 32,
                              width: 1,
                              color: colorScheme.outline.withValues(alpha: 0.3),
                            ),
                            membersAsync.when(
                              data: (members) => _buildStatColumn(
                                icon: Icons.people,
                                value: '${members.length}',
                                label: members.length == 1 ? 'Member' : 'Members',
                                colorScheme: colorScheme,
                              ),
                              loading: () => _buildStatColumn(
                                icon: Icons.people,
                                value: '-',
                                label: 'Members',
                                colorScheme: colorScheme,
                              ),
                              error: (_, __) => _buildStatColumn(
                                icon: Icons.people,
                                value: '-',
                                label: 'Members',
                                colorScheme: colorScheme,
                              ),
                            ),
                            Container(
                              height: 32,
                              width: 1,
                              color: colorScheme.outline.withValues(alpha: 0.3),
                            ),
                            ref.watch(groupGamesProvider(widget.groupId)).when(
                              data: (games) => _buildStatColumn(
                                icon: Icons.casino,
                                value: '${games.length}',
                                label: games.length == 1 ? 'Game' : 'Games',
                                colorScheme: colorScheme,
                              ),
                              loading: () => _buildStatColumn(
                                icon: Icons.casino,
                                value: '-',
                                label: 'Games',
                                colorScheme: colorScheme,
                              ),
                              error: (_, __) => _buildStatColumn(
                                icon: Icons.casino,
                                value: '-',
                                label: 'Games',
                                colorScheme: colorScheme,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Members Section Header
              _buildSectionHeader(
                title: 'Members',
                count: membersAsync.whenOrNull(data: (m) => m.length),
                actionIcon: Icons.person_add,
                actionTooltip: 'Manage Members',
                onAction: () => context.push('/groups/${widget.groupId}/members'),
                theme: theme,
              ),
              const SizedBox(height: 8),
              membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.people_outline,
                      message: 'No members yet',
                      colorScheme: colorScheme,
                    );
                  }
                  // Sort: non-local users first, then local users
                  final sortedMembers = [...members]
                    ..sort((a, b) {
                      final aIsLocal = a.profile?.isLocalUser ?? false;
                      final bIsLocal = b.profile?.isLocalUser ?? false;
                      if (aIsLocal == bIsLocal) return 0;
                      return aIsLocal ? 1 : -1;
                    });
                  // Show max 5 members, with "View All" link
                  final displayMembers = sortedMembers.take(5).toList();
                  return Column(
                    children: [
                      ...displayMembers.map((m) {
                        final profile = m.profile;
                        final fallback = (profile?.firstName?.isNotEmpty == true)
                            ? profile!.firstName!
                            : (profile?.lastName?.isNotEmpty == true ? profile!.lastName! : '?');
                        final isLocal = profile?.isLocalUser ?? false;
                        return _buildMemberTile(
                          member: m,
                          profile: profile,
                          fallback: fallback,
                          isLocal: isLocal,
                          theme: theme,
                          colorScheme: colorScheme,
                        );
                      }),
                      if (sortedMembers.length > 5)
                        TextButton.icon(
                          icon: const Icon(Icons.people),
                          label: Text('View all ${sortedMembers.length} members'),
                          onPressed: () => context.push('/groups/${widget.groupId}/members'),
                        ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, st) => Text('Error loading members: $e'),
              ),
              const SizedBox(height: 24),

              // Games Section Header
              _buildSectionHeader(
                title: 'Games',
                count: ref.watch(groupGamesProvider(widget.groupId)).whenOrNull(data: (g) => g.length),
                actionIcon: Icons.add,
                actionTooltip: 'Create Game',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GamesListScreen(groupId: widget.groupId),
                    ),
                  );
                },
                theme: theme,
              ),
              const SizedBox(height: 8),
              ref.watch(groupGamesProvider(widget.groupId)).when(
                data: (games) {
                  final activeGames = games.where((g) => g.status == 'in_progress').toList();
                  final scheduledGames = games.where((g) => g.status == 'scheduled').toList();
                  final pastGames = games.where((g) => g.status == 'completed' || g.status == 'cancelled').toList();

                  if (games.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.casino_outlined,
                      message: 'No games yet',
                      colorScheme: colorScheme,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Games
                      if (activeGames.isNotEmpty) ...[
                        _buildGameSubsection(
                          title: 'Active',
                          count: activeGames.length,
                          color: Colors.green,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        ...activeGames.map((game) => _buildGameCard(game, colorScheme)),
                        const SizedBox(height: 16),
                      ],

                      // Scheduled Games
                      if (scheduledGames.isNotEmpty) ...[
                        _buildGameSubsection(
                          title: 'Scheduled',
                          count: scheduledGames.length,
                          color: Colors.orange,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        ...scheduledGames.map((game) => _buildGameCard(game, colorScheme)),
                        const SizedBox(height: 16),
                      ],

                      // Past Games
                      if (pastGames.isNotEmpty) ...[
                        _buildGameSubsection(
                          title: 'Past',
                          count: pastGames.length,
                          color: Colors.grey,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        ...pastGames.take(3).map((game) => _buildGameCard(game, colorScheme)),
                        if (pastGames.length > 3)
                          Center(
                            child: TextButton.icon(
                              icon: const Icon(Icons.history),
                              label: Text('View all ${pastGames.length} past games'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => GamesListScreen(groupId: widget.groupId),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, st) => Text('Error loading games: $e'),
              ),
              const SizedBox(height: 24),
              
              // Delete Group Section
              if (_isAdmin) ...[
                const SizedBox(height: 8),
                Card(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.delete_forever, color: colorScheme.error),
                    title: Text(
                      'Delete Group',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'This action cannot be undone',
                      style: TextStyle(
                        color: colorScheme.error.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: colorScheme.error),
                    onTap: () => _showDeleteConfirmation(context, group),
                  ),
                ),
              ],
              const SizedBox(height: 100), // Space for bottom bar
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      bottomNavigationBar: groupAsync.when(
        data: (group) {
          if (group == null) return null;

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.casino, size: 18),
                      label: const Text('Games'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GamesListScreen(groupId: widget.groupId),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.people, size: 18),
                      label: const Text('Members'),
                      onPressed: () {
                        context.push('/groups/${widget.groupId}/members');
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  Widget _buildGameCard(GameModel game, ColorScheme colorScheme) {
    final dateFormatter = DateFormat('MMM d, yyyy');
    final timeFormatter = DateFormat('h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(game.status),
          radius: 20,
          child: Icon(
            _getStatusIcon(game.status),
            color: _getStatusIconColor(game.status),
            size: 20,
          ),
        ),
        title: Text(
          game.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${dateFormatter.format(game.gameDate)} at ${timeFormatter.format(game.gameDate)}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.attach_money, size: 12, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${game.currency} ${game.buyinAmount}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameDetailScreen(gameId: game.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupAvatar(String? url, String fallback, double radius) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : '?';
    if ((url ?? '').isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          letter,
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    if (url!.toLowerCase().contains('svg')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: ClipOval(
          child: SvgPicture.network(
            fixDiceBearUrl(url)!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholderBuilder: (_) => SizedBox(
              width: radius,
              height: radius,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(url),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    int? count,
    required IconData actionIcon,
    required String actionTooltip,
    required VoidCallback onAction,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        IconButton(
          icon: Icon(actionIcon),
          tooltip: actionTooltip,
          onPressed: onAction,
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: colorScheme.outline),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildGameSubsection({
    required String title,
    required int count,
    required Color color,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTile({
    required GroupMemberModel member,
    required ProfileModel? profile,
    required String fallback,
    required bool isLocal,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Tappable avatar for details
            GestureDetector(
              onTap: () => _showMemberDetails(context, member, profile),
              child: Stack(
                children: [
                  _avatar(profile?.avatarUrl, fallback),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: 12,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Name and role badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.fullName ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: member.isCreator
                              ? Colors.orange.withValues(alpha: 0.2)
                              : (member.role == 'admin'
                                  ? Colors.blue.withValues(alpha: 0.2)
                                  : colorScheme.surfaceContainerHighest),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          member.isCreator ? 'Creator' : (member.role == 'admin' ? 'Admin' : 'Member'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: member.isCreator
                                ? Colors.orange[800]
                                : (member.role == 'admin' ? Colors.blue[800] : colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      if (isLocal) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Local',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Admin controls (only for admins, not for creator or local users)
            if (_isAdmin && !member.isCreator && !isLocal)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(
                        height: 24,
                        child: Transform.scale(
                          scale: 0.7,
                          child: Switch(
                            value: member.role == 'admin',
                            onChanged: (value) {
                              final newRole = value ? 'admin' : 'member';
                              _updateRole(member.userId, newRole);
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: colorScheme.error, size: 20),
                    onPressed: () => _confirmRemoveMember(member, profile),
                    tooltip: 'Remove Member',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            // Remove button only for local users (admins can remove them)
            if (_isAdmin && !member.isCreator && isLocal)
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: colorScheme.error, size: 20),
                onPressed: () => _confirmRemoveMember(member, profile),
                tooltip: 'Remove Member',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMember(GroupMemberModel member, ProfileModel? profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Are you sure you want to remove ${profile?.fullName ?? 'this member'} from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _removeUser(member.userId);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.orange.withValues(alpha: 0.2);
      case 'in_progress':
        return Colors.green.withValues(alpha: 0.2);
      case 'completed':
        return Colors.blue.withValues(alpha: 0.2);
      case 'cancelled':
        return Colors.grey.withValues(alpha: 0.2);
      default:
        return Colors.grey.withValues(alpha: 0.2);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'scheduled':
        return Icons.schedule;
      case 'in_progress':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getStatusIconColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.orange;
      case 'in_progress':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
