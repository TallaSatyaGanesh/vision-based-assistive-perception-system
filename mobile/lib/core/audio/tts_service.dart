import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

/// Contract for Text-to-Speech operations.
abstract class BaseTtsService {
  bool get isSpeaking;
  String get currentLocale;
  Future<void> initialize();
  Future<void> speak(String text, {String locale = 'en-US'});
  Future<void> speakAndWait(String text, {String locale = 'en-US'});
  Future<void> stop();
  void dispose();
}

/// Production Text-to-Speech service using flutter_tts.
/// Handles multilingual speech synthesis, initialization, and error containment.
class TtsService implements BaseTtsService {
  final FlutterTts _flutterTts;
  bool _isSpeaking = false;
  bool _isInitialized = false;
  String _currentLocale = 'en-US';
  Completer<void>? _activeSpeakCompleter;

  TtsService({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  String get currentLocale => _currentLocale;

  @override
  Future<void> initialize() async {
    try {
      await _flutterTts.setLanguage(_currentLocale);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        if (_activeSpeakCompleter != null &&
            !_activeSpeakCompleter!.isCompleted) {
          _activeSpeakCompleter!.complete();
        }
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        if (_activeSpeakCompleter != null &&
            !_activeSpeakCompleter!.isCompleted) {
          _activeSpeakCompleter!.complete();
        }
      });

      _flutterTts.setErrorHandler((dynamic msg) {
        _isSpeaking = false;
        if (_activeSpeakCompleter != null &&
            !_activeSpeakCompleter!.isCompleted) {
          _activeSpeakCompleter!.complete();
        }
      });

      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
  }

  @override
  Future<void> speak(String text, {String locale = 'en-US'}) async {
    if (text.trim().isEmpty) return;

    try {
      // Stop existing speech before speaking new result
      await stop();

      if (!_isInitialized) {
        await initialize();
      }

      // Configure requested language locale (e.g. en-US or te-IN)
      if (locale != _currentLocale) {
        try {
          await _flutterTts.setLanguage(locale);
          _currentLocale = locale;
        } catch (_) {
          // If setting specific locale fails, do not crash
        }
      }

      _isSpeaking = true;
      await _flutterTts.speak(text);
    } catch (_) {
      // If TTS fails (e.g. voice engine missing), catch gracefully without crashing
      _isSpeaking = false;
    }
  }

  @override
  Future<void> speakAndWait(String text, {String locale = 'en-US'}) async {
    if (text.trim().isEmpty) return;

    final completer = Completer<void>();
    _activeSpeakCompleter = completer;

    try {
      await stop();

      if (!_isInitialized) {
        await initialize();
      }

      if (locale != _currentLocale) {
        try {
          await _flutterTts.setLanguage(locale);
          _currentLocale = locale;
        } catch (_) {}
      }

      try {
        await _flutterTts.awaitSpeakCompletion(true);
      } catch (_) {}

      _isSpeaking = true;
      await _flutterTts.speak(text);

      // On Android/iOS with awaitSpeakCompletion(true), speak() returns only after speech is done.
      // Complete immediately so we never hang waiting for a separate callback.
      _isSpeaking = false;
      if (!completer.isCompleted) {
        completer.complete();
      }

      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _isSpeaking = false;
        },
      );
    } catch (_) {
      _isSpeaking = false;
    } finally {
      if (_activeSpeakCompleter == completer) {
        _activeSpeakCompleter = null;
      }
    }
  }

  @override
  Future<void> stop() async {
    try {
      _isSpeaking = false;
      if (_activeSpeakCompleter != null &&
          !_activeSpeakCompleter!.isCompleted) {
        _activeSpeakCompleter!.complete();
        _activeSpeakCompleter = null;
      }
      await _flutterTts.stop();
    } catch (_) {
      _isSpeaking = false;
    }
  }

  @override
  void dispose() {
    stop();
  }
}
