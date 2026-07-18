import 'package:dio/dio.dart';
import 'package:smart_frs/core/storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorage _storage;
  final Dio _refreshDio;

  AuthInterceptor(this._storage, this._refreshDio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // Catch 401 errors to run refresh token exchange
    if (err.response?.statusCode == 401) {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null) {
        try {
          final response = await _refreshDio.post(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
          );
          
          if (response.statusCode == 200) {
            final newAccessToken = response.data['access_token'];
            final newRefreshToken = response.data['refresh_token'];
            
            await _storage.saveAccessToken(newAccessToken);
            if (newRefreshToken != null) {
              await _storage.saveRefreshToken(newRefreshToken);
            }
            
            // Re-execute original request with new token
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccessToken';
            
            final client = Dio(BaseOptions(
              baseUrl: opts.baseUrl,
              headers: opts.headers,
              contentType: opts.contentType,
            ));
            
            final responseRetry = await client.request(
              opts.path,
              data: opts.data,
              queryParameters: opts.queryParameters,
              options: Options(method: opts.method),
            );
            
            return handler.resolve(responseRetry);
          }
        } catch (e) {
          // Token refresh failed (e.g. refresh token expired) - clear tokens
          await _storage.clearTokens();
        }
      }
    }
    super.onError(err, handler);
  }
}
