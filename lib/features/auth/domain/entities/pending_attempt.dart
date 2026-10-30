enum PendingStage { enrolment, enrolled, biometric, otp }

/// An in-memory restricted credential. Never an authenticated access token.
class PendingAttempt {
  const PendingAttempt({
    required this.id,
    required this.token,
    required this.stage,
    required this.expiresAt,
    this.subjectId,
  });
  final String? subjectId;
  final String id;
  final String token;
  final PendingStage stage;
  final DateTime expiresAt;
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'AuthFailure($code)';
}
