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
  Future<void> _storageTail = Future.value();
  Future<T> _withStorage<T>(Future<T> Function() operation) {
    final result = _storageTail.then((_) => operation());
    _storageTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _revokeQuietly(String token) async {
    try {
      await ref.read(sessionRepositoryProvider).logout(token);
    } catch (_) {}
  }

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
        _withStorage(() => ref.read(sessionStorageProvider).clear())
            .catchError((Object _) {}),
      );
    });
  }

  @override
  Future<SessionCredentials?> build() async {
    ref.onDispose(() => _deadline?.cancel());
    final generation = _generation;
    final stored = await ref.read(sessionStorageProvider).read();
    if (generation != _generation) return state.value;
    if (stored == null) return null;
    try {
      return await _rotate(stored, generation);
    } on AuthFailure catch (e) {
      if (generation != _generation) return state.value;
      if (e.code == 'SESSION_INVALID') {
        await _withStorage(() => ref.read(sessionStorageProvider).clear());
        return null;
      }
      rethrow;
    }
  }

  Future<SessionCredentials> _rotate(String token, int generation) async {
    final next = await ref.read(sessionRepositoryProvider).refresh(token);
    if (generation != _generation) {
      await _revokeQuietly(next.refreshToken);
      throw const AuthFailure('SESSION_INVALID', 'Please sign in again.');
    }
    await _persist(next, generation);
    _scheduleExpiry(next);
    return next;
  }

  Future<void> _persist(SessionCredentials next, int generation) async {
    try {
      await _withStorage(() async {
        if (generation != _generation) {
          throw const AuthFailure('SESSION_INVALID', 'Please sign in again.');
        }
        final storage = ref.read(sessionStorageProvider);
        try {
          await storage.write(next.refreshToken);
        } catch (_) {
          try {
            await storage.clear();
          } catch (_) {}
          throw const AuthFailure(
            'STORAGE_ERROR',
            'Your session could not be saved securely. Please sign in again.',
          );
        }
        if (generation != _generation) {
          // Still inside the write queue: never erase a newer session's write.
          try {
            await storage.clear();
          } catch (_) {}
          throw const AuthFailure('SESSION_INVALID', 'Please sign in again.');
        }
      });
    } catch (_) {
      await _revokeQuietly(next.refreshToken);
      rethrow;
    }
  }

  Future<void> accept(SessionCredentials next) async {
    _deadline?.cancel();
    final generation = ++_generation;
    await _persist(next, generation);
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
      final operation = _refreshing ??= _rotate(
        current.refreshToken,
        generation,
      );
      final next = await operation;
      if (ref.mounted && state.value == current) state = AsyncData(next);
      return next.accessToken;
    } on AuthFailure catch (e) {
      if (e.code == 'SESSION_INVALID' &&
          generation == _generation &&
          state.value == current) {
        final invalidGeneration = ++_generation;
        _deadline?.cancel();
        state = const AsyncData(null);
        await _withStorage(() async {
          if (invalidGeneration != _generation) return;
          try {
            await ref.read(sessionStorageProvider).clear();
          } catch (_) {
            // The server rejected this credential; keep local UI signed out.
          }
        });
      }
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  Future<bool> logout() async {
    _deadline?.cancel();
    _generation++;
    var token = state.value?.refreshToken;
    state = const AsyncData(null);
    ref.read(pendingMfaProvider.notifier).clear();
    final storage = ref.read(sessionStorageProvider);
    final repository = ref.read(sessionRepositoryProvider);
    var confirmed = true;
    try {
      token ??= await storage.read();
    } catch (_) {
      confirmed = false;
    }
    // Revocation must be attempted even when secure-storage deletion fails.
    try {
      await _withStorage(storage.clear);
    } catch (_) {
      confirmed = false;
    }
    if (token != null) {
      try {
        await repository.logout(token);
      } catch (_) {
        confirmed = false;
      }
    }
    return confirmed;
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
