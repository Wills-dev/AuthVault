import 'biometric_keys.dart';
import '../entities/pending_attempt.dart';

class SigningChallenge {
  const SigningChallenge({
    required this.id,
    required this.payload,
    required this.purpose,
    required this.expiresAt,
  });
  final String id;
  final String payload;
  final String purpose;
  final DateTime expiresAt;
}

abstract interface class BiometricRepository {
  Future<SigningChallenge> challenge(
    PendingAttempt attempt,
    DeviceCredential credential,
  );
  Future<PendingAttempt> prove(
    PendingAttempt attempt,
    DeviceCredential credential,
    SigningChallenge challenge,
    String signature,
  );
  void cancel();
}
