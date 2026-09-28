import 'package:flutter/material.dart';
import '../accessibility/accessibility_constants.dart';
import '../constants/app_colors.dart';

/// Accessible high-contrast theme configuration.
class AccessibleTheme {
  AccessibleTheme._();

  static ThemeData get highContrastTheme {
    return ThemeData(
      brightness: Brightness.dark,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primaryYellow,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryYellow,
        secondary: AppColors.secondaryCyan,
        surface: AppColors.surface,
        error: AppColors.alertRed,
        onPrimary: AppColors.textDark,
        onSurface: AppColors.textLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryYellow,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.primaryYellow,
          fontSize: AccessibilityConstants.titleFontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.textLight,
          fontSize: AccessibilityConstants.headingFontSize,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.primaryYellow,
          fontSize: AccessibilityConstants.titleFontSize,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textLight,
          fontSize: AccessibilityConstants.bodyFontSize,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textLight,
          fontSize: AccessibilityConstants.captionFontSize,
          height: 1.4,
        ),
      ),
    );
  }
}
