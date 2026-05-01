import 'package:flutter/material.dart';
import 'design_system.dart';

ThemeData buildAppTheme() {
  final base = ThemeData.light();

  return base.copyWith(
    scaffoldBackgroundColor: DesignColors.background,
    primaryColor: DesignColors.primary,
    colorScheme: base.colorScheme.copyWith(
      primary: DesignColors.primary,
      secondary: DesignColors.secondary,
      background: DesignColors.background,
      surface: DesignColors.surface,
      error: DesignColors.error,
    ),
    textTheme: base.textTheme.copyWith(
      titleLarge: AppTypography.largeTitle,
      titleMedium: AppTypography.subtitle,
      bodyMedium: AppTypography.body,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: DesignColors.textPrimary,
      centerTitle: false,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
