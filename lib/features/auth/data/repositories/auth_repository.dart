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
      // Create auth user with metadata
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

      // Create profile synchronously to ensure first/last name are saved
      try {
        final profile = await _createProfileSync(
          userId: response.user!.id,
          email: email,
          firstName: firstName,
          lastName: lastName,
          country: country,
        );
        return Success(profile);
      } catch (e) {
        developer.log('Profile creation failed: $e', name: 'AuthRepository');
        // Return user model with provided data even if profile creation fails
        // The database trigger may still create it, or user can update later
        return Success(UserModel(
          id: response.user!.id,
          email: email,
          firstName: firstName,
          lastName: lastName,
          country: country,
        ));
      }
    } catch (e) {
      developer.log('Sign up error: $e', name: 'AuthRepository');
      return Failure('Sign up failed: ${e.toString()}');
    }
  }

  Future<UserModel> _createProfileSync({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    required String country,
  }) async {
    // Check if trigger already created the profile
    final existing = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (existing != null) {
      developer.log('Profile already exists (created by trigger)', name: 'AuthRepository');
      // Update the profile with first/last name if they're empty
      if ((existing['first_name'] ?? '').isEmpty || (existing['last_name'] ?? '').isEmpty) {
        await _client
            .from('profiles')
            .update({
              'first_name': firstName,
              'last_name': lastName,
              'country': country,
            })
            .eq('id', userId);
        return UserModel(
          id: userId,
          email: email,
          firstName: firstName,
          lastName: lastName,
          country: country,
        );
      }
      return UserModel.fromJson(existing);
    }

    // Create profile explicitly
    try {
      final created = await _client
          .from('profiles')
          .insert({
            'id': userId,
            'email': email,
            'first_name': firstName,
            'last_name': lastName,
            'country': country,
          })
          .select()
          .single();

      developer.log('Profile created synchronously for user: $userId', name: 'AuthRepository');
      return UserModel.fromJson(created);
    } on PostgrestException catch (e) {
      // Duplicate key error - trigger created it
      if (e.code == '23505') {
        developer.log('Profile already exists (race with trigger)', name: 'AuthRepository');
        final profile = await _getProfile(userId);
        return profile;
      }
      rethrow;
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
