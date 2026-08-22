import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<Result<UserEntity>> login({required String email, required String password});
  Future<Result<UserEntity>> register({required String username, required String email, required String password});
  Future<Result<UserEntity>> getProfile();
  Future<Result<UserEntity>> updateProfile({String? fullName, String? username, String? email});
  Future<Result<void>> forgotPassword({required String email});
  Future<Result<void>> logout();
  Future<Result<bool>> isAuthenticated();
}
