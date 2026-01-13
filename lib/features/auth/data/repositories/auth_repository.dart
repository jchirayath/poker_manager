import 'dart:developer' as developer;
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
        return const Failure('Sign in failed');
      }

      try {
        final profile = await _getProfile(response.user!.id);
        return Success(profile);
      } catch (e) {
        developer.log('Profile fetch error during sign in: $e', name: 'AuthRepository');
        // Profile doesn't exist, create a basic user model from auth data
        return Success(UserModel(
          id: response.user!.id,
          email: response.user!.email ?? email,
          firstName: '',
          lastName: '',
          country: 'United States',
        ));
      }
    } catch (e) {
      developer.log('Sign in error: $e', name: 'AuthRepository');
      return Failure('Sign in failed: ${e.toString()}');
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
      // Create auth user - the database trigger (handle_new_user) will automatically
      // create the profile using the metadata we pass here. The trigger runs with
      // SECURITY DEFINER so it bypasses RLS policies.
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
        return const Failure('Sign up failed');
      }

      developer.log('User signed up successfully: ${response.user!.id}', name: 'AuthRepository');

      // Return a user model with the data we provided
      // The profile is created by the database trigger (SECURITY DEFINER)
      // We don't try to read/write it here as the user may need email confirmation first
      return Success(UserModel(
        id: response.user!.id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        country: country,
      ));
    } catch (e) {
      developer.log('Sign up error: $e', name: 'AuthRepository');
      return Failure('Sign up failed: ${e.toString()}');
    }
  }

  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Success(null);
    } catch (e) {
      return Failure('Sign out failed: ${e.toString()}');
    }
  }

  Future<Result<void>> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const Success(null);
    } catch (e) {
      return Failure('Password reset failed: ${e.toString()}');
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
        developer.log('Error fetching profile: $e', name: 'AuthRepository');
        return null;
      }
    });
  }
}
