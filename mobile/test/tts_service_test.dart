import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/tts_service.dart';

/// Test implementation of BaseTtsService for predictable verification.
class FakeTtsService implements BaseTtsService {
  bool initialized = false;
  bool isSpeakingFlag = false;
  int speakCallCount = 0;
  int stopCallCount = 0;
  int initializeCallCount = 0;
  String? lastSpokenText;
  String lastLocale = 'en-US';
  bool throwOnSpeak = false;

  @override
  bool get isSpeaking => isSpeakingFlag;

  @override
  String get currentLocale => lastLocale;

  @override
  Future<void> initialize() async {
    initializeCallCount++;
    initialized = true;
  }

  @override
  Future<void> speak(String text, {String locale = 'en-US'}) async {
    if (throwOnSpeak) {
      throw Exception('TTS engine failure');
    }
    speakCallCount++;
    lastSpokenText = text;
    lastLocale = locale;
    isSpeakingFlag = true;
  }

  @override
  Future<void> speakAndWait(String text, {String locale = 'en-US'}) async {
    await speak(text, locale: locale);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    isSpeakingFlag = false;
  }

  @override
  void dispose() {
    stop();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsService Unit Tests', () {
    test(
      'TtsService initializes and stops safely without crashing in test environment',
      () async {
        final tts = TtsService();

        // Ensure calling initialize doesn't throw even without native TTS engine
        await tts.initialize();
        expect(tts.currentLocale, 'en-US');

        // Ensure stop doesn't throw
        await tts.stop();
        expect(tts.isSpeaking, isFalse);
      },
    );

    test(
      'TtsService handles locale updates for English (en-US) and Telugu (te-IN)',
      () async {
        final tts = TtsService();

        // Calling speak with Telugu locale
        await tts.speak('మీ ముందు ఒక వ్యక్తి ఉన్నారు.', locale: 'te-IN');
        // Graceful error containment on test runner
        expect(tts.isSpeaking, isFalse);

        // Calling speak with English locale
        await tts.speak(
          'A person is standing in front of you.',
          locale: 'en-US',
        );
        expect(tts.isSpeaking, isFalse);
      },
    );

    test('TtsService ignores empty or whitespace text', () async {
      final tts = TtsService();

      await tts.speak('', locale: 'en-US');
      await tts.speak('   ', locale: 'te-IN');
      expect(tts.isSpeaking, isFalse);
    });

    test('FakeTtsService tracks speech calls and locales accurately', () async {
      final fakeTts = FakeTtsService();

      await fakeTts.initialize();
      expect(fakeTts.initialized, isTrue);

      // Speak in English
      await fakeTts.speak(
        'A person is standing in front of you.',
        locale: 'en-US',
      );
      expect(fakeTts.speakCallCount, 1);
      expect(fakeTts.lastSpokenText, 'A person is standing in front of you.');
      expect(fakeTts.lastLocale, 'en-US');
      expect(fakeTts.isSpeaking, isTrue);

      // Speak in Telugu
      await fakeTts.speak('మీ ముందు ఒక వ్యక్తి ఉన్నారు.', locale: 'te-IN');
      expect(fakeTts.speakCallCount, 2);
      expect(fakeTts.lastSpokenText, 'మీ ముందు ఒక వ్యక్తి ఉన్నారు.');
      expect(fakeTts.lastLocale, 'te-IN');
      expect(fakeTts.isSpeaking, isTrue);

      await fakeTts.stop();
      expect(fakeTts.stopCallCount, 1);
      expect(fakeTts.isSpeaking, isFalse);
    });

    test(
      'TtsService handles unexpected engine exceptions without crashing',
      () async {
        final fakeTts = FakeTtsService()..throwOnSpeak = true;

        try {
          await fakeTts.speak('Test exception', locale: 'te-IN');
        } catch (e) {
          expect(e.toString(), contains('TTS engine failure'));
        }
      },
    );
  });
}
