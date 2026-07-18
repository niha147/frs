import 'package:dio/dio.dart';

class AttendanceLogModel {
  final int id;
  final String studentId;
  final int classId;
  final String status;
  final String method;
  final double? confidenceScore;
  final bool isFlagged;
  final String markedAt;

  AttendanceLogModel({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.status,
    required this.method,
    this.confidenceScore,
    required this.isFlagged,
    required this.markedAt,
  });

  factory AttendanceLogModel.fromJson(Map<String, dynamic> json) {
    return AttendanceLogModel(
      id: json['id'] as int,
      studentId: json['student_id'] as String,
      classId: json['class_id'] as int,
      status: json['status'] as String,
      method: json['method'] as String,
      confidenceScore: json['confidence_score'] != null
          ? (json['confidence_score'] as num).toDouble()
          : null,
      isFlagged: json['is_flagged'] as bool? ?? false,
      markedAt: json['marked_at'] as String,
    );
  }
}

class AttendanceRepository {
  final Dio _dio;
  AttendanceRepository(this._dio);

  Future<List<AttendanceLogModel>> getClassAttendance(int classId) async {
    final response = await _dio.get('/attendance/class/$classId');
    return (response.data as List).map((x) => AttendanceLogModel.fromJson(x)).toList();
  }

  Future<void> submitManualOverride(String studentId, int classId, String status) async {
    await _dio.post('/attendance/manual', data: {
      'student_id': studentId,
      'class_id': classId,
      'status': status.toLowerCase(),
    });
  }
}
