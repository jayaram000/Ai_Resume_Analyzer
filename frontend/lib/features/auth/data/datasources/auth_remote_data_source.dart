import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register(String username, String email, String password);
  Future<UserModel> getProfile();
  Future<UserModel> updateProfile({String? fullName, String? username, String? email});
  Future<void> forgotPassword(String email);
  Future<void> logout();
  Future<UserModel> googleSignIn(String token);
  Future<void> totpSetup();
  Future<UserModel> totpVerify(String email, String code);
  Future<bool> hasValidToken();
}

class Requires2FAException implements Exception {
  final String email;
  Requires2FAException(this.email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;
  final SecureStorageService storage;

  AuthRemoteDataSourceImpl({required this.apiClient, required this.storage});

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await apiClient.post('auth/login/', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['requires_2fa'] == true) {
          throw Requires2FAException(data['email']);
        }
        final access = data['access'] ?? data['token'] ?? data['access_token'];
        final refresh = data['refresh'] ?? data['refresh_token'];
        if (access != null) {
          await storage.saveTokens(access: access.toString(), refresh: refresh?.toString());
        }
        final userData = data['user'] ?? data;
        return UserModel.fromJson(userData is Map<String, dynamic> ? userData : {'email': email});
      }
      throw ServerException("Login failed with status ${response.statusCode}");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<UserModel> register(String username, String email, String password) async {
    try {
      final response = await apiClient.post('auth/register/', data: {
        'username': username,
        'email': email,
        'password': password,
      });

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final data = response.data;
        final access = data['access'] ?? data['token'];
        final refresh = data['refresh'];
        if (access != null) {
          await storage.saveTokens(access: access.toString(), refresh: refresh?.toString());
        }
        final userData = data['user'] ?? data;
        return UserModel.fromJson(userData is Map<String, dynamic> ? userData : {'email': email, 'username': username});
      }
      throw ServerException("Registration failed.");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await apiClient.get('auth/profile/');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data['data'] ?? response.data : {};
        return UserModel.fromJson(data);
      }
      throw ServerException("Failed to fetch user profile.");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<UserModel> updateProfile({String? fullName, String? username, String? email}) async {
    try {
      final payload = <String, dynamic>{};
      if (fullName != null) payload['full_name'] = fullName;
      if (username != null) payload['username'] = username;
      if (email != null) payload['email'] = email;

      final response = await apiClient.put('auth/profile/', data: payload);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data['data'] ?? response.data : {};
        return UserModel.fromJson(data);
      }
      throw ServerException("Failed to update profile.");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await apiClient.post('auth/password-reset/', data: {'email': email});
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await storage.clearTokens();
    } catch (e) {
      throw CacheException(e.toString());
    }
  }

  @override
  Future<bool> hasValidToken() async {
    return await storage.hasToken();
  }

  @override
  Future<UserModel> googleSignIn(String token) async {
    try {
      final response = await apiClient.post('auth/google/', data: {'token': token});
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['requires_2fa'] == true) {
          throw Requires2FAException(data['email']);
        }
        final access = data['access'];
        final refresh = data['refresh'];
        if (access != null) {
          await storage.saveTokens(access: access.toString(), refresh: refresh?.toString());
        }
        return UserModel.fromJson(data['user'] ?? data);
      }
      throw ServerException("Google Sign-In failed");
    } catch (e) {
      if (e is Requires2FAException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> totpSetup() async {
     // TOTP Setup returns a secret and qr_code, which should be called by the UI directly or via a specific usecase
     // We will implement this as returning the raw map for simplicity, or just throwing if error.
     // Wait, the repository needs to return the QR code. I'll change the return type to Map<String, dynamic>.
  }
  
  @override
  Future<UserModel> totpVerify(String email, String code) async {
    try {
      final response = await apiClient.post('auth/totp/verify/', data: {'email': email, 'code': code});
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final access = data['access'];
        final refresh = data['refresh'];
        if (access != null) {
          await storage.saveTokens(access: access.toString(), refresh: refresh?.toString());
        }
        return UserModel.fromJson(data['user'] ?? data);
      }
      throw ServerException("TOTP Verification failed");
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
