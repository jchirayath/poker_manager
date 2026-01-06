/// Simple sealed result type without code generation.
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Exception? exception) failure,
  }) {
    if (this is Success<T>) {
      final value = this as Success<T>;
      return success(value.data);
    }
    final value = this as Failure<T>;
    return failure(value.message, value.exception);
  }

  R maybeWhen<R>({
    R Function(T data)? success,
    R Function(String message, Exception? exception)? failure,
    required R Function() orElse,
  }) {
    if (this is Success<T>) {
      final value = this as Success<T>;
      if (success != null) {
        return success(value.data);
      }
      return orElse();
    }
    if (this is Failure<T>) {
      final value = this as Failure<T>;
      if (failure != null) {
        return failure(value.message, value.exception);
      }
      return orElse();
    }
    return orElse();
  }

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
}

class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

class Failure<T> extends Result<T> {
  const Failure(this.message, {this.exception});
  final String message;
  final Exception? exception;
}
