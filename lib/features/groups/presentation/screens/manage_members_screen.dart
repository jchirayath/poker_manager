import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/groups_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/models/group_member_model.dart';
import '../../../../core/services/supabase_service.dart';

const _roleLabels = {
  'member': 'Member',
  'admin': 'Admin',
};

class ManageMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  const ManageMembersScreen({super.key, required this.groupId});

  @override
  ConsumerState<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends ConsumerState<ManageMembersScreen> {
  final _searchController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSearching = false;
  List<GroupMemberModel> _membersCache = [];
  List<dynamic> _searchResults = [];
  bool _isAdmin = false;

  @override
  void dispose() {
    _searchController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _refreshMembers() async {
    await ref.refresh(groupMembersProvider(widget.groupId).future);
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

  Future<void> _inviteOrAddByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email')),
      );
      return;
    }

    setState(() => _isSearching = true);
    try {
      // Verify user is authenticated
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        debugPrint('🔴 User not authenticated');
        throw 'User not authenticated';
      }
      debugPrint('🔵 Current user: ${currentUser.id}');

      final fullName = _nameController.text.trim();
      debugPrint('🔵 Inviting $email (fullName: $fullName) to group ${widget.groupId}');
      
      // Call function with explicit auth
      final response = await SupabaseService.instance.functions.invoke(
        'invite-user',
        body: {
          'groupId': widget.groupId,
          'email': email,
          'fullName': fullName,
          'role': 'member',
        },
        headers: {
          'Authorization': 'Bearer ${SupabaseService.instance.auth.currentSession?.accessToken ?? ''}',
        },
      );

      debugPrint('🔵 Invite response: $response');

      final data = response as Map<String, dynamic>?;
      if (data == null || data['status'] != 'ok') {
        final errorMsg = data?['error'] as String? ?? 'Invite failed';
        debugPrint('🔴 Invite error: $errorMsg');
        throw errorMsg;
      }

      debugPrint('✅ User invited successfully: ${data['userId']}');

      await _refreshMembers();
      _emailController.clear();
      _nameController.clear();
      _searchController.clear();
      setState(() => _searchResults = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent')), 
        );
      }
    } catch (e, stack) {
      debugPrint('🔴 Failed to invite: $e');
      debugPrintStack(stackTrace: stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addUser(String userId) async {
    debugPrint('🔵 Adding user $userId to group ${widget.groupId}');
    try {
      final controller = ref.read(groupControllerProvider);
      final ok = await controller.addMember(widget.groupId, userId);
      if (ok) {
        debugPrint('✅ User added successfully');
        await _refreshMembers();
        _searchController.clear();
        setState(() => _searchResults = []);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member added')),
          );
        }
      } else {
        debugPrint('🔴 Failed to add member');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add member')),
        );
      }
    } catch (e, stack) {
      debugPrint('🔴 Error adding member: $e');
      debugPrintStack(stackTrace: stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove member')),
        );
      }
    } catch (e, stack) {
      debugPrint('🔴 Error removing member: $e');
      debugPrintStack(stackTrace: stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update role')),
        );
      }
    } catch (e, stack) {
      debugPrint('🔴 Error updating role: $e');
      debugPrintStack(stackTrace: stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initAdminStatus();
  }

  @override
  Widget build(BuildContext context) {
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Invite by Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSearching ? null : _inviteOrAddByEmail,
                  icon: const Icon(Icons.send),
                  label: const Text('Invite / Add'),
                ),
              ),
              const Divider(height: 32),
              const Text('Add Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
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
                        leading: CircleAvatar(
                          backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                          child: profile.avatarUrl == null ? Text(profile.firstName.isNotEmpty ? profile.firstName[0] : '?') : null,
                        ),
                        title: Text(profile.fullName),
                        subtitle: profile.username != null ? Text('@${profile.username}') : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.person_add_alt),
                          onPressed: () => _addUser(profile.id),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              const Text('Current Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...members.map((m) {
                final p = m.profile;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: p?.avatarUrl != null ? NetworkImage(p!.avatarUrl!) : null,
                      child: p?.avatarUrl == null ? Text(p?.firstName.isNotEmpty == true ? p!.firstName[0] : '?') : null,
                    ),
                    title: Text(p?.fullName ?? 'Unknown'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.isCreator
                              ? 'Creator'
                              : (m.role == 'admin' ? 'Admin' : 'Member'),
                          style: TextStyle(
                            fontWeight: m.isCreator || m.role == 'admin' ? FontWeight.bold : FontWeight.normal,
                            color: m.isCreator ? Colors.orange : (m.role == 'admin' ? Colors.blue : null),
                          ),
                        ),
                        if (_isAdmin && !m.isCreator)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Role'),
                                const SizedBox(height: 6),
                                Slider(
                                  value: m.role == 'admin' ? 1 : 0,
                                  min: 0,
                                  max: 1,
                                  divisions: 1,
                                  label: _roleLabels[m.role == 'admin' ? 'admin' : 'member'],
                                  onChanged: (v) {
                                    final target = v >= 0.5 ? 'admin' : 'member';
                                    if (target != m.role) {
                                      _updateRole(m.userId, target);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: _isAdmin && !m.isCreator
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _removeUser(m.userId),
                            tooltip: 'Remove Member',
                          )
                        : null,
                  ),
                );
              }).toList(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
