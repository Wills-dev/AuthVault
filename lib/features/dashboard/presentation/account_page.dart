import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/VaultComponents/VaultComponents.dart';
import '../../auth/domain/entities/pending_attempt.dart';
import '../../auth/presentation/providers/session_providers.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key, this.profile = false});
  final bool profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return VaultPage(
      eyebrow: profile ? 'Your account' : 'Verified access',
      title: profile ? 'Profile & security' : 'Your secure workspace',
      description: 'Your account is protected by password, device biometric proof and email verification.',
      back: profile,
      children: [
        ...account.when(
          data: (value) => [
            Text(
              'Welcome, ${value.identity['fullName']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            VaultSection(
              title: 'Account',
              child: Text(
                '${value.identity['fullName']}\n${value.identity['email']}',
                style: const TextStyle(height: 1.8),
              ),
            ),
            const SizedBox(height: 16),
            VaultSection(
              title: 'Security status',
              child: Text(
                'Three authentication factors completed\n${value.security['biometricCredentials']} active biometric credential(s)\n${value.security['activeSessions']} active session(s)',
                style: const TextStyle(height: 1.8),
              ),
            ),
            const SizedBox(height: 16),
            VaultSection(
              title: 'Authentication activity',
              child: Text(
                value.security['lastAuthentication'] == null
                    ? 'No completed authentication event is available.'
                    : 'Latest completed MFA\n${DateTime.parse(value.security['lastAuthentication'] as String).toLocal()}',
              ),
            ),
          ],
          loading: () => [const Center(child: CircularProgressIndicator())],
          error: (error, stack) => [
            VaultNotice(
              error is AuthFailure
                  ? error.message
                  : 'Your account could not be loaded.',
              error: true,
            ),
            TextButton(
              onPressed: () => ref.invalidate(accountProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (!profile)
          VaultAction(
            label: 'Profile & security',
            onPressed: () => context.push('/profile'),
          ),
        TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final confirmed = await ref.read(sessionProvider.notifier).logout();
            if (!confirmed) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Signed out locally. Server revocation could not be confirmed.',
                  ),
                ),
              );
            }
          },
          child: const Text('Log out'),
        ),
      ],
    );
  }
}

class RestoreSessionPage extends ConsumerWidget {
  const RestoreSessionPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionProvider);
    return VaultPage(
      eyebrow: 'Secure session',
      title: 'Restoring your access',
      description:
          'AuthVault checks your saved session before opening your account.',
      back: false,
      children: [
        if (state.isLoading) const Center(child: CircularProgressIndicator()),
        if (state.hasError) ...[
          const VaultNotice(
            'Your saved session could not be checked. Check your connection and retry.',
            error: true,
          ),
          TextButton(
            onPressed: () => ref.invalidate(sessionProvider),
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            child: const Text('Sign out locally'),
          ),
        ],
      ],
    );
  }
}
