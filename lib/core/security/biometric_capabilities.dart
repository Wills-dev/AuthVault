import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricReadiness {
  available,
  unsupported,
  notEnrolled,
  locked,
  cancelled,
  failed,
}

class BiometricCapabilities {
  Future<BiometricReadiness> check() async {
    final auth = LocalAuthentication();
    try {
      if (!await auth.isDeviceSupported() || !await auth.canCheckBiometrics) {
        return BiometricReadiness.unsupported;
      }
      return (await auth.getAvailableBiometrics()).isEmpty
          ? BiometricReadiness.notEnrolled
          : BiometricReadiness.available;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => BiometricReadiness.locked,
        LocalAuthExceptionCode.noBiometricsEnrolled =>
          BiometricReadiness.notEnrolled,
        LocalAuthExceptionCode.noBiometricHardware =>
          BiometricReadiness.unsupported,
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled => BiometricReadiness.cancelled,
        _ => BiometricReadiness.failed,
      };
    } on PlatformException catch (error) {
      return switch (error.code) {
        'LockedOut' || 'PermanentlyLockedOut' => BiometricReadiness.locked,
        'NotEnrolled' => BiometricReadiness.notEnrolled,
        'UserCanceled' || 'SystemCanceled' => BiometricReadiness.cancelled,
        _ => BiometricReadiness.failed,
      };
    } catch (_) {
      return BiometricReadiness.failed;
    }
  }
}
