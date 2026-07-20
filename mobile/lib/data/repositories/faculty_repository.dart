import 'package:dio/dio.dart';
import 'package:smart_frs/data/models/faculty_model.dart';

class FacultyRepository {
  final Dio _dio;
  FacultyRepository(this._dio);

  Future<List<FacultyModel>> getFaculty() async {
    final response = await _dio.get('/faculty/');
    return (response.data as List).map((x) => FacultyModel.fromJson(x)).toList();
  }

  Future<FacultyModel> createFaculty(Map<String, dynamic> data) async {
    final response = await _dio.post('/faculty/', data: data);
    return FacultyModel.fromJson(response.data);
  }

  Future<FacultyModel> updateFaculty(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/faculty/$id', data: data);
    return FacultyModel.fromJson(response.data);
  }

  Future<void> deleteFaculty(String id) async {
    await _dio.delete('/faculty/$id');
  }
}
