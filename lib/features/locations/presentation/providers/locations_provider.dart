import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/location_model.dart';
import '../../data/repositories/locations_repository.dart';
import '../../../../core/services/error_logger_service.dart';

final locationsRepositoryProvider =
    Provider((ref) => LocationsRepository());

/// Get all locations for a group
final groupLocationsProvider = FutureProvider.family<List<LocationModel>, String>(
  (ref, groupId) async {
    try {
      final repository = ref.watch(locationsRepositoryProvider);
      final result = await repository.getGroupLocations(groupId);
      return result.when(
        success: (data) {
          ErrorLoggerService.logDebug(
            'Loaded ${data.length} locations for group',
            context: 'groupLocationsProvider',
          );
          return data;
        },
        failure: (error, _) {
          ErrorLoggerService.logWarning(
            'Failed to load group locations: $error',
            context: 'groupLocationsProvider',
          );
          throw Exception(error);
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'groupLocationsProvider',
        additionalData: {'groupId': groupId},
      );
      rethrow;
    }
  },
);

/// Get all locations for a profile
final profileLocationsProvider =
    FutureProvider.family<List<LocationModel>, String>(
  (ref, profileId) async {
    try {
      final repository = ref.watch(locationsRepositoryProvider);
      final result = await repository.getProfileLocations(profileId);
      return result.when(
        success: (data) {
          ErrorLoggerService.logDebug(
            'Loaded ${data.length} locations for profile',
            context: 'profileLocationsProvider',
          );
          return data;
        },
        failure: (error, _) {
          ErrorLoggerService.logWarning(
            'Failed to load profile locations: $error',
            context: 'profileLocationsProvider',
          );
          throw Exception(error);
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'profileLocationsProvider',
        additionalData: {'profileId': profileId},
      );
      rethrow;
    }
  },
);

/// Get locations for a profile within a specific group context
final groupMemberLocationsProvider =
    FutureProvider.family<List<LocationModel>, (String, String)>(
  (ref, params) async {
    try {
      final (groupId, profileId) = params;
      final repository = ref.watch(locationsRepositoryProvider);
      final result =
          await repository.getGroupMemberLocations(groupId, profileId);
      return result.when(
        success: (data) {
          ErrorLoggerService.logDebug(
            'Loaded ${data.length} locations for group member',
            context: 'groupMemberLocationsProvider',
          );
          return data;
        },
        failure: (error, _) {
          ErrorLoggerService.logWarning(
            'Failed to load group member locations: $error',
            context: 'groupMemberLocationsProvider',
          );
          throw Exception(error);
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'groupMemberLocationsProvider',
      );
      rethrow;
    }
  },
);

/// Get a single location by ID
final locationDetailProvider =
    FutureProvider.family<LocationModel, String>(
  (ref, locationId) async {
    try {
      final repository = ref.watch(locationsRepositoryProvider);
      final result = await repository.getLocation(locationId);
      return result.when(
        success: (data) {
          ErrorLoggerService.logDebug(
            'Loaded location: ${data.label ?? data.streetAddress}',
            context: 'locationDetailProvider',
          );
          return data;
        },
        failure: (error, _) {
          ErrorLoggerService.logWarning(
            'Failed to load location: $error',
            context: 'locationDetailProvider',
          );
          throw Exception(error);
        },
      );
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'locationDetailProvider',
        additionalData: {'locationId': locationId},
      );
      rethrow;
    }
  },
);

/// Notifier for managing location creation
class CreateLocationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> createLocation({
    String? groupId,
    String? profileId,
    required String streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    required String country,
    String? label,
    bool isPrimary = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(locationsRepositoryProvider);
      
      ErrorLoggerService.logDebug(
        'Creating location: ${label ?? streetAddress}',
        context: 'CreateLocationNotifier',
      );

      final result = await repository.createLocation(
        groupId: groupId,
        profileId: profileId,
        streetAddress: streetAddress,
        city: city,
        stateProvince: stateProvince,
        postalCode: postalCode,
        country: country,
        label: label,
        isPrimary: isPrimary,
      );

      state = result.when(
        success: (_) {
          ErrorLoggerService.logInfo(
            'Location created: ${label ?? streetAddress}',
            context: 'CreateLocationNotifier',
          );
          return const AsyncValue.data(null);
        },
        failure: (error, _) {
          ErrorLoggerService.logWarning(
            'Location creation failed: $error',
            context: 'CreateLocationNotifier',
          );
          return AsyncValue.error(Exception(error), StackTrace.current);
        },
      );

      // Invalidate related providers to refresh data
      if (groupId != null) {
        ref.invalidate(groupLocationsProvider(groupId));
      }
      if (profileId != null) {
        ref.invalidate(profileLocationsProvider(profileId));
      }
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'CreateLocationNotifier',
        additionalData: {'label': label, 'streetAddress': streetAddress},
      );
      state = AsyncValue.error(e, st);
    }
  }
}

final createLocationNotifierProvider =
    NotifierProvider<CreateLocationNotifier, AsyncValue<void>>(
  CreateLocationNotifier.new,
);

/// Notifier for managing location updates
class UpdateLocationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> updateLocation(
    String locationId, {
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? country,
    String? label,
    bool? isPrimary,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(locationsRepositoryProvider);
      
      ErrorLoggerService.logDebug(
        'Updating location: $locationId',
        context: 'UpdateLocationNotifier',
      );

      final result = await repository.updateLocation(
        locationId,
        streetAddress: streetAddress,
        city: city,
        stateProvince: stateProvince,
        postalCode: postalCode,
        country: country,
        label: label,
        isPrimary: isPrimary,
      );

      state = result.when(
        success: (_) {
          ErrorLoggerService.logInfo(
            'Location updated: $locationId',
            context: 'UpdateLocationNotifier',
          );
          return const AsyncValue.data(null);
        },
        failure: (error, _) {
          ErrorLoggerService.logWarning(
            'Location update failed: $error',
            context: 'UpdateLocationNotifier',
          );
          return AsyncValue.error(Exception(error), StackTrace.current);
        },
      );

      // Invalidate location detail to refresh
      ref.invalidate(locationDetailProvider(locationId));
    } catch (e, st) {
      ErrorLoggerService.logError(
        e,
        st,
        context: 'UpdateLocationNotifier',
        additionalData: {'locationId': locationId},
      );
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setLocationAsPrimary(
    String locationId,
    String profileId,
    String? groupId,
  ) async {
    final repository = ref.read(locationsRepositoryProvider);
    final result =
        await repository.setLocationAsPrimary(locationId, profileId, groupId);

    result.when(
      success: (_) {
        // Invalidate related providers
        if (groupId != null) {
          ref.invalidate(groupLocationsProvider(groupId));
        }
        ref.invalidate(profileLocationsProvider(profileId));
        ref.invalidate(locationDetailProvider(locationId));
      },
      failure: (error, _) => state = AsyncValue.error(error, StackTrace.current),
    );
  }
}

final updateLocationNotifierProvider =
    NotifierProvider<UpdateLocationNotifier, AsyncValue<void>>(
  UpdateLocationNotifier.new,
);

/// Notifier for managing location deletion
class DeleteLocationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> deleteLocation(
    String locationId, {
    String? groupId,
    String? profileId,
  }) async {
    state = const AsyncValue.loading();
    final repository = ref.read(locationsRepositoryProvider);
    final result = await repository.deleteLocation(locationId);

    state = result.when(
      success: (_) => const AsyncValue.data(null),
      failure: (error, _) => AsyncValue.error(error, StackTrace.current),
    );

    // Invalidate related providers
    if (groupId != null) {
      ref.invalidate(groupLocationsProvider(groupId));
    }
    if (profileId != null) {
      ref.invalidate(profileLocationsProvider(profileId));
    }
  }
}

final deleteLocationNotifierProvider =
    NotifierProvider<DeleteLocationNotifier, AsyncValue<void>>(
  DeleteLocationNotifier.new,
);
