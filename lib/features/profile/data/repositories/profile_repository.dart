import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../shared/models/result.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final SupabaseClient _client = SupabaseService.instance;

  /// Helper to fix DiceBear URLs in profile data before mapping to model
  void _fixProfileAvatarUrl(Map<String, dynamic> data) {
    if (data['avatar_url'] != null) {
      final original = data['avatar_url'];
      data['avatar_url'] = fixDiceBearUrl(data['avatar_url']);
      if (original != data['avatar_url']) {
        debugPrint('👤 Profile avatar URL fixed: $original → ${data['avatar_url']}');
      }
    }
  }

  Future<Result<ProfileModel>> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // Auto-create a minimal profile for existing users that predate the trigger
        final email = SupabaseService.currentUser?.email;
        if (email == null || email.isEmpty) {
          return Failure('No profile and missing user email for: $userId');
        }
        try {
          final created = await _client
              .from('profiles')
              .insert({
                'id': userId,
                'email': email,
                'first_name': '',
                'last_name': '',
                'country': 'United States',
              })
              .select()
              .maybeSingle();
          if (created == null) {
            return Failure('Failed to auto-create profile for user: $userId');
          }
          final createdMap = created;
          _fixProfileAvatarUrl(createdMap);
          return Success(ProfileModel.fromJson(createdMap));
        } on PostgrestException catch (e) {
          return Failure('Profile missing and insert blocked: ${e.message}');
        }
      }
      final responseMap = response;
      _fixProfileAvatarUrl(responseMap);
      return Success(ProfileModel.fromJson(responseMap));
    } catch (e) {
      return Failure('Failed to load profile: ${e.toString()}');
    }
  }

  Future<Result<ProfileModel>> updateProfile({
    required String userId,
    String? username,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? country,
  }) async {
    try {
      final updates = <String, dynamic>{};
      bool hasAddressUpdate = false;

      if (username != null && username.isNotEmpty) {
        updates['username'] = username;
      } else if (username != null && username.isEmpty) {
        updates['username'] = null;
      }

      if (firstName != null && firstName.isNotEmpty) updates['first_name'] = firstName;
      if (lastName != null && lastName.isNotEmpty) updates['last_name'] = lastName;

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        updates['phone_number'] = phoneNumber;
      } else if (phoneNumber != null && phoneNumber.isEmpty) {
        updates['phone_number'] = null;
      }

      // Track address updates
      if (streetAddress != null) {
        hasAddressUpdate = true;
        if (streetAddress.isNotEmpty) {
          updates['street_address'] = streetAddress;
        } else {
          updates['street_address'] = null;
        }
      }

      if (city != null) {
        hasAddressUpdate = true;
        if (city.isNotEmpty) {
          updates['city'] = city;
        } else {
          updates['city'] = null;
        }
      }

      if (stateProvince != null) {
        hasAddressUpdate = true;
        if (stateProvince.isNotEmpty) {
          updates['state_province'] = stateProvince;
        } else {
          updates['state_province'] = null;
        }
      }

      if (postalCode != null) {
        hasAddressUpdate = true;
        if (postalCode.isNotEmpty) {
          updates['postal_code'] = postalCode;
        } else {
          updates['postal_code'] = null;
        }
      }

      if (country != null) {
        hasAddressUpdate = true;
        updates['country'] = country;
      }

      // Skip update if no fields to update
      if (updates.isEmpty) {
        debugPrint('⚠️ No fields to update');
        final response = await _client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (response == null) {
          return Failure('Profile not found for user: $userId');
        }
        final responseMap = response;
        _fixProfileAvatarUrl(responseMap);
        return Success(ProfileModel.fromJson(responseMap));
      }

      debugPrint('🔵 Updating profile for user: $userId with updates: $updates');

      // Update profiles table
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      // DUAL WRITE: If address was updated, also update/create location
      if (hasAddressUpdate && streetAddress != null && streetAddress.isNotEmpty) {
        await _syncAddressToLocation(
          userId: userId,
          streetAddress: streetAddress,
          city: city,
          stateProvince: stateProvince,
          postalCode: postalCode,
          country: country ?? 'USA',
          firstName: firstName,
        );
      }

      // Fetch the updated profile separately
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('🔴 Profile update returned null - no rows affected for user: $userId');
        return Failure('Profile update affected 0 rows for user: $userId');
      }
      debugPrint('✅ Profile update successful');
      final responseMap = response;
      _fixProfileAvatarUrl(responseMap);
      return Success(ProfileModel.fromJson(responseMap));
    } catch (e, stack) {
      debugPrint('🔴 Profile update exception: $e');
      debugPrint('Stack trace: $stack');
      return Failure('Failed to update profile: ${e.toString()}');
    }
  }

  /// Sync address from profile to locations table (dual-write pattern)
  /// This ensures addresses appear in location dropdowns
  Future<void> _syncAddressToLocation({
    required String userId,
    required String streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    required String country,
    String? firstName,
  }) async {
    try {
      // Check if user has a primary location
      final existingLocation = await _client
          .from('locations')
          .select()
          .eq('profile_id', userId)
          .eq('is_primary', true)
          .maybeSingle();

      if (existingLocation != null) {
        // Update existing primary location
        debugPrint('📍 Updating existing primary location for user: $userId');
        await _client
            .from('locations')
            .update({
              'street_address': streetAddress,
              'city': city,
              'state_province': stateProvince,
              'postal_code': postalCode,
              'country': country,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingLocation['id']);
      } else {
        // Create new primary location
        debugPrint('📍 Creating new primary location for user: $userId');
        final label = firstName != null && firstName.isNotEmpty
            ? '$firstName\'s Address'
            : 'Primary Address';

        final newLocation = await _client
            .from('locations')
            .insert({
              'profile_id': userId,
              'street_address': streetAddress,
              'city': city,
              'state_province': stateProvince,
              'postal_code': postalCode,
              'country': country,
              'label': label,
              'is_primary': true,
              'created_by': userId,
            })
            .select()
            .maybeSingle();

        // Update profile to reference this location
        if (newLocation != null) {
          await _client
              .from('profiles')
              .update({'primary_location_id': newLocation['id']})
              .eq('id', userId);
        }
      }
    } catch (e) {
      // Don't fail the profile update if location sync fails
      debugPrint('⚠️ Failed to sync address to location: $e');
    }
  }

  Future<Result<ProfileModel>> createLocalProfile({
    required String userId,
    required String firstName,
    required String lastName,
    String? username,
    String? email,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? country,
  }) async {
    try {
      final effectiveEmail = (email != null && email.trim().isNotEmpty)
          ? email.trim()
          : 'local+$userId@local';

      final payload = <String, dynamic>{
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'is_local_user': true,
        'country': country?.isNotEmpty == true ? country : 'United States',
        'email': effectiveEmail,
      };

      if (username != null && username.isNotEmpty) payload['username'] = username;
      if (phoneNumber != null && phoneNumber.isNotEmpty) payload['phone_number'] = phoneNumber;
      if (streetAddress != null && streetAddress.isNotEmpty) {
        payload['street_address'] = streetAddress;
      }
      if (city != null && city.isNotEmpty) payload['city'] = city;
      if (stateProvince != null && stateProvince.isNotEmpty) {
        payload['state_province'] = stateProvince;
      }
      if (postalCode != null && postalCode.isNotEmpty) payload['postal_code'] = postalCode;

      final response = await _client
          .from('profiles')
          .insert(payload)
          .select()
          .maybeSingle();

      if (response == null) {
        return const Failure('Failed to create local profile');
      }

      // DUAL WRITE: Also create location if address provided
      if (streetAddress != null && streetAddress.isNotEmpty) {
        await _syncAddressToLocation(
          userId: userId,
          streetAddress: streetAddress,
          city: city,
          stateProvince: stateProvince,
          postalCode: postalCode,
          country: country?.isNotEmpty == true ? country! : 'United States',
          firstName: firstName,
        );
      }

      final responseMap = response;
      _fixProfileAvatarUrl(responseMap);
      return Success(ProfileModel.fromJson(responseMap));
    } catch (e) {
      return Failure('Failed to create local profile: ${e.toString()}');
    }
  }

  Future<Result<String>> uploadAvatar(String userId, File imageFile) async {
    try {
      final fileName = 'avatar_$userId.jpg';
      final path = '$userId/$fileName';

        await _client.storage
          .from('avatars')
          .upload(path, imageFile, fileOptions: const FileOptions(upsert: true));

      // Append a cache-busting query param so Flutter image cache fetches the new content
      final publicUrl = _client.storage
          .from('avatars')
          .getPublicUrl(path);
      final avatarUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      final updateResponse = await _client
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', userId)
          .select()
          .maybeSingle();

      if (updateResponse == null) {
        return const Failure('Failed to update profile with avatar URL');
      }

      return Success(avatarUrl);
    } on StorageException catch (e) {
      return Failure('Storage error: ${e.message}');
    } on PostgrestException catch (e) {
      return Failure('Database error: ${e.message}');
    } catch (e) {
      return Failure('Upload failed: ${e.toString()}');
    }
  }

  Future<Result<List<ProfileModel>>> searchProfiles(String query) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          // Allow search by first/last/username/email
          .or('first_name.ilike.%$query%,last_name.ilike.%$query%,username.ilike.%$query%,email.ilike.%$query%')
          .limit(20);

      final profiles = (response as List)
          .map((json) {
            final profileMap = json as Map<String, dynamic>;
            _fixProfileAvatarUrl(profileMap);
            return ProfileModel.fromJson(profileMap);
          })
          .toList();

      return Success(profiles);
    } catch (e) {
      return Failure('Search failed: ${e.toString()}');
    }
  }

  Future<Result<void>> deleteProfile(String userId) async {
    try {
      // Delete profile - cascading will handle related records
      await _client.from('profiles').delete().eq('id', userId);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete profile: ${e.toString()}');
    }
  }
}
