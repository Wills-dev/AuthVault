import 'dart:math';

import 'package:authvault/app/app.dart';
import 'package:authvault/app/router/app_router.dart';
import 'package:authvault/core/security/native_biometric_keys.dart';
import 'package:authvault/features/auth/domain/entities/pending_attempt.dart';
import 'package:authvault/features/auth/presentation/providers/credentials_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsOneWidget);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android Keystore enrolment and login reach pending OTP using real signatures',
    (tester) async {
      final random = Random.secure();
      String secret(int bytes) => List.generate(
        bytes,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final email = 'native-${secret(12)}@example.test';
      final password = secret(24);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AuthVaultApp(),
        ),
      );
      final router = container.read(appRouterProvider);
      router.go('/register');
      await tester.pumpAndSettle();
      for (final item in [
        'Native biometric test',
        email,
        password,
        password,
      ].asMap().entries) {
        await tester.enterText(
          find.byType(TextFormField).at(item.key),
          item.value,
        );
      }
      await tap(tester, 'Create account');
      await waitFor(tester, find.textContaining('Account created.'));
      expect(container.read(pendingMfaProvider)?.stage, PendingStage.enrolment);
      await tap(tester, 'Enrol device biometrics');
      await waitFor(tester, find.text('Return to login'));
      expect(container.read(pendingMfaProvider)?.stage, PendingStage.enrolled);
      final subject = container.read(pendingMfaProvider)!.subjectId!;
      final metadata = await const AndroidBiometricKeys().credential(
        subject,
        create: false,
      );
      await tap(tester, 'Return to login');
      await waitFor(tester, find.text('Your secure sign-in'));
      await tester.enterText(find.byType(TextFormField).first, email);
      await tester.enterText(find.byType(TextFormField).last, password);
      await tap(tester, 'Continue securely');
      await waitFor(tester, find.textContaining('Password confirmed.'));
      await tap(tester, 'Verify with biometrics');
      await waitFor(tester, find.text('One final checkpoint'));
      expect(container.read(pendingMfaProvider)?.stage, PendingStage.otp);
      expect(find.textContaining('Device proof verified.'), findsOneWidget);
      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      await container.read(pendingMfaProvider.notifier).abandon();
      router.go('/');
      await tester.pumpAndSettle();
      binding.reportData = {
        'nativeEnrolment': 'passed',
        'serverVerifiedLogin': 'PENDING_OTP',
        'dashboard': 'denied',
        'subjectId': subject,
        'credentialId': metadata.id,
        'hardwareBackedReported': metadata.hardwareBackedReported,
        'physicalHardwareSecurity': 'not established by emulator',
        'otp': 'not implemented',
      };
    },
  );
}
