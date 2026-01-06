import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/result.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final SupabaseClient _client = SupabaseService.instance;

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
          return Success(ProfileModel.fromJson(created));
        } on PostgrestException catch (e) {
          return Failure('Profile missing and insert blocked: ${e.message}');
        }
      }
      return Success(ProfileModel.fromJson(response));
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
      
      if (streetAddress != null && streetAddress.isNotEmpty) {
        updates['street_address'] = streetAddress;
      } else if (streetAddress != null && streetAddress.isEmpty) {
        updates['street_address'] = null;
      }
      
      if (city != null && city.isNotEmpty) {
        updates['city'] = city;
      } else if (city != null && city.isEmpty) {
        updates['city'] = null;
      }
      
      if (stateProvince != null && stateProvince.isNotEmpty) {
        updates['state_province'] = stateProvince;
      } else if (stateProvince != null && stateProvince.isEmpty) {
        updates['state_province'] = null;
      }
      
      if (postalCode != null && postalCode.isNotEmpty) {
        updates['postal_code'] = postalCode;
      } else if (postalCode != null && postalCode.isEmpty) {
        updates['postal_code'] = null;
      }
      
      if (country != null && country.isNotEmpty) updates['country'] = country;

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
        return Success(ProfileModel.fromJson(response));
      }

      debugPrint('🔵 Updating profile for user: $userId with updates: $updates');

      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);

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
      return Success(ProfileModel.fromJson(response));
    } catch (e, stack) {
      debugPrint('🔴 Profile update exception: $e');
      debugPrint('Stack trace: $stack');
      return Failure('Failed to update profile: ${e.toString()}');
    }
  }

  Future<Result<ProfileModel>> createLocalProfile({
    required String userId,
    required String firstName,
    required String lastName,
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

      return Success(ProfileModel.fromJson(response));
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
          .map((json) => ProfileModel.fromJson(json))
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
