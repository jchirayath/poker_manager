import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/result.dart';
import '../models/location_model.dart';

class LocationsRepository {
  final SupabaseClient _client = SupabaseService.instance;

  /// Get all locations for a group
  Future<Result<List<LocationModel>>> getGroupLocations(String groupId) async {
    try {
      final response = await _client
          .from('locations')
          .select()
          .eq('group_id', groupId)
          .order('is_primary', ascending: false)
          .order('created_at', ascending: false);

      final locations = (response as List)
          .map((json) => LocationModel.fromJson(json))
          .toList();

      return Success(locations);
    } catch (e) {
      return Failure('Failed to load group locations: ${e.toString()}');
    }
  }

  /// Get all locations for a profile
  Future<Result<List<LocationModel>>> getProfileLocations(
      String profileId) async {
    try {
      final response = await _client
          .from('locations')
          .select()
          .eq('profile_id', profileId)
          .order('is_primary', ascending: false)
          .order('created_at', ascending: false);

      final locations = (response as List)
          .map((json) => LocationModel.fromJson(json))
          .toList();

      return Success(locations);
    } catch (e) {
      return Failure('Failed to load profile locations: ${e.toString()}');
    }
  }

  /// Get locations for a profile within a specific group context
  Future<Result<List<LocationModel>>> getGroupMemberLocations(
    String groupId,
    String profileId,
  ) async {
    try {
      final response = await _client
          .from('locations')
          .select()
          .eq('group_id', groupId)
          .eq('profile_id', profileId)
          .order('is_primary', ascending: false);

      final locations = (response as List)
          .map((json) => LocationModel.fromJson(json))
          .toList();

      return Success(locations);
    } catch (e) {
      return Failure(
          'Failed to load member locations: ${e.toString()}');
    }
  }

  /// Get a single location by ID
  Future<Result<LocationModel>> getLocation(String locationId) async {
    try {
      final response = await _client
          .from('locations')
          .select()
          .eq('id', locationId)
          .single();

      return Success(LocationModel.fromJson(response));
    } catch (e) {
      return Failure('Failed to load location: ${e.toString()}');
    }
  }

  /// Create a new location
  Future<Result<LocationModel>> createLocation({
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
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        return const Failure('User not authenticated');
      }
      
      final response = await _client
          .from('locations')
          .insert({
            'group_id': groupId,
            'profile_id': profileId,
            'street_address': streetAddress,
            'city': city,
            'state_province': stateProvince,
            'postal_code': postalCode,
            'country': country,
            'label': label,
            'is_primary': isPrimary,
            'created_by': currentUser.id,
          })
          .select()
          .single();

      return Success(LocationModel.fromJson(response));
    } catch (e) {
      return Failure('Failed to create location: ${e.toString()}');
    }
  }

  /// Update an existing location
  Future<Result<LocationModel>> updateLocation(
    String locationId, {
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? country,
    String? label,
    bool? isPrimary,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (streetAddress != null) updates['street_address'] = streetAddress;
      if (city != null) updates['city'] = city;
      if (stateProvince != null) updates['state_province'] = stateProvince;
      if (postalCode != null) updates['postal_code'] = postalCode;
      if (country != null) updates['country'] = country;
      if (label != null) updates['label'] = label;
      if (isPrimary != null) updates['is_primary'] = isPrimary;

      final response = await _client
          .from('locations')
          .update(updates)
          .eq('id', locationId)
          .select()
          .single();

      return Success(LocationModel.fromJson(response));
    } catch (e) {
      return Failure('Failed to update location: ${e.toString()}');
    }
  }

  /// Delete a location
  Future<Result<void>> deleteLocation(String locationId) async {
    try {
      await _client.from('locations').delete().eq('id', locationId);

      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete location: ${e.toString()}');
    }
  }

  /// Set a location as primary and unset others for the same profile/group
  Future<Result<void>> setLocationAsPrimary(
    String locationId,
    String profileId,
    String? groupId,
  ) async {
    try {
      // First, unset all other primary locations for this profile/group
      if (groupId != null) {
        await _client
            .from('locations')
            .update({'is_primary': false})
            .eq('group_id', groupId)
            .eq('profile_id', profileId)
            .neq('id', locationId);
      } else {
        // For profile-only locations (group_id is null), use raw SQL or alternate method
        // Using a filter with null check via query
        final response = await _client
          .from('locations')
          .select('id')
          .eq('profile_id', profileId)
          .not('group_id', 'is', null);
        
        for (final location in response as List) {
          await _client
            .from('locations')
            .update({'is_primary': false})
            .eq('id', location['id']);
        }
      }

      // Then set this location as primary
      await _client
          .from('locations')
          .update({'is_primary': true})
          .eq('id', locationId);

      return const Success(null);
    } catch (e) {
      return Failure('Failed to set primary location: ${e.toString()}');
    }
  }
}
