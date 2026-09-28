import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/camera/permission_service.dart';
import 'package:mobile/features/camera/presentation/camera_screen.dart';
import 'package:mobile/features/language/app_language.dart';
import 'package:mobile/features/language/language_matcher.dart';
import 'package:mobile/features/language/language_preferences_service.dart';
import 'package:mobile/features/language/presentation/language_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageMatcher Unit Tests', () {
    test('Matches various spoken forms of Telugu', () {
      final teluguInputs = [
        'తెలుగు',
        'తెలుగులో',
        'తెలుగుభాష',
        'telugu',
        'Telugu',
        'TELUGU',
        'thelugu',
        'telgu',
        'telugulo',
        'first option',
        'option 1',
        'option one',
        'telugu select cheyyi',
        'telugu select cheyi',
        'telugu choose cheyyi',
        'telugu kavali',
      ];

      for (final input in teluguInputs) {
        expect(
          LanguageMatcher.matchLanguage(input),
          AppLanguage.telugu,
          reason: 'Expected "$input" to match AppLanguage.telugu',
        );
      }
    });

    test('Matches various spoken forms of English', () {
      final englishInputs = [
        'english',
        'English',
        'ENGLISH',
        'inglish',
        'second option',
        'option 2',
        'option two',
        'ఇంగ్లీష్',
        'ఇంగ్లిష్',
        'ఇంగ్లీషు',
        'english select cheyyi',
        'english select cheyi',
        'english choose cheyyi',
        'english kavali',
      ];

      for (final input in englishInputs) {
        expect(
          LanguageMatcher.matchLanguage(input),
          AppLanguage.english,
          reason: 'Expected "$input" to match AppLanguage.english',
        );
      }
    });

    test(
      'Returns null for empty, whitespace, ambiguous, or unrecognized words',
      () {
        final invalidInputs = [
          '',
          '   ',
          'hello',
          'random words',
          'what did you say',
          'తెలుగు లేదా ఇంగ్లీష్', // Mentions both
          'telugu and english', // Mentions both
        ];

        for (final input in invalidInputs) {
          expect(
            LanguageMatcher.matchLanguage(input),
            isNull,
            reason: 'Expected "$input" to return null',
          );
        }
      },
    );
  });

  group('LanguagePreferencesService Unit Tests', () {
    test(
      'Default is empty; saves and retrieves preferences correctly',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = LanguagePreferencesService(prefs: prefs);

        expect(await service.hasLanguagePreference(), isFalse);
        expect(await service.getPreferredLanguage(), isNull);

        await service.setPreferredLanguage(AppLanguage.telugu);
        expect(await service.hasLanguagePreference(), isTrue);
        expect(await service.getPreferredLanguage(), AppLanguage.telugu);

        await service.setPreferredLanguage(AppLanguage.english);
        expect(await service.hasLanguagePreference(), isTrue);
        expect(await service.getPreferredLanguage(), AppLanguage.english);

        await service.clearPreference();
        expect(await service.hasLanguagePreference(), isFalse);
        expect(await service.getPreferredLanguage(), isNull);
      },
    );
  });

  group('First-Launch Voice Flow Widget Tests', () {
    late FakeCameraService fakeCamera;
    late FakePerceptionApiService fakePerception;
    late FakeTtsService fakeTts;
    late FakePermissionService fakePermission;
    late FakeSpeechRecognitionService fakeSpeech;
    late FakeLanguagePreferencesService fakePrefs;

    setUp(() {
      fakeCamera = FakeCameraService();
      fakePerception = FakePerceptionApiService();
      fakeTts = FakeTtsService();
      fakePermission = FakePermissionService();
      fakeSpeech = FakeSpeechRecognitionService();
      fakePrefs = FakeLanguagePreferencesService();

      CameraScreen.debugDefaultPermissionService = fakePermission;
      CameraScreen.debugDefaultLanguagePreferencesService = fakePrefs;
      CameraScreen.debugDefaultSpeechRecognitionService = fakeSpeech;
      CameraScreen.debugDefaultEnableVoiceNavigation = false;
    });

    tearDown(() {
      CameraScreen.debugDefaultPermissionService = null;
      CameraScreen.debugDefaultLanguagePreferencesService = null;
      CameraScreen.debugDefaultSpeechRecognitionService = null;
      CameraScreen.debugDefaultEnableVoiceNavigation = null;
    });

    testWidgets(
      'First launch triggers sequential Telugu & English TTS questions and begins listening',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
              isFirstLaunchOverride: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Microphone permission requested
        expect(fakePermission.requestMicrophonePermissionCallCount, 1);

        // First launch setup UI is displayed
        expect(find.text('Select Language\nభాషను ఎంచుకోండి'), findsOneWidget);
        expect(find.text('తెలుగు (TELUGU)'), findsOneWidget);
        expect(find.text('ENGLISH'), findsOneWidget);

        // TTS spoke both Telugu and English prompts sequentially
        expect(fakeTts.speakAndWaitCallCount, greaterThanOrEqualTo(2));

        // Speech recognition was initialized and started listening
        expect(fakeSpeech.initializeCallCount, 1);
        expect(fakeSpeech.startListeningCallCount, 1);
        expect(fakeSpeech.isListening, isTrue);

        // UI shows listening badge
        expect(
          find.text('LISTENING FOR VOICE / వింటూ ఉంది...'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'User speaking "Telugu" selects Telugu, persists preference, speaks confirmation, and navigates to Telugu camera',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
              isFirstLaunchOverride: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Simulate user speaking "Telugu"
        fakeSpeech.emitSpeechResult('Telugu', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Speech listening stopped
        expect(fakeSpeech.stopListeningCallCount, greaterThanOrEqualTo(1));

        // Preference saved as Telugu
        expect(fakePrefs.setPreferredLanguageCallCount, 1);
        expect(fakePrefs.preferredLanguage, AppLanguage.telugu);

        // Confirmation spoken via TTS in Telugu
        expect(fakeTts.lastLocale, 'te-IN');
        expect(fakeTts.lastSpokenText, 'Bhasha Telugu ga enpika cheyabadindi.');

        // First launch UI is dismissed, main camera screen with Telugu controls is active
        expect(find.text('Select Language\nభాషను ఎంచుకోండి'), findsNothing);
        expect(find.text('క్యాప్చర్ (CAPTURE)'), findsOneWidget);
        expect(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'User speaking "English" selects English, persists preference, speaks confirmation, and navigates to English camera',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
              isFirstLaunchOverride: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Simulate user speaking "English"
        fakeSpeech.emitSpeechResult('english', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Speech listening stopped
        expect(fakeSpeech.stopListeningCallCount, greaterThanOrEqualTo(1));

        // Preference saved as English
        expect(fakePrefs.setPreferredLanguageCallCount, 1);
        expect(fakePrefs.preferredLanguage, AppLanguage.english);

        // Confirmation spoken via TTS in English
        expect(fakeTts.lastLocale, 'en-US');
        expect(fakeTts.lastSpokenText, 'Language set to English.');

        // First launch UI is dismissed, main camera screen with English controls is active
        expect(find.text('Select Language\nభాషను ఎంచుకోండి'), findsNothing);
        expect(find.text('CAPTURE SCENE'), findsOneWidget);
        expect(find.text('RECORD SHORT VIDEO (MAX 10s)'), findsOneWidget);
      },
    );

    testWidgets('Unclear user speech repeats guidance and listens again', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CameraScreen(
            cameraService: fakeCamera,
            perceptionApiService: fakePerception,
            ttsService: fakeTts,
            permissionService: fakePermission,
            speechRecognitionService: fakeSpeech,
            languagePreferencesService: fakePrefs,
            isFirstLaunchOverride: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final initialListenCount = fakeSpeech.startListeningCallCount;

      // User speaks something unclear
      fakeSpeech.emitSpeechResult('random noise', isFinal: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Prompt was repeated with retry guidance
      expect(fakeTts.speakAndWaitCallCount, greaterThan(2));

      // Should start listening again for retry
      expect(
        fakeSpeech.startListeningCallCount,
        greaterThan(initialListenCount),
      );
    });

    testWidgets(
      'Exceeding maximum retries falls back to English without crashing or looping infinitely',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
              isFirstLaunchOverride: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Retry 1
        fakeSpeech.emitSpeechResult('unclear attempt 1', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Retry 2
        fakeSpeech.emitSpeechResult('unclear attempt 2', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Retry 3 (exceeds max retries = 2)
        fakeSpeech.emitSpeechResult('unclear attempt 3', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Preference defaulted to English
        expect(fakePrefs.preferredLanguage, AppLanguage.english);

        // App proceeds to normal camera screen safely
        expect(find.text('Select Language\nభాషను ఎంచుకోండి'), findsNothing);
        expect(find.text('CAPTURE SCENE'), findsOneWidget);
      },
    );

    testWidgets(
      'Microphone permission denied on first launch speaks guidance and keeps visible choice buttons',
      (WidgetTester tester) async {
        fakePermission.statusToReturn = AppPermissionStatus.denied;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
              isFirstLaunchOverride: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Speech recognition was NOT started because mic was denied
        expect(fakeSpeech.startListeningCallCount, 0);

        // Spoke microphone guidance via TTS
        expect(fakeTts.speakCallCount, greaterThanOrEqualTo(1));

        // Buttons remain visible and clickable on screen
        expect(find.text('తెలుగు (TELUGU)'), findsOneWidget);
        expect(find.text('ENGLISH'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping on-screen button immediately saves language and navigates to camera screen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
              isFirstLaunchOverride: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Tap the visible Telugu button
        await tester.tap(find.text('తెలుగు (TELUGU)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Speech recognition stopped
        expect(fakeSpeech.stopListeningCallCount, greaterThanOrEqualTo(1));

        // Preference saved
        expect(fakePrefs.preferredLanguage, AppLanguage.telugu);

        // First launch dismissed, Telugu camera shown
        expect(find.text('Select Language\nభాషను ఎంచుకోండి'), findsNothing);
        expect(find.text('క్యాప్చర్ (CAPTURE)'), findsOneWidget);
      },
    );

    testWidgets(
      'Subsequent launches load saved preference and skip language question directly to live camera',
      (WidgetTester tester) async {
        // Preference already set from previous launch
        fakePrefs.hasPreference = true;
        fakePrefs.preferredLanguage = AppLanguage.telugu;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Language prompt was NOT shown
        expect(find.text('Select Language\nభాషను ఎంచుకోండి'), findsNothing);

        // Did not start listening for language
        expect(fakeSpeech.startListeningCallCount, 0);

        // Loaded Telugu directly
        expect(find.text('క్యాప్చర్ (CAPTURE)'), findsOneWidget);
        expect(find.text('Live Camera Viewfinder'), findsOneWidget);
      },
    );
  });

  group('LanguageSelectionScreen Dedicated Widget Tests', () {
    late FakeCameraService fakeCamera;
    late FakePerceptionApiService fakePerception;
    late FakeTtsService fakeTts;
    late FakePermissionService fakePermission;
    late FakeSpeechRecognitionService fakeSpeech;
    late FakeLanguagePreferencesService fakePrefs;

    setUp(() {
      fakeCamera = FakeCameraService();
      fakePerception = FakePerceptionApiService();
      fakeTts = FakeTtsService();
      fakePermission = FakePermissionService();
      fakeSpeech = FakeSpeechRecognitionService();
      fakePrefs = FakeLanguagePreferencesService();
    });

    testWidgets(
      'Speaks bilingual prompt and does NOT initialize camera prior to selection',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LanguageSelectionScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Camera must NOT be initialized
        expect(fakeCamera.initializeCallCount, 0);
        expect(fakeCamera.isInitialized, isFalse);

        // UI elements rendered
        expect(find.text('Select Language\nభాషను ఎంచుకోండి'), findsOneWidget);
        expect(find.text('ENGLISH'), findsOneWidget);
        expect(find.text('తెలుగు (TELUGU)'), findsOneWidget);
        expect(find.text('LISTENING FOR VOICE / వింటూ ఉంది...'), findsOneWidget);

        // TTS spoke bilingual prompt
        expect(fakeTts.speakAndWaitCallCount, greaterThanOrEqualTo(1));
        expect(fakeTts.lastSpokenText, contains('Please select your language'));

        // Speech recognition listening
        expect(fakeSpeech.isListening, isTrue);
      },
    );

    testWidgets(
      'Spoken "English select cheyyi" saves English and navigates to English CameraScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LanguageSelectionScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Spoken English choice
        fakeSpeech.emitSpeechResult('English select cheyyi', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Preference saved
        expect(fakePrefs.preferredLanguage, AppLanguage.english);

        // Navigated to CameraScreen in English
        expect(find.byType(CameraScreen), findsOneWidget);
        expect(find.text('CAPTURE SCENE'), findsOneWidget);
        expect(fakeCamera.initializeCallCount, 1);
      },
    );

    testWidgets(
      'Spoken "Telugu select cheyyi" saves Telugu and navigates to Telugu CameraScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LanguageSelectionScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Spoken Telugu choice
        fakeSpeech.emitSpeechResult('Telugu select cheyyi', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Preference saved
        expect(fakePrefs.preferredLanguage, AppLanguage.telugu);

        // Navigated to CameraScreen in Telugu
        expect(find.byType(CameraScreen), findsOneWidget);
        expect(find.text('క్యాప్చర్ (CAPTURE)'), findsOneWidget);
        expect(fakeCamera.initializeCallCount, 1);
      },
    );

    testWidgets(
      'Tapping ENGLISH button saves English and navigates to English CameraScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LanguageSelectionScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byKey(const Key('language_button_english')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(fakePrefs.preferredLanguage, AppLanguage.english);
        expect(find.byType(CameraScreen), findsOneWidget);
        expect(find.text('CAPTURE SCENE'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping TELUGU button saves Telugu and navigates to Telugu CameraScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LanguageSelectionScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byKey(const Key('language_button_telugu')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(fakePrefs.preferredLanguage, AppLanguage.telugu);
        expect(find.byType(CameraScreen), findsOneWidget);
        expect(find.text('క్యాప్చర్ (CAPTURE)'), findsOneWidget);
      },
    );
  });
}
