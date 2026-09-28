/// Abstract voice command recognizer service placeholder.
/// Voice input and hotword listening will be integrated in subsequent approved phases.
abstract class BaseVoiceCommandService {
  Future<void> startListening({
    required Function(String command) onCommandRecognized,
  });
  Future<void> stopListening();
  bool get isListening;
}

class VoiceCommandService implements BaseVoiceCommandService {
  bool _isListening = false;

  @override
  Future<void> startListening({
    required Function(String command) onCommandRecognized,
  }) async {
    _isListening = true;
    // Voice command listener placeholder.
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
  }

  @override
  bool get isListening => _isListening;
}
