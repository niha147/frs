import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/data/models/class_session_model.dart';
import 'package:smart_frs/data/repositories/class_repository.dart';

final classRepositoryProvider = Provider<ClassRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ClassRepository(dio);
});

class ClassListNotifier extends AsyncNotifier<List<ClassSessionModel>> {
  late ClassRepository _repo;

  @override
  Future<List<ClassSessionModel>> build() async {
    _repo = ref.watch(classRepositoryProvider);
    return await _repo.getClassSessions();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getClassSessions());
  }

  Future<void> addClassSession(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.createClassSession(data);
      return await _repo.getClassSessions();
    });
  }

  Future<void> deleteClassSession(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteClassSession(id);
      return await _repo.getClassSessions();
    });
  }
}

final classListProvider = AsyncNotifierProvider<ClassListNotifier, List<ClassSessionModel>>(() {
  return ClassListNotifier();
});
