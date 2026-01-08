import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Structured error logging service for consistent error handling across the app.
///
/// This service handles:
/// - Development logging (console/debugPrint)
/// - Production error tracking (developer.log)
/// - Proper stack trace preservation
/// - Context-aware error information
/// - Additional metadata attachment
class ErrorLoggerService {
  static const String _appName = 'PokerManager';

  /// Log errors with proper context, stack trace, and metadata.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await loadGames();
  /// } catch (e, st) {
  ///   ErrorLoggerService.logError(
  ///     e,
  ///     st,
  ///     context: 'gamesProvider',
  ///     additionalData: {'userId': userId, 'groupId': groupId},
  ///   );
  /// }
  /// ```
  static void logError(
    Object error,
    StackTrace stackTrace, {
    required String context,
    Map<String, dynamic>? additionalData,
  }) {
    // Note: errorInfo structure is prepared for future error tracking service integration
    // Currently all error information is logged via developer.log and debugPrint

    // Development: Console logging with full context
    if (kDebugMode) {
      debugPrint('');
      debugPrint('═══════════════════════════════════════');
      debugPrint('❌ ERROR [$context]');
      debugPrint('───────────────────────────────────────');
      debugPrint('Error: $error');
      debugPrint('Type: ${error.runtimeType}');
      if (additionalData != null && additionalData.isNotEmpty) {
        debugPrint('Data:');
        additionalData.forEach((key, value) {
          debugPrint('  $key: $value');
        });
      }
      debugPrint('───────────────────────────────────────');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('═══════════════════════════════════════');
      debugPrint('');
    }

    // Production: Send to error tracking service
    developer.log(
      'Error: $error',
      name: '$_appName/$context',
      error: error,
      stackTrace: stackTrace,
      level: 1000, // SEVERE level
    );

    // TODO: In production, send to error tracking service:
    // - Sentry.captureException(error, stackTrace: stackTrace);
    // - Firebase Crashlytics
    // - Custom analytics service
  }

  /// Log warnings for non-critical issues.
  ///
  /// Example:
  /// ```dart
  /// if (unexpectedCondition) {
  ///   ErrorLoggerService.logWarning(
  ///     'Unexpected game state',
  ///     context: 'gameDetailScreen',
  ///   );
  /// }
  /// ```
  static void logWarning(String message, {String? context}) {
    // Suppressed: Only log errors globally
    return;
  }

  /// Log info for important events (data loaded, action completed, etc).
  ///
  /// Example:
  /// ```dart
  /// ErrorLoggerService.logInfo(
  ///   'Games loaded successfully',
  ///   context: 'gamesProvider',
  /// );
  /// ```
  static void logInfo(String message, {String? context}) {
    // Suppressed: Only log errors globally
    return;
  }

  /// Log debug messages (only in debug mode).
  ///
  /// Example:
  /// ```dart
  /// ErrorLoggerService.logDebug(
  ///   'Fetching games...',
  ///   context: 'gamesProvider',
  /// );
  /// ```
  static void logDebug(String message, {String? context}) {
    // Suppressed: Only log errors globally
    return;
  }

  /// Format error message for user display (removes technical details).
  ///
  /// Example:
  /// ```dart
  /// showSnackBar(
  ///   ErrorLoggerService.getUserFriendlyMessage(error),
  /// );
  /// ```
  static String getUserFriendlyMessage(Object error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('timeout')) {
      return 'Network connection error. Please check your internet connection.';
    }

    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Your session has expired. Please sign in again.';
    }

    if (errorStr.contains('forbidden') || errorStr.contains('403')) {
      return 'You do not have permission to perform this action.';
    }

    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'The requested item was not found.';
    }

    if (errorStr.contains('validation') || errorStr.contains('invalid')) {
      return 'Invalid input. Please check your data and try again.';
    }

    if (errorStr.contains('duplicate') || errorStr.contains('already exists')) {
      return 'This item already exists.';
    }

    // Generic fallback
    return 'An unexpected error occurred. Please try again.';
  }
}
