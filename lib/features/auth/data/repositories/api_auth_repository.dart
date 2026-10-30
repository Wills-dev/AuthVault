import 'package:dio/dio.dart';

import '../../domain/entities/pending_attempt.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.api);
  final AuthApi api;
  CancelToken _cancel = CancelToken();
  @override
  void cancel() {
    _cancel.cancel();
    _cancel = CancelToken();
  }

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw mapFailure(error);
    } on FormatException {
      throw const AuthFailure(
        'INVALID_RESPONSE',
        'The service returned an unexpected response. Try again.',
      );
    } on TypeError {
      throw const AuthFailure(
        'INVALID_RESPONSE',
        'The service returned an unexpected response. Try again.',
      );
    }
  }

  static AuthFailure mapFailure(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return const AuthFailure('CANCELLED', 'The request was cancelled.');
    }
    if (error.response == null) {
      return const AuthFailure(
        'NETWORK_ERROR',
        'Unable to reach AuthVault. Check your connection and try again.',
      );
    }
    final data = error.response?.data;
    final envelope = data is Map ? data['error'] : null;
    final code = envelope is Map ? envelope['code'] : null;
    return switch (code) {
      'INVALID_CREDENTIALS' => const AuthFailure(
        'INVALID_CREDENTIALS',
        'Email or password is incorrect.',
      ),
      'REGISTRATION_UNAVAILABLE' => const AuthFailure(
        'REGISTRATION_UNAVAILABLE',
        'Unable to create an account with these details.',
      ),
      'VALIDATION_ERROR' => const AuthFailure(
        'VALIDATION_ERROR',
        'Check your details and try again.',
      ),
      'RATE_LIMITED' => const AuthFailure(
        'RATE_LIMITED',
        'Too many attempts. Please wait before trying again.',
      ),
      'ATTEMPT_INVALID' => const AuthFailure(
        'ATTEMPT_INVALID',
        'Your sign-in attempt expired or is unavailable. Start again.',
      ),
      _ => const AuthFailure(
        'SERVICE_UNAVAILABLE',
        'AuthVault is temporarily unavailable. Please try again.',
      ),
    };
  }

  PendingAttempt _parse(Map<String, dynamic> data, {String? token}) {
    final id = data['attemptId'] as String;
    final secret = token ?? data['attemptToken'] as String;
    if (id.isEmpty || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(secret)) {
      throw const FormatException();
    }
    final stage = switch (data['stage']) {
      'PENDING_ENROLMENT' => PendingStage.enrolment,
      'PENDING_BIOMETRIC' => PendingStage.biometric,
      'ENROLMENT_COMPLETE' => PendingStage.enrolled,
      'PENDING_OTP' => PendingStage.otp,
      _ => throw const FormatException(),
    };
    return PendingAttempt(
      id: id,
      subjectId: data['subjectId'] as String?,
      token: secret,
      stage: stage,
      expiresAt: DateTime.parse(data['expiresAt'] as String).toUtc(),
    );
  }

  @override
  Future<PendingAttempt> login({
    required String email,
    required String password,
  }) => _request(
    () async => _parse(
      await api.submit('/auth/login', {
        'email': email.trim().toLowerCase(),
        'password': password,
      }, _cancel),
    ),
  );
  @override
  Future<PendingAttempt> register({
    required String fullName,
    required String email,
    required String password,
  }) => _request(
    () async => _parse(
      await api.submit('/auth/register', {
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      }, _cancel),
    ),
  );
  @override
  Future<PendingAttempt> status(PendingAttempt attempt) => _request(() async {
    final data = await api.status(attempt.id, attempt.token, _cancel);
    if (data['attemptId'] != attempt.id) throw const FormatException();
    return _parse(data, token: attempt.token);
  });
  @override
  Future<void> revoke(PendingAttempt attempt) =>
      _request(() => api.revoke(attempt.id, attempt.token, _cancel));
}
