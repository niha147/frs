class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String department;
  final String role;
  final bool isActive;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.department,
    required this.role,
    required this.isActive,
  });
}
