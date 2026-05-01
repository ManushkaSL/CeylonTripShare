import 'package:flutter/material.dart';

class DesignColors {
  // Core Palette - Premium & Refined
  static const Color primary = Color(0xFF1a4d3a); // Deep Teal Green
  static const Color primaryVariant = Color(0xFF0f3d2f);
  static const Color secondary = Color(0xFF2a5a46); // Rich Moss
  static const Color background = Color(0xFF0d1513); // Deep Charcoal
  static const Color surface = Color(0xFF1a2a22); // Subtle Dark Surface
  static const Color accent = Color(0xFFd4a155); // Warm Gold
  static const Color accentSecondary = Color(0xFFe8956f); // Warm Coral
  static const Color error = Color(0xFFc44569);
  static const Color success = Color(0xFF6ec38b);
  static const Color warning = Color(0xFFf4a460);
  static const Color textPrimary = Color(0xFFe8f1ec);
  static const Color textSecondary = Color(0xFF95a89d);
  static const Color textTertiary = Color(0xFF637367);
  static const Color glass = Color(0x80FFFFFF);
  static const Color divider = Color(0xFF2a3a30);
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
