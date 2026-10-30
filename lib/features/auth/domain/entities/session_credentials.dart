class SessionCredentials {
  const SessionCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    this.sessionExpiresAt,
  });
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime? sessionExpiresAt;
  @override
  String toString() => 'SessionCredentials(redacted)';
}

class OtpChallenge {
  const OtpChallenge(this.id, this.expiresAt, this.resendAt);
  final String id;
  final DateTime expiresAt;
  final DateTime resendAt;
}
