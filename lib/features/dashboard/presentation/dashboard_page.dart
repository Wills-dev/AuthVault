import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/VaultComponents/VaultComponents.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => VaultPage(
    eyebrow: 'Your security overview',
    title: 'Welcome, [first name]',
    description: 'Your account security, in one place.',
    children: [
      const VaultNotice(
        'DEVELOPMENT PREVIEW · No authenticated session. All account values are placeholders.',
      ),
      const SizedBox(height: 20),
      const VaultSection(
        title: 'Account protection',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: Not authenticated'),
            SizedBox(height: 12),
            Text('Password · Not verified'),
            SizedBox(height: 12),
            Text('Device biometrics · Not verified'),
            SizedBox(height: 12),
            Text('Email code · Not verified'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const VaultSection(
        title: 'Authentication activity',
        child: Text(
          'No activity available.\n\nLast successful login: Not available.',
        ),
      ),
      const SizedBox(height: 24),
      VaultAction(
        label: 'Profile & security',
        onPressed: () => context.push('/preview/profile'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => context.go('/'),
        child: const Text('Log out · Exit preview'),
      ),
    ],
  );
}
