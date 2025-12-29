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
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final controller = ref.read(profileControllerProvider);

    // Upload avatar if selected
    if (_imageFile != null) {
      await controller.uploadAvatar(_imageFile!);
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

          // Initialize controllers with current values
          _firstNameController.text = profile.firstName;
          _lastNameController.text = profile.lastName;
          _usernameController.text = profile.username ?? '';
          _phoneController.text = profile.phoneNumber ?? '';
          _streetController.text = profile.streetAddress ?? '';
          _cityController.text = profile.city ?? '';
          _stateController.text = profile.stateProvince ?? '';
          _postalCodeController.text = profile.postalCode ?? '';
          _selectedCountry ??= profile.country;

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
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : (profile.avatarUrl != null
                                  ? NetworkImage(profile.avatarUrl!)
                                  : null) as ImageProvider?,
                          child: profile.avatarUrl == null && _imageFile == null
                              ? Builder(
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
                                )
                              : null,
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
                          items: AppConstants.countries.map((country) {
                            return DropdownMenuItem(
                              value: country,
                              child: Text(country),
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
