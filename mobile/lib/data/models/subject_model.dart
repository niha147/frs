class SubjectModel {
  final int id;
  final String name;
  final String code;
  final String department;
  final int year;
  final String section;
  final String? facultyId;
  final String? facultyName;

  SubjectModel({
    required this.id,
    required this.name,
    required this.code,
    required this.department,
    required this.year,
    required this.section,
    this.facultyId,
    this.facultyName,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      department: json['department'] as String,
      year: json['year'] as int,
      section: json['section'] as String,
      facultyId: json['faculty_id'] as String?,
      facultyName: json['faculty_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'department': department,
      'year': year,
      'section': section,
      'faculty_id': facultyId,
    };
  }
}
