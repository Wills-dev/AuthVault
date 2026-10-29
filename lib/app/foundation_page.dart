import 'package:flutter/material.dart';

import '../core/widgets/VaultScaffold/VaultScaffold.dart';
import 'theme/design_tokens.dart';

/// A development shell. Authentication screens are introduced in Phase 2.
class FoundationPage extends StatelessWidget {
  const FoundationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return VaultScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: VaultSpace.extraLarge),
          const Icon(Icons.shield_outlined, size: 48, color: VaultColors.teal),
          const SizedBox(height: VaultSpace.large),
          Text('AuthVault', style: text.headlineLarge),
          const SizedBox(height: VaultSpace.small),
          Text('Security at every step.', style: text.titleLarge),
          const SizedBox(height: VaultSpace.extraLarge),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(VaultSpace.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Application foundation', style: text.titleMedium),
                  const SizedBox(height: VaultSpace.small),
                  Text(
                    'The design system and application structure are ready. '
                    'Authentication will be added in the next development phases.',
                    style: text.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
