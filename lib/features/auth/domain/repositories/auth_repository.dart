import '../entities/pending_attempt.dart';

abstract interface class AuthRepository {
  Future<PendingAttempt> login({
    required String email,
    required String password,
  });
  Future<PendingAttempt> register({
    required String fullName,
    required String email,
    required String password,
  });
  Future<PendingAttempt> status(PendingAttempt attempt);
  Future<void> revoke(PendingAttempt attempt);
  void cancel();
}
