import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/biometric_capabilities.dart';
export '../../../../core/security/biometric_capabilities.dart';

/// OTP remains unavailable until Phase 5; credential forms use credentials_providers.
class AuthUiActions {
  Future<void> submit() async {
    throw const AuthUiUnavailable();
  }
}

enum OtpFailure { invalid, expired }

class AuthUiOtpFailure implements Exception {
  const AuthUiOtpFailure(this.reason);
  final OtpFailure reason;
}

class AuthUiUnavailable implements Exception {
  const AuthUiUnavailable();
}

final authUiActionsProvider = Provider((ref) => AuthUiActions());

class SubmissionController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> submit() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authUiActionsProvider).submit(),
    );
  }
}

final otpSubmissionProvider =
    AsyncNotifierProvider.autoDispose<SubmissionController, void>(
      SubmissionController.new,
    );

final biometricCapabilitiesProvider = Provider(
  (ref) => BiometricCapabilities(),
);
final biometricReadinessProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(biometricCapabilitiesProvider).check();
});

/// Future server timestamps feed this clock. Null means no code was issued.
class OtpTiming {
  const OtpTiming({this.expiresAt, this.resendAt});
  final DateTime? expiresAt;
  final DateTime? resendAt;
  int resendSeconds(DateTime now) {
    final milliseconds = resendAt?.difference(now).inMilliseconds ?? 0;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  bool expired(DateTime now) => expiresAt != null && !now.isBefore(expiresAt!);
}

final otpTimingProvider = Provider((ref) => const OtpTiming());
final otpClockProvider = StreamProvider.autoDispose((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
