import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/constants/app_constants.dart';

/// Application entry point
/// 
/// Initializes:
/// 1. Flutter binding and error handlers
/// 2. Environment variables from env.json
/// 3. Supabase connection
/// 4. Riverpod ProviderScope with observer
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handlers for Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴 Flutter Error: ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };

  // Load environment variables from env.json
  // Required keys: SUPABASE_URL, SUPABASE_ANON_KEY
  await AppConstants.loadEnv();

  // Initialize Supabase with URL and anonymous key
  // Used for authentication, database access, and storage
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      // Provider observer logs all provider state changes
      observers: [_ProviderLogger()],
      child: PokerManagerApp(),
    ),
  );
}

/// Riverpod ProviderObserver for debugging state management
/// 
/// Logs all provider initialization, state changes, and errors
/// to help with state management debugging.
final class _ProviderLogger extends ProviderObserver {
  const _ProviderLogger();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    // Skip logging "Game not found" errors - expected after game deletion
    final errorStr = error.toString();
    if (errorStr.contains('Game not found')) {
      return;
    }
    final providerName = context.provider.name ?? 'unknown';
    debugPrint('🔴 Provider Error [$providerName]: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

/// Main application widget
/// 
/// Configures:
/// - Material 3 theme from AppTheme (light and dark)
/// - GoRouter navigation with automatic theme detection
/// - Error catcher for uncaught async errors
class PokerManagerApp extends ConsumerWidget {
  const PokerManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appNameWithBeta,
      // Light and dark themes from centralized AppTheme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Automatically follows system theme preference
      themeMode: ThemeMode.system,
      // GoRouter configuration for navigation
      routerConfig: ref.watch(routerProvider),
      // Hide debug banner in development
      debugShowCheckedModeBanner: false,
      // Custom error handling wrapper
      builder: (context, child) {
        return _ErrorCatcher(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

/// Error catcher widget
/// 
/// Catches uncaught async errors at the platform level
/// and logs them for debugging purposes.
class _ErrorCatcher extends StatefulWidget {
  final Widget child;
  const _ErrorCatcher({required this.child});

  @override
  State<_ErrorCatcher> createState() => _ErrorCatcherState();
}

class _ErrorCatcherState extends State<_ErrorCatcher> {
  @override
  void initState() {
    super.initState();
    // Catch uncaught async errors that escape Dart error zones
    // These are platform-level errors that would otherwise crash the app
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('🔴 Async Error: $error');
      debugPrintStack(stackTrace: stack);
      return true;
    };
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
