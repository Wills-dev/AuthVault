import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/VaultComponents/VaultComponents.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    tween: Tween(begin: 0, end: 1),
    builder: (context, value, child) => Opacity(opacity: value, child: child),
    child: VaultPage(
      back: false,
      eyebrow: 'Personal security, considered',
      title: 'Your account.\nLayers of protection.',
      description: 'A more deliberate way to sign in. Keep access to your account protected at every step.',
      children: [
        const VaultSection(
          title: 'Three steps. One secure entrance.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('01    Your password'),
              SizedBox(height: 16),
              Text('02    Your device biometrics'),
              SizedBox(height: 16),
              Text('03    A code in your inbox'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        VaultAction(label: 'Log in', onPressed: () => context.push('/login')),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.push('/register'),
          child: const Text('Create an account'),
        ),
        const SizedBox(height: 20),
        const Text('Security at every step.', textAlign: TextAlign.center),
        if (kDebugMode) ...[
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.push('/preview'),
            child: const Text('Development UI preview'),
          ),
        ],
      ],
    ),
  );
}
