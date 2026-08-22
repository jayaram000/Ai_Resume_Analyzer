import 'package:frontend/core/error/failures.dart';

/// Standard Result class for usecases
class Result<T> {
  final T? data;
  final Failure? failure;

  const Result.success(this.data) : failure = null;
  const Result.failure(this.failure) : data = null;

  bool get isSuccess => failure == null;
  bool get isFailure => failure != null;
}

/// Base UseCase contract
abstract class UseCase<Type, Params> {
  Future<Result<Type>> call(Params params);
}

/// For usecases that do not require parameters
class NoParams {
  const NoParams();
}
