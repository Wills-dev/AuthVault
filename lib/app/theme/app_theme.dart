import 'package:flutter/material.dart';

import 'design_tokens.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: VaultColors.navy,
          brightness: Brightness.light,
        ).copyWith(
          primary: VaultColors.navy,
          onPrimary: VaultColors.white,
          secondary: VaultColors.teal,
          onSecondary: VaultColors.white,
          surface: VaultColors.white,
          onSurface: VaultColors.navy,
          onSurfaceVariant: VaultColors.muted,
          outline: VaultColors.border,
          error: VaultColors.error,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(VaultRadius.field),
    );
    return base.copyWith(
      scaffoldBackgroundColor: VaultColors.canvas,
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: VaultColors.navy,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.6),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: VaultColors.canvas,
        foregroundColor: VaultColors.navy,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, VaultSpace.touchTarget),
          padding: const EdgeInsets.all(VaultSpace.medium),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, VaultSpace.touchTarget),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VaultColors.white,
        contentPadding: const EdgeInsets.all(VaultSpace.medium),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VaultRadius.field),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: VaultColors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VaultRadius.card),
          side: const BorderSide(color: VaultColors.border),
        ),
      ),
    );
  }
}
