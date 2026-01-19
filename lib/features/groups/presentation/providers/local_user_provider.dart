import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../locations/data/repositories/locations_repository.dart';
import '../../../locations/data/models/location_model.dart';
import '../../data/repositories/groups_repository.dart';
import 'groups_provider.dart';
import '../../../../shared/models/result.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class LocalUserController {
  LocalUserController(this._profiles, this._groups, this._ref);

  final ProfileRepository _profiles;
  final GroupsRepository _groups;
  final Ref _ref;
  static const _uuid = Uuid();

  Future<Result<ProfileModel>> createLocalUser({
    required String groupId,
    required String firstName,
    required String lastName,
    String? username,
    String? email,
    String? phoneNumber,
    File? avatarFile,
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    String country = 'United States',
  }) async {
    final userId = _uuid.v4();

    final created = await _profiles.createLocalProfile(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      username: username,
      email: email,
      phoneNumber: phoneNumber,
    );

    if (created is! Success<ProfileModel>) {
      if (created is Failure<ProfileModel>) {
        return Failure(created.message, exception: created.exception);
      }
      return const Failure('Failed to create profile');
    }

    // Optional avatar upload
    if (avatarFile != null) {
      debugPrint('🔵 Uploading avatar for local user $userId');
      final avatarResult = await _profiles.uploadAvatar(userId, avatarFile);
      if (avatarResult is Success<String>) {
        debugPrint('✅ Avatar uploaded: ${avatarResult.data}');
      } else if (avatarResult is Failure<String>) {
        debugPrint('🔴 Avatar upload failed: ${avatarResult.message}');
      }
    }

    // Optional address creation
    if (streetAddress != null && streetAddress.trim().isNotEmpty) {
      debugPrint('🔵 Creating address for local user $userId');
      final locationsRepo = LocationsRepository();
      final locationResult = await locationsRepo.createLocation(
        profileId: userId,
        streetAddress: streetAddress,
        city: city,
        stateProvince: stateProvince,
        postalCode: postalCode,
        country: country,
        label: null, // Auto-generated
        isPrimary: true,
      );

      if (locationResult is Success<LocationModel>) {
        debugPrint('🔵 Linking location to profile: ${locationResult.data.id}');
        final updateResult = await _profiles.updatePrimaryLocation(
          userId: userId,
          locationId: locationResult.data.id,
        );

        if (updateResult is Success<ProfileModel>) {
          debugPrint('✅ Address created and linked successfully');
        } else if (updateResult is Failure<ProfileModel>) {
          debugPrint('🔴 Failed to link address: ${updateResult.message}');
        }
      } else if (locationResult is Failure<LocationModel>) {
        debugPrint('🔴 Address creation failed: ${locationResult.message}');
      }
    }

    final addMemberResult = await _groups.addMember(groupId: groupId, userId: userId);
    if (addMemberResult is Failure) {
      return Failure(addMemberResult.message, exception: addMemberResult.exception);
    }

    _ref.invalidate(groupMembersProvider(groupId));
    return created;
  }

  Future<Result<void>> updateLocalUser({
    required String groupId,
    required String userId,
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    String? phoneNumber,
    File? avatarFile,
    String? locationId,
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    String country = 'United States',
  }) async {
    // Upload avatar first if provided
    if (avatarFile != null) {
      debugPrint('Uploading avatar for local user $userId');
      final avatarResult = await _profiles.uploadAvatar(userId, avatarFile);
      if (avatarResult is Success<String>) {
        debugPrint('Avatar uploaded: ${avatarResult.data}');
      } else if (avatarResult is Failure<String>) {
        debugPrint('Avatar upload failed: ${avatarResult.message}');
      }
    }

    // Handle address if provided
    if (streetAddress != null && streetAddress.trim().isNotEmpty) {
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
        } else {
          debugPrint('✅ Location updated successfully');
        }
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
          label: null,
          isPrimary: true,
        );

        if (result is Success<LocationModel>) {
          // Update profile to reference this location as primary
          debugPrint('🔵 Linking location to profile as primary: ${result.data.id}');
          final updateProfileResult = await _profiles.updatePrimaryLocation(
            userId: userId,
            locationId: result.data.id,
          );

          if (updateProfileResult is Failure<ProfileModel>) {
            debugPrint('🔴 Failed to link primary location: ${updateProfileResult.message}');
          } else {
            debugPrint('✅ Location created and linked successfully');
          }
        } else {
          debugPrint('🔴 Failed to create location');
        }
      }
    }

    // Update profile with all other fields
    debugPrint('Updating profile for local user $userId');
    final updateResult = await _profiles.updateProfile(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      username: username,
    );

    if (updateResult is Failure<ProfileModel>) {
      debugPrint('🔴 Profile update failed: ${updateResult.message}');
      return Failure(updateResult.message, exception: updateResult.exception);
    }

    debugPrint('✅ Local user updated successfully');
    _ref.invalidate(groupMembersProvider(groupId));
    return const Success(null);
  }
}

final localUserControllerProvider = Provider((ref) {
  return LocalUserController(
    ref.watch(profileRepositoryProvider),
    ref.watch(groupsRepositoryProvider),
    ref,
  );
});
