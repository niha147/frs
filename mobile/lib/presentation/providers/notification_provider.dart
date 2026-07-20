import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationRepository(dio);
});

class NotificationNotifier extends AsyncNotifier<List<NotificationModel>> {
  late NotificationRepository _repo;

  @override
  Future<List<NotificationModel>> build() async {
    _repo = ref.watch(notificationRepositoryProvider);
    return await _repo.getNotifications();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getNotifications());
  }

  Future<void> markRead(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.markAsRead(id);
      return await _repo.getNotifications();
    });
  }
}

final notificationProvider = AsyncNotifierProvider<NotificationNotifier, List<NotificationModel>>(() {
  return NotificationNotifier();
});
