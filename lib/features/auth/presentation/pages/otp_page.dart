import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/VaultComponents/VaultComponents.dart';
import '../../domain/input_validation.dart';
import '../providers/auth_ui_providers.dart';
import '../providers/credentials_providers.dart';
import '../../domain/entities/pending_attempt.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});
  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final form = GlobalKey<FormState>();
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  void verify() {
    if (ref.read(otpSubmissionProvider).isLoading) return;
    if (form.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      ref.read(otpSubmissionProvider.notifier).submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpSubmissionProvider);
    final failure = state.error;
    final errorMessage = failure is AuthUiOtpFailure
        ? (failure.reason == OtpFailure.expired
              ? 'This code has expired. Request a new code.'
              : 'That code is invalid. Check the six digits and try again.')
        : 'This code could not be verified: no server verification is connected. Access has not been granted.';
    final timing = ref.watch(otpTimingProvider);
    final now = ref.watch(otpClockProvider).value ?? DateTime.now();
    final seconds = timing.resendSeconds(now);
    return VaultPage(
      eyebrow: 'Layer 03 · Your inbox',
      title: 'One final checkpoint',
      description: 'An email code will confirm access to your inbox. Codes will expire after five minutes and can only be used once.',
      children: [
        if (ref.watch(pendingMfaProvider)?.stage == PendingStage.otp)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: VaultNotice(
              'Device proof verified. Email verification is still required. No code has been sent.',
            ),
          ),
        const VaultNotice(
          'No code has been sent. Email verification requires a backend MFA attempt; this screen currently explains the next step.',
        ),
        const SizedBox(height: 24),
        Form(
          key: form,
          child: TextFormField(
            controller: code,
            autofocus: false,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: InputValidation.otp,
            onFieldSubmitted: (_) => verify(),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(letterSpacing: 8),
            decoration: const InputDecoration(
              labelText: '6-digit email code',
              hintText: '000000',
              helperText: 'Enter or paste all six digits.',
              errorMaxLines: 3,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (timing.expired(now))
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: VaultNotice(
              'This code has expired. Request a new code.',
              error: true,
            ),
          ),
        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: VaultNotice(errorMessage, error: true),
          ),
        VaultAction(
          label: 'Verify email code',
          loading: state.isLoading,
          onPressed: verify,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: null,
          child: Text(
            seconds > 0
                ? 'Resend in ${seconds}s'
                : 'Resend unavailable · No active attempt',
          ),
        ),
        const Text(
          'Having trouble? You can return to login and start again when authentication is available.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
