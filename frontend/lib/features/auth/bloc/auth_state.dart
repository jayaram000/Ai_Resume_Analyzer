import 'package:meta/meta.dart';

@immutable
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final String email;
  final Map<String, dynamic> userData;

  Authenticated({required this.email, required this.userData});
}

class Unauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;

  AuthFailure({required this.message});
}
