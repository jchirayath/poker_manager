import 'dart:io';
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
          return Result.failure('No profile and missing user email for: $userId');
        }
        try {
          final created = await _client
              .from('profiles')
              .insert({
                'id': userId,
                'email': email,
                'first_name': '',
                'last_name': '',
                'country': 'US',
              })
              .select()
              .maybeSingle();
          if (created == null) {
            return Result.failure('Failed to auto-create profile for user: $userId');
          }
          return Result.success(ProfileModel.fromJson(created));
        } on PostgrestException catch (e) {
          return Result.failure('Profile missing and insert blocked: ${e.message}');
        }
      }
      return Result.success(ProfileModel.fromJson(response));
    } catch (e) {
      return Result.failure('Failed to load profile: ${e.toString()}');
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
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (username != null) updates['username'] = username;
      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (streetAddress != null) updates['street_address'] = streetAddress;
      if (city != null) updates['city'] = city;
      if (stateProvince != null) updates['state_province'] = stateProvince;
      if (postalCode != null) updates['postal_code'] = postalCode;
      if (country != null) updates['country'] = country;

      final response = await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .maybeSingle();

      if (response == null) {
        return Result.failure('Profile update affected 0 rows for user: $userId');
      }
      return Result.success(ProfileModel.fromJson(response));
    } catch (e) {
      return Result.failure('Failed to update profile: ${e.toString()}');
    }
  }

  Future<Result<String>> uploadAvatar(String userId, File imageFile) async {
    try {
      final fileName = 'avatar_$userId.jpg';
      final path = '$userId/$fileName';

      await _client.storage
          .from('avatars')
          .upload(path, imageFile, fileOptions: const FileOptions(upsert: true));

      final avatarUrl = _client.storage
          .from('avatars')
          .getPublicUrl(path);

      await _client
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', userId);

      return Result.success(avatarUrl);
    } catch (e) {
      return Result.failure('Failed to upload avatar: ${e.toString()}');
    }
  }

  Future<Result<List<ProfileModel>>> searchProfiles(String query) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .or('first_name.ilike.%$query%,last_name.ilike.%$query%,username.ilike.%$query%')
          .limit(20);

      final profiles = (response as List)
          .map((json) => ProfileModel.fromJson(json))
          .toList();

      return Result.success(profiles);
    } catch (e) {
      return Result.failure('Search failed: ${e.toString()}');
    }
  }
}
