import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/security/native_biometric_keys.dart';
import '../../domain/entities/pending_attempt.dart';
import '../../domain/repositories/biometric_repository.dart';
import '../datasources/biometric_api.dart';
import 'api_auth_repository.dart';

class ApiBiometricRepository implements BiometricRepository {
  ApiBiometricRepository(this.api);
  final BiometricApi api;
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
      final body = error.response?.data;
      if (body is Map &&
          body['error'] is Map &&
          body['error']['code'] == 'BIOMETRIC_REJECTED') {
        throw const AuthFailure(
          'BIOMETRIC_REJECTED',
          'The device proof or challenge is no longer valid. Retry with a fresh sign-in attempt.',
        );
      }
      throw ApiAuthRepository.mapFailure(error);
    } on FormatException {
      throw const AuthFailure(
        'INVALID_RESPONSE',
        'Unexpected biometric response. Start again.',
      );
    } on TypeError {
      throw const AuthFailure(
        'INVALID_RESPONSE',
        'Unexpected biometric response. Start again.',
      );
    }
  }

  @override
  Future<SigningChallenge> challenge(
    PendingAttempt attempt,
    DeviceCredential credential,
  ) => _request(() async {
    final purpose = attempt.stage == PendingStage.enrolment
        ? 'ENROLMENT'
        : 'LOGIN';
    final data = await api.post(
      '/biometric/challenge',
      {
        'attemptId': attempt.id,
        'credentialId': credential.id,
        'purpose': purpose,
        'publicKey': purpose == 'ENROLMENT' ? credential.publicKey : '',
      },
      attempt.token,
      _cancel,
    );
    final payload = data['payload'] as String;
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(payload))),
    ) as Map<String, dynamic>;
    if (data['algorithm'] != 'ES256_DER' ||
        data['purpose'] != purpose ||
        data['attemptId'] != attempt.id ||
        data['subjectId'] != attempt.subjectId ||
        data['credentialId'] != credential.id ||
        decoded['protocol'] != 'authvault.biometric.v1' ||
        decoded['challengeId'] != data['challengeId'] ||
        decoded['attemptId'] != attempt.id ||
        decoded['subjectId'] != attempt.subjectId ||
        decoded['credentialId'] != credential.id ||
        decoded['purpose'] != purpose ||
        decoded['expiresAt'] != data['expiresAt']) {
      throw const FormatException();
    }
    return SigningChallenge(
      id: data['challengeId'] as String,
      payload: payload,
      purpose: purpose,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
    );
  });
  @override
  Future<PendingAttempt> prove(
    PendingAttempt attempt,
    DeviceCredential credential,
    SigningChallenge challenge,
    String signature,
  ) => _request(() async {
    final enrolment = attempt.stage == PendingStage.enrolment;
    final data = await api.post(
      enrolment ? '/biometric/enrol' : '/biometric/verify',
      {
        'attemptId': attempt.id,
        'credentialId': credential.id,
        'challengeId': challenge.id,
        'signature': signature,
      },
      attempt.token,
      _cancel,
    );
    if (data['attemptId'] != attempt.id ||
        data['subjectId'] != attempt.subjectId ||
        data['credentialId'] != credential.id ||
        data['stage'] != (enrolment ? 'ENROLMENT_COMPLETE' : 'PENDING_OTP')) {
      throw const FormatException();
    }
    return PendingAttempt(
      id: attempt.id,
      token: attempt.token,
      subjectId: attempt.subjectId,
      stage: enrolment ? PendingStage.enrolled : PendingStage.otp,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
    );
  });
}
