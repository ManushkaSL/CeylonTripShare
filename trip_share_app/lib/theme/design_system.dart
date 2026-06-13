import 'package:flutter/material.dart';

class DesignColors {
  // Core Palette - Luxury Safari Theme
  static const Color primary = Color(0xFF8A5E38); // Deep Antique Bronze
  static const Color primaryDark = Color(0xFF5A3C22); // Dark Walnut
  static const Color primaryLight = Color(0xFFD4A373); // Sunset Amber
  static const Color primaryVariant = Color(0xFF7A512E);
  static const Color secondary = Color(0xFFE6DCD2); // Soft Warm Sand Cream
  static const Color background = Color(0xFFFAF6F2); // Premium Cream Sand
  static const Color surface = Color(0xFFFFFFFF); // Alabaster White
  static const Color accent = Color(0xFFC59B6D); // Radiant Sand Gold
  static const Color accentSecondary = Color(0xFFE07A5F); // Terracotta Coral
  static const Color error = Color(0xFFC94A4A);
  static const Color success = Color(0xFF4E8D6B);
  static const Color warning = Color(0xFFE5A93B);
  static const Color textPrimary = Color(0xFF2C2219); // Deep Luxury Charcoal
  static const Color textSecondary = Color(0xFF6E6053); // Muted Earth Gray
  static const Color textTertiary = Color(0xFFA5978B); // Warm Taupe
  static const Color glass = Color(0xCCFFFFFF);
  static const Color divider = Color(0xFFEDE6DF);
  static const Color heroOverlay = Color(0x66000000); // Overlay gradient color
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
