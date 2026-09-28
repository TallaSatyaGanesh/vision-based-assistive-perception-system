import '../language/app_language.dart';

/// Abstract Text-to-Speech service placeholder on mobile client.
/// Speech synthesis engine will be integrated in subsequent approved phases.
abstract class BaseTtsService {
  Future<void> initialize();
  Future<void> speak(String text, {required AppLanguage language});
  Future<void> stop();
}

class TtsService implements BaseTtsService {
  @override
  Future<void> initialize() async {
    // TTS initialization placeholder.
  }

  @override
  Future<void> speak(String text, {required AppLanguage language}) async {
    // Speech synthesis placeholder.
  }

  @override
  Future<void> stop() async {
    // Speech stop placeholder.
  }
}
