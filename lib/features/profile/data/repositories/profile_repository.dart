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


  Future<Result<ProfileModel>> createLocalProfile({
    required String userId,
    required String firstName,
    required String lastName,
    String? username,
    String? email,
    String? phoneNumber,
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
        'email': effectiveEmail,
      };

      if (username != null && username.isNotEmpty) payload['username'] = username;
      if (phoneNumber != null && phoneNumber.isNotEmpty) payload['phone_number'] = phoneNumber;

      final response = await _client
          .from('profiles')
          .insert(payload)
          .select()
          .maybeSingle();

      if (response == null) {
        return const Failure('Failed to create local profile');
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

      debugPrint('🔵 Uploading avatar to storage: $path');
      await _client.storage
          .from('avatars')
          .upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
      debugPrint('✅ Avatar uploaded to storage: $path');

      // Append a cache-busting query param so Flutter image cache fetches the new content
      final publicUrl = _client.storage
          .from('avatars')
          .getPublicUrl(path);
      final avatarUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('🔵 Updating profile with avatar URL: $avatarUrl');
      final updateResponse = await _client
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', userId)
          .select()
          .maybeSingle();

      if (updateResponse == null) {
        debugPrint('🔴 Failed to update profile with avatar URL');
        return const Failure('Failed to update profile with avatar URL');
      }

      debugPrint('✅ Avatar URL updated in profile: $avatarUrl');
      return Success(avatarUrl);
    } on StorageException catch (e) {
      debugPrint('🔴 Storage error during avatar upload: ${e.message}');
      return Failure('Storage error: ${e.message}');
    } on PostgrestException catch (e) {
      debugPrint('🔴 Database error during avatar upload: ${e.message}');
      return Failure('Database error: ${e.message}');
    } catch (e) {
      debugPrint('🔴 Avatar upload failed: ${e.toString()}');
      return Failure('Upload failed: ${e.toString()}');
    }
  }

  Future<Result<ProfileModel>> updatePrimaryLocation({
    required String userId,
    required String locationId,
  }) async {
    try {
      debugPrint('🔵 Updating primary location for user: $userId to location: $locationId');
      final response = await _client
          .from('profiles')
          .update({'primary_location_id': locationId})
          .eq('id', userId)
          .select()
          .maybeSingle();

      if (response == null) {
        debugPrint('🔴 Failed to update primary location - no rows affected');
        return const Failure('Failed to update primary location');
      }

      final responseMap = response;
      _fixProfileAvatarUrl(responseMap);
      debugPrint('✅ Primary location updated successfully');
      return Success(ProfileModel.fromJson(responseMap));
    } catch (e) {
      debugPrint('🔴 Primary location update exception: $e');
      return Failure('Failed to update primary location: ${e.toString()}');
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
