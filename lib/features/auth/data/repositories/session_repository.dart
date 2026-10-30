import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/session_credentials.dart';
import '../../domain/entities/pending_attempt.dart';
import 'api_auth_repository.dart';

abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  static const key = 'authvault.refresh.v1';
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String token) => storage.write(key: key, value: token);
  @override
  Future<void> clear() => storage.delete(key: key);
}

class SessionRepository {
  SessionRepository(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
    String? pendingToken,
    String? accessToken,
  }) async {
    try {
      final response = await dio.request<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(
          method: data == null ? 'GET' : 'POST',
          headers: {
            'X-MFA-Token': ?pendingToken,
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      return response.data ?? {};
    } on DioException catch (e) {
      final body = e.response?.data;
      final envelope = body is Map ? body['error'] : null;
      final code = envelope is Map ? envelope['code'] : null;
      const messages = {
        'SESSION_INVALID': 'Your session ended. Please sign in again.',
        'OTP_INVALID':
            'That code is invalid. Check the six digits and try again.',
        'OTP_EXPIRED': 'This code has expired. Request a new code.',
        'OTP_EXHAUSTED':
            'Too many incorrect codes. Try signing in again in 15 minutes.',
        'OTP_LOCKED':
            'Too many incorrect codes. Try signing in again in 15 minutes.',
        'OTP_COOLDOWN': 'Please wait before requesting another code.',
        'OTP_SEND_LIMIT':
            'Code request limit reached. Please start a new sign-in.',
        'EMAIL_UNAVAILABLE':
            'The email provider could not accept your code. Please try again.',
      };
      if (messages.containsKey(code)) {
        throw AuthFailure(code as String, messages[code]!);
      }
      throw ApiAuthRepository.mapFailure(e);
    }
  }

  SessionCredentials _credentials(Map<String, dynamic> data) =>
      SessionCredentials(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        accessExpiresAt: DateTime.parse(data['accessExpiresAt'] as String),
        sessionExpiresAt: DateTime.parse(data['sessionExpiresAt'] as String),
      );
  OtpChallenge _challenge(Map<String, dynamic> data) => OtpChallenge(
    data['challengeId'] as String,
    DateTime.parse(data['expiresAt'] as String),
    DateTime.parse(data['resendAt'] as String),
  );
  Future<SessionCredentials> refresh(String token) async => _credentials(
    await request('/auth/refresh', data: {'refreshToken': token}),
  );
  Future<void> logout(String token) async {
    await request('/auth/logout', data: {'refreshToken': token});
  }

  Future<OtpChallenge> send(PendingAttempt attempt) async => _challenge(
    await request(
      '/otp/send',
      data: {'attemptId': attempt.id},
      pendingToken: attempt.token,
    ),
  );
  Future<SessionCredentials> verify(
    PendingAttempt attempt,
    String challenge,
    String code,
  ) async => _credentials(
    await request(
      '/otp/verify',
      data: {'attemptId': attempt.id, 'challengeId': challenge, 'code': code},
      pendingToken: attempt.token,
    ),
  );
}
