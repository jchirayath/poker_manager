class AppException implements Exception {
  final String message;
  final String? code;
  final Exception? innerException;

  AppException(this.message, {this.code, this.innerException});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(super.message);
}

class AuthException extends AppException {
  AuthException(super.message);
}

class ValidationException extends AppException {
  ValidationException(super.message);
}
