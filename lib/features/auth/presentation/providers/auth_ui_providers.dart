import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/biometric_capabilities.dart';
export '../../../../core/security/biometric_capabilities.dart';

final biometricCapabilitiesProvider = Provider(
  (ref) => BiometricCapabilities(),
);
final biometricReadinessProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(biometricCapabilitiesProvider).check();
});

/// Server timestamps feed this clock. Null means no code was issued.
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

final otpClockProvider = StreamProvider.autoDispose((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
