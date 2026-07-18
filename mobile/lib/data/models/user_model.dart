import 'package:smart_frs/domain/entities/user_profile.dart';

class UserModel extends UserProfile {
  UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.phone,
    required super.department,
    required super.role,
    required super.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('roll_number')) {
      return UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: (json['email'] ?? json['roll_number']) as String,
        phone: json['phone_number'] as String?,
        department: json['department'] as String,
        role: 'student',
        isActive: json['is_active'] as bool,
      );
    }
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      department: json['department'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'department': department,
      'role': role,
      'is_active': isActive,
    };
  }
}
