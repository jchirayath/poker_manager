import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/groups_provider.dart';
import '../../../../core/constants/app_constants.dart';

class EditGroupScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String privacy;
  final String currency;
  final double defaultBuyin;
  final List<double> additionalBuyins;

  const EditGroupScreen({
    super.key,
    required this.groupId,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.privacy,
    required this.currency,
    required this.defaultBuyin,
    required this.additionalBuyins,
  });

  @override
  ConsumerState<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends ConsumerState<EditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _defaultBuyinController;
  late TextEditingController _additionalBuyinController;

  late String _privacy;
  late String _currency;
  late double _defaultBuyin;
  String? _avatarUrl;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _descriptionController = TextEditingController(text: widget.description ?? '');
    _defaultBuyinController = TextEditingController(text: widget.defaultBuyin.toStringAsFixed(2));
    _additionalBuyinController = TextEditingController(
      text: widget.additionalBuyins.isNotEmpty ? widget.additionalBuyins.first.toStringAsFixed(2) : '50',
    );
    _privacy = widget.privacy;
    _currency = widget.currency;
    _defaultBuyin = widget.defaultBuyin;
    _avatarUrl = widget.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _defaultBuyinController.dispose();
    _additionalBuyinController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
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
      debugPrint('Error picking image: $e');
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
      _avatarUrl = null;
    });
  }

  Widget _buildAvatarPreview() {
    final letter = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : '?';

    Widget avatarContent;

    if (_selectedImage != null) {
      // Show newly selected image
      avatarContent = ClipOval(
        child: Image.file(
          _selectedImage!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        ),
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      // Show existing avatar
      if (_avatarUrl!.toLowerCase().contains('svg')) {
        avatarContent = ClipOval(
          child: SvgPicture.network(
            _avatarUrl!,
            width: 80,
            height: 80,
            placeholderBuilder: (_) => CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey.shade200,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      } else {
        avatarContent = CircleAvatar(
          radius: 40,
          backgroundImage: NetworkImage(_avatarUrl!),
        );
      }
    } else {
      // Show fallback with letter
      avatarContent = CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey.shade200,
        child: Text(
          letter,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      );
    }

    return avatarContent;
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? '
          'This action cannot be undone and will remove all games, '
          'transactions, and data associated with this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteGroup();
    }
  }

  Future<void> _deleteGroup() async {
    setState(() => _isLoading = true);

    try {
      final controller = ref.read(groupControllerProvider);
      final success = await controller.deleteGroup(widget.groupId);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted successfully')),
        );
        // Pop twice to go back to groups list (skipping the detail screen)
        context.pop();
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete group')),
        );
      }
    } catch (e) {
      debugPrint('🔴 Error deleting group: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateGroup() async {
    debugPrint('🔵 Updating group');
    if (!_formKey.currentState!.validate()) {
      debugPrint('🔴 Form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Handle avatar upload if a new image was selected
      String? newAvatarUrl = _avatarUrl;
      if (_selectedImage != null) {
        try {
          // Upload to Supabase Storage
          final fileName = 'group_${widget.groupId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final bytes = await _selectedImage!.readAsBytes();
          
          await ref.read(groupsRepositoryProvider).client
              .storage
              .from('group-avatars')
              .uploadBinary(fileName, bytes);

          newAvatarUrl = ref.read(groupsRepositoryProvider).client
              .storage
              .from('group-avatars')
              .getPublicUrl(fileName);
          
          debugPrint('✅ Avatar uploaded: $newAvatarUrl');
        } catch (storageError) {
          debugPrint('⚠️ Storage upload failed: $storageError');
          // Continue without updating avatar if storage fails
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Warning: Avatar upload failed. Continuing with other updates.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          // Keep the existing avatar URL
          newAvatarUrl = _avatarUrl;
        }
      } else if (_avatarUrl == null && _selectedImage == null) {
        // Explicitly clear avatar if removed
        newAvatarUrl = '';
      }

      // Parse additional buyin
      final additionalValue = double.tryParse(_additionalBuyinController.text.trim());
      final additionalBuyins = <double>[];
      if (additionalValue != null && additionalValue > 0) {
        additionalBuyins.add(additionalValue);
      }

      final controller = ref.read(groupControllerProvider);
      debugPrint('🔵 Calling updateGroup for ${widget.groupId}');
      final ok = await controller.updateGroup(
        groupId: widget.groupId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        avatarUrl: newAvatarUrl,
        privacy: _privacy,
        defaultCurrency: _currency,
        defaultBuyin: _defaultBuyin,
        additionalBuyinValues: additionalBuyins,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (ok) {
        debugPrint('✅ Group updated successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group updated successfully')),
        );
        context.pop();
      } else {
        debugPrint('🔴 Group update failed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update group')),
        );
      }
    } catch (e, stack) {
      debugPrint('🔴 Error updating group: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Group'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  _buildAvatarPreview(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: Text(_selectedImage != null || _avatarUrl != null
                            ? 'Change Icon'
                            : 'Add Icon'),
                      ),
                      if (_selectedImage != null || _avatarUrl != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _removeAvatar,
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('Remove', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
              onChanged: (value) {
                setState(() {});
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
              'Game Settings',
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
              controller: _defaultBuyinController,
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
              controller: _additionalBuyinController,
              decoration: InputDecoration(
                labelText: 'Additional Buy-in (optional)',
                border: const OutlineInputBorder(),
                helperText: 'Single amount, leave blank if none',
                prefix: Text('$_currency '),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateGroup,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Update Group', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Danger Zone',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isLoading ? null : _showDeleteConfirmation,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text(
                'Delete Group',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
