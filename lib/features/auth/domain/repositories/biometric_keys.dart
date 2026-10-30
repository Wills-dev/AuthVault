class DeviceCredential {
  const DeviceCredential({
    required this.id,
    required this.publicKey,
    required this.hardwareBackedReported,
  });
  final String id;
  final String publicKey;
  final bool hardwareBackedReported;
}

abstract interface class BiometricKeys {
  Future<String> capabilities();
  Future<DeviceCredential> credential(String subjectId, {required bool create});
  Future<String> sign(
    String subjectId,
    String credentialId,
    String payload,
    String purpose,
  );
  Future<void> cancel();
}
