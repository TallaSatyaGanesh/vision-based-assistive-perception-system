import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/camera/presentation/camera_screen.dart';
import 'package:mobile/features/language/app_language.dart';
import 'package:mobile/features/perception/models/perception_result.dart';
import 'package:mobile/features/voice/voice_command.dart';

import 'widget_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceCommandMatcher Unit Tests', () {
    test('Matches English captureImage commands', () {
      final inputs = [
        'capture image',
        'Capture Image',
        'CAPTURE IMAGE',
        'capture an image',
        'Capture an image',
        'capture a photo',
        'Capture a photo',
        'take photo',
        'Take photo',
        'take a photo',
        'Take a photo',
        'take picture',
        'Take picture',
        'take a picture',
        'Take a picture',
        'click a photo',
        'Click a photo',
        'capture photo',
        'click photo',
        'click picture',
        'click a picture',
        'capture a picture',
        'capture picture',
        'photo please',
        'first option',
        'option 1',
        'option one',
      ];
      for (final input in inputs) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.captureImage,
          reason: 'Expected "$input" to match VoiceAction.captureImage',
        );
      }
    });

    test('Matches Telugu captureImage commands (script & transliteration)', () {
      final inputs = [
        'ఫోటో తీయి',
        'ఫోటో తీయండి',
        'ఫోటో తీసుకో',
        'ఫోటో తీసుకోండి',
        'ఫోటో',
        'కెమెరాతో ఫోటో తీయి',
        'photo theeyi',
        'photo teeyi',
        'Photo teeyi',
        'photo teesuko',
        'Photo teesuko',
        'photo capture cheyi',
        'Photo capture cheyi',
        'photo capture cheyandi',
        'photo tisuko',
        'photo theeyandi',
        'photo teeyandi',
        'photo teesukondi',
        'camera tho photo theeyi',
        'camera tho photo teeyi',
        'photo',
      ];
      for (final input in inputs) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.captureImage,
          reason: 'Expected "$input" to match VoiceAction.captureImage',
        );
      }
    });

    test('Matches English recordVideo commands', () {
      final inputs = [
        'record video',
        'Record Video',
        'RECORD VIDEO',
        'record a video',
        'Record a video',
        'start video',
        'Start video',
        'start recording',
        'Start recording',
        'take a video',
        'Take a video',
        'take video',
        'record short video',
        'record a clip',
        'record clip',
        'shoot video',
        'second option',
        'option 2',
        'option two',
      ];
      for (final input in inputs) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.recordVideo,
          reason: 'Expected "$input" to match VoiceAction.recordVideo',
        );
      }
    });

    test('Matches Telugu recordVideo commands (script & transliteration)', () {
      final inputs = [
        'వీడియో రికార్డ్ చేయి',
        'వీడియో రికార్డ్ చేయండి',
        'వీడియో తీయి',
        'వీడియో తీయండి',
        'వీడియో చేయి',
        'వీడియో',
        'video record cheyi',
        'Video record cheyi',
        'video teeyi',
        'Video teeyi',
        'video theeyi',
        'video start cheyi',
        'Video start cheyi',
        'video start cheyandi',
        'video record cheyandi',
        'video teeyandi',
        'record cheyi',
        'video',
      ];
      for (final input in inputs) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.recordVideo,
          reason: 'Expected "$input" to match VoiceAction.recordVideo',
        );
      }
    });

    test('Matches English analyze commands', () {
      final inputs = [
        'analyze',
        'Analyze',
        'ANALYZE',
        'analyse',
        'analyze video',
        'start analysis',
        'inspect',
      ];
      for (final input in inputs) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.analyze,
          reason: 'Expected "$input" to match VoiceAction.analyze',
        );
      }
    });

    test('Matches Telugu analyze commands (Choodu, Chudu, చూడు, Video choodu, Analyze, Analyze cheyi, script, Tenglish & punctuation)', () {
      final inputs = [
        'choodu',
        'Choodu',
        'CHOODU',
        'chudu',
        'Chudu',
        'చూడు',
        'video choodu',
        'Video choodu',
        'analyze',
        'Analyze',
        'ANALYZE',
        'analyze cheyi',
        'Analyze cheyi',
        'విశ్లేషించు',
        'విశ్లేషణ చేయి',
        'విశ్లేషణ చేయండి',
        'విశ్లేషణ',
        'vishleshinchu',
        'visleshinchu',
        'vishleshana cheyi',
        'visleshana cheyi',
        'vishleshana cheyandi',
        'vishleshinchandi',
        'vishleshana',
        // With punctuation & whitespace
        'choodu.',
        'choodu?',
        'choodu!',
        '  choodu  ',
        'chudu.',
        'చూడు!',
        'video choodu.',
        'analyze cheyi?',
        'vishleshinchu.',
        'విశ్లేషించు!',
        '  vishleshana cheyi  ',
      ];
      for (final input in inputs) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.analyze,
          reason: 'Expected "$input" to match VoiceAction.analyze',
        );
      }
    });

    test('Matches English retake commands', () {
      final inputs = [
        'retake',
        'Retake',
        'RETAKE',
        'retake video',
        'record again',
        'discard',
        'try again',
        'take again',
        'retake.',
        'retake?',
      ];
      for (final input in inputs) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.retake,
          reason: 'Expected "$input" to match VoiceAction.retake',
        );
      }
    });

    test('Matches Telugu retake commands (script, Tenglish & punctuation)', () {
      final inputs = [
        'రీటేక్',
        'రీటెక్',
        'మళ్లీ తీయి',
        'మళ్ళీ తీయి',
        'మళ్లీ రికార్డ్ చేయి',
        'మళ్ళీ రికార్డ్ చేయి',
        'మరోసారి తీయి',
        'మరోసారి రికార్డ్ చేయి',
        'మళ్ళీ ప్రయత్నించు',
        'retake',
        'retake cheyi',
        'malli teeyi',
        'malli theeyi',
        'malli teeyandi',
        'malli record cheyi',
        'malli record cheyandi',
        'malli try cheyi',
        'malli cheyi',
        'marosari teeyi',
        'marosari theeyi',
        'marosari record cheyi',
        // With punctuation & whitespace
        'malli teeyi.',
        'retake cheyi?',
        'రీటేక్!',
        '  malli record cheyi  ',
      ];
      for (final input in inputs) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.retake,
          reason: 'Expected "$input" to match VoiceAction.retake',
        );
      }
    });

    test('Matches retry commands', () {
      final inputs = [
        'retry',
        'Retry',
        'RETRY',
        'retry analysis',
        'retry perception',
        'retry photo',
        'retry video',
        'retry image',
        'retry cheyi',
        'retry cheyandi',
        'malli analyze cheyi',
        'malli analyze cheyandi',
        'malli vishleshana cheyi',
        'రీట్రై',
      ];
      for (final input in inputs) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.retry,
          reason: 'Expected "$input" to match VoiceAction.retry',
        );
      }
    });

    test('Returns null for unrecognized or ambiguous inputs', () {
      final invalidInputs = [
        '',
        '   ',
        'hello',
        'what can you do',
        'how are you',
        'what is the weather',
        'can you hear me',
        'good morning',
        'thank you',
        // Partial single words that are not full commands
        'take',
        'record',
        'start',
        'capture',
        'cheyi',
        'teeyi',
        'teesuko',
        'click',
        // Ambiguous commands mentioning both actions
        'capture image or record video',
        'take a photo or record video',
        'take a photo or take a video',
        'take a picture or start recording',
        'click a photo or start video',
        'take a photo and record video',
        'photo theeyi leda video record cheyi',
        'photo teeyi leda video teeyi',
        'photo teesuko leda video start cheyi',
        'photo capture cheyi leda video record cheyi',
        'photo or video',
        'photo leda video',
        'analyze or retake',
        'choodu leda malli teeyi',
        'Choodu leda Malli theeyi',
        'video choodu leda malli record cheyi',
        'చూడు లేదా మళ్ళీ తీయి',
        'choodu leda retake',
        'retake leda choodu',
        'vishleshinchu leda retake',
        'retake leda analyze',
        'retry or retake',
        'retry leda choodu',
      ];
      for (final input in invalidInputs) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          isNull,
          reason: 'Expected "$input" to return null',
        );
      }
    });

    test('Classification test: Distinguishes photo vs video commands accurately', () {
      final photoCommands = [
        'capture image',
        'capture a photo',
        'take a photo',
        'take picture',
        'take a picture',
        'click a photo',
        'photo please',
        'photo teeyi',
        'photo teesuko',
        'photo theeyi',
        'photo capture cheyi',
      ];
      for (final input in photoCommands) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.captureImage,
          reason: 'Expected "$input" to match VoiceAction.captureImage (NOT video)',
        );
      }

      final videoCommands = [
        'record video',
        'record a video',
        'start video',
        'start recording',
        'take a video',
        'video record cheyi',
        'video teeyi',
        'video start cheyi',
      ];
      for (final input in videoCommands) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          VoiceAction.recordVideo,
          reason: 'Expected "$input" to match VoiceAction.recordVideo (NOT photo)',
        );
      }
    });

    test('Robust matching and speech normalization handles punctuation, casing, spacing, and filler phrases', () {
      final punctuationVariants = [
        'Take a photo.',
        'Take a photo!',
        'Take a photo?',
        'Take, a photo',
        'Take - a - photo',
        '"Take a photo"',
        'Take a video.',
        'Record a video!',
        'video record cheyi.',
        'photo capture cheyi!',
      ];
      for (final input in punctuationVariants) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          isNotNull,
          reason: 'Expected "$input" to match valid action despite punctuation',
        );
      }

      final spacingAndCaseVariants = [
        '  take   a   photo  ',
        '  record   video  ',
        'TAKE A PHOTO',
        'Record A Video',
        'vIdEo ReCoRd ChEyI',
      ];
      for (final input in spacingAndCaseVariants) {
        expect(
          VoiceCommandMatcher.matchCommand(input),
          isNotNull,
          reason: 'Expected "$input" to match valid action despite case/spacing',
        );
      }

      final embeddedPhrases = {
        'Please take a photo': VoiceAction.captureImage,
        'Can you record a video': VoiceAction.recordVideo,
        'Hey take a picture': VoiceAction.captureImage,
        'Dayachesi photo teeyi': VoiceAction.captureImage,
        'Okay video record cheyi': VoiceAction.recordVideo,
        'Take a video please': VoiceAction.recordVideo,
        'Could you take a photo for me': VoiceAction.captureImage,
        'Can you start recording now': VoiceAction.recordVideo,
        'Dayachesi photo capture cheyi': VoiceAction.captureImage,
        'Video start cheyi please': VoiceAction.recordVideo,
      };
      embeddedPhrases.forEach((phrase, expectedAction) {
        expect(
          VoiceCommandMatcher.matchCommand(phrase),
          expectedAction,
          reason: 'Expected embedded phrase "$phrase" to match $expectedAction',
        );
      });
    });
  });

  group('Voice Navigation Flow Widget Tests', () {
    late FakeCameraService fakeCamera;
    late FakePerceptionApiService fakePerception;
    late FakeTtsService fakeTts;
    late FakePermissionService fakePermission;
    late FakeSpeechRecognitionService fakeSpeech;
    late FakeLanguagePreferencesService fakePrefs;

    setUp(() {
      fakeCamera = FakeCameraService()
        ..initialized = true
        ..fileToReturn = XFile.fromData(
          Uint8List.fromList([0, 0, 0, 1]),
          name: 'test_photo.jpg',
          path: 'test_photo.jpg',
        )
        ..videoToReturn = XFile.fromData(
          Uint8List.fromList([0, 0, 0, 1]),
          name: 'test_vid.mp4',
          path: 'test_vid.mp4',
        );
      fakePerception = FakePerceptionApiService();
      fakeTts = FakeTtsService();
      fakePermission = FakePermissionService();
      fakeSpeech = FakeSpeechRecognitionService();
      fakePrefs = FakeLanguagePreferencesService()
        ..hasPreference = true
        ..preferredLanguage = AppLanguage.english;

      CameraScreen.debugDefaultPermissionService = fakePermission;
      CameraScreen.debugDefaultLanguagePreferencesService = fakePrefs;
      CameraScreen.debugDefaultSpeechRecognitionService = fakeSpeech;
      CameraScreen.debugDefaultEnableVoiceNavigation = true;
    });

    tearDown(() {
      CameraScreen.debugDefaultPermissionService = null;
      CameraScreen.debugDefaultLanguagePreferencesService = null;
      CameraScreen.debugDefaultSpeechRecognitionService = null;
      CameraScreen.debugDefaultEnableVoiceNavigation = null;
    });

    testWidgets(
      'Startup with English preference speaks English options and starts listening',
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Spoke English prompt
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastLocale, 'en-US');
        expect(
          fakeTts.lastSpokenText,
          'You can say "Take a photo" or "Record video".',
        );

        // Started listening for commands
        expect(fakeSpeech.startListeningCallCount, 1);
        expect(fakeSpeech.isListening, isTrue);

        // Visual Voice Banner is displayed
        expect(find.byIcon(Icons.mic), findsOneWidget);
        expect(
          find.text('Listening... e.g. "Take a photo" or "Record video"'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Startup with Telugu preference speaks Telugu options and starts listening',
      (WidgetTester tester) async {
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Spoke Telugu prompt
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastLocale, 'te-IN');
        expect(
          fakeTts.lastSpokenText,
          'Meeru "Photo teeyi" leda "Video record cheyi" ani cheppavachu.',
        );

        // Started listening for commands
        expect(fakeSpeech.startListeningCallCount, 1);
        expect(fakeSpeech.isListening, isTrue);

        // Visual Voice Banner in Telugu
        expect(find.byIcon(Icons.mic), findsOneWidget);
        expect(
          find.text(
            'Vintoo undi... "Photo teeyi" leda "Video record cheyi"',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Voice command "Capture image" speaks confirmation and executes photo capture',
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // User speaks "capture image"
        fakeSpeech.emitSpeechResult('capture image', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Stop listening was called
        expect(fakeSpeech.stopListeningCallCount, greaterThanOrEqualTo(1));

        // Spoke capturing confirmation
        expect(fakeTts.spokenTexts.contains('Capturing image...'), isTrue);

        // Camera capture was triggered
        expect(fakeCamera.takePictureCallCount, 1);

        // Perception API called
        expect(fakePerception.perceiveFileCallCount, 1);
      },
    );

    testWidgets(
      'Voice command "ఫోటో తీయి" in Telugu speaks Tenglish confirmation and executes capture',
      (WidgetTester tester) async {
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // User speaks Telugu command
        fakeSpeech.emitSpeechResult('ఫోటో తీయి', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Spoke Tenglish capturing confirmation
        expect(fakeTts.spokenTexts.contains('Photo theestunnamu...'), isTrue);

        // Camera capture triggered
        expect(fakeCamera.takePictureCallCount, 1);
        expect(fakePerception.perceiveFileCallCount, 1);
      },
    );

    testWidgets(
      'Voice command "Take a photo" speaks confirmation and executes photo capture',
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // User speaks natural variation "Take a photo"
        fakeSpeech.emitSpeechResult('take a photo', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Stop listening was called
        expect(fakeSpeech.stopListeningCallCount, greaterThanOrEqualTo(1));

        // Spoke capturing confirmation
        expect(fakeTts.spokenTexts.contains('Capturing image...'), isTrue);

        // Camera capture was triggered
        expect(fakeCamera.takePictureCallCount, 1);
        expect(fakePerception.perceiveFileCallCount, 1);
      },
    );

    testWidgets(
      'Voice command "Photo teesuko" in Telugu speaks confirmation and executes capture',
      (WidgetTester tester) async {
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // User speaks Telugu natural variation "photo teesuko"
        fakeSpeech.emitSpeechResult('photo teesuko', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Spoke capturing confirmation
        expect(fakeTts.spokenTexts.contains('Photo theestunnamu...'), isTrue);

        // Camera capture was triggered
        expect(fakeCamera.takePictureCallCount, 1);
        expect(fakePerception.perceiveFileCallCount, 1);
      },
    );

    testWidgets(
      'Speech recognizer status "notListening" without words triggers retry guidance',
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final initialListenCount = fakeSpeech.startListeningCallCount;

        // Recognizer ends session due to Android silence detection
        fakeSpeech.emitStatus('notListening');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Retry guidance was spoken truthfully without hanging
        expect(
          fakeTts.lastSpokenText,
          'I did not understand. You can say "Take a photo" or "Record video".',
        );

        // Listening restarted for retry
        expect(
          fakeSpeech.startListeningCallCount,
          greaterThan(initialListenCount),
        );
      },
    );

    testWidgets('Voice command "Record video" starts video recording', (
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
            enableVoiceNavigation: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // User speaks "record video"
      fakeSpeech.emitSpeechResult('record video', isFinal: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Recording started
      expect(fakeCamera.startVideoRecordingCallCount, 1);
      expect(fakeCamera.isRecordingVideoFlag, isTrue);
    });

    testWidgets('Unclear voice command speaks retry guidance and listens again', (
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
            enableVoiceNavigation: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final initialListenCount = fakeSpeech.startListeningCallCount;

      // User speaks unrecognized words
      fakeSpeech.emitSpeechResult('something unfamiliar', isFinal: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Retry guidance spoken
      expect(
        fakeTts.lastSpokenText,
        'I did not understand. You can say "Take a photo" or "Record video".',
      );

      // Listened again
      expect(
        fakeSpeech.startListeningCallCount,
        greaterThan(initialListenCount),
      );
    });

    testWidgets(
      'Exceeding maximum retries speaks button fallback guidance without crashing or infinite loop',
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Attempt 1: unclear
        fakeSpeech.emitSpeechResult('unclear 1', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Attempt 2: unclear
        fakeSpeech.emitSpeechResult('unclear 2', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Attempt 3: unclear (exceeds _maxVoiceCommandRetries = 2)
        fakeSpeech.emitSpeechResult('unclear 3', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Spoke fallback guidance
        expect(
          fakeTts.lastSpokenText,
          'Voice command not detected. You can use the buttons on screen.',
        );

        // Listening stopped gracefully
        expect(fakeSpeech.isListening, isFalse);

        // Visible buttons remain fully operable as fallback
        expect(find.text('CAPTURE SCENE'), findsOneWidget);
        expect(find.text('RECORD SHORT VIDEO (MAX 10s)'), findsOneWidget);
      },
    );

    testWidgets(
      'After photo perception completes, description is spoken and voice navigation offers actions again',
      (WidgetTester tester) async {
        fakePerception.resultToReturn = PerceptionResult(
          description: 'A brown dog is sitting on a rug.',
          languageCode: 'en',
          timestamp: DateTime.now(),
          isSuccess: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Issue voice capture command
        fakeSpeech.emitSpeechResult('take photo', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Description was displayed
        expect(find.text('A brown dog is sitting on a rug.'), findsOneWidget);

        // Description was spoken, followed by the follow-up prompt
        expect(
          fakeTts.spokenTexts.contains('A brown dog is sitting on a rug.'),
          isTrue,
        );
        expect(
          fakeTts.lastSpokenText,
          'To perceive again, you can say "Take a photo" or "Record video".',
        );

        // Listening is re-enabled for subsequent action
        expect(fakeSpeech.isListening, isTrue);
      },
    );

    testWidgets(
      'Video review screen prompts user and responds to "Analyze" voice command',
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Start recording
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();

        // Stop recording -> transitions to review screen
        await tester.tap(find.text('STOP RECORDING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Review screen is displayed
        expect(find.text('Video Recorded — Ready to Analyze'), findsOneWidget);

        // Review screen voice prompt spoken
        expect(
          fakeTts.lastSpokenText,
          'Video recorded. Say "Analyze" to analyze the video, or "Retake" to record again.',
        );

        // User speaks "analyze"
        fakeSpeech.emitSpeechResult('analyze', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Perception API was called
        expect(fakePerception.perceiveVideoFileCallCount, 1);
      },
    );

    testWidgets(
      'Video review screen responds to "Retake" voice command by returning to live camera',
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Start and stop recording to reach review screen
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.tap(find.text('STOP RECORDING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // User speaks "retake"
        fakeSpeech.emitSpeechResult('retake', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Returned to live camera
        expect(find.text('CAPTURE SCENE'), findsOneWidget);
        expect(find.text('RECORD SHORT VIDEO (MAX 10s)'), findsOneWidget);
      },
    );

    testWidgets(
      'Video review screen in Telugu speaks Tenglish prompt and listens with te_IN locale',
      (WidgetTester tester) async {
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Start and stop recording to reach review screen
        await tester.tap(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
        );
        await tester.pump();
        await tester.tap(find.text('రికార్డింగ్ ఆపు (STOP)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Review screen prompt spoken in Tenglish with te-IN locale
        expect(fakeTts.lastLocale, 'te-IN');
        expect(
          fakeTts.lastSpokenText,
          'Video ayindi. Choodalante "Choodu" ani cheppu. Malli video teeyalante "Malli teeyi" ani cheppu.',
        );

        // Visual Voice Banner in Tenglish
        expect(find.byIcon(Icons.mic), findsOneWidget);
        expect(
          find.text('Vintoo undi... "Choodu" leda "Malli teeyi" ani cheppandi'),
          findsOneWidget,
        );

        // Speech recognition listening with te_IN
        expect(fakeSpeech.isListening, isTrue);
      },
    );

    testWidgets(
      'Video review screen in Telugu recognizes Tenglish "choodu" and runs video perception',
      (WidgetTester tester) async {
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Record short video
        await tester.tap(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
        );
        await tester.pump();
        await tester.tap(find.text('రికార్డింగ్ ఆపు (STOP)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // User speaks Tenglish analyze command "choodu"
        fakeSpeech.emitSpeechResult('choodu', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Video perception triggered with Telugu language
        expect(fakePerception.perceiveVideoFileCallCount, 1);
        expect(fakePerception.lastVideoLanguageReceived, 'te');
      },
    );

    testWidgets(
      'Video review screen in Telugu recognizes "చూడు" and runs video perception',
      (WidgetTester tester) async {
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Record short video
        await tester.tap(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
        );
        await tester.pump();
        await tester.tap(find.text('రికార్డింగ్ ఆపు (STOP)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // User speaks Telugu script command "చూడు"
        fakeSpeech.emitSpeechResult('చూడు', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Video perception triggered with Telugu language
        expect(fakePerception.perceiveVideoFileCallCount, 1);
        expect(fakePerception.lastVideoLanguageReceived, 'te');
      },
    );

    testWidgets(
      'Video review screen in Telugu recognizes Tenglish "malli teeyi" retake command and returns to main camera menu',
      (WidgetTester tester) async {
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Record short video
        await tester.tap(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
        );
        await tester.pump();
        await tester.tap(find.text('రికార్డింగ్ ఆపు (STOP)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // User speaks Tenglish retake command
        fakeSpeech.emitSpeechResult('malli teeyi', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Discarded video and returned to live camera controls
        expect(find.text('క్యాప్చర్ (CAPTURE)'), findsOneWidget);
        expect(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
          findsOneWidget,
        );

        // Spoke main camera prompt in Tenglish
        expect(
          fakeTts.lastSpokenText,
          'Meeru "Photo teeyi" leda "Video record cheyi" ani cheppavachu.',
        );
      },
    );

    testWidgets(
      'Video review screen handles unclear command with Tenglish retry guidance',
      (WidgetTester tester) async {
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Record short video
        await tester.tap(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
        );
        await tester.pump();
        await tester.tap(find.text('రికార్డింగ్ ఆపు (STOP)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // User speaks unrecognized command on review screen
        fakeSpeech.emitSpeechResult('something unrecognized', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Spoke retry prompt with the 2 valid commands in Tenglish
        expect(
          fakeTts.lastSpokenText,
          'Meeru cheppinadi ardham kaaledu. Dayachesi "Choodu" leda "Malli teeyi" ani cheppandi.',
        );

        // Does NOT analyze or discard video
        expect(fakePerception.perceiveVideoFileCallCount, 0);
        expect(find.text('విశ్లేషించు (ANALYZE)'), findsOneWidget);
        expect(find.text('రీటేక్ (RETAKE)'), findsOneWidget);
      },
    );

    testWidgets(
      'Video review screen treats main menu command ("photo theeyi") as unclear and repeats review options',
      (WidgetTester tester) async {
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Record short video
        await tester.tap(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
        );
        await tester.pump();
        await tester.tap(find.text('రికార్డింగ్ ఆపు (STOP)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // User says "photo theeyi" while on review screen
        fakeSpeech.emitSpeechResult('photo theeyi', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Does not capture photo; instead repeats review guidance
        expect(fakeCamera.takePictureCallCount, 0);
        expect(
          fakeTts.lastSpokenText,
          'Meeru cheppinadi ardham kaaledu. Dayachesi "Choodu" leda "Malli teeyi" ani cheppandi.',
        );
      },
    );

    testWidgets(
      'Video review screen stops after 3 failed attempts and leaves on-screen buttons operable',
      (WidgetTester tester) async {
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
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Record short video
        await tester.tap(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
        );
        await tester.pump();
        await tester.tap(find.text('రికార్డింగ్ ఆపు (STOP)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Attempt 1: unclear
        fakeSpeech.emitSpeechResult('unclear 1', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Attempt 2: unclear
        fakeSpeech.emitSpeechResult('unclear 2', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Attempt 3: unclear (exceeds _maxVoiceCommandRetries = 2)
        fakeSpeech.emitSpeechResult('unclear 3', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Fallback guidance spoken in Tenglish
        expect(
          fakeTts.lastSpokenText,
          'Voice command gurtinchabadaledu. Meeru screen pai unna buttons ni use cheyavachu.',
        );

        // Listening stopped
        expect(fakeSpeech.isListening, isFalse);

        // Buttons remain interactive fallback
        expect(find.text('విశ్లేషించు (ANALYZE)'), findsOneWidget);
        expect(find.text('రీటేక్ (RETAKE)'), findsOneWidget);

        // Manual tap on ANALYZE button works
        await tester.tap(find.text('విశ్లేషించు (ANALYZE)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePerception.perceiveVideoFileCallCount, 1);
      },
    );

    testWidgets(
      'Analysis error speaks failure in Telugu and recovers via spoken "Retry"',
      (WidgetTester tester) async {
        fakePrefs.preferredLanguage = AppLanguage.telugu;
        fakeCamera.fileToReturn = XFile('timeout_scene.jpg');
        fakePerception.resultToReturn = PerceptionResult.error(
          'Gemini vision analysis timed out. Please try again.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Initial capture command
        fakeSpeech.emitSpeechResult('photo theeyi', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // First attempt failed with timeout
        expect(fakePerception.perceiveFileCallCount, 1);
        expect(fakeTts.lastSpokenText, contains('Analysis fail ayindi: Gemini vision analysis timed out'));

        // Recognizer enters recoverable listening mode for error
        expect(fakeSpeech.isListening, isTrue);

        // User speaks "Retry"
        fakeSpeech.emitSpeechResult('Retry', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Perception was retried on the existing photo
        expect(fakePerception.perceiveFileCallCount, 2);
      },
    );

    testWidgets(
      'Analysis error recovers via spoken "Photo theeyi" to take new photo',
      (WidgetTester tester) async {
        fakePrefs.preferredLanguage = AppLanguage.telugu;
        fakeCamera.fileToReturn = XFile('photo_1.jpg');
        fakePerception.resultToReturn = PerceptionResult.error(
          'Gemini vision analysis timed out. Please try again.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              permissionService: fakePermission,
              speechRecognitionService: fakeSpeech,
              languagePreferencesService: fakePrefs,
              enableVoiceNavigation: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Initial capture
        fakeSpeech.emitSpeechResult('photo theeyi', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(fakeCamera.takePictureCallCount, 1);

        // First attempt failed
        expect(fakeSpeech.isListening, isTrue);

        // User speaks "Photo theeyi" to capture a fresh photo
        fakeCamera.fileToReturn = XFile('photo_2.jpg');
        fakeSpeech.emitSpeechResult('photo theeyi', isFinal: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // New photo was captured
        expect(fakeCamera.takePictureCallCount, 2);
      },
    );
  });
}
