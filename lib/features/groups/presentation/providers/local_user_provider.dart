import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/data/repositories/profile_repository.dart';
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
    String? email,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? country,
    File? avatarFile,
  }) async {
    final userId = _uuid.v4();

    final created = await _profiles.createLocalProfile(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: phoneNumber,
      streetAddress: streetAddress,
      city: city,
      stateProvince: stateProvince,
      postalCode: postalCode,
      country: country,
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
    String? email,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? country,
    File? avatarFile,
  }) async {
    // Upload avatar first if provided
    if (avatarFile != null) {
      debugPrint('🔵 Uploading avatar for local user $userId');
      final avatarResult = await _profiles.uploadAvatar(userId, avatarFile);
      if (avatarResult is Success<String>) {
        debugPrint('✅ Avatar uploaded: ${avatarResult.data}');
      } else if (avatarResult is Failure<String>) {
        debugPrint('🔴 Avatar upload failed: ${avatarResult.message}');
      }
    }

    // Update profile with all other fields
    debugPrint('🔵 Updating profile for local user $userId');
    final updateResult = await _profiles.updateProfile(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      streetAddress: streetAddress,
      city: city,
      stateProvince: stateProvince,
      postalCode: postalCode,
      country: country,
      username: null,
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
