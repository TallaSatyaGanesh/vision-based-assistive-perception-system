import 'package:flutter/semantics.dart';

/// Helper utility for announcing dynamic state changes to screen readers (TalkBack / VoiceOver).
class SemanticsHelper {
  SemanticsHelper._();

  /// Announce a custom accessibility message directly to the screen reader.
  static void announce(
    String message, {
    TextDirection textDirection = TextDirection.ltr,
  }) {
    if (message.trim().isEmpty) return;
    // ignore: deprecated_member_use
    SemanticsService.announce(message, textDirection);
  }
}
