import 'package:meta/meta.dart';

@immutable
abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  LoginRequested({required this.email, required this.password});
}

class RegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String username;

  RegisterRequested({required this.email, required this.password, required this.username});
}

class LogoutRequested extends AuthEvent {}

class GoogleSignInRequested extends AuthEvent {
  final String token;
  GoogleSignInRequested({required this.token});
}

class TOTPVerifyRequested extends AuthEvent {
  final String email;
  final String code;
  TOTPVerifyRequested({required this.email, required this.code});
}
