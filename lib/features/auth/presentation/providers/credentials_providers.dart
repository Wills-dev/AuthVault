import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_config.dart';
import '../../data/datasources/auth_api.dart';
import '../../data/repositories/api_auth_repository.dart';
import '../../domain/entities/pending_attempt.dart';
import '../../domain/repositories/auth_repository.dart';

final dioProvider = Provider((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      followRedirects: false,
      headers: {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

// Each request owner gets its own cancellation scope.
final credentialsRepositoryProvider = Provider.family<AuthRepository, String>((
  ref,
  scope,
) {
  final repository = ApiAuthRepository(AuthApi(ref.watch(dioProvider)));
  ref.onDispose(repository.cancel);
  return repository;
});

class PendingMfaController extends Notifier<PendingAttempt?> {
  Timer? _expiry;
  @override
  PendingAttempt? build() {
    ref.onDispose(() => _expiry?.cancel());
    return null;
  }

  void set(PendingAttempt attempt) {
    _expiry?.cancel();
    final remaining = attempt.expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      state = null;
      return;
    }
    state = attempt;
    _expiry = Timer(remaining, () => state = null);
  }

  void clear() {
    _expiry?.cancel();
    state = null;
  }

  Future<void> abandon() async {
    final attempt = state;
    clear();
    if (attempt == null) return;
    try {
      await ref.read(credentialsRepositoryProvider('revoke')).revoke(attempt);
    } on AuthFailure {
      /* Local secrets are cleared even if the server is unreachable. */
    }
  }
}

final pendingMfaProvider =
    NotifierProvider<PendingMfaController, PendingAttempt?>(
      PendingMfaController.new,
    );

class CredentialsController extends AsyncNotifier<PendingAttempt?> {
  CredentialsController(this.scope);
  final String scope;
  late AuthRepository repository;
  @override
  PendingAttempt? build() {
    // Resolve only when submitting, so a missing release URL becomes a form error.
    return null;
  }

  Future<bool> submit({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      repository = ref.read(credentialsRepositoryProvider(scope));
      ref.onDispose(repository.cancel);
      final pending = fullName == null
          ? await repository.login(email: email, password: password)
          : await repository.register(
              fullName: fullName,
              email: email,
              password: password,
            );
      if (!ref.mounted) return false;
      if (!pending.expiresAt.isAfter(DateTime.now())) {
        throw const AuthFailure(
          'ATTEMPT_INVALID',
          'Your sign-in attempt expired. Start again.',
        );
      }
      ref.read(pendingMfaProvider.notifier).set(pending);
      state = AsyncData(pending);
      return true;
    } catch (error, stack) {
      if (ref.mounted) {
        state = AsyncError(
          error is AuthFailure
              ? error
              : const AuthFailure(
                  'CONFIGURATION_ERROR',
                  'Authentication is unavailable. Check the app configuration and try again.',
                ),
          stack,
        );
      }
      return false;
    }
  }
}

final loginCredentialsProvider =
    AsyncNotifierProvider.autoDispose<CredentialsController, PendingAttempt?>(
      () => CredentialsController('login'),
    );
final registerCredentialsProvider =
    AsyncNotifierProvider.autoDispose<CredentialsController, PendingAttempt?>(
      () => CredentialsController('register'),
    );

final pendingStatusProvider = FutureProvider.autoDispose<PendingAttempt?>((
  ref,
) async {
  final attempt = ref.watch(pendingMfaProvider);
  if (attempt == null) return null;
  try {
    final repository = ref.watch(credentialsRepositoryProvider('status'));
    ref.onDispose(repository.cancel);
    final current = await repository.status(attempt);
    if (current.stage != attempt.stage) {
      Future.microtask(() {
        if (ref.mounted) ref.read(pendingMfaProvider.notifier).set(current);
      });
    }
    return current;
  } on AuthFailure catch (error) {
    if (error.code == 'ATTEMPT_INVALID') {
      Future.microtask(() {
        if (ref.mounted) ref.read(pendingMfaProvider.notifier).clear();
      });
    }
    rethrow;
  }
});
