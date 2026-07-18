import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/storage/secure_storage.dart';
import 'package:smart_frs/core/network/auth_interceptor.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ServerUrlNotifier extends Notifier<String> {
  static const _key = 'server_url_key';
  SharedPreferences? _prefs;

  @override
  String build() {
    _init();
    // Default fallback to local IP
    return 'http://10.29.17.164:8000/api/v1';
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedUrl = _prefs?.getString(_key);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        state = savedUrl;
      }
    } catch (_) {}
  }

  Future<void> setUrl(String url) async {
    state = url;
    if (_prefs != null) {
      await _prefs!.setString(_key, url);
    }
  }
}

final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(() {
  return ServerUrlNotifier();
});

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

final dioProvider = Provider<Dio>((ref) {
  final secureStorage = ref.read(secureStorageProvider);
  final baseUrl = ref.watch(serverUrlProvider);

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  final refreshDio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  dio.interceptors.add(AuthInterceptor(secureStorage, refreshDio));
  
  return dio;
});
