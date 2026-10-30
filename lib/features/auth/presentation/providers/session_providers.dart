import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/session_repository.dart';
import '../../domain/entities/session_credentials.dart';
import '../../domain/entities/pending_attempt.dart';
import 'credentials_providers.dart';

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SecureSessionStorage(),
);
final sessionRepositoryProvider = Provider(
  (ref) => SessionRepository(ref.watch(dioProvider)),
);
final sessionProvider =
    AsyncNotifierProvider<SessionController, SessionCredentials?>(
      SessionController.new,
      retry: (count, error) => null,
    );

class SessionController extends AsyncNotifier<SessionCredentials?> {
  Future<SessionCredentials>? _refreshing;
  int _generation = 0;
  Timer? _deadline;
  void _scheduleExpiry(SessionCredentials credentials) {
    _deadline?.cancel();
    final expiresAt = credentials.sessionExpiresAt;
    if (expiresAt == null) return;
    final remaining = expiresAt.difference(DateTime.now());
    _deadline = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      _generation++;
      state = const AsyncData(null);
      unawaited(
        ref.read(sessionStorageProvider).clear().catchError((Object _) {}),
      );
    });
  }

  @override
  Future<SessionCredentials?> build() async {
    ref.onDispose(() => _deadline?.cancel());
    final stored = await ref.read(sessionStorageProvider).read();
    if (stored == null) return null;
    try {
      return await _rotate(stored);
    } on AuthFailure catch (e) {
      if (e.code == 'SESSION_INVALID') {
        await ref.read(sessionStorageProvider).clear();
        return null;
      }
      rethrow;
    }
  }

  Future<SessionCredentials> _rotate(String token) async {
    final generation = _generation;
    final next = await ref.read(sessionRepositoryProvider).refresh(token);
    if (generation != _generation) {
      try {
        await ref.read(sessionRepositoryProvider).logout(next.refreshToken);
      } catch (_) {}
      throw const AuthFailure('SESSION_INVALID', 'Please sign in again.');
    }
    await _persist(next);
    if (generation != _generation) {
      await ref.read(sessionStorageProvider).clear();
      throw const AuthFailure('SESSION_INVALID', 'Please sign in again.');
    }
    _scheduleExpiry(next);
    return next;
  }

  Future<void> _persist(SessionCredentials next) async {
    try {
      await ref.read(sessionStorageProvider).write(next.refreshToken);
    } catch (_) {
      try {
        await ref.read(sessionRepositoryProvider).logout(next.refreshToken);
      } catch (_) {
        /* Fail closed even if revocation is unreachable. */
      }
      await ref.read(sessionStorageProvider).clear();
      throw const AuthFailure(
        'STORAGE_ERROR',
        'Your session could not be saved securely. Please sign in again.',
      );
    }
  }

  Future<void> accept(SessionCredentials next) async {
    final generation = ++_generation;
    await _persist(next);
    if (generation != _generation) {
      await ref.read(sessionStorageProvider).clear();
      await ref.read(sessionRepositoryProvider).logout(next.refreshToken);
      return;
    }
    _scheduleExpiry(next);
    state = AsyncData(next);
    ref.read(pendingMfaProvider.notifier).clear();
  }

  Future<String> accessToken({bool force = false}) async {
    final generation = _generation;
    final current = state.value;
    if (current == null) {
      throw const AuthFailure('SESSION_INVALID', 'Please sign in again.');
    }
    if (!force &&
        current.accessExpiresAt.isAfter(
          DateTime.now().add(const Duration(seconds: 15)),
        )) {
      return current.accessToken;
    }
    try {
      final operation = _refreshing ??= _rotate(current.refreshToken);
      final next = await operation;
      if (ref.mounted && state.value == current) state = AsyncData(next);
      return next.accessToken;
    } on AuthFailure catch (e) {
      if (e.code == 'SESSION_INVALID' &&
          generation == _generation &&
          state.value == current) {
        await ref.read(sessionStorageProvider).clear();
        state = const AsyncData(null);
      }
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  Future<bool> logout() async {
    _deadline?.cancel();
    _generation++;
    final token =
        state.value?.refreshToken ??
        await ref.read(sessionStorageProvider).read();
    state = const AsyncData(null);
    await ref.read(sessionStorageProvider).clear();
    ref.read(pendingMfaProvider.notifier).clear();
    if (token == null) return true;
    try {
      await ref.read(sessionRepositoryProvider).logout(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> authorizedGet(String path) async {
    final repo = ref.read(sessionRepositoryProvider);
    try {
      return await repo.request(path, accessToken: await accessToken());
    } on AuthFailure catch (e) {
      if (e.code != 'SESSION_INVALID') rethrow;
      return repo.request(path, accessToken: await accessToken(force: true));
    }
  }
}

final accountProvider = FutureProvider.autoDispose((ref) async {
  ref.watch(sessionProvider);
  final controller = ref.read(sessionProvider.notifier);
  final identity = await controller.authorizedGet('/users/me');
  final security = await controller.authorizedGet('/users/me/security');
  return (identity: identity, security: security);
});
final otpChallengeProvider =
    AsyncNotifierProvider.autoDispose<OtpController, OtpChallenge?>(
      OtpController.new,
    );

class OtpController extends AsyncNotifier<OtpChallenge?> {
  OtpChallenge? lastChallenge;
  bool sending = false;
  @override
  OtpChallenge? build() => null;
  Future<void> send() async {
    if (state.isLoading) return;

    final attempt = ref.read(pendingMfaProvider);
    if (attempt == null || attempt.stage != PendingStage.otp) return;
    sending = true;
    state = const AsyncLoading();
    try {
      final challenge = await ref.read(sessionRepositoryProvider).send(attempt);
      if (ref.mounted) {
        sending = false;
        lastChallenge = challenge;
        state = AsyncData(challenge);
      }
    } catch (e, s) {
      sending = false;
      if (ref.mounted) state = AsyncError<OtpChallenge?>(e, s);
    }
  }

  Future<bool> verify(String code) async {
    final challenge = lastChallenge, attempt = ref.read(pendingMfaProvider);
    if (state.isLoading || challenge == null || attempt == null) return false;
    final repository = ref.read(sessionRepositoryProvider);
    final session = ref.read(sessionProvider.notifier);
    sending = false;
    state = const AsyncLoading<OtpChallenge?>();
    try {
      final credentials = await repository.verify(attempt, challenge.id, code);
      if (!ref.mounted || ref.read(pendingMfaProvider)?.id != attempt.id) {
        try {
          await repository.logout(credentials.refreshToken);
        } catch (_) {}
        return false;
      }
      await session.accept(credentials);
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } catch (e, s) {
      sending = false;
      if (ref.mounted) state = AsyncError<OtpChallenge?>(e, s);
      return false;
    }
  }
}
