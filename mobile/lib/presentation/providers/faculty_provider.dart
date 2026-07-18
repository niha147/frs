import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/data/models/faculty_model.dart';
import 'package:smart_frs/data/repositories/faculty_repository.dart';

final facultyRepositoryProvider = Provider<FacultyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FacultyRepository(dio);
});

class FacultyListNotifier extends AsyncNotifier<List<FacultyModel>> {
  late final FacultyRepository _repo;

  @override
  Future<List<FacultyModel>> build() async {
    _repo = ref.watch(facultyRepositoryProvider);
    return await _repo.getFaculty();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getFaculty());
  }

  Future<void> addFaculty(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.createFaculty(data);
      return await _repo.getFaculty();
    });
  }

  Future<void> updateFaculty(String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateFaculty(id, data);
      return await _repo.getFaculty();
    });
  }

  Future<void> deleteFaculty(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteFaculty(id);
      return await _repo.getFaculty();
    });
  }
}

final facultyListProvider = AsyncNotifierProvider<FacultyListNotifier, List<FacultyModel>>(() {
  return FacultyListNotifier();
});
