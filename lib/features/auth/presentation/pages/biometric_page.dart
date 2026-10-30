import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/VaultComponents/VaultComponents.dart';
import '../providers/auth_ui_providers.dart';
import '../widgets/pending_attempt_panel.dart';

class BiometricPage extends ConsumerWidget {
  const BiometricPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(biometricReadinessProvider);
    return VaultPage(
      eyebrow: 'Layer 02 · Your device',
      title: 'A familiar touch.\nAn extra layer.',
      description: 'Use your fingerprint or face through your device’s secure biometric prompt. Biometric images stay with your operating system.',
      children: [
        const PendingAttemptPanel(),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Icon(
              Icons.fingerprint_rounded,
              size: 72,
              color: Color(0xFF006D77),
            ),
          ),
        ),
        const SizedBox(height: 16),
        VaultSection(
          title: 'Device readiness',
          child: readiness.when(
            loading: () => const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Checking biometric availability…')),
              ],
            ),
            error: (_, _) => const VaultNotice(
              'Device check failed. Try checking again.',
              error: true,
            ),
            data: (value) => VaultNotice(switch (value) {
              BiometricReadiness.available => 'Biometrics are available on this device. This checks readiness only; your identity has not been verified.',
              BiometricReadiness.unsupported => 'Biometric protection is unavailable on this device. A supported device is required.',
              BiometricReadiness.notEnrolled => 'No biometrics are enrolled. Add a fingerprint or face in your device settings, then check again.',
              BiometricReadiness.locked => 'Biometrics are temporarily locked. Follow your device’s recovery instructions, then retry.',
              BiometricReadiness.cancelled => 'The device check was cancelled. You can check again when ready.',
              BiometricReadiness.failed => 'Unable to check biometrics. Check device permissions and try again.',
            }, error: value != BiometricReadiness.available),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: readiness.isLoading
              ? null
              : () => ref.invalidate(biometricReadinessProvider),
          child: const Text('Check device again'),
        ),
        const SizedBox(height: 16),
        const VaultNotice(
          'Verification is not available yet. Secure key enrolment and a server-issued challenge are required before a biometric prompt can verify access.',
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.push('/otp'),
          child: const Text('About email verification'),
        ),
      ],
    );
  }
}
