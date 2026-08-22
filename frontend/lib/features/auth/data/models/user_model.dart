import 'package:frontend/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.username,
    super.fullName,
    super.avatarUrl,
    super.isStaff = false,
    super.isPremium = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['pk'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      username: (json['username'] ?? json['email'] ?? '').toString(),
      fullName: json['full_name'] ?? json['name'] ?? json['first_name'],
      avatarUrl: json['avatar_url'] ?? json['avatar'],
      isStaff: json['is_staff'] ?? false,
      isPremium: json['is_premium'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'is_staff': isStaff,
      'is_premium': isPremium,
    };
  }
}
