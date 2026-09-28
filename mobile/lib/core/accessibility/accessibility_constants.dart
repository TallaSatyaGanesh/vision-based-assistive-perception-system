/// Accessibility sizing standards and semantic guidelines.
class AccessibilityConstants {
  AccessibilityConstants._();

  /// Minimum touch target size for accessible controls (Standard Android is 48x48,
  /// assistive apps benefit from larger 64x64 or higher touch targets).
  static const double minTouchTargetDimension = 72.0;

  /// Large touch target height for primary action areas.
  static const double primaryActionHeight = 120.0;

  /// High contrast border width.
  static const double borderWidth = 3.0;

  /// Generous border radius for tactile touch feedback boundaries.
  static const double borderRadius = 16.0;

  /// Typography sizing for low-vision clarity.
  static const double headingFontSize = 26.0;
  static const double titleFontSize = 22.0;
  static const double bodyFontSize = 18.0;
  static const double captionFontSize = 16.0;
}
