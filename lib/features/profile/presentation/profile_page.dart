import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/VaultComponents/VaultComponents.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => VaultPage(
    eyebrow: 'Profile & security',
    title: 'Your account details',
    description: 'Understand how your account will be protected.',
    children: [
      const VaultNotice(
        'DEVELOPMENT PREVIEW · No account data or authenticated session.',
      ),
      const SizedBox(height: 20),
      const VaultSection(
        title: 'Personal information',
        child: Text('Full name\nNot available\n\nEmail address\nNot available'),
      ),
      const SizedBox(height: 16),
      const VaultSection(
        title: 'Security settings',
        child: Text(
          'Device biometrics\nEnrolment status not available.\n\nPassword & email verification\nNot connected. Settings become available after backend integration.',
        ),
      ),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => context.go('/'),
        child: const Text('Log out · Exit preview'),
      ),
    ],
  );
}
