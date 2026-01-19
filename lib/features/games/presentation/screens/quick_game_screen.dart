import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/currencies.dart';
import '../../../../shared/models/result.dart';
import '../../../groups/data/models/group_member_model.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../groups/presentation/providers/local_user_provider.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/models/game_model.dart';
import '../providers/games_provider.dart';
import 'game_detail_screen.dart';

class QuickGameScreen extends ConsumerStatefulWidget {
  const QuickGameScreen({super.key});

  @override
  ConsumerState<QuickGameScreen> createState() => _QuickGameScreenState();
}

class _QuickGameScreenState extends ConsumerState<QuickGameScreen> {
  final _formKey = GlobalKey<FormState>();

  // Group settings
  late TextEditingController _groupNameController;
  String _privacy = 'private';
  String _currency = AppConstants.currencies.first;
  double _defaultBuyin = 100.0;
  final TextEditingController _buyinController = TextEditingController(text: '100');
  final TextEditingController _additionalBuyinsController = TextEditingController(text: '50');

  // Game settings
  late TextEditingController _gameNameController;
  DateTime _gameDate = DateTime.now();

  // User management
  final List<ProfileModel> _selectedUsers = [];
  final List<Map<String, String?>> _pendingLocalUsers = [];
  final List<Contact> _selectedContacts = [];
  final TextEditingController _userSearchController = TextEditingController();

  // Contacts
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  final TextEditingController _contactSearchController = TextEditingController();

  bool _isLoading = false;
  bool _hasContactsPermission = false;

  @override
  void initState() {
    super.initState();
    _generateGroupName();
    _gameNameController = TextEditingController(text: 'Quick Game');
    // Don't auto-load contacts - load on demand when user expands the section
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _buyinController.dispose();
    _additionalBuyinsController.dispose();
    _gameNameController.dispose();
    _userSearchController.dispose();
    _contactSearchController.dispose();
    super.dispose();
  }

  void _generateGroupName() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final random = Random().nextInt(9000) + 1000; // 4-digit number (1000-9999)
    _groupNameController = TextEditingController(text: 'Quick Game $dateStr $random');
  }

  Future<void> _loadContacts() async {
    try {
      bool hasPermission = await FlutterContacts.requestPermission();

      if (!hasPermission) {
        hasPermission = await FlutterContacts.requestPermission();
      }

      if (hasPermission) {
        if (mounted) {
          setState(() => _hasContactsPermission = true);
        }

        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );

        if (mounted) {
          setState(() {
            _allContacts = contacts;
            _filteredContacts = contacts;
          });

          if (contacts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No contacts found on your device'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          setState(() => _hasContactsPermission = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contacts permission denied. Please enable in Settings.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasContactsPermission = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading contacts: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _filterContacts(String query) {
    if (query.isEmpty) {
      setState(() => _filteredContacts = _allContacts);
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredContacts = _allContacts.where((contact) {
        final name = contact.displayName.toLowerCase();
        return name.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) return;

    final profileController = ref.read(profileControllerProvider);
    final results = await profileController.searchProfiles(query);

    // Filter out already selected users
    final selectedIds = _selectedUsers.map((u) => u.id).toSet();
    final availableUsers = results.where((u) => !selectedIds.contains(u.id)).toList();

    if (availableUsers.isNotEmpty && mounted) {
      _showUserSearchResults(availableUsers);
    }
  }

  void _showUserSearchResults(List<ProfileModel> users) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_search,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Users',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${users.length} user${users.length != 1 ? 's' : ''} found',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surface,
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable list with scroll indicator
              Flexible(
                child: Stack(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isFirst = index == 0;
                        final isLast = index == users.length - 1;

                        return Container(
                          margin: EdgeInsets.only(
                            left: 12,
                            right: 12,
                            top: isFirst ? 4 : 2,
                            bottom: isLast ? 4 : 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: _buildSafeAvatar(
                              avatarUrl: user.avatarUrl,
                              firstName: user.firstName,
                              lastName: user.lastName,
                              radius: 24,
                            ),
                            title: Text(
                              '${user.firstName ?? ''} ${user.lastName ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: user.username != null
                                ? Text(
                                    '@${user.username}',
                                    style: TextStyle(color: colorScheme.primary),
                                  )
                                : user.email != null
                                    ? Text(
                                        user.email!,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                            trailing: Icon(
                              Icons.add_circle,
                              color: colorScheme.primary,
                              size: 28,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _addUser(user);
                            },
                          ),
                        );
                      },
                    ),
                    // Scroll indicator at bottom
                    if (users.length > 4)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colorScheme.surface.withValues(alpha: 0.0),
                                colorScheme.surface.withValues(alpha: 0.9),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_downward,
                                    size: 16,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Scroll for more',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addUser(ProfileModel user) {
    setState(() => _selectedUsers.add(user));
    _userSearchController.clear();
  }

  void _removeUser(ProfileModel user) {
    setState(() => _selectedUsers.remove(user));
  }

  void _addContactAsLocalUser(Contact contact) {
    // Check if already added
    if (_selectedContacts.any((c) => c.id == contact.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact already added')),
      );
      return;
    }

    setState(() => _selectedContacts.add(contact));
  }

  void _removeContact(Contact contact) {
    setState(() => _selectedContacts.remove(contact));
  }

  Future<void> _addLocalUser() async {
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
                                  'username': username.isNotEmpty ? username : null,
                                  'email': email.isNotEmpty ? email : null,
                                  'phone': phone.isNotEmpty ? phone : null,
                                });
                              });

                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$firstName $lastName added')),
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
    );
  }

  void _removeLocalUser(Map<String, String?> user) {
    setState(() => _pendingLocalUsers.remove(user));
  }

  Widget _buildSafeAvatar({
    String? avatarUrl,
    String? firstName,
    String? lastName,
    double radius = 20,
  }) {
    // If we have an avatar URL, try to load it with error handling
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to initials on error
              return _buildInitialsAvatar(firstName, lastName, radius);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                width: radius * 2,
                height: radius * 2,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // No avatar URL, use initials
    return _buildInitialsAvatar(firstName, lastName, radius);
  }

  Widget _buildInitialsAvatar(String? firstName, String? lastName, double radius) {
    final hasInitials = (firstName?.isNotEmpty ?? false) && (lastName?.isNotEmpty ?? false);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: hasInitials
          ? Text(
              firstName![0].toUpperCase() + lastName![0].toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            )
          : Icon(
              Icons.person,
              size: radius * 1.2,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
    );
  }

  Future<void> _selectDate() async {
    if (!mounted) return;

    final date = await showDatePicker(
      context: context,
      initialDate: _gameDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_gameDate),
      );

      if (time != null && mounted) {
        setState(() {
          _gameDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createQuickGame() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    // Validate group name
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    // Validate buy-in
    final buyin = double.tryParse(_buyinController.text);
    if (buyin == null || buyin <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid buy-in amount')),
      );
      return;
    }

    // Check if at least one user is selected
    final totalUsers = _selectedUsers.length + _selectedContacts.length + _pendingLocalUsers.length;

    if (totalUsers == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one player')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create the group
      final additionalValue = double.tryParse(_additionalBuyinsController.text.trim());
      final additionalBuyins = <double>[];
      if (additionalValue != null && additionalValue > 0) {
        additionalBuyins.add(additionalValue);
      }

      final controller = ref.read(groupControllerProvider);
      final createResult = await controller.createGroup(
        name: _groupNameController.text.trim(),
        description: 'Quick game group created on ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
        privacy: _privacy,
        defaultCurrency: _currency,
        defaultBuyin: _defaultBuyin,
        additionalBuyinValues: additionalBuyins,
      );

      if (createResult is! Success<String>) {
        throw Exception('Failed to create group');
      }

      final groupId = createResult.data;

      // 2. Add registered members
      for (final user in _selectedUsers) {
        await controller.addMember(groupId, user.id);
      }

      // 3. Create local users from contacts
      final localUserController = ref.read(localUserControllerProvider);
      final List<String> createdContactUserIds = [];
      for (final contact in _selectedContacts) {
        final firstName = contact.name.first.isNotEmpty ? contact.name.first : 'Unknown';
        final lastName = contact.name.last.isNotEmpty ? contact.name.last : 'User';
        final email = contact.emails.isNotEmpty ? contact.emails.first.address : null;
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;

        final result = await localUserController.createLocalUser(
          groupId: groupId,
          firstName: firstName,
          lastName: lastName,
          email: email,
          phoneNumber: phone,
        );
        if (result is Success<ProfileModel>) {
          createdContactUserIds.add(result.data.id);
        } else if (result is Failure<ProfileModel>) {
          // If duplicate email/user, try to find the existing user
          if (result.message.contains('duplicate key') && email != null) {
            try {
              final profileController = ref.read(profileControllerProvider);
              final searchResults = await profileController.searchProfiles(email);
              if (searchResults.isNotEmpty) {
                final existingUser = searchResults.first;
                createdContactUserIds.add(existingUser.id);
                await controller.addMember(groupId, existingUser.id);
              }
            } catch (e) {
              // Silently handle error - user won't be added
            }
          }
        }
      }

      // 4. Create manually added local users
      final List<String> createdLocalUserIds = [];
      for (final localUser in _pendingLocalUsers) {
        final firstName = localUser['firstName'] ?? '';
        final lastName = localUser['lastName'] ?? '';
        final username = localUser['username'];
        final email = localUser['email'];
        final phone = localUser['phone'];

        final result = await localUserController.createLocalUser(
          groupId: groupId,
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
          phoneNumber: phone,
        );

        if (result is Success<ProfileModel>) {
          createdLocalUserIds.add(result.data.id);
        }
      }

      // 5. Build participant list from created users
      final List<String> playerIds = [];

      // Add registered users
      for (final user in _selectedUsers) {
        playerIds.add(user.id);
      }

      // Add contact-based local users
      for (final userId in createdContactUserIds) {
        playerIds.add(userId);
      }

      // Add manually created local users
      for (final userId in createdLocalUserIds) {
        playerIds.add(userId);
      }

      if (playerIds.isEmpty) {
        throw Exception('No participants found for game');
      }

      // 6. Create the game
      final gamesRepo = ref.read(gamesRepositoryProvider);
      final gameResult = await gamesRepo.createGame(
        groupId: groupId,
        name: _gameNameController.text.trim(),
        gameDate: _gameDate,
        location: null,
        currency: _currency,
        buyinAmount: buyin,
        additionalBuyinValues: additionalBuyins,
        participantUserIds: playerIds,
        allowMemberTransactions: true,
      );

      if (gameResult is! Success<GameModel>) {
        throw Exception('Failed to create game');
      }

      final gameId = gameResult.data.id;

      // 7. Start the game immediately
      final startGameNotifier = ref.read(startGameProvider.notifier);
      await startGameNotifier.startExistingGame(gameId);

      // 8. Invalidate providers to refresh
      ref.invalidate(activeGamesProvider);
      ref.invalidate(groupGamesWithGroupInfoProvider(groupId));

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quick game created and started!')),
        );

        // Navigate back to games screen first, then to the game detail
        Navigator.pop(context);

        // Navigate to the game detail screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailScreen(
              gameId: gameId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flash_on, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Quick Game'),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Group Information Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.flash_on,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Group Settings',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _groupNameController,
                      decoration: InputDecoration(
                        labelText: 'Group Name *',
                        prefixIcon: Icon(Icons.group, color: colorScheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _privacy,
                      decoration: InputDecoration(
                        labelText: 'Privacy',
                        prefixIcon: Icon(
                          _privacy == 'private' ? Icons.lock_outlined : Icons.public,
                          color: colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
              ),
            ),
            const SizedBox(height: 16),

            // Game Settings Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.casino_outlined,
                            color: colorScheme.onSecondaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Game Settings',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: InputDecoration(
                        labelText: 'Currency',
                        prefixIcon: Icon(Icons.attach_money, color: colorScheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        labelText: 'Default Buy-in *',
                        prefixIcon: Icon(Icons.payments_outlined, color: colorScheme.primary),
                        prefixText: '${Currencies.symbols[_currency] ?? _currency} ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Game Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.event,
                            color: colorScheme.onTertiaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Game Details',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gameNameController,
                      decoration: InputDecoration(
                        labelText: 'Game Name',
                        prefixIcon: Icon(Icons.casino, color: colorScheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.calendar_today, color: colorScheme.primary),
                      title: const Text('Date & Time'),
                      subtitle: Text(
                        DateFormat('MMM d, yyyy \'at\' h:mm a').format(_gameDate),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _selectDate,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Players Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.people,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Players',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Add Registered Members
                    ExpansionTile(
                      leading: Icon(Icons.person_add, color: colorScheme.primary),
                      title: const Text('Add Registered Members'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: _userSearchController,
                            decoration: InputDecoration(
                              labelText: 'Search Users',
                              hintText: 'Search by name or username',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: _searchUsers,
                          ),
                        ),
                        if (_selectedUsers.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedUsers.map((user) {
                                return Chip(
                                  avatar: _buildSafeAvatar(
                                    avatarUrl: user.avatarUrl,
                                    firstName: user.firstName,
                                    lastName: user.lastName,
                                    radius: 12,
                                  ),
                                  label: Text('${user.firstName ?? ''} ${user.lastName ?? ''}'),
                                  onDeleted: () => _removeUser(user),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),

                    // Add from Contacts
                    ExpansionTile(
                      leading: Icon(Icons.contacts, color: colorScheme.secondary),
                      title: const Text('Add from Contacts'),
                      initiallyExpanded: false,
                      onExpansionChanged: (expanded) {
                        if (expanded && !_hasContactsPermission && _allContacts.isEmpty) {
                          // Auto-request permission when expanding
                          _loadContacts();
                        }
                      },
                      children: [
                        if (!_hasContactsPermission)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.contacts_outlined,
                                  size: 48,
                                  color: colorScheme.outline,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Contact Access Required',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Allow access to add contacts as local players',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _loadContacts,
                                  icon: const Icon(Icons.contacts),
                                  label: const Text('Allow Contact Access'),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: TextField(
                              controller: _contactSearchController,
                              decoration: InputDecoration(
                                labelText: 'Search Contacts',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onChanged: _filterContacts,
                            ),
                          ),
                          _filteredContacts.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.contacts_outlined,
                                      size: 48,
                                      color: colorScheme.outline,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _allContacts.isEmpty
                                        ? 'No contacts found on your device'
                                        : 'No contacts match your search',
                                      style: TextStyle(color: colorScheme.outline),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : SizedBox(
                                height: 250,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _filteredContacts.length,
                                  itemBuilder: (context, index) {
                                    final contact = _filteredContacts[index];
                                    final isSelected = _selectedContacts.any((c) => c.id == contact.id);

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: colorScheme.primaryContainer,
                                        child: Icon(
                                          Icons.person,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      title: Text(contact.displayName),
                                      trailing: isSelected
                                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                                        : Icon(Icons.add_circle_outline, color: colorScheme.outline),
                                      onTap: isSelected
                                        ? () => _removeContact(contact)
                                        : () => _addContactAsLocalUser(contact),
                                    );
                                  },
                                ),
                              ),
                          if (_selectedContacts.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedContacts.map((contact) {
                                  return Chip(
                                    avatar: const CircleAvatar(
                                      child: Icon(Icons.person, size: 16),
                                    ),
                                    label: Text(contact.displayName),
                                    onDeleted: () => _removeContact(contact),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ],
                    ),

                    // Create and Add Users
                    ExpansionTile(
                      leading: Icon(Icons.person_add_alt, color: colorScheme.tertiary),
                      title: const Text('Create and Add Users'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: FilledButton.icon(
                            onPressed: _addLocalUser,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Local User'),
                          ),
                        ),
                        if (_pendingLocalUsers.isNotEmpty)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _pendingLocalUsers.length,
                            itemBuilder: (context, index) {
                              final user = _pendingLocalUsers[index];
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text('${user['firstName']} ${user['lastName']}'),
                                subtitle: user['email']?.isNotEmpty == true
                                  ? Text(user['email']!)
                                  : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeLocalUser(user),
                                ),
                              );
                            },
                          ),
                      ],
                    ),

                    // Summary
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people, color: colorScheme.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Text(
                            'Total Players: ${_selectedUsers.length + _selectedContacts.length + _pendingLocalUsers.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
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

            // Create and Start Button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _createQuickGame,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          const Icon(Icons.flash_on, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          _isLoading ? 'Creating Game...' : 'Create and Start Game',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
