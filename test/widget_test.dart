import 'dart:async';

import 'package:authvault/app/app.dart';
import 'package:authvault/features/auth/presentation/providers/credentials_providers.dart';
import 'package:authvault/features/auth/domain/entities/pending_attempt.dart';
import 'package:authvault/features/auth/domain/repositories/auth_repository.dart';
import 'package:authvault/app/router/app_router.dart';
import 'package:authvault/features/auth/presentation/providers/auth_ui_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingAction extends AuthUiActions {
  final completer = Completer<void>();
  int calls = 0;
  @override
  Future<void> submit() {
    calls++;
    return completer.future;
  }
}

class FailedOtpAction extends AuthUiActions {
  FailedOtpAction(this.failure);
  final OtpFailure failure;
  @override
  Future<void> submit() async => throw AuthUiOtpFailure(failure);
}

class OfflineRepository implements AuthRepository {
  OfflineRepository(this.action);
  final AuthUiActions? action;
  Future<PendingAttempt> unavailable() async {
    try {
      if (action != null) await action!.submit();
    } catch (_) {
      /* Controlled fixture. */
    }
    throw const AuthFailure(
      'NETWORK_ERROR',
      'Unable to reach AuthVault. Check your connection and try again.',
    );
  }

  @override
  Future<PendingAttempt> login({
    required String email,
    required String password,
  }) => unavailable();
  @override
  Future<PendingAttempt> register({
    required String fullName,
    required String email,
    required String password,
  }) => unavailable();
  @override
  Future<PendingAttempt> status(PendingAttempt attempt) => unavailable();
  @override
  Future<void> revoke(PendingAttempt attempt) async {}
  @override
  void cancel() {}
}

class ReadyDevice extends BiometricCapabilities {
  ReadyDevice(this.readiness);
  final BiometricReadiness readiness;
  @override
  Future<BiometricReadiness> check() async => readiness;
}

Future<ProviderContainer> open(
  WidgetTester tester,
  String path, {
  AuthUiActions? action,
  BiometricReadiness readiness = BiometricReadiness.notEnrolled,
  OtpTiming timing = const OtpTiming(),
  DateTime? clock,
}) async {
  final container = ProviderContainer(
    overrides: [
      credentialsRepositoryProvider.overrideWith(
        (ref, scope) => OfflineRepository(action),
      ),
      biometricCapabilitiesProvider.overrideWithValue(ReadyDevice(readiness)),
      if (action != null) authUiActionsProvider.overrideWithValue(action),
      otpTimingProvider.overrideWithValue(timing),
      otpClockProvider.overrideWith(
        (ref) => Stream.value(clock ?? DateTime.utc(2026, 10, 29, 12)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const AuthVaultApp(),
    ),
  );
  container.read(appRouterProvider).go(path);
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapText(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('OTP timing uses expiry boundaries and clamps countdown', () {
    final now = DateTime.utc(2026, 10, 29, 12);
    final timing = OtpTiming(
      expiresAt: now.add(const Duration(minutes: 5)),
      resendAt: now.add(const Duration(seconds: 60)),
    );
    expect(timing.resendSeconds(now), 60);
    expect(timing.resendSeconds(now.add(const Duration(seconds: 2))), 58);
    expect(timing.resendSeconds(now.add(const Duration(minutes: 2))), 0);
    expect(timing.expired(now.add(const Duration(minutes: 5))), isTrue);
    expect(timing.expired(now), isFalse);
  });

  testWidgets('informational MFA links and unavailable recovery work', (
    tester,
  ) async {
    await open(tester, '/login');
    await tapText(tester, 'Forgot password? · Coming soon');
    expect(
      find.text('Password recovery is not available yet.'),
      findsOneWidget,
    );
    await tapText(tester, 'How device verification works');
    expect(find.text('Device readiness'), findsOneWidget);
    await tapText(tester, 'About email verification');
    expect(find.text('One final checkpoint'), findsOneWidget);
  });

  testWidgets(
    'switching credential routes does not reuse sensitive form state',
    (tester) async {
      await open(tester, '/login');
      await tester.enterText(
        find.byType(TextFormField).last,
        'private password',
      );
      await tapText(tester, 'New to AuthVault? Create an account');
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.every((field) => field.controller!.text.isEmpty), isTrue);
    },
  );

  testWidgets('welcome links open login and registration', (tester) async {
    final container = await open(tester, '/');
    await tapText(tester, 'Log in');
    expect(find.text('Your secure sign-in'), findsOneWidget);
    container.read(appRouterProvider).go('/');
    await tester.pumpAndSettle();
    await tapText(tester, 'Create an account');
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('login validates required fields and malformed email', (
    tester,
  ) async {
    await open(tester, '/login');
    await tapText(tester, 'Continue securely');
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'wrong');
    await tapText(tester, 'Continue securely');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('registration validates name, passphrase and confirmation', (
    tester,
  ) async {
    await open(tester, '/register');
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'A');
    await tester.enterText(fields.at(1), 'a@example.com');
    await tester.enterText(fields.at(2), 'short');
    await tester.enterText(fields.at(3), 'different');
    await tapText(tester, 'Create account');
    expect(
      find.text('Enter your full name (at least 2 characters).'),
      findsOneWidget,
    );
    expect(find.text('Use at least 12 characters.'), findsOneWidget);
    expect(find.text('Passwords must match.'), findsOneWidget);
  });

  testWidgets('password visibility toggles without clearing input', (
    tester,
  ) async {
    await open(tester, '/login');
    await tester.enterText(
      find.byType(TextFormField).last,
      'private passphrase',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.obscureText, isFalse);
    expect(field.controller!.text, 'private passphrase');
  });

  testWidgets('valid input never creates a session or advances MFA', (
    tester,
  ) async {
    final container = await open(tester, '/login');
    await tester.enterText(find.byType(TextFormField).first, 'a@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tapText(tester, 'Continue securely');
    expect(find.textContaining('Unable to reach AuthVault'), findsOneWidget);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/login',
    );
  });

  testWidgets(
    'localized loading prevents duplicate submissions then displays error',
    (tester) async {
      final action = PendingAction();
      final container = await open(tester, '/login', action: action);
      await tester.enterText(find.byType(TextFormField).first, 'a@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password');
      await tester.ensureVisible(find.text('Continue securely'));
      await tester.tap(find.text('Continue securely'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await container
          .read(loginCredentialsProvider.notifier)
          .submit(email: 'a@example.com', password: 'password');
      expect(action.calls, 1);
      action.completer.completeError(const AuthUiUnavailable());
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to reach AuthVault'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'OTP filters non-digits, limits length, supports paste and validates',
    (tester) async {
      await open(tester, '/otp');
      await tapText(tester, 'Verify email code');
      expect(find.text('Enter all 6 digits.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '12a34567');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '123456',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': '654321'};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      editable.widget.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await editable.pasteText(SelectionChangedCause.toolbar);
      await tester.pump();
      expect(editable.widget.controller.text, '654321');
      await tapText(tester, 'Verify email code');
      expect(find.textContaining('no server verification'), findsOneWidget);
    },
  );

  for (final failure in OtpFailure.values) {
    testWidgets('OTP renders $failure response without granting access', (
      tester,
    ) async {
      final container = await open(
        tester,
        '/otp',
        action: FailedOtpAction(failure),
      );
      await tester.enterText(find.byType(TextFormField), '123456');
      await tapText(tester, 'Verify email code');
      expect(
        find.textContaining(
          failure == OtpFailure.invalid
              ? 'That code is invalid'
              : 'This code has expired',
        ),
        findsOneWidget,
      );
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/otp',
      );
    });
  }

  testWidgets('OTP server timestamp countdown and expiry are presented', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 29, 12);
    await open(
      tester,
      '/otp',
      timing: OtpTiming(
        expiresAt: now.subtract(const Duration(seconds: 1)),
        resendAt: now.add(const Duration(seconds: 60)),
      ),
    );
    expect(find.textContaining('This code has expired'), findsOneWidget);
    expect(find.text('Resend in 60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Resend in 60s'), findsOneWidget);
  });

  for (final readiness in BiometricReadiness.values) {
    testWidgets(
      'biometric readiness $readiness never claims identity verification',
      (tester) async {
        await open(tester, '/biometric', readiness: readiness);
        expect(
          find.textContaining('No verification has occurred'),
          findsOneWidget,
        );
        expect(find.text('Check device again'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'protected routes redirect; preview remains explicitly separate',
    (tester) async {
      final container = await open(tester, '/dashboard');
      expect(find.text('Your secure sign-in'), findsOneWidget);
      container.read(appRouterProvider).go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Your secure sign-in'), findsOneWidget);
      container.read(appRouterProvider).go('/preview/dashboard');
      await tester.pumpAndSettle();
      expect(find.textContaining('DEVELOPMENT PREVIEW'), findsOneWidget);
      await tapText(tester, 'Profile & security');
      expect(find.text('Your account details'), findsOneWidget);
      await tapText(tester, 'Log out · Exit preview');
      expect(find.text('Your account.\nLayers of protection.'), findsOneWidget);
    },
  );

  test('release preview and protected path policy fails closed', () {
    for (final path in ['/preview', '/preview/dashboard', '/preview/profile']) {
      expect(routeRedirect(path, debugBuild: false), '/');
    }
    expect(routeRedirect('/dashboard', debugBuild: false), '/login');
    expect(routeRedirect('/profile', debugBuild: false), '/login');
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    for (final path in [
      '/',
      '/login',
      '/register',
      '/biometric',
      '/otp',
      '/preview/dashboard',
      '/preview/profile',
    ]) {
      testWidgets('$path fits $size with large text and keyboard', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 100);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await open(tester, path);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -1000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
