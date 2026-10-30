import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:async';

import 'package:authvault/app/app.dart';
import 'package:authvault/app/router/app_router.dart';
import 'package:authvault/core/security/native_biometric_keys.dart';
import 'package:authvault/features/auth/domain/entities/pending_attempt.dart';
import 'package:authvault/features/auth/domain/repositories/biometric_repository.dart';
import 'package:authvault/features/auth/presentation/providers/auth_ui_providers.dart';
import 'package:authvault/features/auth/presentation/providers/biometric_providers.dart';
import 'package:authvault/features/auth/presentation/providers/credentials_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FixtureKeys implements BiometricKeys {
  String availability = 'AVAILABLE';
  String? failure;
  Completer<String>? gate;
  int signs = 0;
  bool? createRequested;
  @override
  Future<String> capabilities() async => availability;
  @override
  Future<DeviceCredential> credential(
    String subjectId, {
    required bool create,
  }) async {
    createRequested = create;
    if (failure == 'KEY_MISSING' || failure == 'KEY_INVALIDATED') {
      throw AndroidBiometricKeys.nativeFailure(failure!);
    }
    return const DeviceCredential(
      id: 'fixture-credential',
      publicKey: 'fixture-public-key',
      hardwareBackedReported: false,
    );
  }

  @override
  Future<String> sign(
    String subjectId,
    String credentialId,
    String payload,
    String purpose,
  ) async {
    signs++;
    if (failure != null) throw AndroidBiometricKeys.nativeFailure(failure!);
    return gate == null ? 'fixture-signature' : gate!.future;
  }

  @override
  Future<void> cancel() async {}
}

class FixtureBiometricRepository implements BiometricRepository {
  bool expired = false;
  bool networkFailure = false;
  int proofs = 0;
  @override
  Future<SigningChallenge> challenge(
    PendingAttempt attempt,
    DeviceCredential credential,
  ) async {
    if (networkFailure) {
      throw const AuthFailure(
        'NETWORK_ERROR',
        'Connection interrupted. Retry.',
      );
    }
    return SigningChallenge(
      id: 'fixture-challenge',
      payload: 'fixture-payload',
      purpose: attempt.stage == PendingStage.enrolment ? 'ENROLMENT' : 'LOGIN',
      expiresAt: DateTime.now().add(Duration(seconds: expired ? -1 : 120)),
    );
  }

  @override
  Future<PendingAttempt> prove(
    PendingAttempt attempt,
    DeviceCredential credential,
    SigningChallenge challenge,
    String signature,
  ) async {
    proofs++;
    return PendingAttempt(
      id: attempt.id,
      token: attempt.token,
      subjectId: attempt.subjectId,
      expiresAt: attempt.expiresAt,
      stage: attempt.stage == PendingStage.enrolment
          ? PendingStage.enrolled
          : PendingStage.otp,
    );
  }

  @override
  void cancel() {}
}

Future<ProviderContainer> open(
  WidgetTester tester,
  FixtureKeys keys,
  FixtureBiometricRepository repository, {
  PendingStage stage = PendingStage.biometric,
}) async {
  final container = ProviderContainer(
    overrides: [
      biometricKeysProvider.overrideWithValue(keys),
      biometricRepositoryProvider.overrideWithValue(repository),
      biometricReadinessProvider.overrideWith(
        (ref) async => BiometricReadiness.available,
      ),
      pendingStatusProvider.overrideWith(
        (ref) async => ref.watch(pendingMfaProvider),
      ),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(pendingMfaProvider.notifier)
      .set(
        PendingAttempt(
          id: 'fixture-attempt',
          subjectId: 'fixture-subject',
          token: 'a' * 43,
          stage: stage,
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        ),
      );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const AuthVaultApp(),
    ),
  );
  container.read(appRouterProvider).go('/biometric');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('server-confirmed enrolment enables login only', (tester) async {
    final keys = FixtureKeys();
    final repository = FixtureBiometricRepository();
    final container = await open(
      tester,
      keys,
      repository,
      stage: PendingStage.enrolment,
    );
    await tester.ensureVisible(find.text('Enrol device biometrics'));
    await tester.tap(find.text('Enrol device biometrics'));
    await tester.pumpAndSettle();
    expect(keys.createRequested, isTrue);
    expect(repository.proofs, 1);
    expect(container.read(pendingMfaProvider)?.stage, PendingStage.enrolled);
    expect(find.text('Return to login'), findsOneWidget);
    container.read(pendingMfaProvider.notifier).clear();
  });
  testWidgets(
    'verified login advances to pending OTP and dashboard remains guarded',
    (tester) async {
      final keys = FixtureKeys();
      final repository = FixtureBiometricRepository();
      final container = await open(tester, keys, repository);
      await tester.ensureVisible(find.text('Verify with biometrics'));
      await tester.tap(find.text('Verify with biometrics'));
      await tester.pumpAndSettle();
      expect(keys.createRequested, isFalse);
      expect(container.read(pendingMfaProvider)?.stage, PendingStage.otp);
      expect(find.textContaining('No code has been sent'), findsOneWidget);
      final router = container.read(appRouterProvider);
      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      container.read(pendingMfaProvider.notifier).clear();
    },
  );
  for (final code in [
    'CANCELLED',
    'NOT_ENROLLED',
    'UNAVAILABLE',
    'TEMPORARY_LOCKOUT',
    'PERMANENT_LOCKOUT',
    'KEY_INVALIDATED',
    'KEY_MISSING',
    'AUTHENTICATION_FAILED',
  ]) {
    testWidgets('$code cannot advance MFA or submit proof', (tester) async {
      final keys = FixtureKeys();
      final repository = FixtureBiometricRepository();
      if (['UNAVAILABLE', 'NOT_ENROLLED'].contains(code)) {
        keys.availability = code;
      } else {
        keys.failure = code;
      }
      final container = await open(tester, keys, repository);
      await container.read(biometricControllerProvider.notifier).verify();
      await tester.pumpAndSettle();
      expect(
        (container.read(biometricControllerProvider).error! as AuthFailure)
            .code,
        code,
      );
      expect(container.read(pendingMfaProvider)?.stage, PendingStage.biometric);
      expect(repository.proofs, 0);
      container.read(pendingMfaProvider.notifier).clear();
    });
  }
  testWidgets('expired challenge and network interruption fail closed', (
    tester,
  ) async {
    final keys = FixtureKeys();
    final repository = FixtureBiometricRepository()..expired = true;
    final container = await open(tester, keys, repository);
    await container.read(biometricControllerProvider.notifier).verify();
    await tester.pumpAndSettle();
    expect(
      (container.read(biometricControllerProvider).error! as AuthFailure).code,
      'CHALLENGE_EXPIRED',
    );
    expect(keys.signs, 0);
    repository.expired = false;
    repository.networkFailure = true;
    await container.read(biometricControllerProvider.notifier).verify();
    await tester.pumpAndSettle();
    expect(
      (container.read(biometricControllerProvider).error! as AuthFailure).code,
      'NETWORK_ERROR',
    );
    expect(repository.proofs, 0);
    container.read(pendingMfaProvider.notifier).clear();
  });
  testWidgets('prompt loading prevents duplicate operations', (tester) async {
    final gate = Completer<String>();
    final keys = FixtureKeys()..gate = gate;
    final repository = FixtureBiometricRepository();
    final container = await open(tester, keys, repository);
    final first = container.read(biometricControllerProvider.notifier).verify();
    await tester.pump();
    await container.read(biometricControllerProvider.notifier).verify();
    await tester.pump();
    expect(keys.signs, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete('fixture-signature');
    await first;
    await tester.pumpAndSettle();
    expect(repository.proofs, 1);
    container.read(pendingMfaProvider.notifier).clear();
  });
  test('native platform error mapping and capability discovery never produce proof', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('authvault/biometric_keys');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'capabilities') return {'status': 'NOT_ENROLLED'};
      throw PlatformException(code: 'CANCELLED');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    const keys = AndroidBiometricKeys();
    expect(await keys.capabilities(), 'NOT_ENROLLED');
    await expectLater(
      keys.sign('subject', 'credential', 'payload', 'LOGIN'),
      throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'CANCELLED')),
    );
  });
}
