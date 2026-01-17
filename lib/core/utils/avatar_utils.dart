/// Utilities for avatar URL handling
library;

import 'dart:math';

/// Fixes DiceBear avatar URLs to exclude metadata tags
///
/// DiceBear API v7+ includes <metadata/> tags by default which flutter_svg
/// cannot parse. This function adds &excludeMetadata=true to fix that.
///
/// Example:
/// ```dart
/// final url = 'https://api.dicebear.com/7.x/avataaars/svg?seed=JD';
/// final fixed = fixDiceBearUrl(url);
/// // Returns: 'https://api.dicebear.com/7.x/avataaars/svg?seed=JD&excludeMetadata=true'
/// ```
String? fixDiceBearUrl(String? url) {
  if (url == null || url.isEmpty) return url;

  // Check if it's a DiceBear URL
  if (!url.contains('api.dicebear.com')) return url;

  // Check if it already has the excludeMetadata parameter
  if (url.contains('excludeMetadata=true')) return url;

  // Add the parameter
  return '$url&excludeMetadata=true';
}

/// Generates a random DiceBear avatar URL for groups
///
/// Uses the 'shapes' style which is suitable for groups/organizations.
/// The seed can be a group ID, name, or any unique identifier.
/// If no seed is provided, a random one is generated.
///
/// Example:
/// ```dart
/// final url = generateGroupAvatarUrl('my-group-id');
/// // Returns: 'https://api.dicebear.com/7.x/shapes/svg?seed=my-group-id&excludeMetadata=true'
/// ```
String generateGroupAvatarUrl([String? seed]) {
  final avatarSeed = seed ?? 'group-${Random().nextInt(1000000)}';
  return 'https://api.dicebear.com/7.x/shapes/svg?seed=$avatarSeed&excludeMetadata=true';
}

/// Generates a random DiceBear avatar URL for users/profiles
///
/// Uses the 'avataaars' style which is suitable for human avatars.
/// The seed can be a user ID, name, or any unique identifier.
/// If no seed is provided, a random one is generated.
///
/// Example:
/// ```dart
/// final url = generateUserAvatarUrl('user-123');
/// // Returns: 'https://api.dicebear.com/7.x/avataaars/svg?seed=user-123&excludeMetadata=true'
/// ```
String generateUserAvatarUrl([String? seed]) {
  final avatarSeed = seed ?? 'user-${Random().nextInt(1000000)}';
  return 'https://api.dicebear.com/7.x/avataaars/svg?seed=$avatarSeed&excludeMetadata=true';
}
