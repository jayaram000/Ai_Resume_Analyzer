import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/auth/domain/entities/user_entity.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<UserEntity>> login({required String email, required String password}) async {
    try {
      final user = await remoteDataSource.login(email, password);
      return Result.success(user);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<UserEntity>> register({required String username, required String email, required String password}) async {
    try {
      final user = await remoteDataSource.register(username, email, password);
      return Result.success(user);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<UserEntity>> getProfile() async {
    try {
      final user = await remoteDataSource.getProfile();
      return Result.success(user);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<UserEntity>> updateProfile({String? fullName, String? username, String? email}) async {
    try {
      final user = await remoteDataSource.updateProfile(fullName: fullName, username: username, email: email);
      return Result.success(user);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> forgotPassword({required String email}) async {
    try {
      await remoteDataSource.forgotPassword(email);
      return const Result.success(null);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await remoteDataSource.logout();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> isAuthenticated() async {
    try {
      final isAuth = await remoteDataSource.hasValidToken();
      return Result.success(isAuth);
    } catch (e) {
      return const Result.success(false);
    }
  }
}
