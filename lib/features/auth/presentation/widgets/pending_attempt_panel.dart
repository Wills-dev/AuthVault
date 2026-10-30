import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/VaultComponents/VaultComponents.dart';
import '../../domain/entities/pending_attempt.dart';
import '../providers/credentials_providers.dart';

class PendingAttemptPanel extends ConsumerWidget {
  const PendingAttemptPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempt = ref.watch(pendingMfaProvider);
    if (attempt == null) return const SizedBox.shrink();
    final status = ref.watch(pendingStatusProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          status.when(
            loading: () =>
                const VaultNotice('Checking your pending sign-in attempt…'),
            error: (_, _) => Column(
              children: [
                const VaultNotice(
                  'Unable to confirm the pending attempt. No access has been granted.',
                  error: true,
                ),
                TextButton(
                  onPressed: () => ref.invalidate(pendingStatusProvider),
                  child: const Text('Retry attempt check'),
                ),
              ],
            ),
            data: (current) => VaultNotice(
              current?.stage == PendingStage.enrolment
                  ? 'Account created. Biometric enrolment is required next. No authenticated session has been issued.'
                  : 'Password confirmed. Biometric and email verification are still required. Your dashboard remains locked.',
            ),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(pendingMfaProvider.notifier).abandon();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Cancel attempt & return to login'),
          ),
        ],
      ),
    );
  }
}
