import 'package:dio/dio.dart';
import 'package:smart_frs/data/models/student_model.dart';

class StudentRepository {
  final Dio _dio;
  StudentRepository(this._dio);

  Future<List<StudentModel>> getStudents() async {
    final response = await _dio.get('/students');
    return (response.data as List).map((x) => StudentModel.fromJson(x)).toList();
  }

  Future<StudentModel> createStudent(Map<String, dynamic> data) async {
    final response = await _dio.post('/students', data: data);
    return StudentModel.fromJson(response.data);
  }

  Future<StudentModel> updateStudent(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/students/$id', data: data);
    return StudentModel.fromJson(response.data);
  }

  Future<void> deleteStudent(String id) async {
    await _dio.delete('/students/$id');
  }
}
