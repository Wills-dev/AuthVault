import 'dart:math';

import 'package:dio/dio.dart';
import 'package:authvault/features/auth/presentation/providers/session_providers.dart';

import 'package:authvault/app/app.dart';
import 'package:authvault/core/widgets/VaultComponents/VaultComponents.dart';
import 'package:authvault/app/router/app_router.dart';
import 'package:authvault/core/security/native_biometric_keys.dart';
import 'package:authvault/features/auth/domain/entities/pending_attempt.dart';
import 'package:authvault/features/auth/presentation/providers/credentials_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const biometricTestWait = Duration(
  seconds: bool.fromEnvironment('MANUAL_BIOMETRIC_TEST') ? 110 : 60,
);

Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  if (finder.evaluate().isEmpty) {
    final feedback = tester
        .widgetList<VaultNotice>(find.byType(VaultNotice))
        .map((notice) => notice.message)
        .join(' | ');
    fail('Expected screen was unavailable. Safe UI feedback: $feedback');
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
  testWidgets('real Android MFA, mailbox OTP, restart restoration and logout', (
    tester,
  ) async {
    final random = Random.secure();
    String secret(int bytes) => List.generate(
      bytes,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final email = 'native-${secret(12)}@example.test';
    final password = secret(24);
    var container = ProviderContainer();
    addTearDown(() => container.dispose());
    await container.read(sessionProvider.future);
    await container.read(sessionProvider.notifier).logout();
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
    await waitFor(
      tester,
      find.text('Return to login'),
      timeout: biometricTestWait,
    );
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
    await waitFor(
      tester,
      find.text('One final checkpoint'),
      timeout: biometricTestWait,
    );
    expect(container.read(pendingMfaProvider)?.stage, PendingStage.otp);
    router.go('/dashboard');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    router.go('/otp');
    await tester.pumpAndSettle();
    await tap(tester, 'Send email code');
    await waitFor(tester, find.textContaining('The email provider accepted'));
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('otp-issued');
    // Test-only mailbox read. The shipping app never reads the mailbox API.
    final mailbox = Dio();
    final response = await mailbox.get<List<dynamic>>(
      'http://10.0.2.2:8025/messages',
    );
    final delivered = response.data!.cast<Map<String, dynamic>>().lastWhere(
      (m) => (m['to'] as List).contains(email),
    );
    final actual = RegExp(r'Your sign-in code: (\d{6})')
        .firstMatch(delivered['raw'] as String)!
        .group(1)!;
    final invalid = ((int.parse(actual) + 1) % 1000000).toString().padLeft(
      6,
      '0',
    );
    await tester.enterText(find.byType(TextFormField), invalid);
    await tap(tester, 'Verify email code');
    await waitFor(tester, find.textContaining('That code is invalid'));
    expect(container.read(sessionProvider).value, isNull);
    await tester.showKeyboard(find.byType(TextFormField));
    await tester.pumpAndSettle();
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    editable.widget.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: editable.widget.controller.text.length,
    );
    await Clipboard.setData(ClipboardData(text: actual));
    await editable.pasteText(SelectionChangedCause.toolbar);
    await Clipboard.setData(const ClipboardData(text: ''));
    await tester.pump();
    expect(
      editable.widget.controller.text == actual,
      isTrue,
      reason: 'Pasted field must contain the mailbox code (value redacted)',
    );
    var submissions = 0;
    container
        .read(dioProvider)
        .interceptors
        .add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/otp/verify') {
                submissions++;
                expect(
                  (options.data as Map)['code'] == actual,
                  isTrue,
                  reason:
                      'OTP request must match mailbox code (value redacted)',
                );
              }
              handler.next(options);
            },
          ),
        );
    await tap(tester, 'Verify email code');
    await waitFor(tester, find.text('Welcome, Native biometric test'));
    expect(submissions, 1);
    expect(router.routeInformationProvider.value.uri.path, '/dashboard');
    expect(container.read(pendingMfaProvider), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('dashboard');
    final original = container;
    // Recreate every Dart provider: access JWT disappears; real secure storage restores via rotation.
    container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AuthVaultApp(),
      ),
    );
    await waitFor(tester, find.text('Welcome, Native biometric test'));
    original.dispose();
    final restored = container.read(appRouterProvider);
    expect(restored.routeInformationProvider.value.uri.path, '/dashboard');
    await tap(tester, 'Profile & security');
    await waitFor(tester, find.text('Profile & security').first);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('profile');
    await tap(tester, 'Log out');
    await waitFor(tester, find.text('Your secure sign-in'));
    expect(container.read(sessionProvider).value, isNull);
    restored.go('/dashboard');
    await tester.pumpAndSettle();
    expect(restored.routeInformationProvider.value.uri.path, '/login');
    mailbox.close(force: true);
    binding.reportData = {
      ...?binding.reportData,
      'nativeEnrolment': 'passed',
      'serverVerifiedLogin': 'PENDING_OTP',
      'dashboard': 'authenticated identity retrieved, then denied after logout',
      'subjectId': subject,
      'credentialId': metadata.id,
      'hardwareBackedReported': metadata.hardwareBackedReported,
      'physicalHardwareSecurity': 'not established by emulator',
      'otp': 'SMTP accepted; mailbox code verified; wrong code rejected',
      'restoration':
          'fresh provider container rotated securely stored refresh token',
      'logout': 'passed',
    };
  });
}
