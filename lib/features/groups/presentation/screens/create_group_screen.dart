import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../providers/groups_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../shared/models/result.dart';
import '../../../../core/services/supabase_service.dart';
import '../providers/local_user_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _buyinController = TextEditingController();
  final _additionalBuyinsController = TextEditingController(text: '50');
  final _userSearchController = TextEditingController();

  String _privacy = 'private';
  String _currency = AppConstants.currencies.first;
  double _defaultBuyin = 100.0;
  final List<ProfileModel> _selectedUsers = [];
  List<ProfileModel> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _showInviteSection = false;
  bool _showLocalUserSection = false;
  final _inviteEmailController = TextEditingController();
  final _inviteNameController = TextEditingController();
  final List<Map<String, String>> _pendingInvites = [];
  final List<Map<String, String>> _pendingLocalUsers = [];
  bool _isInviting = false;
  bool _isAddingLocalUser = false;

  Widget _buildUserAvatar(String? url, String initials) {
    if ((url ?? '').isEmpty) {
      return Text(initials);
    }

    // Check if URL contains 'svg' - handles DiceBear URLs like /svg?seed=...
    if (url!.toLowerCase().contains('svg')) {
      return SvgPicture.network(
        url,
        width: 40,
        height: 40,
        placeholderBuilder: (_) => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Image.network(
      url,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Text(initials);
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _buyinController.dispose();
    _additionalBuyinsController.dispose();
    _userSearchController.dispose();
    _inviteEmailController.dispose();
    _inviteNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _buyinController.text = _defaultBuyin.toStringAsFixed(2);
  }

  Future<void> _createGroup() async {
    debugPrint('🔵 Creating new group');
    
    // Pre-validation: Check all required fields
    if (!_validateBeforeCreate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parse single additional buy-in amount (optional)
      final additionalValue = double.tryParse(_additionalBuyinsController.text.trim());
      final additionalBuyins = <double>[];
      if (additionalValue != null && additionalValue > 0) {
        additionalBuyins.add(additionalValue);
      }

      final controller = ref.read(groupControllerProvider);
      debugPrint('🔵 Calling createGroup with name: ${_nameController.text}');
      final createResult = await controller.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        privacy: _privacy,
        defaultCurrency: _currency,
        defaultBuyin: _defaultBuyin,
        additionalBuyinValues: additionalBuyins,
      );

      if (!mounted) return;

      // Add selected users as members
      if (createResult is Success<String>) {
        final groupId = createResult.data;
        debugPrint('✅ Group created with ID: $groupId');

        if (_selectedUsers.isNotEmpty) {
          debugPrint('🔵 Adding ${_selectedUsers.length} members');
          for (final user in _selectedUsers) {
            await controller.addMember(groupId, user.id);
          }
          debugPrint('✅ Members added');
        }

        if (_pendingInvites.isNotEmpty) {
          debugPrint('🔵 Sending ${_pendingInvites.length} invitations');
          for (final invite in _pendingInvites) {
            try {
              await SupabaseService.instance.from('group_invitations').insert({
                'group_id': groupId,
                'email': invite['email'],
                'invited_by': SupabaseService.currentUserId,
                'status': 'pending',
                'invited_name': invite['name'],
              });
            } catch (e) {
              debugPrint('⚠️ Failed to send invite to ${invite['email']}: $e');
            }
          }
          debugPrint('✅ Invitations sent');
        }

        if (_pendingLocalUsers.isNotEmpty) {
          debugPrint('🔵 Creating ${_pendingLocalUsers.length} local users');
          final localUserController = ref.read(localUserControllerProvider);
          for (final localUser in _pendingLocalUsers) {
            try {
              await localUserController.createLocalUser(
                groupId: groupId,
                firstName: localUser['firstName'] ?? '',
                lastName: localUser['lastName'] ?? '',
                email: localUser['email'],
                phoneNumber: localUser['phone'],
              );
            } catch (e) {
              debugPrint('⚠️ Failed to create local user ${localUser['firstName']}: $e');
            }
          }
          debugPrint('✅ Local users created');
        }

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully')),
        );
        // Use push so the user can navigate back to Create or List
        context.push(RouteConstants.groupDetail.replaceAll(':id', groupId));
      } else if (createResult is Failure<String>) {
        debugPrint('🔴 Group creation failed: ${createResult.message}');
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: ${createResult.message}')),
        );
      }
    } catch (e, stack) {
      debugPrint('🔴 Error creating group: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    debugPrint('🔵 Searching for users: $query');
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final profileController = ref.read(profileControllerProvider);
      final results = await profileController.searchProfiles(query);
      debugPrint('✅ Found ${results.length} users');

      if (mounted) {
        setState(() {
          _searchResults = results
              .where((profile) => !_selectedUsers.any((u) => u.id == profile.id))
              .toList();
          _isSearching = false;
        });
      }
    } catch (e, stack) {
      debugPrint('🔴 Search error: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _addUser(ProfileModel user) {
    setState(() {
      _selectedUsers.add(user);
      _searchResults.removeWhere((u) => u.id == user.id);
      _userSearchController.clear();
      _searchResults = [];
    });
  }

  void _removeUser(ProfileModel user) {
    setState(() {
      _selectedUsers.removeWhere((u) => u.id == user.id);
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
      // Add to pending invites list for group creation
      final email = _inviteEmailController.text.trim();
      final name = _inviteNameController.text.trim();
      if (!_pendingInvites.any((inv) => inv['email'] == email)) {
        setState(() {
          _pendingInvites.add({
            'email': email,
            'name': name,
          });
          _inviteEmailController.clear();
          _inviteNameController.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite added to pending list')),
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

  void _removeInvite(String email) {
    setState(() {
      _pendingInvites.removeWhere((inv) => inv['email'] == email);
    });
  }

  void _addLocalUser() {
    setState(() => _isAddingLocalUser = true);
    // Show a dialog to collect local user details (similar to AddLocalUserDialog)
    showDialog(
      context: context,
      builder: (dialogContext) {
        final firstNameCtrl = TextEditingController();
        final lastNameCtrl = TextEditingController();
        final emailCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final formKey = GlobalKey<FormState>();
        
        return AlertDialog(
          title: const Text('Add Local User'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add a user who doesn\'t have an account.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: firstNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a first name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lastNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a last name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty && !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                
                final firstName = firstNameCtrl.text.trim();
                final lastName = lastNameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                
                setState(() {
                  _pendingLocalUsers.add({
                    'firstName': firstName,
                    'lastName': lastName,
                    'email': email,
                    'phone': phone,
                  });
                });
                
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$firstName $lastName added to pending list')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted) setState(() => _isAddingLocalUser = false);
    });
  }

  void _removeLocalUser(String name) {
    setState(() {
      _pendingLocalUsers.removeWhere((user) => user['name'] == name);
    });
  }
  bool _validateBeforeCreate() {
    // Validate form fields (group name, buy-in, etc.)
    if (!_formKey.currentState!.validate()) {
      debugPrint('🔴 Form validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return false;
    }

    // Validate group name is not empty
    if (_nameController.text.trim().isEmpty) {
      debugPrint('🔴 Group name is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name is required')),
      );
      return false;
    }

    // Validate default buy-in is valid
    final buyin = double.tryParse(_buyinController.text);
    if (buyin == null || buyin <= 0) {
      debugPrint('🔴 Invalid buy-in amount');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default buy-in must be a valid positive number')),
      );
      return false;
    }

    // Validate currency is selected
    if (_currency.isEmpty) {
      debugPrint('🔴 Currency not selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a currency')),
      );
      return false;
    }

    // Validate privacy is selected
    if (_privacy.isEmpty) {
      debugPrint('🔴 Privacy setting not selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select privacy setting')),
      );
      return false;
    }

    debugPrint('✅ All validations passed');
    return true;
  }

  bool _isCreateButtonEnabled() {
    return _nameController.text.trim().isNotEmpty &&
        _buyinController.text.trim().isNotEmpty &&
        double.tryParse(_buyinController.text) != null &&
        (double.tryParse(_buyinController.text) ?? 0) > 0 &&
        _currency.isNotEmpty &&
        _privacy.isNotEmpty &&
        !_isLoading;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name *',
                border: OutlineInputBorder(),
              ),
              maxLength: AppConstants.maxGroupNameLength,
              onChanged: (value) {
                setState(() {}); // Trigger button state update
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a group name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _privacy,
              decoration: const InputDecoration(
                labelText: 'Privacy',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'private', child: Text('Private')),
                DropdownMenuItem(value: 'public', child: Text('Public')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _privacy = value);
                }
              },
            ),
            const SizedBox(height: 24),

            const Text(
              'Default Game Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.currencies.map((currency) {
                return DropdownMenuItem(
                  value: currency,
                  child: Text(currency),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _currency = value);
                }
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _buyinController,
              decoration: InputDecoration(
                labelText: 'Default Buy-in',
                border: const OutlineInputBorder(),
                prefix: Text('$_currency '),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a default buy-in';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < AppConstants.minBuyin) {
                  return 'Invalid amount';
                }
                return null;
              },
              onChanged: (value) {
                final amount = double.tryParse(value);
                if (amount != null) {
                  setState(() => _defaultBuyin = amount);
                } else {
                  setState(() {}); // Trigger button state update even if invalid
                }
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _additionalBuyinsController,
              decoration: InputDecoration(
                labelText: 'Additional Buy-in (optional)',
                border: const OutlineInputBorder(),
                helperText: 'Single amount, leave blank if none',
                prefix: Text('$_currency '),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),

            const Text(
              'Add Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _userSearchController,
              decoration: InputDecoration(
                labelText: 'Search Users',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
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
              ),
              onChanged: (value) {
                _searchUsers(value);
              },
            ),
            const SizedBox(height: 8),

            if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: _buildUserAvatar(
                          user.avatarUrl,
                          (user.firstName?.isNotEmpty == true ? user.firstName![0] : '?'),
                        ),
                      ),
                      title: Text(user.fullName),
                      subtitle: user.username != null
                          ? Text('@${user.username}')
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _addUser(user),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            if (_selectedUsers.isNotEmpty) ...[
              const Text(
                'Selected Members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedUsers.map((user) {
                  final initials = (user.firstName?.isNotEmpty == true ? user.firstName![0] : '?');
                  return Chip(
                    avatar: CircleAvatar(
                      child: _buildUserAvatar(user.avatarUrl, initials),
                    ),
                    label: Text(user.fullName),
                    onDeleted: () => _removeUser(user),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Invite by Email Section
            Card(
              child: ExpansionTile(
                title: const Text('Invite by Email'),
                subtitle: const Text('Invite people to join (optional)'),
                initiallyExpanded: _showInviteSection,
                onExpansionChanged: (expanded) {
                  setState(() => _showInviteSection = expanded);
                },
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _inviteEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _inviteNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _isInviting ? null : _sendInvite,
                          icon: _isInviting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          label: const Text('Add to Pending Invites'),
                        ),
                        if (_pendingInvites.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Pending Invites',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _pendingInvites.length,
                            itemBuilder: (context, index) {
                              final invite = _pendingInvites[index];
                              return ListTile(
                                leading: const Icon(Icons.email, size: 20),
                                title: Text(invite['email']!),
                                subtitle: invite['name']!.isNotEmpty
                                    ? Text(invite['name']!)
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      _removeInvite(invite['email']!),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Add Local Users Section
            Card(
              child: ExpansionTile(
                title: const Text('Add Local Users'),
                subtitle: const Text('Add members without accounts (optional)'),
                initiallyExpanded: _showLocalUserSection,
                onExpansionChanged: (expanded) {
                  setState(() => _showLocalUserSection = expanded);
                },
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isAddingLocalUser ? null : _addLocalUser,
                          icon: _isAddingLocalUser
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.person_add),
                          label: const Text('Add Local User'),
                        ),
                        if (_pendingLocalUsers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Pending Local Users',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                                leading: const Icon(Icons.person, size: 20),
                                title: Text(displayName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (user['email']?.isNotEmpty == true)
                                      Text('📧 ${user['email']}'),
                                    if (user['phone']?.isNotEmpty == true)
                                      Text('📞 ${user['phone']}'),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      _removeLocalUser(displayName),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isCreateButtonEnabled() ? _createGroup : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Group', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }


}
