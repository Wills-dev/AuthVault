import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/VaultComponents/VaultComponents.dart';
import '../providers/auth_ui_providers.dart';
import '../providers/biometric_providers.dart';
import '../providers/credentials_providers.dart';
import '../../domain/entities/pending_attempt.dart';
import '../widgets/pending_attempt_panel.dart';

class BiometricPage extends ConsumerWidget {
  const BiometricPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(biometricReadinessProvider);
    final operation = ref.watch(biometricControllerProvider);
    final attempt = ref.watch(pendingMfaProvider);
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
        if (attempt == null)
          const VaultNotice(
            'Sign in or register first to obtain an authorized biometric context. No verification has occurred.',
          ),
        if (operation.hasError &&
            [
              PendingStage.enrolment,
              PendingStage.biometric,
            ].contains(attempt?.stage))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: VaultNotice(
              operation.error is AuthFailure
                  ? (operation.error! as AuthFailure).message
                  : 'Device verification failed. Try again.',
              error: true,
            ),
          ),
        if (attempt != null &&
            [
              PendingStage.enrolment,
              PendingStage.biometric,
            ].contains(attempt.stage))
          VaultAction(
            label: attempt.stage == PendingStage.enrolment
                ? 'Enrol device biometrics'
                : 'Verify with biometrics',
            loading: operation.isLoading,
            onPressed: () async {
              final stage = await ref
                  .read(biometricControllerProvider.notifier)
                  .verify();
              if (stage == PendingStage.otp && context.mounted) {
                context.go('/otp');
              }
            },
          ),
        if (attempt?.stage == PendingStage.otp)
          VaultAction(
            label: 'Continue to email verification',
            onPressed: () => context.go('/otp'),
          ),
        if (attempt?.stage == PendingStage.enrolled)
          VaultAction(
            label: 'Return to login',
            onPressed: () async {
              await ref.read(pendingMfaProvider.notifier).abandon();
              if (context.mounted) context.go('/login');
            },
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
