import 'package:frontend/config.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? avatarPath;

  User({required this.id, required this.name, required this.email, required this.role, this.avatarPath});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'] ?? 'customer',
      avatarPath: json['avatar_path'],
    );
  }

  bool get isAdmin => role == 'admin';

  String get fullAvatarUrl => avatarPath != null ? '${AppConfig.storageUrl}/$avatarPath' : 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y';
}
