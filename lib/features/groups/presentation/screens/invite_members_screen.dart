import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/groups_provider.dart';
import '../../../../core/services/supabase_service.dart';

class InviteMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  const InviteMembersScreen({super.key, required this.groupId});

  @override
  ConsumerState<InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends ConsumerState<InviteMembersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingInvites = [];
  bool _loadingInvites = false;

  @override
  void initState() {
    super.initState();
    _loadPendingInvites();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingInvites() async {
    setState(() => _loadingInvites = true);
    try {
      // Query group_invitations table for pending invites
      final response = await SupabaseService.instance
          .from('group_invitations')
          .select()
          .eq('group_id', widget.groupId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pendingInvites = List<Map<String, dynamic>>.from(response as List);
          _loadingInvites = false;
        });
      }
    } catch (e) {
      // Removed group debug info
      if (mounted) {
        setState(() => _loadingInvites = false);
      }
    }
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw 'User not authenticated';
      }

      final email = _emailController.text.trim();
      final fullName = _nameController.text.trim();

      // Removed group debug info
      // Removed group debug info
      
      // First, try to check if we have a valid session token
      final session = SupabaseService.instance.auth.currentSession;
      final hasValidToken = session != null && session.accessToken.isNotEmpty;
      // Removed group debug info

      // Always try direct database insertion first (works for local users and authenticated users)
      try {
        // Removed group debug info
        await SupabaseService.instance.from('group_invitations').insert({
          'group_id': widget.groupId,
          'email': email,
          'invited_by': currentUser.id,
          'status': 'pending',
          'invited_name': fullName,
        });
        // Removed group debug info
      } catch (dbError) {
        // Removed group debug info
        // If direct insertion fails, try the function call (for authenticated users)
        if (hasValidToken) {
          // Removed group debug info
          final response = await SupabaseService.instance.functions.invoke(
            'invite-user',
            body: {
              'groupId': widget.groupId,
              'email': email,
              'fullName': fullName,
              'role': 'member',
            },
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
            },
          );

          final data = response as Map<String, dynamic>?;
          if (data == null || data['status'] != 'ok') {
            final errorMsg = data?['error'] as String? ?? 'Invite failed';
            throw errorMsg;
          }
          // Removed group debug info
        } else {
          // No valid token and database insert failed
          rethrow;
        }
      }

      // Clear form and reload invites
      _emailController.clear();
      _nameController.clear();
      await _loadPendingInvites();
      
      // Invalidate members list
      ref.invalidate(groupMembersProvider(widget.groupId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation sent successfully')),
      );
    } catch (e) {
      // Removed group debug info
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelInvite(String inviteId) async {
    try {
      await SupabaseService.instance
          .from('group_invitations')
          .update({'status': 'cancelled'})
          .eq('id', inviteId);

      await _loadPendingInvites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation cancelled')),
        );
      }
    } catch (e) {
      // Removed group debug info
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel invite: $e')),
        );
      }
    }
  }

  Future<void> _resendInvite(String inviteId, String email) async {
    try {
      // Update the invitation timestamp to mark as resent
      await SupabaseService.instance
          .from('group_invitations')
          .update({'created_at': DateTime.now().toIso8601String()})
          .eq('id', inviteId);

      await _loadPendingInvites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation resent to $email')),
        );
      }
    } catch (e) {
      // Removed group debug info
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend invite: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Members'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Group Info Card
            groupAsync.when(
              data: (group) => group != null
                  ? Card(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: ListTile(
                        title: Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text('Send invitations to join this group'),
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Invite Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Send Invitation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an email address';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                      helperText: 'Helps personalize the invitation',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _sendInvite,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Send Invitation'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Pending Invites Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Invitations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_loadingInvites)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadPendingInvites,
                    tooltip: 'Refresh',
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_pendingInvites.isEmpty && !_loadingInvites)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.mail_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No pending invitations',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._pendingInvites.map((invite) {
                final email = invite['email'] as String;
                final invitedName = invite['invited_name'] as String?;
                final createdAt = DateTime.parse(invite['created_at'] as String);
                final daysAgo = DateTime.now().difference(createdAt).inDays;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.pending, color: Colors.white),
                    ),
                    title: Text(invitedName ?? email),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (invitedName != null) Text(email),
                        Text(
                          daysAgo == 0
                              ? 'Sent today'
                              : 'Sent $daysAgo day${daysAgo == 1 ? '' : 's'} ago',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'resend') {
                          _resendInvite(invite['id'] as String, email);
                        } else if (value == 'cancel') {
                          _cancelInvite(invite['id'] as String);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'resend',
                          child: Row(
                            children: [
                              Icon(Icons.refresh),
                              SizedBox(width: 8),
                              Text('Resend'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Cancel', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
