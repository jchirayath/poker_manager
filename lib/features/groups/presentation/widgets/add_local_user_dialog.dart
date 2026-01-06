import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/supabase_service.dart';
import '../providers/groups_provider.dart';

class AddLocalUserDialog extends ConsumerStatefulWidget {
  final String groupId;
  const AddLocalUserDialog({super.key, required this.groupId});

  @override
  ConsumerState<AddLocalUserDialog> createState() => _AddLocalUserDialogState();
}

class _AddLocalUserDialogState extends ConsumerState<AddLocalUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _addLocalUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Generate a UUID for the local user
      final userId = SupabaseService.instance.auth.currentUser?.id;
      if (userId == null) throw 'Not authenticated';

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();

      debugPrint('🔵 Creating local user: $firstName $lastName');

      // Generate a UUID for the local user
      const uuid = Uuid();
      final localUserId = uuid.v4();

      debugPrint('🔵 Generated UUID: $localUserId');

      // Create the local user profile with explicit ID
      final profileResponse = await SupabaseService.instance
          .from('profiles')
          .insert({
            'id': localUserId,
            'first_name': firstName,
            'last_name': lastName,
            'email': email.isEmpty ? null : email,
            'phone_number': phone.isEmpty ? null : phone,
            'is_local_user': true,
            'country': 'United States', // Default
          })
          .select()
          .single();

      final newUserId = profileResponse['id'] as String;
      debugPrint('✅ Local user created: $newUserId');

      // Add the local user to the group
      await SupabaseService.instance.from('group_members').insert({
        'group_id': widget.groupId,
        'user_id': newUserId,
        'role': 'member',
        'is_creator': false,
      });

      debugPrint('✅ Local user added to group');

      // Invalidate the members list
      ref.invalidate(groupMembersProvider(widget.groupId));

      if (!mounted) return;
      context.pop(true); // Return true to indicate success

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$firstName $lastName added successfully')),
      );
    } catch (e, stack) {
      debugPrint('🔴 Error adding local user: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add user: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Local User'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add a user who doesn\'t have an account. They can join games and track stats.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
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
                controller: _lastNameController,
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
                controller: _emailController,
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
                controller: _phoneController,
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
          onPressed: _isLoading ? null : () => context.pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addLocalUser,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add User'),
        ),
      ],
    );
  }
}
