import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../providers/profile_provider.dart';
import '../../../../core/constants/app_constants.dart';

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
    debugPrint('🔵 Picking image from gallery');
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      debugPrint('✅ Image selected: ${image.path}');
      setState(() => _imageFile = File(image.path));
    } else {
      debugPrint('🔵 Image selection cancelled');
    }
  }

  Future<void> _saveProfile() async {
    debugPrint('🔵 Saving profile');
    if (!_formKey.currentState!.validate()) {
      debugPrint('🔴 Form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(profileControllerProvider);

      // Upload avatar if selected
      bool avatarSuccess = true;
      if (_imageFile != null) {
        debugPrint('🔵 Uploading avatar');
        avatarSuccess = await controller.uploadAvatar(_imageFile!);
        if (!avatarSuccess) {
          debugPrint('🔴 Avatar upload failed');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload avatar. Continuing with other changes...'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          debugPrint('✅ Avatar uploaded successfully');
        }
      }

      // Update profile
      debugPrint('🔵 Updating profile fields');
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
        debugPrint('✅ Profile updated successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        context.pop();
      } else {
        debugPrint('🔴 Profile update failed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    } catch (e, stack) {
      debugPrint('🔴 Error saving profile: $e');
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
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
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
            _firstNameController.text = profile.firstName;
            _lastNameController.text = profile.lastName;
            _usernameController.text = profile.username ?? '';
            _phoneController.text = profile.phoneNumber ?? '';
            _streetController.text = profile.streetAddress ?? '';
            _cityController.text = profile.city ?? '';
            _stateController.text = profile.stateProvince ?? '';
            _postalCodeController.text = profile.postalCode ?? '';
            // Map common country abbreviations to full names
            String mappedCountry = profile.country;
            if (mappedCountry == 'US' || mappedCountry == 'USA' || mappedCountry == 'U.S.' || mappedCountry == 'U.S.A.') {
              mappedCountry = 'United States';
            } else if (mappedCountry == 'UK' || mappedCountry == 'GB') {
              mappedCountry = 'United Kingdom';
            } else if (mappedCountry == 'CA') {
              mappedCountry = 'Canada';
            }
            // Only set if the country exists in our dropdown list
            if (AppConstants.countries.contains(mappedCountry)) {
              _selectedCountry = mappedCountry;
            } else {
              _selectedCountry = 'United States'; // Default fallback
            }
            _controllersInitialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          child: _imageFile != null
                              ? ClipOval(
                                  child: Image.file(
                                    _imageFile!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : profile.avatarUrl != null
                                  ? ClipOval(
                                      child: Image.network(
                                        profile.avatarUrl!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          final fn = (profile.firstName).trim();
                                          final ln = (profile.lastName).trim();
                                          final i1 = fn.isNotEmpty ? fn.substring(0, 1) : '';
                                          final i2 = ln.isNotEmpty ? ln.substring(0, 1) : '';
                                          final initials = (i1 + i2).isNotEmpty ? (i1 + i2) : '?';
                                          return Container(
                                            width: 120,
                                            height: 120,
                                            color: Colors.grey[300],
                                            child: Center(
                                              child: Text(
                                                initials,
                                                style: const TextStyle(fontSize: 32),
                                              ),
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Builder(
                                      builder: (_) {
                                        final fn = (profile.firstName).trim();
                                        final ln = (profile.lastName).trim();
                                        final i1 = fn.isNotEmpty ? fn.substring(0, 1) : '';
                                        final i2 = ln.isNotEmpty ? ln.substring(0, 1) : '';
                                        final initials = (i1 + i2).isNotEmpty ? (i1 + i2) : '?';
                                        return Text(
                                          initials,
                                          style: const TextStyle(fontSize: 32),
                                        );
                                      },
                                    ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white),
                              onPressed: _pickImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Basic Info
                  const Text(
                    'Basic Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Email (read-only)
                  TextFormField(
                    initialValue: profile.email,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your first name';
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
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your last name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),

                  // Address
                  const Text(
                    'Address (Optional)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(
                      labelText: 'Street Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            border: OutlineInputBorder(),
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
                          decoration: const InputDecoration(
                            labelText: 'Postal Code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCountry,
                          decoration: const InputDecoration(
                            labelText: 'Country *',
                            border: OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: AppConstants.countries.map((country) {
                            return DropdownMenuItem(
                              value: country,
                              child: Text(
                                country,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedCountry = value);
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
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
}
