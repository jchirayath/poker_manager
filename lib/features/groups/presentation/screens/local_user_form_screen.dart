import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
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
  String _selectedCountry = 'United States';
  ProfileModel? _profile;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
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
    _emailController.text = profile.email;
    _phoneController.text = profile.phoneNumber ?? '';
    _streetController.text = profile.streetAddress ?? '';
    _cityController.text = profile.city ?? '';
    _stateController.text = profile.stateProvince ?? '';
    _postalController.text = profile.postalCode ?? '';

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
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final street = _streetController.text.trim();
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();
      final postal = _postalController.text.trim();

      debugPrint('🔵 Saving local user: imageChanged=$_imageChanged, imageFile=$_imageFile');

      if (widget.isEdit) {
        final ok = await controller.updateLocalUser(
          groupId: widget.groupId,
          userId: widget.userId!,
          firstName: firstName,
          lastName: lastName,
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
        debugPrint('🔵 Update result: $ok');
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

  Widget _buildAvatar(ProfileModel? profile) {
    final initials = _initialsFrom(profile);
    if (_imageFile != null) {
      return ClipOval(
        child: Image.file(
          _imageFile!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }

    final url = profile?.avatarUrl;
    if (url != null && url.isNotEmpty) {
      if (url.toLowerCase().contains('svg')) {
        return SvgPicture.network(
          url,
          width: 120,
          height: 120,
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
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _initialsWidget(initials),
        ),
      );
    }

    return _initialsWidget(initials);
  }

  String _initialsFrom(ProfileModel? profile) {
    final fn = profile?.firstName ?? _firstNameController.text;
    final ln = profile?.lastName ?? _lastNameController.text;
    final i1 = fn.isNotEmpty ? fn.substring(0, 1) : '';
    final i2 = ln.isNotEmpty ? ln.substring(0, 1) : '';
    final initials = (i1 + i2).isNotEmpty ? (i1 + i2) : '?';
    return initials;
  }

  Widget _initialsWidget(String initials) {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.grey.shade300,
      child: Text(
        initials,
        style: const TextStyle(fontSize: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _loadExistingProfileIfNeeded();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Local User' : 'Add Local User'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      _buildAvatar(_profile),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              onPressed: _isLoading ? null : _pickImage,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Basic Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'First name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Last name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty && !value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Address',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _streetController,
                  decoration: const InputDecoration(
                    labelText: 'Street Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State/Province',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _postalController,
                  decoration: const InputDecoration(
                    labelText: 'Postal Code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCountry,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(),
                  ),
                  items: AppConstants.countries
                      .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedCountry = value ?? _selectedCountry),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: const Icon(Icons.check),
                  label: Text(widget.isEdit ? 'Save Changes' : 'Create Local User'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
