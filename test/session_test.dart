import 'dart:async';

import 'package:authvault/app/app.dart';
import 'package:authvault/app/router/app_router.dart';
import 'package:authvault/features/auth/data/repositories/session_repository.dart';
import 'package:authvault/features/auth/domain/entities/session_credentials.dart';
import 'package:authvault/features/auth/domain/entities/pending_attempt.dart';
import 'package:authvault/features/auth/presentation/providers/credentials_providers.dart';
import 'package:authvault/features/auth/presentation/providers/session_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Deliberately non-secret fixtures. Real signatures/SMTP are covered by backend and device tests.
SessionCredentials credentials(String name, {bool expired = false}) =>
    SessionCredentials(
      accessToken: 'access-$name',
      refreshToken: 'refresh-$name',
      accessExpiresAt: DateTime.now().add(Duration(minutes: expired ? -1 : 5)),
    );

class MemoryStorage implements SessionStorage {
  String? token;
  bool fail = false;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('fixture storage failure');
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class FixtureRepository extends SessionRepository {
  FixtureRepository() : super(Dio());
  int refreshes = 0, sends = 0, verifications = 0, logouts = 0;
  Object? error;
  Completer<SessionCredentials>? refreshPending;
  Completer<OtpChallenge>? sendPending;
  final challenge = OtpChallenge(
    'fixture-challenge',
    DateTime.now().add(const Duration(minutes: 5)),
    DateTime.now().add(const Duration(seconds: 60)),
  );
  @override
  Future<SessionCredentials> refresh(String token) async {
    refreshes++;
    if (error != null) throw error!;
    return refreshPending?.future ?? Future.value(credentials('rotated'));
  }

  @override
  Future<void> logout(String token) async {
    logouts++;
    if (error != null) throw error!;
  }

  @override
  Future<OtpChallenge> send(PendingAttempt attempt) async {
    sends++;
    if (error != null) throw error!;
    return sendPending?.future ?? Future.value(challenge);
  }

  @override
  Future<SessionCredentials> verify(
    PendingAttempt attempt,
    String challenge,
    String code,
  ) async {
    verifications++;
    if (error != null) throw error!;
    return credentials('verified');
  }

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
    String? pendingToken,
    String? accessToken,
  }) async {
    if (error != null) throw error!;
    return path == '/users/me'
        ? {'fullName': 'Fixture User', 'email': 'fixture@example.test'}
        : {
            'biometricCredentials': 1,
            'activeSessions': 1,
            'lastAuthentication': null,
          };
  }
}

void main() {
  late MemoryStorage storage;
  late FixtureRepository repo;
  late ProviderContainer container;
  setUp(
    () => {
      storage = MemoryStorage(),
      repo = FixtureRepository(),
      container = ProviderContainer(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          sessionRepositoryProvider.overrideWithValue(repo),
        ],
      ),
    },
  );
  tearDown(() => container.dispose());
  void pending() => container
      .read(pendingMfaProvider.notifier)
      .set(
        PendingAttempt(
          id: 'fixture',
          token: 'pending',
          stage: PendingStage.otp,
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        ),
      );
  test(
    'restores only through refresh rotation and persists new refresh token',
    () async {
      storage.token = 'refresh-original';
      final restored = await container.read(sessionProvider.future);
      expect(restored?.accessToken, 'access-rotated');
      expect(storage.token, 'refresh-rotated');
      expect(repo.refreshes, 1);
    },
  );
  test('invalid saved session is cleared without granting access', () async {
    storage.token = 'refresh-original';
    repo.error = const AuthFailure('SESSION_INVALID', 'Expired');
    expect(await container.read(sessionProvider.future), isNull);
    expect(storage.token, isNull);
  });
  test('network failure preserves saved credential and stays gated', () async {
    storage.token = 'refresh-original';
    repo.error = const AuthFailure('NETWORK_ERROR', 'Offline');
    await expectLater(
      container.read(sessionProvider.future),
      throwsA(isA<AuthFailure>()),
    );
    expect(storage.token, 'refresh-original');
    expect(container.read(sessionProvider).value, isNull);
  });
  test(
    'secure persistence failure revokes new credentials and fails closed',
    () async {
      await container.read(sessionProvider.future);
      storage.fail = true;
      await expectLater(
        container
            .read(sessionProvider.notifier)
            .accept(credentials('verified')),
        throwsA(isA<AuthFailure>()),
      );
      expect(container.read(sessionProvider).value, isNull);
      expect(storage.token, isNull);
      expect(repo.logouts, 1);
    },
  );
  test('concurrent refresh callers share one rotation', () async {
    await container.read(sessionProvider.future);
    final controller = container.read(sessionProvider.notifier);
    await controller.accept(credentials('old', expired: true));
    repo.refreshPending = Completer();
    final first = controller.accessToken(), second = controller.accessToken();
    await Future<void>.delayed(Duration.zero);
    expect(repo.refreshes, 1);
    repo.refreshPending!.complete(credentials('new'));
    expect(await first, 'access-new');
    expect(await second, 'access-new');
    expect(storage.token, 'refresh-new');
  });
  test('expired refresh session clears state and storage', () async {
    await container.read(sessionProvider.future);
    final controller = container.read(sessionProvider.notifier);
    await controller.accept(credentials('old', expired: true));
    repo.error = const AuthFailure('SESSION_INVALID', 'Expired');
    await expectLater(controller.accessToken(), throwsA(isA<AuthFailure>()));
    expect(container.read(sessionProvider).value, isNull);
    expect(storage.token, isNull);
  });
  test('logout clears local storage even if server is unavailable', () async {
    await container.read(sessionProvider.future);
    final controller = container.read(sessionProvider.notifier);
    await controller.accept(credentials('old'));
    repo.error = const AuthFailure('NETWORK_ERROR', 'Offline');
    expect(await controller.logout(), isFalse);
    expect(storage.token, isNull);
    expect(container.read(sessionProvider).value, isNull);
  });
  test('logout during refresh cannot restore a session', () async {
    await container.read(sessionProvider.future);
    final controller = container.read(sessionProvider.notifier);
    await controller.accept(credentials('old', expired: true));
    repo.refreshPending = Completer();
    final request = controller.accessToken();
    await Future<void>.delayed(Duration.zero);
    await controller.logout();
    repo.refreshPending!.complete(credentials('new'));
    await expectLater(request, throwsA(isA<AuthFailure>()));
    expect(storage.token, isNull);
    expect(container.read(sessionProvider).value, isNull);
  });
  test(
    'OTP only issues in pending OTP, prevents duplicate send, retains cooldown',
    () async {
      final subscription = container.listen(
        otpChallengeProvider,
        (_, value) {},
      );
      addTearDown(subscription.close);
      final otp = container.read(otpChallengeProvider.notifier);
      await otp.send();
      expect(repo.sends, 0);
      pending();
      repo.sendPending = Completer();
      final first = otp.send();
      await otp.send();
      expect(repo.sends, 1);
      expect(container.read(otpChallengeProvider).isLoading, isTrue);
      repo.sendPending!.complete(repo.challenge);
      await first;
      expect(otp.lastChallenge?.resendAt, repo.challenge.resendAt);
    },
  );
  test('OTP completion saves credentials, clears pending MFA and authorizes navigation', () async {
    await container.read(sessionProvider.future);
    pending();
    final sub = container.listen(otpChallengeProvider, (_, value) {});
    addTearDown(sub.close);
    final otp = container.read(otpChallengeProvider.notifier);
    await otp.send();
    expect(await otp.verify('123456'), isTrue);
    expect(storage.token, 'refresh-verified');
    expect(container.read(pendingMfaProvider), isNull);
    expect(
      routeRedirect(
        '/otp',
        authenticated: container.read(sessionProvider).value != null,
      ),
      '/dashboard',
    );
  });
  test(
    'OTP network failure retains challenge for retry and never grants access',
    () async {
      await container.read(sessionProvider.future);
      pending();
      final sub = container.listen(otpChallengeProvider, (_, value) {});
      addTearDown(sub.close);
      final otp = container.read(otpChallengeProvider.notifier);
      await otp.send();
      repo.error = const AuthFailure('NETWORK_ERROR', 'Offline');
      expect(await otp.verify('123456'), isFalse);
      expect(otp.lastChallenge, repo.challenge);
      expect(container.read(otpChallengeProvider).hasError, isTrue);
      expect(container.read(sessionProvider).value, isNull);
    },
  );
  testWidgets(
    'real OTP UI renders resend countdown, loading and network error',
    (tester) async {
      await container.read(sessionProvider.future);
      pending();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AuthVaultApp(),
        ),
      );
      container.read(appRouterProvider).go('/otp');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send email code'));
      await tester.tap(find.text('Send email code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Resend in '), findsOneWidget);
      repo.error = const AuthFailure('NETWORK_ERROR', 'Offline');
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.ensureVisible(find.text('Verify email code'));
      await tester.tap(find.text('Verify email code'));
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      expect(container.read(sessionProvider).value, isNull);
      container.read(pendingMfaProvider.notifier).clear();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets(
      'authenticated dashboard and profile fit $size with large text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await container.read(sessionProvider.future);
        await container
            .read(sessionProvider.notifier)
            .accept(credentials('verified'));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const AuthVaultApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Welcome, Fixture User'), findsOneWidget);
        expect(tester.takeException(), isNull);
        container.read(appRouterProvider).go('/profile');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('expired session redirects real protected navigation to login', (
    tester,
  ) async {
    await container.read(sessionProvider.future);
    final session = container.read(sessionProvider.notifier);
    await session.accept(credentials('old'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AuthVaultApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/dashboard',
    );
    repo.error = const AuthFailure('SESSION_INVALID', 'Expired');
    await expectLater(
      session.accessToken(force: true),
      throwsA(isA<AuthFailure>()),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/login',
    );
    expect(storage.token, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('absolute session deadline removes cached dashboard access', (
    tester,
  ) async {
    await container.read(sessionProvider.future);
    await container
        .read(sessionProvider.notifier)
        .accept(
          SessionCredentials(
            accessToken: 'fixture',
            refreshToken: 'fixture',
            accessExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
            sessionExpiresAt: DateTime.now().add(const Duration(seconds: 1)),
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AuthVaultApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/login',
    );
    expect(storage.token, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
