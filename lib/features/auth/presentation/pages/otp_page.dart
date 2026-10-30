import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/VaultComponents/VaultComponents.dart';
import '../../domain/input_validation.dart';
import '../providers/auth_ui_providers.dart';
import '../providers/session_providers.dart';
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

  Future<void> verify() async {
    if (ref.read(otpChallengeProvider).isLoading) return;
    if (form.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      if (await ref.read(otpChallengeProvider.notifier).verify(code.text)) {
        if (mounted) code.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingMfaProvider, (previous, next) {
      if (previous?.id != next?.id) code.clear();
    });
    final state = ref.watch(otpChallengeProvider);
    final sending = ref.read(otpChallengeProvider.notifier).sending;
    final failure = state.error;
    final errorMessage = failure is AuthFailure
        ? failure.message
        : 'Verification is unavailable. Please try again.';
    final challenge = ref.read(otpChallengeProvider.notifier).lastChallenge;
    final timing = OtpTiming(
      expiresAt: challenge?.expiresAt,
      resendAt: challenge?.resendAt,
    );
    final now = ref.watch(otpClockProvider).value ?? DateTime.now();
    final seconds = timing.resendSeconds(now);
    return VaultPage(
      eyebrow: 'Layer 03 · Your inbox',
      title: 'One final checkpoint',
      description: 'An email code will confirm access to your inbox. Codes will expire after five minutes and can only be used once.',
      children: [
        VaultNotice(
          challenge == null
              ? 'Request a code after device verification. No code has been sent from this screen.'
              : 'The email provider accepted your code. Check your inbox. Delivery to your inbox can take a moment.',
        ),
        if (challenge != null && !timing.expired(now))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Code expires in ${challenge.expiresAt.difference(now).inSeconds.clamp(0, 300)}s',
            ),
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
          loading: state.isLoading && !sending,
          onPressed: verify,
        ),
        const SizedBox(height: 12),
        if (sending) const Center(child: CircularProgressIndicator()),
        TextButton(
          onPressed:
              seconds > 0 ||
                  state.isLoading ||
                  ref.watch(pendingMfaProvider)?.stage != PendingStage.otp
              ? null
              : () {
                  code.clear();
                  ref.read(otpChallengeProvider.notifier).send();
                },
          child: Text(
            seconds > 0
                ? 'Resend in ${seconds}s'
                : challenge == null
                ? 'Send email code'
                : 'Resend email code',
          ),
        ),
        TextButton(
          onPressed: () async {
            code.clear();
            await ref.read(pendingMfaProvider.notifier).abandon();
            if (context.mounted) context.go('/login');
          },
          child: const Text('Start a new sign-in'),
        ),
      ],
    );
  }
}
