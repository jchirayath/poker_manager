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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initAdminStatus();
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
    debugPrint('🔵 Removing user $userId from group ${widget.groupId}');
    try {
      final controller = ref.read(groupControllerProvider);
      final ok = await controller.removeMember(widget.groupId, userId);
      if (ok) {
        debugPrint('✅ User removed successfully');
        await _refreshMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member removed')),
          );
        }
      } else {
        debugPrint('🔴 Failed to remove member');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove member')),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('🔴 Error removing member: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateRole(String userId, String role) async {
    debugPrint('🔵 Updating user $userId role to $role');
    try {
      final controller = ref.read(groupControllerProvider);
      final ok = await controller.updateMemberRole(
        groupId: widget.groupId,
        userId: userId,
        role: role,
      );
      if (ok) {
        debugPrint('✅ Role updated to $role');
        await _refreshMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Role updated to $role')),
          );
        }
      } else {
        debugPrint('🔴 Failed to update role');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update role')),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('🔴 Error updating role: $e');
      debugPrintStack(stackTrace: stack);
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
                color: Colors.red.withOpacity(0.1),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Details'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/groups');
              }
            },
          ),
        ),
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: _avatar(group.avatarUrl, group.name),
                title: Text(group.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                    ],
                    membersAsync.when(
                      data: (members) => Text('${group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(2)} • ${members.length} member${members.length == 1 ? '' : 's'}'),
                      loading: () => Text('${group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(2)} • loading members...'),
                      error: (e, _) => Text('${group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(2)} • members unavailable'),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
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
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  membersAsync.when(
                    data: (members) => Text('Members (${members.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    loading: () => const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    error: (e, _) => const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    tooltip: 'Add Members',
                    onPressed: () {
                      context.push('/groups/${widget.groupId}/members');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return const Text('No members yet');
                  }
                  // Sort: non-local users first, then local users
                  final sortedMembers = [...members]
                    ..sort((a, b) {
                      final aIsLocal = a.profile?.isLocalUser ?? false;
                      final bIsLocal = b.profile?.isLocalUser ?? false;
                      if (aIsLocal == bIsLocal) return 0;
                      return aIsLocal ? 1 : -1;
                    });
                  return Column(
                    children: sortedMembers.map((m) {
                      final profile = m.profile;
                      final fallback = (profile?.firstName?.isNotEmpty == true)
                          ? profile!.firstName!
                          : (profile?.lastName?.isNotEmpty == true ? profile!.lastName! : '?');
                      final isLocal = profile?.isLocalUser ?? false;
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: _avatar(profile?.avatarUrl, fallback),
                          title: GestureDetector(
                            onTap: () => _showMemberDetails(context, m, profile),
                            child: Text(
                              profile?.fullName ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          subtitle: Text(
                            m.isCreator
                                ? 'Creator'
                                : (m.role == 'admin' ? 'Admin' : 'Member'),
                            style: TextStyle(
                              fontWeight: m.isCreator || m.role == 'admin' ? FontWeight.bold : FontWeight.normal,
                              color: m.isCreator ? Colors.orange : (m.role == 'admin' ? Colors.blue : null),
                            ),
                          ),
                          trailing: _isAdmin && !m.isCreator
                              ? (isLocal
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Local',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _removeUser(m.userId),
                                          tooltip: 'Remove Member',
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text('Admin', style: TextStyle(fontSize: 11)),
                                            Transform.scale(
                                              scale: 0.8,
                                              child: Switch(
                                                value: m.role == 'admin',
                                                onChanged: (value) {
                                                  final target = value ? 'admin' : 'member';
                                                  _updateRole(m.userId, target);
                                                },
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _removeUser(m.userId),
                                          tooltip: 'Remove Member',
                                        ),
                                      ],
                                    ))
                              : null,
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error loading members: $e'),
              ),
              const SizedBox(height: 32),
              
              // Games Section
              const Text(
                'Games',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ref.watch(groupGamesProvider(widget.groupId)).when(
                data: (games) {
                  final activeGames = games.where((g) => g.status == 'in_progress').toList();
                  final scheduledGames = games.where((g) => g.status == 'scheduled').toList();
                  final pastGames = games.where((g) => g.status == 'completed' || g.status == 'cancelled').toList();
                  
                  if (games.isEmpty) {
                    return const Text('No games yet');
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Games
                      if (activeGames.isNotEmpty) ...[
                        Text(
                          'Active Games (${activeGames.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...activeGames.map((game) => _buildGameCard(game)),
                        const SizedBox(height: 16),
                      ],
                      
                      // Scheduled Games
                      if (scheduledGames.isNotEmpty) ...[
                        Text(
                          'Scheduled Games (${scheduledGames.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...scheduledGames.map((game) => _buildGameCard(game)),
                        const SizedBox(height: 16),
                      ],
                      
                      // Past Games
                      if (pastGames.isNotEmpty) ...[
                        Text(
                          'Past Games (${pastGames.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...pastGames.take(3).map((game) => _buildGameCard(game)),
                        if (pastGames.length > 3)
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => GamesListScreen(groupId: widget.groupId),
                                ),
                              );
                            },
                            child: Text('View all ${pastGames.length} past games'),
                          ),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error loading games: $e'),
              ),
              const SizedBox(height: 32),
              
              // Delete Group Section
              if (_isAdmin)
                Column(
                  children: [
                    const Divider(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text(
                          'Delete Group',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () => _showDeleteConfirmation(context, group),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Warning: This action cannot be undone',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.games),
                      label: const Text('Manage Games'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GamesListScreen(groupId: widget.groupId),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.group_add),
                      label: const Text('Manage Members'),
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

  Widget _buildGameCard(GameModel game) {
    final dateFormatter = DateFormat('MMM d, yyyy HH:mm');
    final gameDate = dateFormatter.format(game.gameDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: ListTile(
        title: Text(game.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gameDate),
            if (game.location != null) Text('📍 ${game.location}'),
            Text(
              'Buy-in: ${game.currency} ${game.buyinAmount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: _getStatusColor(game.status),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: Text(
            _getStatusLabel(game.status),
            style: const TextStyle(fontSize: 12),
          ),
        ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue.withValues(alpha: 0.3);
      case 'in_progress':
        return Colors.green.withValues(alpha: 0.3);
      case 'completed':
        return Colors.grey.withValues(alpha: 0.3);
      case 'cancelled':
        return Colors.red.withValues(alpha: 0.3);
      default:
        return Colors.grey.withValues(alpha: 0.3);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'Active';
      case 'scheduled':
        return 'Scheduled';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
