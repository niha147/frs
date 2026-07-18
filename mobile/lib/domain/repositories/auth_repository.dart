import 'package:smart_frs/domain/entities/user_profile.dart';

abstract class AuthRepository {
  Future<UserProfile> login(String emailOrRoll, String password, {bool isStudent = false, String? deviceId});
  Future<UserProfile> getMe({bool isStudent = false});
  Future<void> logout();
}
