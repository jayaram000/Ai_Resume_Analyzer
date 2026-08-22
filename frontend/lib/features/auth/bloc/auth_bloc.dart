import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/domain/usecases/auth_usecases.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/features/auth/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final isAuthResult = await authRepository.isAuthenticated();
    if (isAuthResult.data != true) {
      emit(Unauthenticated());
      return;
    }

    final profileResult = await authRepository.getProfile();
    if (profileResult.isSuccess && profileResult.data != null) {
      final user = profileResult.data!;
      emit(Authenticated(
        email: user.email,
        userData: {
          'id': user.id,
          'email': user.email,
          'username': user.username,
          'full_name': user.fullName,
          'is_staff': user.isStaff,
          'is_premium': user.isPremium,
        },
      ));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final loginUseCase = LoginUseCase(authRepository);
    final result = await loginUseCase(LoginParams(email: event.email, password: event.password));

    if (result.isSuccess && result.data != null) {
      final user = result.data!;
      emit(Authenticated(
        email: user.email,
        userData: {
          'id': user.id,
          'email': user.email,
          'username': user.username,
          'full_name': user.fullName,
          'is_staff': user.isStaff,
          'is_premium': user.isPremium,
        },
      ));
    } else {
      emit(AuthFailure(message: result.failure?.message ?? 'Invalid email or password.'));
    }
  }

  Future<void> _onRegisterRequested(RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final registerUseCase = RegisterUseCase(authRepository);
    final result = await registerUseCase(RegisterParams(
      username: event.username,
      email: event.email,
      password: event.password,
    ));

    if (result.isSuccess) {
      emit(Unauthenticated());
    } else {
      emit(AuthFailure(message: result.failure?.message ?? 'Registration failed.'));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final logoutUseCase = LogoutUseCase(authRepository);
    await logoutUseCase(const NoParams());
    emit(Unauthenticated());
  }
}
