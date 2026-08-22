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
