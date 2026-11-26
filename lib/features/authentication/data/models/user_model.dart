import 'package:equatable/equatable.dart';

/// User role in the LIQAA educational ecosystem.
enum UserRole { child, parent, specialist }

extension UserRoleLabelX on UserRole {
  String get arabicTitle => switch (this) {
    UserRole.child => 'بطل صغير',
    UserRole.parent => 'ولي أمر',
    UserRole.specialist => 'أخصائي تخاطب',
  };
}

/// User model representing an authenticated local/session user.
class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? organization;
  final UserRole role;
  final String? token;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.organization,
    this.role = UserRole.child,
    this.token,
    required this.createdAt,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? organization,
    UserRole? role,
    String? token,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      organization: organization ?? this.organization,
      role: role ?? this.role,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'organization': organization,
    'role': role.name,
    'token': token,
    'created_at': createdAt.toIso8601String(),
  };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? 'user_1',
      name: json['name'] as String? ?? 'صديق ياسر',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      organization: json['organization'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.child,
      ),
      token: json['token'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    organization,
    role,
    token,
    createdAt,
  ];
}
