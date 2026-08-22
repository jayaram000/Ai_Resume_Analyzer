import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:frontend/core/storage/secure_storage.dart';

class ApiClient {
  final Dio dio;
  final SecureStorageService _secureStorage;
  
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api/';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api/';
      }
    } catch (_) {}
    return 'http://localhost:8000/api/';
  }

  ApiClient(this._secureStorage) : dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Accept': 'application/json',
    },
  )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secureStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        // Automatic Refresh on 401 errors
        if (error.response?.statusCode == 401 && error.requestOptions.path != 'auth/login/') {
          final refreshToken = await _secureStorage.getRefreshToken();
          if (refreshToken != null) {
            try {
              // Attempt to refresh
              final refreshResponse = await Dio().post(
                '${baseUrl}auth/token/refresh/',
                data: {'refresh': refreshToken},
              );
              
              if (refreshResponse.statusCode == 200) {
                final access = refreshResponse.data['access'];
                final refresh = refreshResponse.data['refresh'] ?? refreshToken;
                
                await _secureStorage.saveTokens(access: access, refresh: refresh);
                
                // Retry request
                final retryOptions = error.requestOptions;
                retryOptions.headers['Authorization'] = 'Bearer $access';
                
                final response = await dio.fetch(retryOptions);
                return handler.resolve(response);
              }
            } catch (e) {
              // If refresh fails, clear token (requires user login again)
              await _secureStorage.clearTokens();
            }
          }
        }
        return handler.next(error);
      }
    ));
  }

  // Helper request wrappers
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    return await dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(String path, {dynamic data, Options? options}) async {
    return await dio.post(path, data: data, options: options);
  }

  Future<Response> put(String path, {dynamic data, Options? options}) async {
    return await dio.put(path, data: data, options: options);
  }

  Future<Response> patch(String path, {dynamic data, Options? options}) async {
    return await dio.patch(path, data: data, options: options);
  }

  Future<Response> delete(String path, {dynamic data, Options? options}) async {
    return await dio.delete(path, data: data, options: options);
  }
}
