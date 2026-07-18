import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/data/models/subject_model.dart';
import 'package:smart_frs/data/repositories/subject_repository.dart';

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SubjectRepository(dio);
});

class SubjectListNotifier extends AsyncNotifier<List<SubjectModel>> {
  late final SubjectRepository _repo;

  @override
  Future<List<SubjectModel>> build() async {
    _repo = ref.watch(subjectRepositoryProvider);
    return await _repo.getSubjects();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getSubjects());
  }

  Future<void> addSubject(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.createSubject(data);
      return await _repo.getSubjects();
    });
  }

  Future<void> updateSubject(int id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateSubject(id, data);
      return await _repo.getSubjects();
    });
  }

  Future<void> deleteSubject(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteSubject(id);
      return await _repo.getSubjects();
    });
  }
}

final subjectListProvider = AsyncNotifierProvider<SubjectListNotifier, List<SubjectModel>>(() {
  return SubjectListNotifier();
});
