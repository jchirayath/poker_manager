/// Utilities for avatar URL handling
library;

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
