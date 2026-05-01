import 'package:flutter/material.dart';

class DesignColors {
  // Light Theme - Modern Mint & Teal
  static const Color primary = Color(0xFF0D7377); // Deep Teal
  static const Color primaryVariant = Color(0xFF14919B); // Medium Teal
  static const Color secondary = Color(0xFF40C4CB); // Light Teal
  static const Color background = Color(0xFFF0F9F8); // Very Light Mint
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color accent = Color(0xFF0D7377); // Deep Teal (primary)
  static const Color accentSecondary = Color(0xFF40C4CB); // Light Teal
  static const Color error = Color(0xFFE74C3C); // Warm Red
  static const Color success = Color(0xFF27AE60); // Green
  static const Color warning = Color(0xFFF39C12); // Orange
  static const Color textPrimary = Color(0xFF1A1A1A); // Dark gray (almost black)
  static const Color textSecondary = Color(0xFF5A7A78); // Medium gray-teal
  static const Color textTertiary = Color(0xFF8B9D9A); // Light gray-teal
  static const Color divider = Color(0xFFE0F2F1); // Very light teal
  static const Color glass = Color(0x80FFFFFF); // White with opacity
}

class Spacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class AppTypography {
  // Headings
  static const TextStyle largeTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: DesignColors.textPrimary,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: DesignColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: DesignColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle subtitleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: DesignColors.textPrimary,
  );

  // Body
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: DesignColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: DesignColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: DesignColors.textTertiary,
    letterSpacing: 0.5,
  );
}
