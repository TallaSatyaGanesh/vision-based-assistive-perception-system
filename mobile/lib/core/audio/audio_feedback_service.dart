/// Placeholder service for non-speech auditory cues (chimes, beeps, sound markers).
/// Full audio playback integration will be added in subsequent phases.
abstract class BaseAudioFeedbackService {
  /// Play an auditory cue when capture starts.
  Future<void> playCaptureChime();

  /// Play an auditory cue when processing completes.
  Future<void> playSuccessChime();

  /// Play an auditory cue when an error occurs.
  Future<void> playErrorChime();
}

class AudioFeedbackService implements BaseAudioFeedbackService {
  @override
  Future<void> playCaptureChime() async {
    // Non-speech chime playback to be implemented with audio package in future phase.
  }

  @override
  Future<void> playSuccessChime() async {
    // Non-speech chime playback to be implemented with audio package in future phase.
  }

  @override
  Future<void> playErrorChime() async {
    // Non-speech chime playback to be implemented with audio package in future phase.
  }
}
