import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../providers/groups_provider.dart';
import '../providers/local_user_provider.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/models/group_member_model.dart';
import '../../../../core/services/supabase_service.dart';

class ManageMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  const ManageMembersScreen({super.key, required this.groupId});

  @override
  ConsumerState<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends ConsumerState<ManageMembersScreen> {
  final _searchController = TextEditingController();
  final _contactSearchController = TextEditingController();
  final _inviteEmailController = TextEditingController();
  final _inviteNameController = TextEditingController();

  bool _isSearching = false;
  List<GroupMemberModel> _membersCache = [];
  List<ProfileModel> _searchResults = [];
  bool _isAdmin = false;

  // Contacts section state
  bool _showContactsSection = false;
  bool _isLoadingContacts = false;
  List<Contact> _deviceContacts = [];
  List<Contact> _filteredContacts = [];

  // Local users section state
  bool _showLocalUserSection = false;
  bool _isAddingLocalUser = false;
  final List<Map<String, String>> _pendingLocalUsers = [];

  // Invite section state
  bool _showInviteSection = false;
  bool _isInviting = false;
  final List<Map<String, String>> _pendingInvites = [];

  Widget _buildUserAvatar(String? url, String initials) {
    final colorScheme = Theme.of(context).colorScheme;

    if ((url ?? '').isEmpty) {
      return CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          initials,
          style: TextStyle(color: colorScheme.onPrimaryContainer),
        ),
      );
    }

    // Check if URL contains 'svg' - handles DiceBear URLs like /svg?seed=...
    if (url!.toLowerCase().contains('svg')) {
      return CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
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
    _contactSearchController.dispose();
    _inviteEmailController.dispose();
    _inviteNameController.dispose();
    super.dispose();
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(String? url, String groupId, String groupName, double size) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallbackLetter = groupName.isNotEmpty ? groupName[0].toUpperCase() : '?';

    // If no URL, generate a random DiceBear avatar using group ID as seed
    if (url == null || url.isEmpty) {
      final generatedUrl = generateGroupAvatarUrl(groupId);
      return SvgPicture.network(
        generatedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => Container(
          width: size,
          height: size,
          color: colorScheme.primaryContainer,
          child: Center(
            child: Text(
              fallbackLetter,
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      );
    }

    // If URL contains 'svg', use SvgPicture
    if (url.toLowerCase().contains('svg')) {
      return SvgPicture.network(
        fixDiceBearUrl(url)!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => Container(
          width: size,
          height: size,
          color: colorScheme.primaryContainer,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
        ),
      );
    }

    // Otherwise, use regular network image
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        color: colorScheme.primaryContainer,
        child: Center(
          child: Text(
            fallbackLetter,
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
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
    } catch (e) {
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
    } catch (e) {
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
        await _refreshMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Role updated to $role')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update role')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleMemberRole(String userId, bool isAdmin, bool isCreator) async {
    final newRole = isAdmin ? 'admin' : 'member';

    // Check if trying to demote an admin
    if (!isAdmin && !isCreator) {
      // Verify there will be at least one admin remaining
      final members = _membersCache.where((m) => m.role == 'admin').toList();
      if (members.length <= 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot demote the last admin. At least one admin must remain.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    await _updateRole(userId, newRole);
  }

  // Contact loading methods
  Future<void> _loadContacts() async {
    if (_deviceContacts.isNotEmpty) return;

    setState(() => _isLoadingContacts = true);

    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );
        if (mounted) {
          setState(() {
            _deviceContacts = contacts;
            _filteredContacts = contacts;
            _isLoadingContacts = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingContacts = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission denied')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load contacts: $e')),
        );
      }
    }
  }

  void _filterContacts(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredContacts = _deviceContacts);
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredContacts = _deviceContacts.where((contact) {
        return contact.displayName.toLowerCase().contains(lowercaseQuery);
      }).toList();
    });
  }

  Future<void> _addContactAsLocalUser(Contact contact) async {
    String firstName = contact.name.first;
    String lastName = contact.name.last;

    // If both names are empty, use displayName as first name
    if (firstName.isEmpty && lastName.isEmpty) {
      firstName = contact.displayName;
    }

    final email = contact.emails.isNotEmpty ? contact.emails.first.address : '';
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';

    // Check if already added
    final displayName = '$firstName $lastName'.trim();
    if (_pendingLocalUsers.any((user) =>
        '${user['firstName']} ${user['lastName']}'.trim() == displayName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$displayName is already added')),
      );
      return;
    }

    // Add to pending local users for now (batch add later)
    setState(() {
      _pendingLocalUsers.add({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$displayName added to pending list')),
    );
  }

  void _removeLocalUser(String displayName) {
    setState(() {
      _pendingLocalUsers.removeWhere(
        (user) => '${user['firstName']} ${user['lastName']}'.trim() == displayName,
      );
    });
  }

  void _addLocalUser() {
    setState(() => _isAddingLocalUser = true);
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        final firstNameCtrl = TextEditingController();
        final lastNameCtrl = TextEditingController();
        final usernameCtrl = TextEditingController();
        final emailCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final formKey = GlobalKey<FormState>();

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.person_add, color: colorScheme.primary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Local User',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Add a member without an account',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Basic Info Section
                    Text(
                      'Basic Information',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: firstNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'First Name *',
                              prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: lastNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Last Name *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Contact Section
                    Text(
                      'Contact (Optional)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty && !value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined, color: colorScheme.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Payment Section
                    Text(
                      'Payment (Optional)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Used for PayPal, Venmo transactions',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: '@username',
                        prefixIcon: Icon(Icons.alternate_email, color: colorScheme.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              if (!formKey.currentState!.validate()) return;

                              final firstName = firstNameCtrl.text.trim();
                              final lastName = lastNameCtrl.text.trim();
                              final username = usernameCtrl.text.trim();
                              final email = emailCtrl.text.trim();
                              final phone = phoneCtrl.text.trim();

                              setState(() {
                                _pendingLocalUsers.add({
                                  'firstName': firstName,
                                  'lastName': lastName,
                                  'username': username,
                                  'email': email,
                                  'phone': phone,
                                });
                              });

                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$firstName $lastName added to pending list')),
                              );
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Add User'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) setState(() => _isAddingLocalUser = false);
    });
  }

  Future<void> _sendInvite() async {
    if (_inviteEmailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    if (!_inviteEmailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _isInviting = true);
    try {
      final email = _inviteEmailController.text.trim();
      final name = _inviteNameController.text.trim();
      if (!_pendingInvites.any((inv) => inv['email'] == email)) {
        // Send invite directly to existing group
        await SupabaseService.instance.from('group_invitations').insert({
          'group_id': widget.groupId,
          'email': email,
          'invited_by': SupabaseService.currentUserId,
          'status': 'pending',
          'invited_name': name,
        });

        setState(() {
          _inviteEmailController.clear();
          _inviteNameController.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invitation sent to $email')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This email is already invited')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _savePendingLocalUsers() async {
    if (_pendingLocalUsers.isEmpty) return;

    final localUserController = ref.read(localUserControllerProvider);

    for (final localUser in _pendingLocalUsers) {
      try {
        await localUserController.createLocalUser(
          groupId: widget.groupId,
          firstName: localUser['firstName'] ?? '',
          lastName: localUser['lastName'] ?? '',
          username: localUser['username'],
          email: localUser['email'],
          phoneNumber: localUser['phone'],
        );
      } catch (e) {
        // Silently continue if local user creation fails
      }
    }

    setState(() => _pendingLocalUsers.clear());
    await _refreshMembers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local users added successfully')),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Members'),
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
      ),
      body: membersAsync.when(
        data: (members) {
          _membersCache = members;
          final group = groupAsync.asData?.value;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header section with gradient background
                if (group != null)
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
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: colorScheme.primaryContainer,
                            child: ClipOval(
                              child: _buildGroupAvatar(
                                group.avatarUrl,
                                group.id,
                                group.name,
                                80,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            group.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${members.length} member${members.length == 1 ? '' : 's'}',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          if (group.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              group.description!,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // Content section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Add Registered Members Card
                      _buildSectionCard(
                        context: context,
                        icon: Icons.people_outline,
                        title: 'Add Registered Members',
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search Users',
                              hintText: 'Search by name or username',
                              prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: _searchUsers,
                          ),
                          if (_searchResults.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                border: Border.all(color: colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final user = _searchResults[index];
                                  return ListTile(
                                    leading: _buildUserAvatar(
                                      user.avatarUrl,
                                      (user.firstName?.isNotEmpty == true ? user.firstName![0] : '?'),
                                    ),
                                    title: Text(user.fullName),
                                    subtitle: user.username != null ? Text('@${user.username}') : null,
                                    trailing: IconButton(
                                      icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                                      onPressed: () => _addUser(user.id),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Invite by Email Section
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ExpansionTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.email_outlined, size: 20, color: colorScheme.secondary),
                          ),
                          title: Text(
                            'Invite by Email to Join',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Invite people to register and join the group',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          initiallyExpanded: _showInviteSection,
                          onExpansionChanged: (expanded) => setState(() => _showInviteSection = expanded),
                          children: [
                            TextFormField(
                              controller: _inviteEmailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _inviteNameController,
                              decoration: InputDecoration(
                                labelText: 'Full Name (Optional)',
                                prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isInviting ? null : _sendInvite,
                                icon: _isInviting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.send),
                                label: const Text('Send Invitation'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Add from Contacts Section
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ExpansionTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.contacts_outlined, size: 20, color: colorScheme.secondary),
                          ),
                          title: Text(
                            'Add from Contacts (Local)',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Import user from your device contacts without App registration',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          initiallyExpanded: _showContactsSection,
                          onExpansionChanged: (expanded) {
                            setState(() => _showContactsSection = expanded);
                            if (expanded && _deviceContacts.isEmpty) {
                              _loadContacts();
                            }
                          },
                          children: [
                            if (_isLoadingContacts)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (_deviceContacts.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.contacts_outlined, size: 48, color: colorScheme.onSurfaceVariant),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No contacts available',
                                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: _loadContacts,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else ...[
                              TextField(
                                controller: _contactSearchController,
                                decoration: InputDecoration(
                                  labelText: 'Search Contacts',
                                  hintText: 'Search by name',
                                  prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onChanged: _filterContacts,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 250),
                                decoration: BoxDecoration(
                                  border: Border.all(color: colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _filteredContacts.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Center(
                                          child: Text(
                                            'No contacts found',
                                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: _filteredContacts.length,
                                        itemBuilder: (context, index) {
                                          final contact = _filteredContacts[index];
                                          final email = contact.emails.isNotEmpty
                                              ? contact.emails.first.address
                                              : null;
                                          final phone = contact.phones.isNotEmpty
                                              ? contact.phones.first.number
                                              : null;
                                          return ListTile(
                                            dense: true,
                                            visualDensity: VisualDensity.compact,
                                            leading: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: colorScheme.primaryContainer,
                                              child: Text(
                                                contact.displayName.isNotEmpty
                                                    ? contact.displayName[0].toUpperCase()
                                                    : '?',
                                                style: TextStyle(
                                                  color: colorScheme.onPrimaryContainer,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              contact.displayName,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (phone != null)
                                                  Text(
                                                    phone,
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                if (email != null)
                                                  Text(
                                                    email,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            isThreeLine: phone != null && email != null,
                                            trailing: IconButton(
                                              icon: Icon(Icons.add_circle_outline, color: colorScheme.primary, size: 20),
                                              onPressed: () => _addContactAsLocalUser(contact),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Add Local Users Section
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ExpansionTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.person_add_outlined, size: 20, color: colorScheme.tertiary),
                          ),
                          title: Text(
                            'Add Users to Group (Local)',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Add members directly to group without requiring them to register',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          initiallyExpanded: _showLocalUserSection,
                          onExpansionChanged: (expanded) => setState(() => _showLocalUserSection = expanded),
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isAddingLocalUser ? null : _addLocalUser,
                                icon: _isAddingLocalUser
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.person_add),
                                label: const Text('Add Local User'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            if (_pendingLocalUsers.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Text(
                                'Pending Local Users',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _pendingLocalUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _pendingLocalUsers[index];
                                  final displayName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.person, size: 20, color: colorScheme.primary),
                                    ),
                                    title: Text(displayName),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (user['username']?.isNotEmpty == true)
                                          Text('@${user['username']}', style: TextStyle(color: colorScheme.primary)),
                                        if (user['email']?.isNotEmpty == true)
                                          Text(user['email']!, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                                        if (user['phone']?.isNotEmpty == true)
                                          Text(user['phone']!, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(Icons.close, color: colorScheme.error),
                                      onPressed: () => _removeLocalUser(displayName),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _savePendingLocalUsers,
                                  icon: const Icon(Icons.save),
                                  label: Text('Save ${_pendingLocalUsers.length} Local User${_pendingLocalUsers.length == 1 ? '' : 's'}'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Current Members Section
                      _buildSectionCard(
                        context: context,
                        icon: Icons.group_outlined,
                        title: 'Current Members (${members.length})',
                        children: [
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
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: colorScheme.outlineVariant),
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Stack(
                                  children: [
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: _buildUserAvatar(p?.avatarUrl, p != null && p.fullName.isNotEmpty ? p.fullName[0] : '?'),
                                      title: Text(p?.fullName ?? 'Unknown'),
                                      subtitle: Text(
                                        m.isCreator
                                            ? 'Creator'
                                            : (m.role == 'admin' ? 'Admin' : 'Member'),
                                        style: TextStyle(
                                          fontWeight: m.isCreator || m.role == 'admin' ? FontWeight.bold : FontWeight.normal,
                                          color: m.isCreator
                                              ? colorScheme.tertiary
                                              : (m.role == 'admin' ? colorScheme.primary : colorScheme.onSurfaceVariant),
                                        ),
                                      ),
                                      trailing: _isAdmin
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Local users cannot be admins, so no toggle for them
                                            if (!isLocal) ...[
                                              if (m.isCreator)
                                                // Creator can toggle their own admin status
                                                Switch(
                                                  value: m.role == 'admin',
                                                  onChanged: (value) => _toggleMemberRole(m.userId, value, m.isCreator),
                                                )
                                              else ...[
                                                // Non-creator registered members can have role toggled
                                                Switch(
                                                  value: m.role == 'admin',
                                                  onChanged: (value) => _toggleMemberRole(m.userId, value, m.isCreator),
                                                ),
                                              ],
                                            ],
                                            // Edit button only for local users
                                            if (isLocal)
                                              IconButton(
                                                icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
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
                                            // Delete button for non-creators only
                                            if (!m.isCreator)
                                              IconButton(
                                                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                                                onPressed: () => _removeUser(m.userId),
                                                tooltip: 'Remove Member',
                                              ),
                                          ],
                                        )
                                      : null,
                                    ),
                                    // Position "Local" badge in top-right corner
                                    if (isLocal)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Local',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            });
                          }(),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
