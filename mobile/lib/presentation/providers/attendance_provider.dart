import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/data/repositories/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AttendanceRepository(dio);
});

final attendanceLogsProvider = FutureProvider.family.autoDispose<List<AttendanceLogModel>, int>((ref, classId) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.getClassAttendance(classId);
});
