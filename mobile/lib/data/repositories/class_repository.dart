import 'package:dio/dio.dart';
import 'package:smart_frs/data/models/class_session_model.dart';

class ClassRepository {
  final Dio _dio;
  ClassRepository(this._dio);

  Future<List<ClassSessionModel>> getClassSessions() async {
    final response = await _dio.get('/classes');
    return (response.data as List).map((x) => ClassSessionModel.fromJson(x)).toList();
  }

  Future<ClassSessionModel> createClassSession(Map<String, dynamic> data) async {
    final response = await _dio.post('/classes', data: data);
    return ClassSessionModel.fromJson(response.data);
  }

  Future<void> deleteClassSession(int id) async {
    await _dio.delete('/classes/$id');
  }
}
