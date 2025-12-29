import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/result.dart';
import '../models/user_model.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseService.instance;

  Future<Result<UserModel>> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return const Result.failure('Sign in failed');
      }

      try {
        final profile = await _getProfile(response.user!.id);
        return Result.success(profile);
      } catch (e) {
        print('Profile fetch error during sign in: $e');
        // Profile doesn't exist, create a basic user model from auth data
        return Result.success(UserModel(
          id: response.user!.id,
          email: response.user!.email ?? email,
          firstName: '',
          lastName: '',
          country: 'United States',
        ));
      }
    } catch (e) {
      print('Sign in error: $e');
      return Result.failure('Sign in failed: ${e.toString()}');
    }
  }

  Future<Result<UserModel>> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String country,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'country': country,
        },
      );

      if (response.user == null) {
        return const Result.failure('Sign up failed');
      }

      // Rely on DB trigger to create profile; fetch if available
      final fetched = await _client
          .from('profiles')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();
      if (fetched != null) {
        return Result.success(UserModel.fromJson(fetched));
      }
      // Fallback: return basic model; profile will be available shortly
      return Result.success(UserModel(
        id: response.user!.id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        country: country,
      ));
    } catch (e) {
      print('Sign up error: $e');
      return Result.failure('Sign up failed: ${e.toString()}');
    }
  }

  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Sign out failed: ${e.toString()}');
    }
  }

  Future<Result<void>> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Password reset failed: ${e.toString()}');
    }
  }

  Future<UserModel> _getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (response == null) {
      // Fallback to auth user info if profile is missing
      final authUser = _client.auth.currentUser;
      return UserModel(
        id: userId,
        email: authUser?.email ?? '',
        firstName: '',
        lastName: '',
        country: 'United States',
      );
    }
    return UserModel.fromJson(response);
  }

  Stream<UserModel?> watchCurrentUser() {
    return _client.auth.onAuthStateChange.asyncMap((state) async {
      try {
        if (state.session?.user == null) return null;
        return await _getProfile(state.session!.user.id);
      } catch (e) {
        print('Error fetching profile: $e');
        return null;
      }
    });
  }
}
