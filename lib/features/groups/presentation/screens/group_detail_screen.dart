import '../../../../core/constants/currencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../providers/groups_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../games/presentation/screens/games_entry_screen.dart';
import '../../../games/presentation/screens/create_game_screen.dart';
import '../../../games/presentation/providers/games_provider.dart';
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

      IconData _getCurrencyIcon(String currency) {
        switch (currency) {
          case 'EUR':
            return Icons.euro;
          case 'GBP':
            return Icons.currency_pound;
          case 'JPY':
            return Icons.currency_yen;
          case 'INR':
            return Icons.currency_rupee;
          case 'CNY':
            return Icons.currency_yuan;
          case 'KRW':
            return Icons.currency_yen;
          case 'RUB':
            return Icons.currency_ruble;
          case 'TRY':
            return Icons.currency_lira;
          case 'USD':
          default:
            return Icons.attach_money;
        }
      }
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

  Future<void> _refreshAll() async {
    // Refresh both group data and members
    ref.invalidate(groupProvider(widget.groupId));
    ref.invalidate(groupMembersProvider(widget.groupId));
    ref.invalidate(groupGamesProvider(widget.groupId));
    await Future.wait([
      ref.read(groupProvider(widget.groupId).future),
      ref.read(groupMembersProvider(widget.groupId).future),
    ]);
  }

  Future<void> _removeUser(String userId) async {
    try {
      final controller = ref.read(groupControllerProvider);
      final ok = await controller.removeMember(widget.groupId, userId);

      if (ok) {
        // Invalidate all related providers
        ref.invalidate(groupMembersProvider(widget.groupId));
        ref.invalidate(groupProvider(widget.groupId));

        // Wait a moment for the invalidation to process
        await Future.delayed(const Duration(milliseconds: 100));

        // Force re-fetch
        await ref.read(groupMembersProvider(widget.groupId).future);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Member removed successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove member'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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
    } catch (e) {
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
                    _formatDate(member.joinedAt),
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
        final (success, errorMessage) = await controller.deleteGroup(widget.groupId);

        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group deleted successfully')),
          );
          // Navigate back to groups list
          context.go('/groups');
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage ?? 'Failed to delete group')),
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
            errorBuilder: (context, error, stackTrace) {
              return const Text('?');
            },
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

          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
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
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                                maxWidth: 40,
                                maxHeight: 40,
                              ),
                              child: _buildGroupAvatar(group.avatarUrl, group.name, 32),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (group.description?.isNotEmpty == true)
                                  Container(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 100),
                                    child: Text(
                                      group.description!,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatColumn(
                                  icon: Icons.calendar_today,
                                  value: group.createdAt != null
                                      ? DateFormat('MMM yyyy').format(group.createdAt!)
                                      : 'Unknown',
                                  label: 'Created',
                                  colorScheme: colorScheme,
                                  valueFontSize: 13,
                                ),
                                Container(
                                  height: 32,
                                  width: 1,
                                  color: colorScheme.outline.withValues(alpha: 0.3),
                                ),
                                _buildStatColumn(
                                  icon: _getCurrencyIcon(group.defaultCurrency),
                                  value: '${Currencies.symbols[group.defaultCurrency] ?? group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(0)}',
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
                                  error: (error, stackTrace) => _buildStatColumn(
                                    icon: Icons.people,
                                    value: '-',
                                    label: 'Members',
                                    colorScheme: colorScheme,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              color: colorScheme.outline.withValues(alpha: 0.2),
                              indent: 16,
                              endIndent: 16,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatColumn(
                                  icon: group.privacy == 'private' ? Icons.lock : Icons.public,
                                  value: group.privacy == 'private' ? 'Private' : 'Public',
                                  label: 'Visibility',
                                  colorScheme: colorScheme,
                                ),
                                Container(
                                  height: 32,
                                  width: 1,
                                  color: colorScheme.outline.withValues(alpha: 0.3),
                                ),
                                _buildStatColumn(
                                  icon: Icons.add_circle_outline,
                                  value: group.additionalBuyinValues.isNotEmpty
                                      ? group.additionalBuyinValues.map((v) => '${Currencies.symbols[group.defaultCurrency] ?? group.defaultCurrency}${v.toStringAsFixed(0)}').join(', ')
                                      : 'None',
                                  label: 'Add-ons',
                                  colorScheme: colorScheme,
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
                                  error: (error, stackTrace) => _buildStatColumn(
                                    icon: Icons.casino,
                                    value: '-',
                                    label: 'Games',
                                    colorScheme: colorScheme,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Members and Games Tabs
              Row(
                children: [
                  Expanded(
                    child: _buildTabChip(
                      icon: Icons.people,
                      label: 'Members',
                      count: membersAsync.whenOrNull(data: (m) => m.length),
                      isSelected: true,
                      colorScheme: colorScheme,
                      onTap: () {
                        context.push(RouteConstants.manageMembers.replaceFirst(':id', widget.groupId));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                    Expanded(
                    child: _buildTabChip(
                      icon: Icons.casino,
                      label: 'Games',
                      count: ref.watch(groupGamesProvider(widget.groupId)).whenOrNull(data: (g) => g.length),
                      isSelected: true,
                      colorScheme: colorScheme.copyWith(
                      primary: Colors.deepOrange.shade400,
                      primaryContainer: Colors.orange.shade100,
                      onPrimary: Colors.deepOrange.shade900,
                      onPrimaryContainer: Colors.deepOrange.shade800,
                      ),
                      onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                        builder: (context) => GamesEntryScreen(groupId: widget.groupId),
                        ),
                      );
                      },
                    ),
                    ),
                  ],
                  ),
              const SizedBox(height: 16),

              // Members Section Header
              _buildSectionHeader(
                title: 'Members',
                count: membersAsync.whenOrNull(data: (m) => m.length),
                actionIcon: Icons.person_add,
                actionTooltip: 'Manage Members',
                onAction: () => context.push(RouteConstants.manageMembers.replaceFirst(':id', widget.groupId)),
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
                  // Show all members
                  return Column(
                    children: [
                      ...sortedMembers.map((m) {
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
              const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CreateGameScreen(groupId: widget.groupId),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Game'),
        tooltip: 'Create new game for this group',
      ),
    );
  }


  Widget _buildGroupAvatar(String? url, String fallback, double radius) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : '?';
    if ((url ?? '').isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: radius * 0.8,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
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

  Widget _buildTabChip({
    required IconData icon,
    required String label,
    required int? count,
    required bool isSelected,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
    required ColorScheme colorScheme,
    double? valueFontSize,
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
                fontSize: valueFontSize ?? 16,
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
            // Admin controls (only for admins, not for creator)
            if (_isAdmin && !member.isCreator)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show admin toggle for non-local users only
                  if (!isLocal)
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
                  // Show edit button for local users only
                  if (isLocal)
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 20),
                      onPressed: () async {
                        final result = await context.push(
                          '/groups/${widget.groupId}/local-user/${member.userId}',
                          extra: profile,
                        );
                        if (result == true) {
                          await _refreshMembers();
                        }
                      },
                      tooltip: 'Edit local user',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  // Delete button for all non-creator members
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                    onPressed: () => _confirmRemoveMember(member, profile),
                    tooltip: 'Remove Member',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
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
      await _removeUser(member.userId);
    }
  }

}
