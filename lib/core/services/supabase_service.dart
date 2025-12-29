import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  static SupabaseClient get instance => client;

  static User? get currentUser => client.auth.currentUser;

  static String? get currentUserId => currentUser?.id;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static bool get isAuthenticated => currentUser != null;
}
