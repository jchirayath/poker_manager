import '../../locations/data/models/location_model.dart';

/// Resolves the location display text from a stored location value
/// 
/// If the location is a UUID (old format), looks it up in the locations list
/// and returns the label or full address. Otherwise returns the location string as-is.
String? resolveLocationDisplay(String? location, List<LocationModel> locations) {
  if (location == null || location.isEmpty) {
    return null;
  }

  // Check if location looks like a UUID (contains hyphens and is 36 chars)
  final isUuid = location.length == 36 && location.contains('-');
  
  if (isUuid) {
    // Look up the location by ID
    try {
      final foundLocation = locations.firstWhere(
        (loc) => loc.id == location,
        orElse: () => throw Exception('Location not found'),
      );
      return foundLocation.label ?? foundLocation.fullAddress;
    } catch (e) {
      // Location not found, return null or the ID
      return null;
    }
  }
  
  // Already a readable address
  return location;
}
