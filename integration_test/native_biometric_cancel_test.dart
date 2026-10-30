import 'dart:convert';

import 'package:authvault/core/security/native_biometric_keys.dart';
import 'package:authvault/features/auth/domain/entities/pending_attempt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Android prompt cancellation returns no signature', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Native biometric cancellation check')),
      ),
    );
    await tester.pumpAndSettle();
    const keys = AndroidBiometricKeys();
    expect(await keys.capabilities(), 'AVAILABLE');
    const subject = '11111111-1111-4111-8111-111111111111';
    final credential = await keys.credential(subject, create: true);
    expect(credential.publicKey, isNotEmpty);
    final payload = base64Url
        .encode(utf8.encode('AuthVault native cancellation test'))
        .replaceAll('=', '');
    final operation = keys.sign(subject, credential.id, payload, 'LOGIN');
    final rejection = expectLater(
      operation,
      throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'CANCELLED')),
    );
    await tester.pump(const Duration(seconds: 2));
    await keys.cancel();
    await rejection;
    binding.reportData = {
      'nativeCancellation': 'passed',
      'hardwareBackedReported': credential.hardwareBackedReported,
      'physicalHardwareSecurity': 'not established by emulator',
    };
  });
}
