// Project convention for reusable widget files.
// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/design_tokens.dart';
import '../VaultScaffold/VaultScaffold.dart';

class VaultPage extends StatelessWidget {
  const VaultPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.children,
    this.back = true,
  });
  final String eyebrow;
  final String title;
  final String description;
  final List<Widget> children;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return VaultScaffold(
      key: ValueKey(title),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (back)
                IconButton(
                  tooltip: 'Back',
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              const Icon(
                Icons.shield_outlined,
                color: VaultColors.teal,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AuthVault',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            eyebrow.toUpperCase(),
            style: text.labelMedium?.copyWith(
              color: VaultColors.teal,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: text.headlineLarge),
          const SizedBox(height: 12),
          Text(
            description,
            style: text.bodyLarge?.copyWith(color: VaultColors.muted),
          ),
          const SizedBox(height: 28),
          ...children,
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class VaultNotice extends StatelessWidget {
  const VaultNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFEDEA) : const Color(0xFFE7F3F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: error ? VaultColors.error : VaultColors.navy,
          height: 1.5,
        ),
      ),
    ),
  );
}

class VaultAction extends StatelessWidget {
  const VaultAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: loading ? null : onPressed,
    child: loading
        ? Semantics(
            label: 'Please wait',
            child: const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : Text(label),
  );
}

class VaultSection extends StatelessWidget {
  const VaultSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}
