import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/native_biometric_keys.dart';
import '../../data/datasources/biometric_api.dart';
import '../../data/repositories/api_biometric_repository.dart';
import '../../domain/entities/pending_attempt.dart';
import '../../domain/repositories/biometric_repository.dart';
import 'credentials_providers.dart';

final biometricKeysProvider = Provider<BiometricKeys>(
  (ref) => const AndroidBiometricKeys(),
);
final biometricRepositoryProvider = Provider.autoDispose<BiometricRepository>((
  ref,
) {
  final repository = ApiBiometricRepository(
    BiometricApi(ref.watch(dioProvider)),
  );
  ref.onDispose(repository.cancel);
  return repository;
});

class BiometricController extends AsyncNotifier<PendingStage?> {
  @override
  PendingStage? build() {
    final keys = ref.read(biometricKeysProvider);
    ref.onDispose(() => unawaited(keys.cancel()));
    return null;
  }

  Future<PendingStage?> verify() async {
    if (state.isLoading) return null;
    final attempt = ref.read(pendingMfaProvider);
    if (attempt == null ||
        attempt.subjectId == null ||
        !attempt.expiresAt.isAfter(DateTime.now()) ||
        ![
          PendingStage.enrolment,
          PendingStage.biometric,
        ].contains(attempt.stage)) {
      state = AsyncError(
        const AuthFailure(
          'ATTEMPT_INVALID',
          'Your sign-in attempt expired or cannot authorize this step. Start again.',
        ),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading();
    final keys = ref.read(biometricKeysProvider);
    final repository = ref.read(biometricRepositoryProvider);
    // Keep the repository alive for this screen operation and cancel on leaving.
    final keep = ref.listen(biometricRepositoryProvider, (_, _) {});
    ref.onDispose(repository.cancel);
    try {
      final availability = await keys.capabilities();
      if (availability != 'AVAILABLE') {
        throw AndroidBiometricKeys.nativeFailure(availability);
      }
      final credential = await keys.credential(
        attempt.subjectId!,
        create: attempt.stage == PendingStage.enrolment,
      );
      if (!ref.mounted) return null;
      final challenge = await repository.challenge(attempt, credential);
      if (!ref.mounted) return null;
      if (!challenge.expiresAt.isAfter(DateTime.now())) {
        throw const AuthFailure(
          'CHALLENGE_EXPIRED',
          'The challenge expired. Retry to request a fresh one.',
        );
      }
      final signature = await keys.sign(
        attempt.subjectId!,
        credential.id,
        challenge.payload,
        challenge.purpose,
      );
      if (!ref.mounted) return null;
      final verified = await repository.prove(
        attempt,
        credential,
        challenge,
        signature,
      );
      if (!ref.mounted) return null;
      if (!verified.expiresAt.isAfter(DateTime.now())) {
        throw const AuthFailure(
          'ATTEMPT_INVALID',
          'Your sign-in attempt expired. Start again.',
        );
      }
      ref.read(pendingMfaProvider.notifier).set(verified);
      ref.invalidate(pendingStatusProvider);
      state = AsyncData(verified.stage);
      return verified.stage;
    } catch (error, stack) {
      if (ref.mounted) {
        ref.invalidate(pendingStatusProvider);
        state = AsyncError(
          error is AuthFailure
              ? error
              : const AuthFailure(
                  'BIOMETRIC_FAILURE',
                  'Unable to complete device verification. Retry safely.',
                ),
          stack,
        );
      }
      return null;
    } finally {
      keep.close();
    }
  }
}

final biometricControllerProvider =
    AsyncNotifierProvider.autoDispose<BiometricController, PendingStage?>(
      BiometricController.new,
    );
