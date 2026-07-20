import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/data/models/student_model.dart';
import 'package:smart_frs/data/repositories/student_repository.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return StudentRepository(dio);
});

class StudentListNotifier extends AsyncNotifier<List<StudentModel>> {
  late StudentRepository _repo;

  @override
  Future<List<StudentModel>> build() async {
    _repo = ref.watch(studentRepositoryProvider);
    return await _repo.getStudents();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getStudents());
  }

  Future<void> addStudent(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.createStudent(data);
      return await _repo.getStudents();
    });
  }

  Future<void> updateStudent(String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateStudent(id, data);
      return await _repo.getStudents();
    });
  }

  Future<void> deleteStudent(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteStudent(id);
      return await _repo.getStudents();
    });
  }
}

final studentListProvider = AsyncNotifierProvider<StudentListNotifier, List<StudentModel>>(() {
  return StudentListNotifier();
});
