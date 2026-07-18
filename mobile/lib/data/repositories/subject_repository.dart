import 'package:dio/dio.dart';
import 'package:smart_frs/data/models/subject_model.dart';

class SubjectRepository {
  final Dio _dio;
  SubjectRepository(this._dio);

  Future<List<SubjectModel>> getSubjects() async {
    final response = await _dio.get('/subjects');
    return (response.data as List).map((x) => SubjectModel.fromJson(x)).toList();
  }

  Future<SubjectModel> createSubject(Map<String, dynamic> data) async {
    final response = await _dio.post('/subjects', data: data);
    return SubjectModel.fromJson(response.data);
  }

  Future<SubjectModel> updateSubject(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/subjects/$id', data: data);
    return SubjectModel.fromJson(response.data);
  }

  Future<void> deleteSubject(int id) async {
    await _dio.delete('/subjects/$id');
  }
}
