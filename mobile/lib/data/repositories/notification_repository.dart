import 'package:dio/dio.dart';

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      isRead: json['is_read'] as bool,
      createdAt: json['created_at'] as String,
    );
  }
}

class NotificationRepository {
  final Dio _dio;
  NotificationRepository(this._dio);

  Future<List<NotificationModel>> getNotifications() async {
    final response = await _dio.get('/notifications/');
    return (response.data as List).map((x) => NotificationModel.fromJson(x)).toList();
  }

  Future<void> markAsRead(int id) async {
    await _dio.post('/notifications/mark-read/$id');
  }
}
