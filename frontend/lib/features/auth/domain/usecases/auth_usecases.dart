import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/auth/domain/entities/user_entity.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';

class LoginParams {
  final String email;
  final String password;
  const LoginParams({required this.email, required this.password});
}

class LoginUseCase implements UseCase<UserEntity, LoginParams> {
  final AuthRepository repository;
  const LoginUseCase(this.repository);

  @override
  Future<Result<UserEntity>> call(LoginParams params) {
    return repository.login(email: params.email, password: params.password);
  }
}

class RegisterParams {
  final String username;
  final String email;
  final String password;
  const RegisterParams({required this.username, required this.email, required this.password});
}

class RegisterUseCase implements UseCase<UserEntity, RegisterParams> {
  final AuthRepository repository;
  const RegisterUseCase(this.repository);

  @override
  Future<Result<UserEntity>> call(RegisterParams params) {
    return repository.register(username: params.username, email: params.email, password: params.password);
  }
}

class GetProfileUseCase implements UseCase<UserEntity, NoParams> {
  final AuthRepository repository;
  const GetProfileUseCase(this.repository);

  @override
  Future<Result<UserEntity>> call(NoParams params) {
    return repository.getProfile();
  }
}

class LogoutUseCase implements UseCase<void, NoParams> {
  final AuthRepository repository;
  const LogoutUseCase(this.repository);

  @override
  Future<Result<void>> call(NoParams params) {
    return repository.logout();
  }
}
