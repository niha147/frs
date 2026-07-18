import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';

class SubjectSummary {
  final int subjectId;
  final String subjectName;
  final String subjectCode;
  final int totalClasses;
  final int attended;
  final double percentage;
  final String riskStatus;

  SubjectSummary({
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.totalClasses,
    required this.attended,
    required this.percentage,
    required this.riskStatus,
  });

  factory SubjectSummary.fromJson(Map<String, dynamic> json) {
    return SubjectSummary(
      subjectId: json['subject_id'] as int,
      subjectName: json['subject_name'] as String,
      subjectCode: json['subject_code'] as String,
      totalClasses: json['total_classes'] as int,
      attended: json['attended'] as int,
      percentage: (json['percentage'] as num).toDouble(),
      riskStatus: json['risk_status'] as String,
    );
  }
}

class HistoryItem {
  final int classId;
  final String subjectName;
  final String subjectCode;
  final String classroom;
  final String scheduledStart;
  final String status;
  final String method;

  HistoryItem({
    required this.classId,
    required this.subjectName,
    required this.subjectCode,
    required this.classroom,
    required this.scheduledStart,
    required this.status,
    required this.method,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      classId: json['class_id'] as int,
      subjectName: json['subject_name'] as String,
      subjectCode: json['subject_code'] as String,
      classroom: json['classroom'] as String,
      scheduledStart: json['scheduled_start'] as String,
      status: json['status'] as String,
      method: json['method'] as String,
    );
  }
}

final studentSummaryProvider = FutureProvider.autoDispose<List<SubjectSummary>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/student-auth/attendance/summary');
  final list = response.data as List;
  return list.map((item) => SubjectSummary.fromJson(item)).toList();
});

final studentHistoryProvider = FutureProvider.autoDispose<List<HistoryItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/student-auth/attendance/history');
  final list = response.data as List;
  return list.map((item) => HistoryItem.fromJson(item)).toList();
});
