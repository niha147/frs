import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/network/api_client.dart';
import 'package:smart_frs/data/repositories/auth_repository_impl.dart';
import 'package:smart_frs/domain/entities/user_profile.dart';
import 'package:smart_frs/domain/repositories/auth_repository.dart';
import 'package:smart_frs/core/storage/secure_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthRepositoryImpl(dio, secureStorage);
});

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(UserProfile user) => AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.unauthenticated() => AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.error(String message) => AuthState(status: AuthStatus.error, errorMessage: message);
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repo;
  late final SecureStorage _storage;

  @override
  AuthState build() {
    _repo = ref.watch(authRepositoryProvider);
    _storage = ref.watch(secureStorageProvider);
    _checkAuthStatus();
    return AuthState.initial();
  }

  Future<void> _checkAuthStatus() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      state = AuthState.unauthenticated();
      return;
    }
    
    state = AuthState.loading();
    try {
      final user = await _repo.getMe();
      state = AuthState.authenticated(user);
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  Future<void> login(String emailOrRoll, String password, {bool isStudent = false, String? deviceId}) async {
    state = AuthState.loading();
    try {
      final user = await _repo.login(emailOrRoll, password, isStudent: isStudent, deviceId: deviceId);
      state = AuthState.authenticated(user);
    } catch (e) {
      String message = "Connection error. Please try again.";
      if (e is DioException && e.response?.data != null) {
        try {
          message = e.response!.data['error']['message'] as String;
        } catch (_) {}
      } else if (e.toString().contains("400") || e.toString().contains("401")) {
        message = "Incorrect credentials.";
      }
      state = AuthState.error(message);
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    await _repo.logout();
    state = AuthState.unauthenticated();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
