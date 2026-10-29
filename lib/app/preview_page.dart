import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/VaultComponents/VaultComponents.dart';

class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key});
  @override
  Widget build(BuildContext context) => VaultPage(
    eyebrow: 'Development tools',
    title: 'UI preview gallery',
    description: 'Inspect screen designs without signing in.',
    children: [
      const VaultNotice(
        'DEBUG ONLY · This gallery creates no session and authorizes no backend requests.',
      ),
      const SizedBox(height: 20),
      for (final entry in {
        'Login': '/login',
        'Registration': '/register',
        'Device biometrics': '/biometric',
        'Email code': '/otp',
        'Dashboard preview': '/preview/dashboard',
        'Profile preview': '/preview/profile',
      }.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton(
            onPressed: () => context.push(entry.value),
            child: Text(entry.key),
          ),
        ),
    ],
  );
}
