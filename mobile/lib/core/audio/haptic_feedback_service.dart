import 'package:flutter/services.dart';

/// Haptic feedback provider for tactile perception cues.
class HapticFeedbackService {
  /// Feedback for tap interactions and selections.
  static Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Feedback for primary actions (e.g., initiating image capture).
  static Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Feedback for errors or alerts.
  static Future<void> errorAlert() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}
