import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';

class OverallAttendanceModel {
  final String studentUid;
  final String rollNumber;
  final String fullName;
  final String department;
  final int year;
  final String section;
  final int totalSessions;
  final int attendedSessions;
  final double attendancePercent;
  final String riskStatus;

  OverallAttendanceModel({
    required this.studentUid,
    required this.rollNumber,
    required this.fullName,
    required this.department,
    required this.year,
    required this.section,
    required this.totalSessions,
    required this.attendedSessions,
    required this.attendancePercent,
    required this.riskStatus,
  });

  factory OverallAttendanceModel.fromJson(Map<String, dynamic> json) {
    return OverallAttendanceModel(
      studentUid: json['student_uid'] as String,
      rollNumber: json['roll_number'] as String,
      fullName: json['full_name'] as String,
      department: json['department'] as String,
      year: json['year'] as int,
      section: json['section'] as String,
      totalSessions: json['total_sessions'] as int,
      attendedSessions: json['attended_sessions'] as int,
      attendancePercent: (json['attendance_percent'] as num).toDouble(),
      riskStatus: json['risk_status'] as String,
    );
  }
}

final overallAttendanceProvider = FutureProvider.family.autoDispose<List<OverallAttendanceModel>, Map<String, dynamic>>((ref, filters) async {
  final dio = ref.watch(dioProvider);
  
  // Clean null filters
  final cleaned = Map<String, dynamic>.from(filters)..removeWhere((key, val) => val == null);
  
  final response = await dio.get('/reports/overall-attendance', queryParameters: cleaned);
  return (response.data as List).map((x) => OverallAttendanceModel.fromJson(x)).toList();
});
