import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../providers/groups_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/currencies.dart';
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
  bool _showContactsSection = false;
  bool _isLoadingContacts = false;
  List<Contact> _deviceContacts = [];
  List<Contact> _filteredContacts = [];
  final _contactSearchController = TextEditingController();
  final _inviteEmailController = TextEditingController();
  final _inviteNameController = TextEditingController();
  final List<Map<String, String>> _pendingInvites = [];
  final List<Map<String, String>> _pendingLocalUsers = [];
  bool _isInviting = false;
  bool _isAddingLocalUser = false;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  late String _randomAvatarSeed;

  Widget _buildUserAvatar(String? url, String initials) {
    if ((url ?? '').isEmpty) {
      return Text(initials);
    }

    // Check if URL contains 'svg' - handles DiceBear URLs like /svg?seed=...
    if (url!.toLowerCase().contains('svg')) {
      return SvgPicture.network(
        fixDiceBearUrl(url)!,
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
    _contactSearchController.dispose();
    _inviteEmailController.dispose();
    _inviteNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _buyinController.text = _defaultBuyin.toStringAsFixed(2);
    _randomAvatarSeed = 'group-${Random().nextInt(1000000)}';
  }

  Future<void> _pickImage() async {
    final colorScheme = Theme.of(context).colorScheme;
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_photo_alternate, color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('Choose Image Source')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_library, color: colorScheme.secondary),
              ),
              title: const Text('Gallery'),
              subtitle: Text('Choose from photos', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.camera_alt, color: colorScheme.secondary),
              ),
              title: const Text('Camera'),
              subtitle: Text('Take a new photo', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _removeAvatar() {
    setState(() {
      _selectedImage = null;
    });
  }

  Widget _buildAvatarPreview() {
    final colorScheme = Theme.of(context).colorScheme;

    Widget avatarContent;

    if (_selectedImage != null) {
      avatarContent = ClipOval(
        child: Image.file(
          _selectedImage!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } else {
      // Use DiceBear random avatar when no image is selected
      final avatarUrl = generateGroupAvatarUrl(_randomAvatarSeed);
      avatarContent = ClipOval(
        child: SvgPicture.network(
          avatarUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.primary,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: avatarContent,
    );
  }

  Future<void> _createGroup() async {
    // Removed group debug info
    
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
      // Removed group debug info
      final createResult = await controller.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        privacy: _privacy,
        defaultCurrency: _currency,
        defaultBuyin: _defaultBuyin,
        additionalBuyinValues: additionalBuyins,
      );

      if (!mounted) return;

      // Handle success - avatar, members, invites, local users
      if (createResult is Success<String>) {
        final groupId = createResult.data;

        // Handle avatar - either upload custom image or use random DiceBear
        String? avatarUrl;
        if (_selectedImage != null) {
          // Upload custom image
          try {
            final fileName = 'group_${groupId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final bytes = await _selectedImage!.readAsBytes();

            await ref.read(groupsRepositoryProvider).client
                .storage
                .from('group-avatars')
                .uploadBinary(fileName, bytes);

            avatarUrl = ref.read(groupsRepositoryProvider).client
                .storage
                .from('group-avatars')
                .getPublicUrl(fileName);
          } catch (storageError) {
            // Fall back to random DiceBear avatar
            avatarUrl = generateGroupAvatarUrl(_randomAvatarSeed);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Warning: Avatar upload failed. Using generated avatar.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          // Use the random DiceBear avatar that was shown in preview
          avatarUrl = generateGroupAvatarUrl(_randomAvatarSeed);
        }

        // Update group with avatar URL
        await controller.updateGroup(
          groupId: groupId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          avatarUrl: avatarUrl,
          privacy: _privacy,
          defaultCurrency: _currency,
          defaultBuyin: _defaultBuyin,
          additionalBuyinValues: additionalBuyins,
        );
        // Removed group debug info

        if (_selectedUsers.isNotEmpty) {
          // Removed group debug info
          for (final user in _selectedUsers) {
            await controller.addMember(groupId, user.id);
          }
          // Removed group debug info
        }

        if (_pendingInvites.isNotEmpty) {
          // Removed group debug info
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
              // Silently continue if invite fails
            }
          }
          // Removed group debug info
        }

        if (_pendingLocalUsers.isNotEmpty) {
          // Removed group debug info
          final localUserController = ref.read(localUserControllerProvider);
          for (final localUser in _pendingLocalUsers) {
            try {
              await localUserController.createLocalUser(
                groupId: groupId,
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
          // Removed group debug info
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
        // Removed group debug info
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: ${createResult.message}')),
        );
      }
    } catch (e) {
      // Removed group debug info
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    // Removed group debug info
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
      // Removed group debug info

      if (mounted) {
        setState(() {
          _searchResults = results
              .where((profile) => !_selectedUsers.any((u) => u.id == profile.id))
              .toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      // Removed group debug info
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

  void _removeLocalUser(String name) {
    setState(() {
      _pendingLocalUsers.removeWhere((user) => user['name'] == name);
    });
  }

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

  void _addContactAsLocalUser(Contact contact) {
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

  static const List<Map<String, String>> _wittyGroupSuggestions = [
    {'name': 'The Royal Flush Club', 'description': 'Where every hand feels like a winning hand, even when it\'s not.'},
    {'name': 'Chips & Giggles', 'description': 'Serious poker. Seriously fun people.'},
    {'name': 'The Bluff Brothers', 'description': 'Trust no one. Especially Dave.'},
    {'name': 'Pocket Rockets Society', 'description': 'We don\'t always get aces, but when we do, we slow-play them badly.'},
    {'name': 'The River Rats', 'description': 'Catching miracles on the river since day one.'},
    {'name': 'Full House Party', 'description': 'Three of a kind meets a pair of good times.'},
    {'name': 'The Chip Whisperers', 'description': 'We speak fluent poker. Our chips? Not so much.'},
    {'name': 'All-In Anonymous', 'description': 'Hi, my name is... and I have a shoving problem.'},
    {'name': 'The Felt Philosophers', 'description': 'Deep thoughts, deeper stacks.'},
    {'name': 'Aces & Spaces', 'description': 'Premium hands and even more premium banter.'},
    {'name': 'The Calling Station', 'description': 'We call. It\'s what we do. Don\'t judge.'},
    {'name': 'Fold \'Em & Hold \'Em', 'description': 'Sometimes you gotta know when to walk away.'},
    {'name': 'The Suited Connectors', 'description': 'We\'re better together. Like 7-8 suited.'},
    {'name': 'Bad Beat Buddies', 'description': 'Supporting each other through the worst hands imaginable.'},
    {'name': 'The Poker Faces', 'description': 'Unreadable expressions. Questionable decisions.'},
    {'name': 'Kings of the Felt', 'description': 'Royalty at the table, peasants at the ATM.'},
    {'name': 'The Ante Up Crew', 'description': 'We came to play. And to eat all the snacks.'},
    {'name': 'Deuces Wild', 'description': 'Even the worst cards have potential. Right?'},
    {'name': 'The Nutty Professors', 'description': 'Calculating odds and cracking jokes.'},
    {'name': 'Shuffle Up Society', 'description': 'Where friendships are tested and chips are shuffled.'},
  ];

  void _generateWittyName() {
    final random = Random();
    final suggestion = _wittyGroupSuggestions[random.nextInt(_wittyGroupSuggestions.length)];

    setState(() {
      _nameController.text = suggestion['name']!;
      _descriptionController.text = suggestion['description']!;
    });
  }

  bool _validateBeforeCreate() {
    // Validate form fields (group name, buy-in, etc.)
    if (!_formKey.currentState!.validate()) {
      // Removed group debug info
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return false;
    }

    // Validate group name is not empty
    if (_nameController.text.trim().isEmpty) {
      // Removed group debug info
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name is required')),
      );
      return false;
    }

    // Validate default buy-in is valid
    final buyin = double.tryParse(_buyinController.text);
    if (buyin == null || buyin <= 0) {
      // Removed group debug info
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default buy-in must be a valid positive number')),
      );
      return false;
    }

    // Validate currency is selected
    if (_currency.isEmpty) {
      // Removed group debug info
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a currency')),
      );
      return false;
    }

    // Validate privacy is selected
    if (_privacy.isEmpty) {
      // Removed group debug info
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select privacy setting')),
      );
      return false;
    }

    // Removed group debug info
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header section with gradient background
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
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          _buildAvatarPreview(),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: Text(_selectedImage != null ? 'Change Photo' : 'Add Photo'),
                        ),
                        if (_selectedImage != null) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _removeAvatar,
                            icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                            label: Text('Remove', style: TextStyle(color: colorScheme.error)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Content section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Group Information Card
                    _buildSectionCard(
                      context: context,
                      icon: Icons.group_outlined,
                      title: 'Group Information',
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Group Name',
                            hintText: 'Enter group name',
                            prefixIcon: Icon(Icons.badge_outlined, color: colorScheme.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          maxLength: AppConstants.maxGroupNameLength,
                          onChanged: (value) => setState(() {}),
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
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'What is this group about?',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(bottom: 48),
                              child: Icon(Icons.description_outlined, color: colorScheme.primary),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _generateWittyName,
                            icon: Icon(Icons.auto_awesome, size: 18, color: colorScheme.secondary),
                            label: Text(
                              'Generate witty name & description',
                              style: TextStyle(color: colorScheme.secondary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _privacy,
                          decoration: InputDecoration(
                            labelText: 'Privacy',
                            prefixIcon: Icon(
                              _privacy == 'private' ? Icons.lock_outlined : Icons.public,
                              color: colorScheme.primary,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'private', child: Text('Private')),
                            DropdownMenuItem(value: 'public', child: Text('Public')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _privacy = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Game Settings Card
                    _buildSectionCard(
                      context: context,
                      icon: Icons.casino_outlined,
                      title: 'Game Settings',
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: InputDecoration(
                            labelText: 'Currency',
                            prefixIcon: Icon(Icons.attach_money, color: colorScheme.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: AppConstants.currencies.map((currency) {
                            final symbol = Currencies.symbols[currency] ?? '';
                            return DropdownMenuItem(
                              value: currency,
                              child: Text('$symbol  $currency'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _currency = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _buyinController,
                          decoration: InputDecoration(
                            labelText: 'Default Buy-in',
                            prefixIcon: Icon(Icons.payments_outlined, color: colorScheme.primary),
                            prefixText: '${Currencies.symbols[_currency] ?? _currency} ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                              setState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _additionalBuyinsController,
                          decoration: InputDecoration(
                            labelText: 'Additional Buy-in (optional)',
                            helperText: 'Secondary buy-in amount for rebuys',
                            prefixIcon: Icon(Icons.add_card, color: colorScheme.primary),
                            prefixText: '${Currencies.symbols[_currency] ?? _currency} ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Members Card
                    _buildSectionCard(
                      context: context,
                      icon: Icons.people_outline,
                      title: 'Add Registered Members',
                      children: [
                        TextField(
                          controller: _userSearchController,
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
                          onChanged: (value) => _searchUsers(value),
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
                                  leading: CircleAvatar(
                                    child: _buildUserAvatar(
                                      user.avatarUrl,
                                      (user.firstName?.isNotEmpty == true ? user.firstName![0] : '?'),
                                    ),
                                  ),
                                  title: Text(user.fullName),
                                  subtitle: user.username != null ? Text('@${user.username}') : null,
                                  trailing: IconButton(
                                    icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                                    onPressed: () => _addUser(user),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        if (_selectedUsers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Selected Members',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
                                deleteIcon: Icon(Icons.close, size: 18, color: colorScheme.error),
                                onDeleted: () => _removeUser(user),
                              );
                            }).toList(),
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
                              label: const Text('Add to Pending Invites'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          if (_pendingInvites.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            Text(
                              'Pending Invites',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _pendingInvites.length,
                              itemBuilder: (context, index) {
                                final invite = _pendingInvites[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.email, size: 20, color: colorScheme.primary),
                                  ),
                                  title: Text(invite['email']!),
                                  subtitle: invite['name']!.isNotEmpty ? Text(invite['name']!) : null,
                                  trailing: IconButton(
                                    icon: Icon(Icons.close, color: colorScheme.error),
                                    onPressed: () => _removeInvite(invite['email']!),
                                  ),
                                );
                              },
                            ),
                          ],
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
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isCreateButtonEnabled() ? _createGroup : null,
                        icon: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: Text(_isLoading ? 'Creating...' : 'Create Group'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
