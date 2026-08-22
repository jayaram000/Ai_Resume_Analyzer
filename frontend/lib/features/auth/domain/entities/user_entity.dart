class UserEntity {
  final String id;
  final String email;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool isStaff;
  final bool isPremium;

  const UserEntity({
    required this.id,
    required this.email,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.isStaff = false,
    this.isPremium = false,
  });
}
