class FacultyModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String department;
  final String role;
  final bool isActive;

  FacultyModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.department,
    required this.role,
    required this.isActive,
  });

  factory FacultyModel.fromJson(Map<String, dynamic> json) {
    return FacultyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String? ?? '',
      department: json['department'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
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
