class ClassSessionModel {
  final int id;
  final int subjectId;
  final String subjectName;
  final String subjectCode;
  final String classroom;
  final String scheduledStart;
  final String scheduledEnd;
  final String status;

  ClassSessionModel({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.classroom,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.status,
  });

  factory ClassSessionModel.fromJson(Map<String, dynamic> json) {
    return ClassSessionModel(
      id: json['id'] as int,
      subjectId: json['subject_id'] as int,
      subjectName: json['subject_name'] as String? ?? '',
      subjectCode: json['subject_code'] as String? ?? '',
      classroom: json['classroom'] as String,
      scheduledStart: json['scheduled_start'] as String,
      scheduledEnd: json['scheduled_end'] as String,
      status: json['status'] as String? ?? 'scheduled',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'classroom': classroom,
      'scheduled_start': scheduledStart,
      'scheduled_end': scheduledEnd,
    };
  }
}
