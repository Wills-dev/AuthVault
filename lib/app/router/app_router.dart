import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/biometric_page.dart';
import '../../features/auth/presentation/pages/credentials_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../preview_page.dart';
import '../../features/auth/presentation/providers/session_providers.dart';
import '../../features/dashboard/presentation/account_page.dart';

/// UI protection complements the backend JWT and live-session guard.
String? routeRedirect(
  String path, {
  bool debugBuild = kDebugMode,
  bool authenticated = false,
  bool restoring = false,
}) {
  if (restoring && !path.startsWith("/preview")) {
    return path == "/restore" ? null : "/restore";
  }
  if (!restoring && path == "/restore") {
    return authenticated ? "/dashboard" : "/";
  }
  if (authenticated &&
      ["/", "/login", "/register", "/biometric", "/otp"].contains(path)) {
    return "/dashboard";
  }
  if (path == '/dashboard' ||
      path.startsWith('/dashboard/') ||
      path == '/profile' ||
      path.startsWith('/profile/')) {
    return authenticated ? null : '/login';
  }
  if (!debugBuild && (path == '/preview' || path.startsWith('/preview/'))) {
    return '/';
  }
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, value) => refresh.value++);
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      return routeRedirect(
        state.uri.path,
        authenticated: session.value != null,
        restoring: session.isLoading || session.hasError,
      );
    },
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
      GoRoute(
        path: '/restore',
        builder: (context, state) => const RestoreSessionPage(),
      ),
      GoRoute(path: '/otp', builder: (context, state) => const OtpPage()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const AccountPage(profile: true),
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
