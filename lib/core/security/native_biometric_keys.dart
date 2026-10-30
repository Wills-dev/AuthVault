import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/auth/domain/entities/pending_attempt.dart';
import '../../features/auth/domain/repositories/biometric_keys.dart';
export '../../features/auth/domain/repositories/biometric_keys.dart';

class AndroidBiometricKeys implements BiometricKeys {
  const AndroidBiometricKeys({
    this.channel = const MethodChannel('authvault/biometric_keys'),
  });
  final MethodChannel channel;
  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const AuthFailure(
        'UNAVAILABLE',
        'Secure device signing is currently supported on Android only.',
      );
    }
    try {
      return Map<String, dynamic>.from(
        await channel.invokeMapMethod<String, dynamic>(method, arguments) ?? {},
      );
    } on MissingPluginException {
      throw const AuthFailure(
        'UNAVAILABLE',
        'Secure biometric signing is unavailable on this device.',
      );
    } on PlatformException catch (error) {
      throw nativeFailure(error.code);
    }
  }

  static AuthFailure nativeFailure(
    String code,
  ) => AuthFailure(code, switch (code) {
    'CANCELLED' => 'Biometric authentication was cancelled. You can try again.',
    'NOT_ENROLLED' =>
      'Add a strong fingerprint or face in Android settings before continuing.',
    'UNAVAILABLE' =>
      'Strong biometric protection is unavailable on this device.',
    'TEMPORARY_LOCKOUT' =>
      'Biometrics are temporarily locked. Wait before trying again.',
    'PERMANENT_LOCKOUT' =>
      'Unlock your device through Android settings before retrying biometrics.',
    'KEY_INVALIDATED' => 'Your device key was invalidated. Secure account recovery is required; a new key cannot bypass verification.',
    'KEY_MISSING' => 'No registered key was found on this device. Use your enrolled device; recovery is not available yet.',
    'AUTHENTICATION_FAILED' =>
      'Biometric authentication failed. No proof was accepted. Try again.',
    'BUSY' => 'A biometric operation is already in progress.',
    'HARDWARE_PROTECTION_REQUIRED' ||
    'UNSAFE_KEY' => 'This device cannot provide the required key protection.',
    _ => 'The secure device-key operation could not be completed. Try again.',
  });
  @override
  Future<String> capabilities() async =>
      (await _call('capabilities'))['status'] as String;
  @override
  Future<DeviceCredential> credential(
    String subjectId, {
    required bool create,
  }) async {
    final data = await _call(create ? 'create' : 'credential', {
      'subjectId': subjectId,
    });
    if (data['nonExportable'] != true || data['authPerUse'] != true) {
      throw nativeFailure('UNSAFE_KEY');
    }
    return DeviceCredential(
      id: data['credentialId'] as String,
      publicKey: data['publicKey'] as String,
      hardwareBackedReported: data['hardwareBackedReported'] as bool,
    );
  }

  @override
  Future<String> sign(
    String subjectId,
    String credentialId,
    String payload,
    String purpose,
  ) async =>
      (await _call('sign', {
            'subjectId': subjectId,
            'credentialId': credentialId,
            'payload': payload,
            'purpose': purpose,
          }))['signature']
          as String;
  @override
  Future<void> cancel() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await channel.invokeMethod<void>('cancel');
    } on PlatformException {
      /* Fail closed. */
    } on MissingPluginException {
      /* No operation exists. */
    }
  }
}
