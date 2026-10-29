import 'package:authvault/app/app.dart';
import 'package:authvault/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('inspect every Phase 2 screen on Android', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AuthVaultApp(),
      ),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    final routes = {
      'welcome': '/',
      'login': '/login',
      'registration': '/register',
      'biometric': '/biometric',
      'otp': '/otp',
      'gallery': '/preview',
      'dashboard': '/preview/dashboard',
      'profile': '/preview/profile',
    };
    for (final entry in routes.entries) {
      container.read(appRouterProvider).go(entry.value);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('phase-2-${entry.key}');
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('phase-2-${entry.key}-lower');
    }
    container.read(appRouterProvider).go('/dashboard');
    await tester.pumpAndSettle();
    expect(find.text('Your secure sign-in'), findsOneWidget);
    container.read(appRouterProvider).go('/');
    await tester.pumpAndSettle();
  });
}
