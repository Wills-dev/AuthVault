import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:authvault/app/app.dart';
import 'package:authvault/app/router/app_router.dart';
import 'package:authvault/core/network/api_config.dart';
import 'package:authvault/features/auth/data/datasources/auth_api.dart';
import 'package:authvault/features/auth/data/repositories/api_auth_repository.dart';
import 'package:authvault/features/auth/domain/entities/pending_attempt.dart';
import 'package:authvault/features/auth/presentation/providers/auth_ui_providers.dart';
import 'package:authvault/features/auth/presentation/providers/credentials_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FixtureAdapter implements HttpClientAdapter {
  FixtureAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
Map<String, String> attemptBody({String stage = 'PENDING_BIOMETRIC'}) => {
  'attemptId': 'f9d65b16-bec6-4396-9c75-f7bd725fdad7',
  'attemptToken': 'a' * 43,
  'stage': stage,
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
};

class DeviceFixture extends BiometricCapabilities {
  @override
  Future<BiometricReadiness> check() async => BiometricReadiness.unsupported;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('pending MFA expiry clears the restricted credential', (
    tester,
  ) async {
    final container = ProviderContainer();
    final notifier = container.read(pendingMfaProvider.notifier);
    notifier.set(
      PendingAttempt(
        id: 'fixture',
        token: 'a' * 43,
        stage: PendingStage.biometric,
        expiresAt: DateTime.now().add(const Duration(seconds: 1)),
      ),
    );
    expect(container.read(pendingMfaProvider), isNotNull);
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(pendingMfaProvider), isNull);
    container.dispose();
  });

  test('network configuration permits local HTTP only in debug', () {
    expect(
      ApiConfig.validate('http://10.0.2.2:3000/v1', debugBuild: true),
      'http://10.0.2.2:3000/v1',
    );
    for (final input in [
      'http://10.0.2.2:3000/v1',
      'http://remote.example/v1',
      '',
      'https://user:password@example.com/v1',
    ]) {
      expect(
        () => ApiConfig.validate(input, debugBuild: false),
        throwsFormatException,
      );
    }
    expect(
      () => ApiConfig.validate('http://remote.example/v1', debugBuild: true),
      throwsFormatException,
    );
    expect(
      ApiConfig.validate('https://auth.example/v1', debugBuild: false),
      'https://auth.example/v1',
    );
  });

  test('registration posts real contract with normalized details and no confirmation', () async {
    final adapter = FixtureAdapter(
      (_) async => jsonResponse(attemptBody(stage: 'PENDING_ENROLMENT'), 201),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.example/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final pending = await ApiAuthRepository(AuthApi(dio)).register(
      fullName: ' Test Person ',
      email: ' TEST@EXAMPLE.COM ',
      password: '  test passphrase  ',
    );
    expect(adapter.requests.single.path, '/auth/register');
    expect(adapter.requests.single.data, {
      'fullName': 'Test Person',
      'email': 'test@example.com',
      'password': '  test passphrase  ',
    });
    expect(pending.stage, PendingStage.enrolment);
  });

  test(
    'login/status use distinct pending credential header and never bearer',
    () async {
      final body = attemptBody();
      final adapter = FixtureAdapter(
        (options) async => jsonResponse(
          options.method == 'GET'
              ? (Map<String, String>.from(body)..remove('attemptToken'))
              : body,
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.example/v1'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = ApiAuthRepository(AuthApi(dio));
      final pending = await repository.login(
        email: 'test@example.com',
        password: 'test passphrase',
      );
      expect(pending.stage, PendingStage.biometric);
      final status = await repository.status(pending);
      expect(status.id, pending.id);
      expect(adapter.requests.last.headers['X-MFA-Token'], pending.token);
      expect(
        adapter.requests.last.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );

  for (final code in [
    'INVALID_CREDENTIALS',
    'REGISTRATION_UNAVAILABLE',
    'VALIDATION_ERROR',
    'RATE_LIMITED',
    'ATTEMPT_INVALID',
  ]) {
    test('maps $code without reflecting backend secrets', () async {
      final adapter = FixtureAdapter(
        (_) async => jsonResponse({
          'error': {'code': code, 'message': 'sensitive server text'},
        }, code == 'RATE_LIMITED' ? 429 : 400),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.example/v1'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      await expectLater(
        ApiAuthRepository(AuthApi(dio))
            .login(email: 'test@example.com', password: 'test passphrase'),
        throwsA(
          isA<AuthFailure>()
              .having((e) => e.code, 'code', code)
              .having(
                (e) => e.message.contains('sensitive'),
                'redacted',
                isFalse,
              ),
        ),
      );
    });
  }

  test('network failure maps to recoverable error', () async {
    final adapter = FixtureAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.example/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    await expectLater(
      ApiAuthRepository(AuthApi(dio))
          .login(email: 'test@example.com', password: 'test passphrase'),
      throwsA(
        isA<AuthFailure>().having((e) => e.code, 'code', 'NETWORK_ERROR'),
      ),
    );
  });

  test('cancellation aborts an in-flight request', () async {
    final gate = Completer<ResponseBody>();
    final adapter = FixtureAdapter((_) => gate.future);
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.example/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final repository = ApiAuthRepository(AuthApi(dio));
    final future = repository.login(
      email: 'test@example.com',
      password: 'test passphrase',
    );
    final expectation = expectLater(
      future,
      throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'CANCELLED')),
    );
    await Future<void>.delayed(Duration.zero);
    repository.cancel();
    gate.complete(jsonResponse(attemptBody()));
    await expectation;
  });

  test('unexpected completed stage is rejected', () async {
    final adapter = FixtureAdapter(
      (_) async => jsonResponse(attemptBody(stage: 'COMPLETED')),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.example/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    await expectLater(
      ApiAuthRepository(AuthApi(dio))
          .login(email: 'test@example.com', password: 'test passphrase'),
      throwsA(
        isA<AuthFailure>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
      ),
    );
  });

  testWidgets(
    'real API adapter success moves to pending biometrics, keeps dashboard guarded',
    (tester) async {
      final body = attemptBody();
      final adapter = FixtureAdapter(
        (options) async => jsonResponse(
          options.method == 'GET'
              ? (Map<String, String>.from(body)..remove('attemptToken'))
              : body,
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.example/v1'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          biometricCapabilitiesProvider.overrideWithValue(DeviceFixture()),
        ],
      );
      addTearDown(() {
        container.dispose();
        dio.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AuthVaultApp(),
        ),
      );
      final router = container.read(appRouterProvider);
      router.go('/login');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'test passphrase',
      );
      await tester.ensureVisible(find.text('Continue securely'));
      await tester.tap(find.text('Continue securely'));
      await tester.pumpAndSettle();
      expect(container.read(pendingMfaProvider)?.stage, PendingStage.biometric);
      expect(find.textContaining('Password confirmed'), findsOneWidget);
      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(find.text('Your secure sign-in'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/login');
      container.read(pendingMfaProvider.notifier).clear();
    },
  );

  testWidgets('registration reaches pending enrolment without completing MFA', (
    tester,
  ) async {
    final body = attemptBody(stage: 'PENDING_ENROLMENT');
    final adapter = FixtureAdapter(
      (options) async => jsonResponse(
        options.method == 'GET'
            ? (Map<String, String>.from(body)..remove('attemptToken'))
            : body,
        options.method == 'POST' ? 201 : 200,
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.example/v1'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        biometricCapabilitiesProvider.overrideWithValue(DeviceFixture()),
      ],
    );
    addTearDown(() {
      container.dispose();
      dio.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AuthVaultApp(),
      ),
    );
    container.read(appRouterProvider).go('/register');
    await tester.pumpAndSettle();
    for (final entry in [
      'Test Person',
      'test@example.com',
      'test passphrase',
      'test passphrase',
    ].asMap().entries) {
      await tester.enterText(
        find.byType(TextFormField).at(entry.key),
        entry.value,
      );
    }
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(container.read(pendingMfaProvider)?.stage, PendingStage.enrolment);
    expect(find.textContaining('Account created.'), findsOneWidget);
    expect(find.textContaining('No authenticated session'), findsOneWidget);
    container.read(pendingMfaProvider.notifier).clear();
  });
}
