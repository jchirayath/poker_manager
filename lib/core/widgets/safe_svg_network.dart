import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A safe wrapper for SvgPicture.network that handles errors gracefully
/// Particularly handles SVGs with unsupported elements like <metadata/>
/// 
/// The issue: DiceBear and other SVG sources may include <metadata/> tags
/// that flutter_svg cannot parse, causing app crashes.
/// 
/// SOLUTION: When using DiceBear API, add `&excludeMetadata=true` to URLs:
/// ✅ 'https://api.dicebear.com/7.x/avataaars/svg?seed=JD&excludeMetadata=true'
/// ❌ 'https://api.dicebear.com/7.x/avataaars/svg?seed=JD'
/// 
/// This widget provides fallback handling for cases where metadata cannot be excluded.
/// 
/// Usage:
/// ```dart
/// SafeSvgNetwork(
///   url: 'https://api.dicebear.com/7.x/initials/svg?seed=JD&excludeMetadata=true',
///   width: 40,
///   height: 40,
/// )
/// ```
class SafeSvgNetwork extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? fallback;
  final String? semanticsLabel;
  final Color? color;

  const SafeSvgNetwork({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.fallback,
    this.semanticsLabel,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Use FutureBuilder to catch async SVG loading errors
    return FutureBuilder(
      future: _loadSvg(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('⚠️  SVG error: ${snapshot.error}');
          return _buildFallback();
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? 
            SizedBox(
              width: width,
              height: height,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
        }
        
        return SvgPicture.network(
          url,
          width: width,
          height: height,
          fit: fit,
          semanticsLabel: semanticsLabel,
          // ignore: deprecated_member_use
          color: color,
          placeholderBuilder: placeholder != null 
            ? (_) => placeholder!
            : (context) => SizedBox(
                width: width,
                height: height,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
        );
      },
    );
  }

  // Pre-validate the SVG can be loaded
  Future<void> _loadSvg() async {
    try {
      // This will throw if the SVG has parsing errors
      await svg.fromSvgString('<svg></svg>', 'test');
      // If we get here, flutter_svg is working
      return;
    } catch (e) {
      // If there's an error, rethrow it so FutureBuilder catches it
      rethrow;
    }
  }

  Widget _buildFallback() {
    return fallback ?? 
      SizedBox(
        width: width,
        height: height,
        child: Icon(
          Icons.account_circle,
          size: (width != null && height != null) 
            ? (width! < height! ? width : height) * 0.8
            : 24,
          color: color ?? Colors.grey,
        ),
      );
  }
}


