import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/models/profile_model.dart';
import '../../../../shared/models/result.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../locations/data/repositories/locations_repository.dart';
import '../../../locations/data/models/location_model.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository());

final currentProfileProvider = StreamProvider<ProfileModel?>((ref) async* {
  final userId = SupabaseService.currentUserId;
  if (userId == null) {
    yield null;
    return;
  }

  final repository = ref.watch(profileRepositoryProvider);

  // Emit immediately
  final initial = await repository.getProfile(userId);
  yield initial is Success<ProfileModel> ? initial.data : null;

  // Then poll periodically for changes
  yield* Stream.periodic(const Duration(seconds: 30)).asyncMap((_) async {
    final result = await repository.getProfile(userId);
    return result is Success<ProfileModel> ? result.data : null;
  });
});

final profileControllerProvider = Provider((ref) {
  return ProfileController(
    ref.watch(profileRepositoryProvider),
    ref,
  );
});

class ProfileController {
  final ProfileRepository _repository;
  final Ref _ref;

  ProfileController(this._repository, this._ref);

  Future<bool> updateProfile({
    String? username,
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    final result = await _repository.updateProfile(
      userId: userId,
      username: username,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );

    if (result is Success) {
      _ref.invalidate(currentProfileProvider);
      _ref.invalidate(authStateProvider);
      return true;
    }
    
    if (result is Failure) {
      debugPrint('🔴 Profile update failed: ${(result as Failure).message}');
    }
    return false;
  }

  Future<bool> uploadAvatar(File imageFile) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    final result = await _repository.uploadAvatar(userId, imageFile);

    if (result is Success) {
      _ref.invalidate(authStateProvider);
      _ref.invalidate(currentProfileProvider);
      return true;
    }
    return false;
  }

  Future<List<ProfileModel>> searchProfiles(String query) async {
    final result = await _repository.searchProfiles(query);
    return result is Success<List<ProfileModel>> ? result.data : [];
  }

  Future<bool> deleteProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    final result = await _repository.deleteProfile(userId);

    if (result is Success) {
      // Sign out the user after deletion
      await SupabaseService.instance.auth.signOut();
      _ref.invalidate(authStateProvider);
      _ref.invalidate(currentProfileProvider);
      return true;
    }
    return false;
  }

  Future<bool> updateAddress({
    String? locationId, // Null if creating new location
    required String streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    required String country,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      debugPrint('🔴 Cannot update address: user not logged in');
      return false;
    }

    try {
      final locationsRepo = LocationsRepository();

      if (locationId != null) {
        // Update existing location
        debugPrint('🔵 Updating existing location: $locationId');
        final result = await locationsRepo.updateLocation(
          locationId,
          streetAddress: streetAddress,
          city: city,
          stateProvince: stateProvince,
          postalCode: postalCode,
          country: country,
        );

        if (result is Failure<LocationModel>) {
          debugPrint('🔴 Failed to update location: ${result.message}');
          return false;
        }

        debugPrint('✅ Location updated successfully');
      } else {
        // Create new location
        debugPrint('🔵 Creating new location for user: $userId');
        final result = await locationsRepo.createLocation(
          profileId: userId,
          streetAddress: streetAddress,
          city: city,
          stateProvince: stateProvince,
          postalCode: postalCode,
          country: country,
          label: null, // Auto-generated from profile name
          isPrimary: true,
        );

        if (result is Success<LocationModel>) {
          // Update profile to reference this location as primary
          debugPrint('🔵 Linking location to profile as primary: ${result.data.id}');
          final updateProfileResult = await _repository.updatePrimaryLocation(
            userId: userId,
            locationId: result.data.id,
          );

          if (updateProfileResult is Failure<ProfileModel>) {
            debugPrint('🔴 Failed to link primary location: ${updateProfileResult.message}');
            return false;
          }

          debugPrint('✅ Location created and linked successfully');
        } else {
          debugPrint('🔴 Failed to create location');
          return false;
        }
      }

      _ref.invalidate(currentProfileProvider);
      return true;
    } catch (e) {
      debugPrint('🔴 Address update exception: $e');
      return false;
    }
  }
}
