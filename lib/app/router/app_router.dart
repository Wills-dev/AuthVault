import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/biometric_page.dart';
import '../../features/auth/presentation/pages/credentials_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../preview_page.dart';

/// There is no authenticated state in Phase 2. Protected paths always fail closed.
String? routeRedirect(String path, {bool debugBuild = kDebugMode}) {
  if (path == '/dashboard' ||
      path.startsWith('/dashboard/') ||
      path == '/profile' ||
      path.startsWith('/profile/')) {
    return '/login';
  }
  if (!debugBuild && (path == '/preview' || path.startsWith('/preview/'))) {
    return '/';
  }
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    redirect: (context, state) => routeRedirect(state.uri.path),
    errorBuilder: (context, state) => const WelcomePage(),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const CredentialsPage(key: ValueKey('login')),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const CredentialsPage(
          key: ValueKey('register'),
          registration: true,
        ),
      ),
      GoRoute(
        path: '/biometric',
        builder: (context, state) => const BiometricPage(),
      ),
      GoRoute(path: '/otp', builder: (context, state) => const OtpPage()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      if (kDebugMode) ...[
        GoRoute(
          path: '/preview',
          builder: (context, state) => const PreviewPage(),
        ),
        GoRoute(
          path: '/preview/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/preview/profile',
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
