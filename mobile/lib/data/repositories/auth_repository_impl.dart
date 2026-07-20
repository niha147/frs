import 'package:dio/dio.dart';
import 'package:smart_frs/core/storage/secure_storage.dart';
import 'package:smart_frs/data/models/user_model.dart';
import 'package:smart_frs/domain/entities/user_profile.dart';
import 'package:smart_frs/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final SecureStorage _storage;

  AuthRepositoryImpl(this._dio, this._storage);

  @override
  Future<UserProfile> login(String emailOrRoll, String password, {bool isStudent = false, String? deviceId}) async {
    final url = isStudent ? '/student-auth/login' : '/auth/login';
    final data = isStudent 
      ? {
          'roll_number': emailOrRoll,
          'password': password,
          if (deviceId != null) 'device_id': deviceId,
        }
      : {
          'email': emailOrRoll,
          'password': password,
        };

    final response = await _dio.post(url, data: data);
    
    final accessToken = response.data['access_token'] as String;
    final refreshToken = response.data['refresh_token'] as String;
    
    await _storage.saveAccessToken(accessToken);
    await _storage.saveRefreshToken(refreshToken);
    await _storage.saveUserRole(isStudent ? 'student' : 'faculty');
    
    return await getMe(isStudent: isStudent);
  }

  @override
  Future<UserProfile> registerStudent({
    required String rollNumber,
    required String name,
    required String email,
    required String department,
    required int year,
    required String section,
    required String password,
    String? deviceId,
  }) async {
    final response = await _dio.post('/student-auth/register', data: {
      'roll_number': rollNumber,
      'name': name,
      'email': email,
      'department': department,
      'year': year,
      'section': section,
      'password': password,
      if (deviceId != null) 'device_id': deviceId,
    });

    final accessToken = response.data['access_token'] as String;
    final refreshToken = response.data['refresh_token'] as String;

    await _storage.saveAccessToken(accessToken);
    await _storage.saveRefreshToken(refreshToken);
    await _storage.saveUserRole('student');

    return await getMe(isStudent: true);
  }

  @override
  Future<UserProfile> registerFaculty({
    required String name,
    required String email,
    required String department,
    required String password,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'department': department,
      'password': password,
    });

    final accessToken = response.data['access_token'] as String;
    final refreshToken = response.data['refresh_token'] as String;

    await _storage.saveAccessToken(accessToken);
    await _storage.saveRefreshToken(refreshToken);
    await _storage.saveUserRole('faculty');

    return await getMe(isStudent: false);
  }

  @override
  Future<UserProfile> getMe({bool isStudent = false}) async {
    bool studentMode = isStudent;
    if (!isStudent) {
      final role = await _storage.getUserRole();
      if (role == 'student') {
        studentMode = true;
      }
    }
    
    final url = studentMode ? '/student-auth/me' : '/auth/me';
    final response = await _dio.get(url);
    return UserModel.fromJson(response.data);
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // Catch connection errors to force offline cleanouts
    } finally {
      await _storage.clearTokens();
    }
  }
}
