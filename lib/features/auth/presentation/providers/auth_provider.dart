import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';
import '../../../../shared/models/result.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authStateProvider = StreamProvider<UserModel?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.watchCurrentUser();
});

final authControllerProvider = Provider((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController {
  final AuthRepository _repository;

  AuthController(this._repository);

  Future<Result<UserModel>> signIn(String email, String password) async {
    return await _repository.signIn(email, password);
  }

  Future<Result<UserModel>> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String country,
  }) async {
    return await _repository.signUp(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      country: country,
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  Future<Result<void>> resetPassword(String email) async {
    return await _repository.resetPassword(email);
  }

  Future<Result<void>> updatePassword(String newPassword) async {
    return await _repository.updatePassword(newPassword);
  }
}
