import 'package:authvault/app/app.dart';
import 'package:authvault/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final route in ['/', '/login', '/register', '/otp']) {
    testWidgets('audit accessibility targets and labels on $route', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final semantics = tester.ensureSemantics();

      try {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const AuthVaultApp(),
          ),
        );
        await tester.pumpAndSettle();
        container.read(appRouterProvider).go(route);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    });
  }
}
