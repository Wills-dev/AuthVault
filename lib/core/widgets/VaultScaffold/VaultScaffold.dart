// Reusable widget filenames follow the project’s requested PascalCase convention.
// ignore_for_file: file_names

import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';

class VaultScaffold extends StatelessWidget {
  const VaultScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(VaultSpace.large),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: VaultSpace.contentWidth,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
