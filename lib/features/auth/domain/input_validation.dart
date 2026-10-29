abstract final class InputValidation {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? name(String? value) => (value?.trim().length ?? 0) < 2
      ? 'Enter your full name (at least 2 characters).'
      : null;

  static String? password(String? value) {
    if ((value?.length ?? 0) < 12) return 'Use at least 12 characters.';
    if (value!.length > 128) return 'Use no more than 128 characters.';
    return null;
  }

  static String? loginPassword(String? value) =>
      (value?.isEmpty ?? true) ? 'Enter your password.' : null;

  static String? otp(String? value) =>
      RegExp(r'^\d{6}$').hasMatch(value ?? '') ? null : 'Enter all 6 digits.';
}
