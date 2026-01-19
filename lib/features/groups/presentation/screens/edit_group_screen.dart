import '../../../../core/constants/currencies.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/avatar_utils.dart';
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
  final bool autoSendRsvpEmails;

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
    this.autoSendRsvpEmails = true,
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
  late bool _autoSendRsvpEmails;
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
    _autoSendRsvpEmails = widget.autoSendRsvpEmails;
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
      _avatarUrl = null;
    });
  }

  Widget _buildAvatarPreview() {
    final colorScheme = Theme.of(context).colorScheme;
    final letter = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : '?';

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
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      if (_avatarUrl!.toLowerCase().contains('svg')) {
        avatarContent = ClipOval(
          child: SvgPicture.network(
            fixDiceBearUrl(_avatarUrl!)!,
            width: 100,
            height: 100,
            placeholderBuilder: (_) => Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        );
      } else {
        avatarContent = ClipOval(
          child: Image.network(
            _avatarUrl!,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(letter, colorScheme),
          ),
        );
      }
    } else {
      avatarContent = _buildFallbackAvatar(letter, colorScheme);
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

  Widget _buildFallbackAvatar(String letter, ColorScheme colorScheme) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('Delete Group')),
          ],
        ),
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
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
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
      final (success, errorMessage) = await controller.deleteGroup(widget.groupId);

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
          SnackBar(content: Text(errorMessage ?? 'Failed to delete group')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateGroup() async {
    if (!_formKey.currentState!.validate()) {
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
        } catch (storageError) {
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
      final ok = await controller.updateGroup(
        groupId: widget.groupId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        avatarUrl: newAvatarUrl,
        privacy: _privacy,
        defaultCurrency: _currency,
        defaultBuyin: _defaultBuyin,
        additionalBuyinValues: additionalBuyins,
        autoSendRsvpEmails: _autoSendRsvpEmails,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group updated successfully')),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update group')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
        title: const Text('Edit Group'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _updateGroup,
              tooltip: 'Save Changes',
            ),
        ],
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
                          label: Text(_selectedImage != null || _avatarUrl != null
                              ? 'Change'
                              : 'Add Photo'),
                        ),
                        if (_selectedImage != null || _avatarUrl != null) ...[
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
                    // Group Info Card
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a group name';
                            }
                            return null;
                          },
                          onChanged: (value) => setState(() {}),
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
                        const SizedBox(height: 16),
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
                          items: Currencies.symbols.keys.map((currency) {
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
                          controller: _defaultBuyinController,
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
                            if (amount != null) setState(() => _defaultBuyin = amount);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _additionalBuyinController,
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
                    const SizedBox(height: 24),

                    // RSVP Email Settings Card
                    Card(
                      elevation: 0,
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
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
                                  child: Icon(Icons.email, color: colorScheme.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'RSVP Email Settings',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              value: _autoSendRsvpEmails,
                              onChanged: (value) {
                                setState(() => _autoSendRsvpEmails = value);
                              },
                              title: const Text('Auto-send RSVP emails'),
                              subtitle: const Text(
                                'Automatically send RSVP invitation emails when a new game is created',
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _updateGroup,
                        icon: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Danger Zone Card
                    Card(
                      elevation: 0,
                      color: colorScheme.errorContainer.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.3)),
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
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.warning_amber_rounded, size: 20, color: colorScheme.error),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Danger Zone',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Deleting this group will permanently remove all games, transactions, and data.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _showDeleteConfirmation,
                                icon: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
                                label: Text('Delete Group', style: TextStyle(color: colorScheme.error)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
