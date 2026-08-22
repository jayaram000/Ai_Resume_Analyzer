abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([String message = "Server error occurred. Please try again."]) : super(message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = "No internet connection or server unreachable."]) : super(message);
}

class AuthFailure extends Failure {
  const AuthFailure([String message = "Authentication failed."]) : super(message);
}

class CacheFailure extends Failure {
  const CacheFailure([String message = "Local cache error occurred."]) : super(message);
}
