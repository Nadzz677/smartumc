import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';

/// Material theme for the shared SmartUMC Android and web application.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brandCyan,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.actionBlue,
          secondary: AppColors.brandCyan,
          surface: AppColors.white,
          onSurface: AppColors.ink,
        );

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: const BorderSide(color: AppColors.paleBlueBorder),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.navy,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        titleLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          color: AppColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
        bodyLarge: TextStyle(
          color: AppColors.body,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: AppColors.body,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          color: AppColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 2,
        shadowColor: AppColors.ink.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paleBlue,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        hintStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: TextStyle(
          color: colorScheme.error,
          fontSize: 12,
          height: 1.25,
        ),
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(color: AppColors.actionBlue, width: 1.5),
        ),
        errorBorder: outline.copyWith(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: outline.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          foregroundColor: const WidgetStatePropertyAll(AppColors.white),
          backgroundColor: const WidgetStatePropertyAll(AppColors.actionBlue),
          elevation: const WidgetStatePropertyAll(2),
          shadowColor: WidgetStatePropertyAll(
            AppColors.brandCyan.withValues(alpha: 0.25),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.input),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.actionBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
      ),
      dividerColor: AppColors.divider,
    );
  }
}
