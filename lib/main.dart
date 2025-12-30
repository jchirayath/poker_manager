import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴 Flutter Error: ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };

  // Load environment variables
  await AppConstants.loadEnv();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      observers: const [_ProviderLogger()],
      child: const PokerManagerApp(),
    ),
  );
}

class _ProviderLogger extends ProviderObserver {
  const _ProviderLogger();

  @override
  void onError(ProviderBase provider, Object error, StackTrace stackTrace) {
    debugPrint('🔴 Provider Error [${provider.name ?? 'unknown'}]: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class PokerManagerApp extends ConsumerWidget {
  const PokerManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Poker Manager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return _ErrorCatcher(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

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
    // Catch uncaught async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('🔴 Async Error: $error');
      debugPrintStack(stackTrace: stack);
      return true;
    };
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
