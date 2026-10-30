import 'dart:math';

import 'package:authvault/app/app.dart';
import 'package:authvault/app/router/app_router.dart';
import 'package:authvault/features/auth/domain/entities/pending_attempt.dart';
import 'package:authvault/features/auth/presentation/providers/credentials_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsOneWidget);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real emulator registration and password login remain pending MFA',
    (tester) async {
      final random = Random.secure();
      final suffix = List.generate(
        12,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final email = 'android-$suffix@example.test';
      final password = List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
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
      final fields = find.byType(TextFormField);
      for (final entry in [
        'Android verification',
        email,
        password,
        password,
      ].asMap().entries) {
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await waitFor(tester, find.textContaining('Account created.'));
      expect(container.read(pendingMfaProvider)?.stage, PendingStage.enrolment);
      await tester.pumpAndSettle();
      await container.read(pendingMfaProvider.notifier).abandon();
      router.go('/login');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, email);
      await tester.enterText(find.byType(TextFormField).last, password);
      await tester.ensureVisible(find.text('Continue securely'));
      await tester.tap(find.text('Continue securely'));
      await waitFor(tester, find.textContaining('Password confirmed.'));
      expect(container.read(pendingMfaProvider)?.stage, PendingStage.biometric);
      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.text('Your secure sign-in'), findsOneWidget);
      await container.read(pendingMfaProvider.notifier).abandon();
      router.go('/');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
