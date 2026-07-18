class StudentModel {
  final String id;
  final String name;
  final String rollNumber;
  final String email;
  final String phone;
  final String department;
  final int year;
  final String section;
  final bool isFaceRegistered;
  final bool isActive;

  StudentModel({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.email,
    required this.phone,
    required this.department,
    required this.year,
    required this.section,
    required this.isFaceRegistered,
    required this.isActive,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      rollNumber: json['roll_number'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String? ?? '',
      department: json['department'] as String,
      year: json['year'] as int,
      section: json['section'] as String,
      isFaceRegistered: json['is_face_registered'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roll_number': rollNumber,
      'email': email,
      'phone': phone,
      'department': department,
      'year': year,
      'section': section,
      'is_face_registered': isFaceRegistered,
      'is_active': isActive,
    };
  }
}
