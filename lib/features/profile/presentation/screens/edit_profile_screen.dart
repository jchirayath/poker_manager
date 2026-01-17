import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/avatar_utils.dart';
import 'package:go_router/go_router.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/utils/input_validators.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _usernameController;

  Widget _buildAvatarImage(String? url, String initials, ColorScheme colorScheme) {
    if ((url ?? '').isEmpty) {
      return _buildFallbackAvatar(initials, colorScheme);
    }

    if (url!.toLowerCase().contains('svg')) {
      return SvgPicture.network(
        fixDiceBearUrl(url)!,
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
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(initials, colorScheme),
      );
    }

    return Image.network(
      url,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(initials, colorScheme),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackAvatar(String initials, ColorScheme colorScheme) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : '?',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  late TextEditingController _phoneController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;

  String? _selectedCountry;
  File? _imageFile;
  bool _isLoading = false;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _usernameController = TextEditingController();
    _phoneController = TextEditingController();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _postalCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
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

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
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
            const Flexible(child: Text('Delete Profile')),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your profile? '
          'This action cannot be undone and will remove all your data, '
          'group memberships, and game history.',
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
      await _deleteProfile();
    }
  }

  Future<void> _deleteProfile() async {
    setState(() => _isLoading = true);

    try {
      final controller = ref.read(profileControllerProvider);
      final success = await controller.deleteProfile();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile deleted successfully')),
        );
        // Sign out and go to sign-in
        context.go(RouteConstants.signIn);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete profile')),
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

  Future<void> _showLogoutConfirmation() async {
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
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.logout, color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('Sign Out')),
          ],
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final controller = ref.read(authControllerProvider);
      await controller.signOut();
      if (mounted) {
        context.go(RouteConstants.signIn);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(profileControllerProvider);

      // Upload avatar if selected
      bool avatarSuccess = true;
      if (_imageFile != null) {
        avatarSuccess = await controller.uploadAvatar(_imageFile!);
        if (!avatarSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload avatar. Continuing with other changes...'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
        }
      }

      // Update profile
      final success = await controller.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        streetAddress: _streetController.text.trim(),
        city: _cityController.text.trim(),
        stateProvince: _stateController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        country: _selectedCountry,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
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
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _isLoading ? null : _showLogoutConfirmation,
          ),
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
              tooltip: 'Save',
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No profile found'));
          }

          // Initialize controllers with current values only once
          if (!_controllersInitialized) {
            _firstNameController.text = profile.firstName ?? '';
            _lastNameController.text = profile.lastName ?? '';
            _usernameController.text = profile.username ?? '';
            _phoneController.text = profile.phoneNumber ?? '';
            _streetController.text = profile.streetAddress ?? '';
            _cityController.text = profile.city ?? '';
            _stateController.text = profile.stateProvince ?? '';
            _postalCodeController.text = profile.postalCode ?? '';
            String mappedCountry = profile.country ?? 'United States';
            if (mappedCountry == 'US' || mappedCountry == 'USA' || mappedCountry == 'U.S.' || mappedCountry == 'U.S.A.') {
              mappedCountry = 'United States';
            } else if (mappedCountry == 'UK' || mappedCountry == 'GB') {
              mappedCountry = 'United Kingdom';
            } else if (mappedCountry == 'CA') {
              mappedCountry = 'Canada';
            }
            if (AppConstants.countries.contains(mappedCountry)) {
              _selectedCountry = mappedCountry;
            } else {
              _selectedCountry = 'United States';
            }
            _controllersInitialized = true;
          }

          final initials = _getInitials(profile.firstName ?? '', profile.lastName ?? '');

          return Form(
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
                              Container(
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
                                child: ClipOval(
                                  child: _imageFile != null
                                      ? Image.file(
                                          _imageFile!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        )
                                      : _buildAvatarImage(
                                          profile.avatarUrl,
                                          initials,
                                          colorScheme,
                                        ),
                                ),
                              ),
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
                        const SizedBox(height: 16),
                        Text(
                          profile.firstName != null || profile.lastName != null
                              ? '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim()
                              : 'Your Name',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (profile.username != null && profile.username!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@${profile.username}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: const Text('Change Photo'),
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
                        // Basic Information Card
                        _buildSectionCard(
                          context: context,
                          icon: Icons.person_outline,
                          title: 'Basic Information',
                          children: [
                            TextFormField(
                              initialValue: profile.email,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined, color: colorScheme.onSurfaceVariant),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    decoration: InputDecoration(
                                      labelText: 'First Name',
                                      prefixIcon: Icon(Icons.badge_outlined, color: colorScheme.primary),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Last Name',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                hintText: 'For Venmo & PayPal',
                                prefixIcon: Icon(Icons.alternate_email, color: colorScheme.primary),
                                helperText: 'Letters, numbers, dots, underscores, hyphens',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: InputValidators.validateUsername,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: 'For Venmo payments',
                                prefixIcon: Icon(Icons.phone_outlined, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: InputValidators.validatePhoneNumber,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Address Card
                        _buildSectionCard(
                          context: context,
                          icon: Icons.location_on_outlined,
                          title: 'Address (Optional)',
                          children: [
                            TextFormField(
                              controller: _streetController,
                              decoration: InputDecoration(
                                labelText: 'Street Address',
                                prefixIcon: Icon(Icons.home_outlined, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _cityController,
                                    decoration: InputDecoration(
                                      labelText: 'City',
                                      prefixIcon: Icon(Icons.location_city_outlined, color: colorScheme.primary),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _stateController,
                                    decoration: InputDecoration(
                                      labelText: 'State',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _postalCodeController,
                                    decoration: InputDecoration(
                                      labelText: 'Postal Code',
                                      prefixIcon: Icon(Icons.markunread_mailbox_outlined, color: colorScheme.primary),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: InputValidators.validatePostalCode,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedCountry,
                                    decoration: InputDecoration(
                                      labelText: 'Country',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    isExpanded: true,
                                    items: AppConstants.countries.map((country) {
                                      return DropdownMenuItem(
                                        value: country,
                                        child: Text(country, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() => _selectedCountry = value);
                                    },
                                    validator: (value) {
                                      if (value == null) return 'Required';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _saveProfile,
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
                                  'Deleting your profile will permanently remove all your data, group memberships, and game history.',
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
                                    label: Text('Delete Profile', style: TextStyle(color: colorScheme.error)),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  String _getInitials(String firstName, String lastName) {
    final fn = firstName.trim();
    final ln = lastName.trim();
    final i1 = fn.isNotEmpty ? fn.substring(0, 1) : '';
    final i2 = ln.isNotEmpty ? ln.substring(0, 1) : '';
    return (i1 + i2).isNotEmpty ? (i1 + i2) : '?';
  }
}
