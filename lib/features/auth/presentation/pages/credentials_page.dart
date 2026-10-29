import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/VaultComponents/VaultComponents.dart';
import '../../domain/input_validation.dart';
import '../providers/auth_ui_providers.dart';
import '../widgets/auth_field.dart';

class CredentialsPage extends ConsumerStatefulWidget {
  const CredentialsPage({super.key, this.registration = false});
  final bool registration;
  @override
  ConsumerState<CredentialsPage> createState() => _CredentialsPageState();
}

class _CredentialsPageState extends ConsumerState<CredentialsPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  @override
  void dispose() {
    for (final controller in [name, email, password, confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  AsyncNotifierProvider<SubmissionController, void> get submission =>
      widget.registration ? registrationSubmissionProvider : submissionProvider;

  void submit() {
    if (ref.read(submission).isLoading) return;
    if (form.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      ref.read(submission.notifier).submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.registration;
    final state = ref.watch(submission);
    return VaultPage(
      eyebrow: register ? 'Start with a strong foundation' : 'Welcome back',
      title: register ? 'Create your account' : 'Your secure sign-in',
      description: register
          ? 'Set up your details. Device biometrics and email verification will add the next layers.'
          : 'Begin with your email and password. Your device and email code come next.',
      children: [
        Form(
          key: form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (register)
                  AuthField(
                    label: 'Full name',
                    controller: name,
                    validator: InputValidation.name,
                    autofillHints: const [AutofillHints.name],
                  ),
                AuthField(
                  label: 'Email address',
                  controller: email,
                  email: true,
                  validator: InputValidation.email,
                  autofillHints: const [AutofillHints.email],
                ),
                AuthField(
                  label: 'Password',
                  controller: password,
                  password: true,
                  validator: register
                      ? InputValidation.password
                      : InputValidation.loginPassword,
                  last: !register,
                  onSubmitted: submit,
                ),
                if (register) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Text(
                      'Use 12–128 characters. A unique passphrase is a good choice.',
                    ),
                  ),
                  AuthField(
                    label: 'Confirm password',
                    controller: confirmation,
                    password: true,
                    last: true,
                    onSubmitted: submit,
                    validator: (value) =>
                        value == password.text && (value?.isNotEmpty ?? false)
                        ? null
                        : 'Passwords must match.',
                  ),
                ] else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password recovery is not available yet.',
                              ),
                            ),
                          ),
                      child: const Text('Forgot password? · Coming soon'),
                    ),
                  ),
                if (state.hasError)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: VaultNotice(
                      'Authentication is not connected yet. Your details were not sent or saved. Please try again after backend setup.',
                      error: true,
                    ),
                  ),
                VaultAction(
                  label: register ? 'Create account' : 'Continue securely',
                  loading: state.isLoading,
                  onPressed: submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            ref.invalidate(submission);
            context.go(register ? '/login' : '/register');
          },
          child: Text(
            register
                ? 'Already have an account? Log in'
                : 'New to AuthVault? Create an account',
          ),
        ),
        if (!register)
          TextButton(
            onPressed: () => context.push('/biometric'),
            child: const Text('How device verification works'),
          ),
      ],
    );
  }
}
