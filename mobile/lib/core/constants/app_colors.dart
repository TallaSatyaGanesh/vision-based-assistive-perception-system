import 'package:flutter/material.dart';

/// High-contrast color palette designed for visually impaired users.
/// Conforms to WCAG AAA contrast ratio standards (greater than 7:1).
class AppColors {
  AppColors._();

  // Primary High-Contrast Colors
  static const Color background = Color(0xFF000000); // Pure Black
  static const Color surface = Color(0xFF1E1E1E); // Dark Charcoal
  static const Color surfaceBorder = Color(0xFFFFFFFF); // High-contrast border

  // Accent Colors
  static const Color primaryYellow = Color(0xFFFFD600); // Vivid High-Vis Yellow
  static const Color textLight = Color(0xFFFFFFFF); // Pure White text
  static const Color textDark = Color(0xFF000000); // Pure Black text
  static const Color secondaryCyan = Color(0xFF00E5FF); // High-contrast Cyan
  static const Color alertRed = Color(0xFFFF5252); // High-contrast Warning Red
}
