import 'package:smart_frs/domain/entities/user_profile.dart';

abstract class AuthRepository {
  Future<UserProfile> login(String emailOrRoll, String password, {bool isStudent = false, String? deviceId});
  Future<UserProfile> registerStudent({
    required String rollNumber,
    required String name,
    required String email,
    required String department,
    required int year,
    required String section,
    required String password,
    String? deviceId,
  });
  Future<UserProfile> registerFaculty({
    required String name,
    required String email,
    required String department,
    required String password,
  });
  Future<UserProfile> getMe({bool isStudent = false});
  Future<void> logout();
}
