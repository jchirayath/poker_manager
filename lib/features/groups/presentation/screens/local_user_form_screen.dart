import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/avatar_utils.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/result.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/local_user_provider.dart';

class LocalUserFormScreen extends ConsumerStatefulWidget {
  const LocalUserFormScreen({
    super.key,
    required this.groupId,
    this.userId,
    this.initialProfile,
  });

  final String groupId;
  final String? userId;
  final ProfileModel? initialProfile;

  bool get isEdit => userId != null;

  @override
  ConsumerState<LocalUserFormScreen> createState() => _LocalUserFormScreenState();
}

class _LocalUserFormScreenState extends ConsumerState<LocalUserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _streetController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalController;

  File? _imageFile;
  bool _imageChanged = false;
  bool _isLoading = false;
  bool _fetchingProfile = false;
  bool _appliedProfile = false;
  bool _showAddressSection = false;
  String _selectedCountry = 'United States';
  ProfileModel? _profile;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _postalController = TextEditingController();

    _profile = widget.initialProfile;
    _applyProfileToControllers();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfileIfNeeded() async {
    if (!widget.isEdit || _profile != null || _fetchingProfile) return;
    _fetchingProfile = true;
    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.getProfile(widget.userId!);
    if (result is Success<ProfileModel>) {
      _profile = result.data;
    }
    _fetchingProfile = false;
    if (mounted) {
      setState(_applyProfileToControllers);
    }
  }

  void _applyProfileToControllers() {
    if (_profile == null || _appliedProfile) return;
    final profile = _profile!;
    _firstNameController.text = profile.firstName ?? '';
    _lastNameController.text = profile.lastName ?? '';
    _usernameController.text = profile.username ?? '';
    _emailController.text = profile.email;
    _phoneController.text = profile.phoneNumber ?? '';
    _streetController.text = profile.streetAddress ?? '';
    _cityController.text = profile.city ?? '';
    _stateController.text = profile.stateProvince ?? '';
    _postalController.text = profile.postalCode ?? '';

    // Check if address fields have data to expand the section
    if (_streetController.text.isNotEmpty ||
        _cityController.text.isNotEmpty ||
        _stateController.text.isNotEmpty ||
        _postalController.text.isNotEmpty) {
      _showAddressSection = true;
    }

    String mappedCountry = profile.country ?? 'United States';
    if (mappedCountry == 'US' || mappedCountry == 'USA' || mappedCountry == 'U.S.' || mappedCountry == 'U.S.A.') {
      mappedCountry = 'United States';
    } else if (mappedCountry == 'UK' || mappedCountry == 'GB') {
      mappedCountry = 'United Kingdom';
    } else if (mappedCountry == 'CA') {
      mappedCountry = 'Canada';
    }
    _selectedCountry = AppConstants.countries.contains(mappedCountry)
        ? mappedCountry
        : 'United States';

    _appliedProfile = true;
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
      setState(() {
        _imageFile = File(image.path);
        _imageChanged = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(localUserControllerProvider);
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final street = _streetController.text.trim();
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();
      final postal = _postalController.text.trim();

      debugPrint('Saving local user: imageChanged=$_imageChanged, imageFile=$_imageFile');

      if (widget.isEdit) {
        final ok = await controller.updateLocalUser(
          groupId: widget.groupId,
          userId: widget.userId!,
          firstName: firstName,
          lastName: lastName,
          username: username.isEmpty ? null : username,
          email: email.isEmpty ? null : email,
          phoneNumber: phone.isEmpty ? null : phone,
          streetAddress: street.isEmpty ? null : street,
          city: city.isEmpty ? null : city,
          stateProvince: state.isEmpty ? null : state,
          postalCode: postal.isEmpty ? null : postal,
          country: _selectedCountry,
          avatarFile: _imageChanged ? _imageFile : null,
        );

        if (!mounted) return;
        debugPrint('Update result: $ok');
        if (ok is Success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Local user updated')),
          );
          context.pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok is Failure ? ok.message : 'Failed to update user'),
            ),
          );
        }
      } else {
        final created = await controller.createLocalUser(
          groupId: widget.groupId,
          firstName: firstName,
          lastName: lastName,
          username: username.isEmpty ? null : username,
          email: email.isEmpty ? null : email,
          phoneNumber: phone.isEmpty ? null : phone,
          streetAddress: street.isEmpty ? null : street,
          city: city.isEmpty ? null : city,
          stateProvince: state.isEmpty ? null : state,
          postalCode: postal.isEmpty ? null : postal,
          country: _selectedCountry,
          avatarFile: _imageFile,
        );

        if (!mounted) return;
        if (created is Success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Local user added to group')),
          );
          context.pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(created is Failure<ProfileModel> ? created.message : 'Failed to add user'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildAvatar(ProfileModel? profile, ColorScheme colorScheme) {
    final initials = _initialsFrom(profile);
    if (_imageFile != null) {
      return ClipOval(
        child: Image.file(
          _imageFile!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    }

    final url = profile?.avatarUrl;
    if (url != null && url.isNotEmpty) {
      if (url.toLowerCase().contains('svg')) {
        return SvgPicture.network(
          fixDiceBearUrl(url)!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return ClipOval(
        child: Image.network(
          url,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _initialsWidget(initials, colorScheme),
        ),
      );
    }

    return _initialsWidget(initials, colorScheme);
  }

  String _initialsFrom(ProfileModel? profile) {
    final fn = profile?.firstName ?? _firstNameController.text;
    final ln = profile?.lastName ?? _lastNameController.text;
    final i1 = fn.isNotEmpty ? fn.substring(0, 1) : '';
    final i2 = ln.isNotEmpty ? ln.substring(0, 1) : '';
    final initials = (i1 + i2).isNotEmpty ? (i1 + i2) : '?';
    return initials;
  }

  Widget _initialsWidget(String initials, ColorScheme colorScheme) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<Widget> children,
    String? subtitle,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
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
    _loadExistingProfileIfNeeded();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Local User' : 'Add Local User'),
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
                      onTap: _isLoading ? null : _pickImage,
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
                            child: _buildAvatar(_profile, colorScheme),
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _isLoading ? null : _pickImage,
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: Text(_imageFile != null || _profile?.avatarUrl != null ? 'Change Photo' : 'Add Photo'),
                        ),
                        if (_imageFile != null) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _imageFile = null;
                                _imageChanged = true;
                              });
                            },
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
                    // Basic Information Card
                    _buildSectionCard(
                      context: context,
                      icon: Icons.person_outline,
                      title: 'Basic Information',
                      children: [
                        TextFormField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            labelText: 'First Name *',
                            prefixIcon: Icon(Icons.badge_outlined, color: colorScheme.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'First name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Last Name *',
                            prefixIcon: Icon(Icons.badge_outlined, color: colorScheme.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'Last name is required' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Contact Information Card
                    _buildSectionCard(
                      context: context,
                      icon: Icons.contact_phone_outlined,
                      title: 'Contact Information',
                      subtitle: 'Optional',
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value != null && value.isNotEmpty && !value.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone',
                            prefixIcon: Icon(Icons.phone_outlined, color: colorScheme.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Payment Username Card
                    _buildSectionCard(
                      context: context,
                      icon: Icons.payments_outlined,
                      title: 'Payment Username',
                      subtitle: 'Used for PayPal, Venmo transactions',
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            hintText: '@username',
                            prefixIcon: Icon(Icons.alternate_email, color: colorScheme.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Address Card (Expandable)
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
                          child: Icon(Icons.location_on_outlined, size: 20, color: colorScheme.secondary),
                        ),
                        title: Text(
                          'Address',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Optional',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                        initiallyExpanded: _showAddressSection,
                        onExpansionChanged: (expanded) => setState(() => _showAddressSection = expanded),
                        children: [
                          TextFormField(
                            controller: _streetController,
                            decoration: InputDecoration(
                              labelText: 'Street Address',
                              prefixIcon: Icon(Icons.home_outlined, color: colorScheme.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cityController,
                                  decoration: InputDecoration(
                                    labelText: 'City',
                                    prefixIcon: Icon(Icons.location_city_outlined, color: colorScheme.primary),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  textCapitalization: TextCapitalization.words,
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
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _postalController,
                                  decoration: InputDecoration(
                                    labelText: 'Postal Code',
                                    prefixIcon: Icon(Icons.markunread_mailbox_outlined, color: colorScheme.primary),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  keyboardType: TextInputType.text,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCountry,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Country',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  items: AppConstants.countries
                                      .map((c) => DropdownMenuItem<String>(
                                            value: c,
                                            child: Text(c, overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (value) => setState(() => _selectedCountry = value ?? _selectedCountry),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _save,
                        icon: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isLoading
                            ? 'Saving...'
                            : (widget.isEdit ? 'Save Changes' : 'Add Local User')),
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
