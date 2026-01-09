import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../providers/groups_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/models/group_member_model.dart';
import '../../../../core/services/supabase_service.dart';
// Local user form is reached via named route; direct import not needed here.

class ManageMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  const ManageMembersScreen({super.key, required this.groupId});

  @override
  ConsumerState<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends ConsumerState<ManageMembersScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<GroupMemberModel> _membersCache = [];
  List<dynamic> _searchResults = [];
  bool _isAdmin = false;

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshMembers() async {
    ref.invalidate(groupMembersProvider(widget.groupId));
    await ref.read(groupMembersProvider(widget.groupId).future);
  }

  Future<void> _initAdminStatus() async {
    final controller = ref.read(groupControllerProvider);
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    _isAdmin = await controller.isUserAdmin(widget.groupId, uid);
    setState(() {});
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final profileController = ref.read(profileControllerProvider);
    final results = await profileController.searchProfiles(query);
    final memberIds = _membersCache.map((m) => m.userId).toSet();
    setState(() {
      _searchResults = results.where((p) => !memberIds.contains(p.id)).toList();
      _isSearching = false;
    });
  }

  Future<void> _addUser(String userId) async {
    // Removed group debug info
    try {
      final controller = ref.read(groupControllerProvider);
      final ok = await controller.addMember(widget.groupId, userId);
      if (ok) {
        // Removed group debug info
        await _refreshMembers();
        if (!mounted) return;
        _searchController.clear();
        setState(() => _searchResults = []);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member added')),
          );
        }
      } else {
        // Removed group debug info
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add member')),
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

  @override
  void initState() {
    super.initState();
    _initAdminStatus();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Members'),
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
      ),
      body: membersAsync.when(
        data: (members) {
          _membersCache = members;
          final group = groupAsync.asData?.value;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (group != null)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: _avatar(group.avatarUrl, group.name),
                    title: Text(group.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${members.length} member${members.length == 1 ? '' : 's'}'),
                        if (group.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            group.description!,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Invite Members Button
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/groups/${widget.groupId}/invite');
                },
                icon: const Icon(Icons.mail_outline),
                label: const Text('Invite Members by Email'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              // Add Local User Button
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await context.push(
                    '/groups/${widget.groupId}/local-user',
                  );
                  if (result == true) {
                    await _refreshMembers();
                  }
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add Local User (No Account)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Add Members • ${members.length} total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Users',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
                onChanged: _searchUsers,
              ),
              const SizedBox(height: 8),
              if (_searchResults.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final profile = _searchResults[index];
                        return ListTile(
                          leading: _avatar(profile.avatarUrl, profile.fullName),
                          title: Text(
                            profile.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: profile.username != null
                              ? Text(
                                  '@${profile.username}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.person_add_alt),
                            onPressed: () => _addUser(profile.id),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text('Current Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...() {
                // Sort: non-local users first, then local users
                final sortedMembers = [...members]
                  ..sort((a, b) {
                    final aIsLocal = a.profile?.isLocalUser ?? false;
                    final bIsLocal = b.profile?.isLocalUser ?? false;
                    if (aIsLocal == bIsLocal) return 0;
                    return aIsLocal ? 1 : -1;
                  });
                return sortedMembers.map((m) {
                  final p = m.profile;
                  final isLocal = p?.isLocalUser ?? false;
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: _avatar(p?.avatarUrl, p?.fullName ?? ''),
                      title: Row(
                        children: [
                          Flexible(child: Text(p?.fullName ?? 'Unknown')),
                          if (isLocal) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Local',
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
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
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLocal)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit local user',
                                    onPressed: () async {
                                      final result = await context.push(
                                        '/groups/${widget.groupId}/local-user/${m.userId}',
                                        extra: p,
                                      );
                                      if (result == true) {
                                        await _refreshMembers();
                                      }
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removeUser(m.userId),
                                  tooltip: 'Remove Member',
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                });
              }(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
