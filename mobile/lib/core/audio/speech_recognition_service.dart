import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Contract for Speech-to-Text operations.
abstract class BaseSpeechRecognitionService {
  bool get isListening;
  bool get isAvailable;

  Future<bool> initialize({
    Function(String errorMsg)? onError,
    Function(String status)? onStatus,
  });

  Future<void> startListening({
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(String status)? onStatus,
    Function(String errorMsg)? onError,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
  });

  Future<void> stopListening();
  Future<void> cancelListening();
  void dispose();
}

/// Production implementation of [BaseSpeechRecognitionService] using speech_to_text.
class SpeechRecognitionService implements BaseSpeechRecognitionService {
  final stt.SpeechToText _speechToText;
  bool _isListening = false;
  bool _isAvailable = false;
  Function(String errorMsg)? _onError;
  Function(String status)? _onStatus;

  SpeechRecognitionService({stt.SpeechToText? speechToText})
    : _speechToText = speechToText ?? stt.SpeechToText();

  @override
  bool get isListening => _isListening;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<bool> initialize({
    Function(String errorMsg)? onError,
    Function(String status)? onStatus,
  }) async {
    if (onError != null) _onError = onError;
    if (onStatus != null) _onStatus = onStatus;

    try {
      debugPrint('[SpeechService] Initializing speech recognizer engine...');
      _isAvailable = await _speechToText.initialize(
        onError: (val) {
          debugPrint('[SpeechService] Error event: ${val.errorMsg} (permanent: ${val.permanent})');
          _isListening = false;
          _onError?.call(val.errorMsg);
        },
        onStatus: (val) {
          debugPrint('[SpeechService] Status event: "$val"');
          _isListening = val == 'listening';
          _onStatus?.call(val);
        },
        debugLogging: kDebugMode,
      );
      debugPrint('[SpeechService] Initialization complete. isAvailable: $_isAvailable');
      return _isAvailable;
    } catch (e) {
      debugPrint('[SpeechService] Exception during initialize: $e');
      _isAvailable = false;
      _isListening = false;
      _onError?.call(e.toString());
      return false;
    }
  }

  @override
  Future<void> startListening({
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(String status)? onStatus,
    Function(String errorMsg)? onError,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
  }) async {
    if (onStatus != null) _onStatus = onStatus;
    if (onError != null) _onError = onError;

    if (!_isAvailable) {
      debugPrint('[SpeechService] Recognizer not initialized. Running initialize()...');
      final init = await initialize();
      if (!init) {
        debugPrint('[SpeechService] Speech recognition unavailable on device.');
        _isListening = false;
        _onStatus?.call('notListening');
        return;
      }
    }

    try {
      debugPrint('[SpeechService] Starting listen (locale: $localeId, listenFor: $listenFor, pauseFor: $pauseFor)...');
      _isListening = true;
      await _speechToText.listen(
        onResult: (result) {
          debugPrint('[SpeechService] onResult: "${result.recognizedWords}", isFinal: ${result.finalResult}');
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.deviceDefault,
          cancelOnError: false,
          partialResults: true,
          listenFor: listenFor ?? const Duration(seconds: 10),
          pauseFor: pauseFor ?? const Duration(seconds: 3),
          localeId: localeId,
        ),
      );
    } catch (e) {
      debugPrint('[SpeechService] Exception in startListening: $e');
      _isListening = false;
      _onError?.call(e.toString());
      _onStatus?.call('notListening');
    }
  }

  @override
  Future<void> stopListening() async {
    debugPrint('[SpeechService] Stopping listening...');
    try {
      _isListening = false;
      await _speechToText.stop();
    } catch (e) {
      debugPrint('[SpeechService] Exception in stopListening: $e');
      _isListening = false;
    }
  }

  @override
  Future<void> cancelListening() async {
    debugPrint('[SpeechService] Cancelling listening...');
    try {
      _isListening = false;
      await _speechToText.cancel();
    } catch (e) {
      debugPrint('[SpeechService] Exception in cancelListening: $e');
      _isListening = false;
    }
  }

  @override
  void dispose() {
    stopListening();
  }
}
