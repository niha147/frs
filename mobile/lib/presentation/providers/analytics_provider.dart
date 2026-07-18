import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';

class DefaulterModel {
  final String studentId;
  final String name;
  final String rollNumber;
  final String department;
  final int year;
  final String section;
  final double attendancePercentage;
  final double riskScore;
  final int bunkFlagsCount;

  DefaulterModel({
    required this.studentId,
    required this.name,
    required this.rollNumber,
    required this.department,
    required this.year,
    required this.section,
    required this.attendancePercentage,
    required this.riskScore,
    required this.bunkFlagsCount,
  });

  factory DefaulterModel.fromJson(Map<String, dynamic> json) {
    return DefaulterModel(
      studentId: json['student_id'] as String,
      name: json['name'] as String,
      rollNumber: json['roll_number'] as String,
      department: json['department'] as String,
      year: json['year'] as int,
      section: json['section'] as String,
      attendancePercentage: (json['attendance_percentage'] as num).toDouble(),
      riskScore: (json['risk_score'] as num).toDouble(),
      bunkFlagsCount: json['bunk_flags_count'] as int? ?? 0,
    );
  }
}

class TrendModel {
  final String label;
  final double percentage;

  TrendModel({required this.label, required this.percentage});

  factory TrendModel.fromJson(Map<String, dynamic> json) {
    return TrendModel(
      label: (json['date_str'] ?? json['month_str']) as String,
      percentage: (json['attendance_percentage'] as num).toDouble(),
    );
  }
}

final defaultersProvider = FutureProvider.autoDispose<List<DefaulterModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/analytics/defaulters');
  return (response.data as List).map((x) => DefaulterModel.fromJson(x)).toList();
});

final dailyTrendsProvider = FutureProvider.autoDispose<List<TrendModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/analytics/daily');
  return (response.data as List).map((x) => TrendModel.fromJson(x)).toList();
});

final monthlyTrendsProvider = FutureProvider.autoDispose<List<TrendModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/analytics/monthly');
  return (response.data as List).map((x) => TrendModel.fromJson(x)).toList();
});
