import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/groups_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../shared/models/result.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _additionalBuyinsController = TextEditingController(text: '50');
  final _userSearchController = TextEditingController();

  String _privacy = 'private';
  String _currency = AppConstants.currencies.first;
  double _defaultBuyin = 100.0;
  final List<ProfileModel> _selectedUsers = [];
  List<ProfileModel> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _additionalBuyinsController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    debugPrint('🔵 Creating new group');
    if (!_formKey.currentState!.validate()) {
      debugPrint('🔴 Form validation failed');
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

        setState(() => _isLoading = false);

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
              value: _privacy,
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
              value: _currency,
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
              initialValue: _defaultBuyin.toStringAsFixed(2),
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
                        backgroundImage: user.avatarUrl != null
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? Text(user.firstName.isNotEmpty
                                ? user.firstName[0]
                                : '?')
                            : null,
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
                  return Chip(
                    avatar: user.avatarUrl != null
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(user.avatarUrl!),
                          )
                        : CircleAvatar(
                            child: Text(user.firstName.isNotEmpty
                                ? user.firstName[0]
                                : '?'),
                          ),
                    label: Text(user.fullName),
                    onDeleted: () => _removeUser(user),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isLoading ? null : _createGroup,
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
