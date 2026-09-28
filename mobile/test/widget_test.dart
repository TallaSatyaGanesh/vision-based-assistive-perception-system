import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/speech_recognition_service.dart';
import 'package:mobile/core/audio/tts_service.dart';
import 'package:mobile/features/camera/camera_service.dart';
import 'package:mobile/features/camera/image_capture_service.dart';
import 'package:mobile/features/camera/permission_service.dart';
import 'package:mobile/features/camera/presentation/camera_screen.dart';
import 'package:mobile/features/language/app_language.dart';
import 'package:mobile/features/language/language_preferences_service.dart';
import 'package:mobile/features/perception/models/perception_result.dart';
import 'package:mobile/features/perception/services/perception_api_service.dart';
import 'package:mobile/main.dart';

/// Test mock implementation of BaseCameraService.
class FakeCameraService implements BaseCameraService {
  bool initialized = false;
  bool isTakingPictureFlag = false;
  bool isRecordingVideoFlag = false;
  String? error;
  List<CameraDescription> cameras = [];
  CameraDescription? selectedCamera;
  XFile? fileToReturn;
  XFile? videoToReturn;
  int takePictureCallCount = 0;
  int startVideoRecordingCallCount = 0;
  int stopVideoRecordingCallCount = 0;
  int switchCameraCallCount = 0;
  int disposeCallCount = 0;
  int initializeCallCount = 0;

  @override
  List<CameraDescription> get availableCamerasList => cameras;

  @override
  CameraController? get controller => null;

  @override
  bool get isInitialized => initialized;

  @override
  bool get isTakingPicture => isTakingPictureFlag;

  @override
  bool get isRecordingVideo => isRecordingVideoFlag;

  @override
  String? get errorMessage => error;

  @override
  CameraDescription? get currentCamera => selectedCamera;

  @override
  Future<void> initialize() async {
    initializeCallCount++;
    if (error == null) {
      initialized = true;
    }
  }

  @override
  Future<XFile?> takePicture() async {
    takePictureCallCount++;
    return fileToReturn;
  }

  @override
  Future<void> startVideoRecording() async {
    startVideoRecordingCallCount++;
    if (error == null) {
      isRecordingVideoFlag = true;
    }
  }

  @override
  Future<XFile?> stopVideoRecording() async {
    stopVideoRecordingCallCount++;
    isRecordingVideoFlag = false;
    return videoToReturn;
  }

  @override
  Future<void> switchCamera() async {
    switchCameraCallCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    initialized = false;
    isRecordingVideoFlag = false;
  }
}

/// Test mock implementation of BasePerceptionApiService.
class FakePerceptionApiService implements BasePerceptionApiService {
  PerceptionResult? resultToReturn;
  Completer<PerceptionResult>? pendingCompleter;
  int perceiveFileCallCount = 0;
  String? lastLanguageReceived;

  int perceiveVideoFileCallCount = 0;
  String? lastVideoLanguageReceived;
  XFile? lastVideoFileReceived;

  @override
  Future<PerceptionResult> perceiveFile({
    required XFile file,
    String language = 'en',
  }) async {
    perceiveFileCallCount++;
    lastLanguageReceived = language;
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    if (resultToReturn != null) {
      return resultToReturn!;
    }
    return PerceptionResult(
      description: language == 'te'
          ? 'మీ ముందు రోడ్డు దగ్గర ఒక వ్యక్తి ఉన్నారు.'
          : 'A person is standing in front of you. A paved sidewalk is nearby.',
      languageCode: language,
      timestamp: DateTime.now(),
      isSuccess: true,
    );
  }

  @override
  Future<PerceptionResult> perceiveImage({
    required String imagePath,
    String language = 'en',
    Uint8List? imageBytes,
  }) async {
    return perceiveFile(file: XFile(imagePath), language: language);
  }

  @override
  Future<PerceptionResult> perceiveVideoFile({
    required XFile file,
    String language = 'en',
    Uint8List? videoBytes,
  }) async {
    perceiveVideoFileCallCount++;
    lastVideoLanguageReceived = language;
    lastVideoFileReceived = file;
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    if (resultToReturn != null) {
      return resultToReturn!;
    }
    return PerceptionResult(
      description: language == 'te'
          ? 'ఒక వ్యక్తి కుడి వైపుకు నడుస్తూ మెట్లు ఎక్కుతున్నారు.'
          : 'A person is walking towards the right and climbing stairs.',
      languageCode: language,
      timestamp: DateTime.now(),
      isSuccess: true,
    );
  }
}

/// Test mock implementation of BaseTtsService.
class FakeTtsService implements BaseTtsService {
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
  }

  int speakAndWaitCallCount = 0;
  final List<String> spokenTexts = [];

  @override
  Future<void> speak(String text, {String locale = 'en-US'}) async {
    if (throwOnSpeak) {
      throw Exception('Telugu TTS voice not installed on device');
    }
    speakCallCount++;
    lastSpokenText = text;
    spokenTexts.add(text);
    lastLocale = locale;
    isSpeakingFlag = true;
  }

  @override
  Future<void> speakAndWait(String text, {String locale = 'en-US'}) async {
    speakAndWaitCallCount++;
    await speak(text, locale: locale);
    isSpeakingFlag = false;
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

/// Test mock implementation of BasePermissionService.
class FakePermissionService implements BasePermissionService {
  AppPermissionStatus statusToReturn = AppPermissionStatus.granted;
  int requestMicrophonePermissionCallCount = 0;
  int checkMicrophonePermissionCallCount = 0;
  int openAppSettingsCallCount = 0;
  bool shouldThrowOnRequest = false;

  @override
  Future<AppPermissionStatus> requestMicrophonePermission() async {
    requestMicrophonePermissionCallCount++;
    if (shouldThrowOnRequest) {
      throw Exception('Permission request platform failure');
    }
    return statusToReturn;
  }

  @override
  Future<AppPermissionStatus> checkMicrophonePermission() async {
    checkMicrophonePermissionCallCount++;
    return statusToReturn;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCallCount++;
    return true;
  }
}

/// Test mock implementation of BaseLanguagePreferencesService.
class FakeLanguagePreferencesService implements BaseLanguagePreferencesService {
  AppLanguage? preferredLanguage;
  bool hasPreference = false;
  int setPreferredLanguageCallCount = 0;
  int getPreferredLanguageCallCount = 0;
  int hasLanguagePreferenceCallCount = 0;
  int clearPreferenceCallCount = 0;

  @override
  Future<AppLanguage?> getPreferredLanguage() async {
    getPreferredLanguageCallCount++;
    return preferredLanguage;
  }

  @override
  Future<void> setPreferredLanguage(AppLanguage language) async {
    setPreferredLanguageCallCount++;
    preferredLanguage = language;
    hasPreference = true;
  }

  @override
  Future<bool> hasLanguagePreference() async {
    hasLanguagePreferenceCallCount++;
    return hasPreference;
  }

  @override
  Future<void> clearPreference() async {
    clearPreferenceCallCount++;
    preferredLanguage = null;
    hasPreference = false;
  }
}

/// Test mock implementation of BaseSpeechRecognitionService.
class FakeSpeechRecognitionService implements BaseSpeechRecognitionService {
  bool isListeningFlag = false;
  bool isAvailableFlag = true;
  int initializeCallCount = 0;
  int startListeningCallCount = 0;
  int stopListeningCallCount = 0;
  int cancelListeningCallCount = 0;
  Function(String recognizedWords, bool isFinal)? onResultCallback;
  String? wordsToEmitOnListen;
  bool isFinalToEmitOnListen = true;
  bool shouldThrowOnListen = false;

  @override
  bool get isListening => isListeningFlag;

  Function(String status)? onStatusCallback;
  Function(String errorMsg)? onErrorCallback;

  @override
  bool get isAvailable => isAvailableFlag;

  @override
  Future<bool> initialize({
    Function(String errorMsg)? onError,
    Function(String status)? onStatus,
  }) async {
    initializeCallCount++;
    onErrorCallback = onError;
    onStatusCallback = onStatus;
    return isAvailableFlag;
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
    startListeningCallCount++;
    if (shouldThrowOnListen) {
      throw Exception('Speech recognition hardware failure');
    }
    isListeningFlag = true;
    onResultCallback = onResult;
    if (onStatus != null) onStatusCallback = onStatus;
    if (onError != null) onErrorCallback = onError;

    if (wordsToEmitOnListen != null) {
      onResult(wordsToEmitOnListen!, isFinalToEmitOnListen);
    }
  }

  void emitSpeechResult(String words, {bool isFinal = true}) {
    onResultCallback?.call(words, isFinal);
  }

  void emitStatus(String status) {
    isListeningFlag = status == 'listening';
    onStatusCallback?.call(status);
  }

  void emitError(String errorMsg) {
    isListeningFlag = false;
    onErrorCallback?.call(errorMsg);
  }

  @override
  Future<void> stopListening() async {
    stopListeningCallCount++;
    isListeningFlag = false;
  }

  @override
  Future<void> cancelListening() async {
    cancelListeningCallCount++;
    isListeningFlag = false;
  }

  @override
  void dispose() {
    stopListening();
  }
}

void main() {
  setUp(() {
    CameraScreen.debugDefaultPermissionService = FakePermissionService();
    CameraScreen.debugDefaultLanguagePreferencesService =
        FakeLanguagePreferencesService()
          ..hasPreference = true
          ..preferredLanguage = AppLanguage.english;
    CameraScreen.debugDefaultSpeechRecognitionService =
        FakeSpeechRecognitionService();
    CameraScreen.debugDefaultEnableVoiceNavigation = false;
  });

  tearDown(() {
    CameraScreen.debugDefaultPermissionService = null;
    CameraScreen.debugDefaultLanguagePreferencesService = null;
    CameraScreen.debugDefaultSpeechRecognitionService = null;
    CameraScreen.debugDefaultEnableVoiceNavigation = null;
  });

  group('Assistive Camera App & Multilingual Perception Widget Tests', () {
    testWidgets(
      'Displays AppBar header, active camera controls, and language selector (English & Telugu)',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService();

        await tester.pumpWidget(
          AssistivePerceptionApp(cameraService: fakeCamera),
        );
        await tester.pumpAndSettle();

        // Verify Header
        expect(find.text('Assistive Camera'), findsOneWidget);

        // Verify Language Selector Buttons
        expect(find.text('ENGLISH'), findsOneWidget);
        expect(find.text('తెలుగు (TELUGU)'), findsOneWidget);

        // Verify Camera Active Status
        expect(
          find.text('Camera Active — Point at surroundings'),
          findsOneWidget,
        );

        // Verify Viewfinder Placeholder
        expect(find.text('Live Camera Viewfinder'), findsOneWidget);

        // Verify Accessible Large Capture Button
        expect(find.text('CAPTURE SCENE'), findsOneWidget);
        expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      },
    );

    testWidgets(
      'Default English selection sends language=en and triggers en-US TTS with returned English description',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..fileToReturn = XFile('test_photo.jpg');
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Capture button in default English mode
        expect(find.text('CAPTURE SCENE'), findsOneWidget);
        await tester.tap(find.text('CAPTURE SCENE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify English sent to backend
        expect(fakePerception.lastLanguageReceived, 'en');

        // Verify English TTS locale and description
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastLocale, 'en-US');
        expect(
          fakeTts.lastSpokenText,
          'A person is standing in front of you. A paved sidewalk is nearby.',
        );

        // Verify description displayed on screen
        expect(
          find.text(
            'A person is standing in front of you. A paved sidewalk is nearby.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Telugu selection sends language=te, triggers te-IN TTS, and displays Telugu description',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..fileToReturn = XFile('test_photo.jpg');
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Telugu Language Selector
        await tester.tap(find.text('తెలుగు (TELUGU)'));
        await tester.pumpAndSettle();

        // Verify button updated to Telugu capture text
        expect(find.text('క్యాప్చర్ (CAPTURE)'), findsOneWidget);

        // Tap Capture button
        await tester.tap(find.text('క్యాప్చర్ (CAPTURE)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Telugu language code sent to backend
        expect(fakePerception.lastLanguageReceived, 'te');

        // Verify Telugu TTS locale te-IN used
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastLocale, 'te-IN');
        expect(
          fakeTts.lastSpokenText,
          'మీ ముందు రోడ్డు దగ్గర ఒక వ్యక్తి ఉన్నారు.',
        );

        // Verify Telugu description displayed on screen
        expect(find.text('దృశ్యం గుర్తించబడింది'), findsOneWidget);
        expect(
          find.text('మీ ముందు రోడ్డు దగ్గర ఒక వ్యక్తి ఉన్నారు.'),
          findsOneWidget,
        );

        // Verify photo preview is still visible
        expect(find.text('Photo captured: test_photo.jpg'), findsOneWidget);
      },
    );

    testWidgets(
      'Switching from English to Telugu after perception completes stops TTS, re-runs perception with language=te, and speaks in Telugu',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..fileToReturn = XFile('test_photo.jpg');
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Capture photo in English
        await tester.tap(find.text('CAPTURE SCENE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePerception.perceiveFileCallCount, 1);
        expect(fakePerception.lastLanguageReceived, 'en');
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastLocale, 'en-US');
        expect(
          find.text(
            'A person is standing in front of you. A paved sidewalk is nearby.',
          ),
          findsOneWidget,
        );

        // Now switch language to Telugu while captured photo is displayed
        await tester.tap(find.text('తెలుగు (TELUGU)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // TTS should have been stopped
        expect(fakeTts.stopCallCount, greaterThanOrEqualTo(1));

        // Perception re-run in Telugu
        expect(fakePerception.perceiveFileCallCount, 2);
        expect(fakePerception.lastLanguageReceived, 'te');

        // Spoken in Telugu locale
        expect(fakeTts.speakCallCount, 2);
        expect(fakeTts.lastLocale, 'te-IN');
        expect(
          fakeTts.lastSpokenText,
          'మీ ముందు రోడ్డు దగ్గర ఒక వ్యక్తి ఉన్నారు.',
        );

        // Telugu description displayed on screen
        expect(
          find.text('మీ ముందు రోడ్డు దగ్గర ఒక వ్యక్తి ఉన్నారు.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Switching from Telugu to English after perception completes stops TTS, re-runs perception with language=en, and speaks in English',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..fileToReturn = XFile('test_photo.jpg');
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              initialLanguage: AppLanguage.telugu,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Capture photo in Telugu
        await tester.tap(find.text('క్యాప్చర్ (CAPTURE)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePerception.perceiveFileCallCount, 1);
        expect(fakePerception.lastLanguageReceived, 'te');
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastLocale, 'te-IN');

        // Now switch language to English while captured photo is displayed
        await tester.tap(find.text('ENGLISH'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // TTS should have been stopped
        expect(fakeTts.stopCallCount, greaterThanOrEqualTo(1));

        // Perception re-run in English
        expect(fakePerception.perceiveFileCallCount, 2);
        expect(fakePerception.lastLanguageReceived, 'en');

        // Spoken in English locale
        expect(fakeTts.speakCallCount, 2);
        expect(fakeTts.lastLocale, 'en-US');
        expect(
          fakeTts.lastSpokenText,
          'A person is standing in front of you. A paved sidewalk is nearby.',
        );

        // English description displayed on screen
        expect(
          find.text(
            'A person is standing in front of you. A paved sidewalk is nearby.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Switching language on live camera does NOT trigger perception before capture',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..fileToReturn = XFile('test_photo.jpg');
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch language before capture
        await tester.tap(find.text('తెలుగు (TELUGU)'));
        await tester.pumpAndSettle();

        // No perception call should have occurred
        expect(fakePerception.perceiveFileCallCount, 0);
        expect(fakeTts.speakCallCount, 0);

        // When photo is captured later, it uses Telugu
        await tester.tap(find.text('క్యాప్చర్ (CAPTURE)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePerception.perceiveFileCallCount, 1);
        expect(fakePerception.lastLanguageReceived, 'te');
      },
    );

    testWidgets(
      'When Telugu TTS fails, app does NOT crash and continues displaying Telugu description',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..fileToReturn = XFile('test_photo.jpg');
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService()..throwOnSpeak = true;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
              initialLanguage: AppLanguage.telugu,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap capture in Telugu mode with failing TTS
        await tester.tap(find.text('క్యాప్చర్ (CAPTURE)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // App must NOT crash; Telugu description must remain visible
        expect(
          find.text('మీ ముందు రోడ్డు దగ్గర ఒక వ్యక్తి ఉన్నారు.'),
          findsOneWidget,
        );

        // Retake button is present and functional
        expect(find.text('మళ్ళీ తీయి (RETAKE PHOTO)'), findsOneWidget);
        await tester.tap(find.text('మళ్ళీ తీయి (RETAKE PHOTO)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Returned safely to camera
        expect(find.text('క్యాప్చర్ (CAPTURE)'), findsOneWidget);
      },
    );

    testWidgets(
      'Shows loading state and does NOT speak while perception is in-flight',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..fileToReturn = XFile('test_photo.jpg');
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();
        final completer = Completer<PerceptionResult>();
        fakePerception.pendingCompleter = completer;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Capture
        await tester.tap(find.text('CAPTURE SCENE'));
        await tester.pump();

        // Verify Loading states are shown
        expect(find.text('Analyzing Environment...'), findsOneWidget);
        expect(find.text('Analyzing Scene...'), findsOneWidget);

        // Speech must NOT be triggered during loading
        expect(fakeTts.speakCallCount, 0);

        // Complete the request
        completer.complete(
          PerceptionResult(
            description: 'A hallway with doors on either side.',
            languageCode: 'en',
            timestamp: DateTime.now(),
            isSuccess: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // After loading finishes, speech is triggered exactly once
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastLocale, 'en-US');
        expect(fakeTts.lastSpokenText, 'A hallway with doors on either side.');
        expect(find.text('Scene Understood'), findsOneWidget);
      },
    );

    testWidgets(
      'Displays error UI, retry button, and does NOT trigger speech when perception fails',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..fileToReturn = XFile('test_photo.jpg');
        final fakePerception = FakePerceptionApiService()
          ..resultToReturn = PerceptionResult.error(
            'Unable to reach backend server. Please verify the server is running.',
          );
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Capture
        await tester.tap(find.text('CAPTURE SCENE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Error state
        expect(find.text('Analysis Error'), findsOneWidget);
        expect(find.text('Perception Failed'), findsOneWidget);
        expect(
          find.text(
            'Unable to reach backend server. Please verify the server is running.',
          ),
          findsOneWidget,
        );

        // Verify speech was NEVER triggered on failure
        expect(fakeTts.speakCallCount, 0);

        // Now set success and tap RETRY
        fakePerception.resultToReturn = PerceptionResult(
          description: 'Perception retry succeeded. Clear walkway.',
          languageCode: 'en',
          timestamp: DateTime.now(),
          isSuccess: true,
        );

        await tester.tap(find.text('RETRY'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePerception.perceiveFileCallCount, 2);
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastLocale, 'en-US');
        expect(
          fakeTts.lastSpokenText,
          'Perception retry succeeded. Clear walkway.',
        );
        expect(find.text('Scene Understood'), findsOneWidget);
      },
    );

    testWidgets('STOP SPEECH control stops playback', (
      WidgetTester tester,
    ) async {
      final fakeCamera = FakeCameraService()
        ..fileToReturn = XFile('test_photo.jpg');
      final fakePerception = FakePerceptionApiService();
      final fakeTts = FakeTtsService();

      await tester.pumpWidget(
        MaterialApp(
          home: CameraScreen(
            cameraService: fakeCamera,
            perceptionApiService: fakePerception,
            ttsService: fakeTts,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Capture photo
      await tester.tap(find.text('CAPTURE SCENE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeTts.isSpeaking, isTrue);

      // Tap STOP SPEECH control
      expect(find.text('STOP SPEECH'), findsOneWidget);
      await tester.tap(find.text('STOP SPEECH'));
      await tester.pump();

      expect(fakeTts.stopCallCount, 1);
      expect(fakeTts.isSpeaking, isFalse);
    });

    testWidgets(
      'Camera switch button appears when multiple cameras are available',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..cameras = [
            const CameraDescription(
              name: '0',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 90,
            ),
            const CameraDescription(
              name: '1',
              lensDirection: CameraLensDirection.front,
              sensorOrientation: 270,
            ),
          ];

        await tester.pumpWidget(
          MaterialApp(home: CameraScreen(cameraService: fakeCamera)),
        );
        await tester.pumpAndSettle();

        // Verify switch camera icon button is present via tooltip
        final switchBtn = find.byTooltip('Switch camera');
        expect(switchBtn, findsOneWidget);

        await tester.tap(switchBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakeCamera.switchCameraCallCount, 1);
      },
    );

    testWidgets(
      'Live camera state displays RECORD SHORT VIDEO secondary button and omits gallery video button',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService();

        await tester.pumpWidget(
          MaterialApp(home: CameraScreen(cameraService: fakeCamera)),
        );
        await tester.pumpAndSettle();

        // English record button present, gallery button omitted
        expect(find.text('RECORD SHORT VIDEO (MAX 10s)'), findsOneWidget);
        expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
        expect(find.text('SELECT SHORT VIDEO (MAX 10s)'), findsNothing);
        expect(find.byIcon(Icons.video_library_rounded), findsNothing);

        // Switch to Telugu
        await tester.tap(find.text('తెలుగు (TELUGU)'));
        await tester.pumpAndSettle();

        // Telugu record button present, gallery button omitted
        expect(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
          findsOneWidget,
        );
        expect(
          find.text('చిన్న వీడియోను ఎంచుకోండి (గరిష్టం 10సె)'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Starting short video recording updates UI to recording state with countdown and STOP RECORDING button',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService();

        await tester.pumpWidget(
          MaterialApp(home: CameraScreen(cameraService: fakeCamera)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();

        expect(fakeCamera.startVideoRecordingCallCount, 1);
        expect(fakeCamera.isRecordingVideoFlag, isTrue);

        // Displays stop recording button & icon
        expect(find.text('STOP RECORDING'), findsOneWidget);
        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

        // Displays REC badge and banner
        expect(find.text('REC 00:10'), findsOneWidget);
        expect(find.text('RECORDING VIDEO (10s remaining)'), findsOneWidget);
      },
    );

    testWidgets(
      'Stopping recording displays video review preview with RETAKE and ANALYZE VIDEO buttons without uploading yet',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..videoToReturn = XFile.fromData(
            Uint8List.fromList([0, 0, 0, 1]),
            name: 'camera_capture.mp4',
            path: 'camera_capture.mp4',
          );
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start recording
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();

        // Stop recording
        await tester.tap(find.text('STOP RECORDING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakeCamera.stopVideoRecordingCallCount, 1);
        // Perception API has NOT been called yet
        expect(fakePerception.perceiveVideoFileCallCount, 0);

        // Review screen controls and info
        expect(find.text('Video Recorded — Ready to Analyze'), findsOneWidget);
        expect(find.text('Recorded Short Video'), findsOneWidget);
        expect(find.text('camera_capture.mp4'), findsOneWidget);
        expect(find.text('RETAKE'), findsOneWidget);
        expect(find.text('ANALYZE VIDEO'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping ANALYZE VIDEO uploads recorded video in English, sends language=en, and speaks via TTS',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..videoToReturn = XFile.fromData(
            Uint8List.fromList([0, 0, 0, 1]),
            name: 'walking_scene.mp4',
            path: 'walking_scene.mp4',
          );
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start and stop recording
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.tap(find.text('STOP RECORDING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePerception.perceiveVideoFileCallCount, 0);

        // Tap ANALYZE VIDEO
        await tester.tap(find.text('ANALYZE VIDEO'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify perception API called with language=en
        expect(fakePerception.perceiveVideoFileCallCount, 1);
        expect(fakePerception.lastVideoLanguageReceived, 'en');
        expect(fakePerception.lastVideoFileReceived?.name, 'walking_scene.mp4');

        // Verify Video Info Card is displayed
        expect(find.text('Recorded Short Video'), findsOneWidget);
        expect(find.text('walking_scene.mp4'), findsOneWidget);
        expect(find.text('Video Understood'), findsOneWidget);

        // Verify TTS spoken in en-US
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastLocale, 'en-US');
        expect(
          fakeTts.lastSpokenText,
          'A person is walking towards the right and climbing stairs.',
        );

        // Verify description shown on screen
        expect(
          find.text(
            'A person is walking towards the right and climbing stairs.',
          ),
          findsOneWidget,
        );
        expect(find.text('RECORD NEW VIDEO'), findsOneWidget);
      },
    );

    testWidgets(
      'Recording and analyzing in Telugu sends language=te, displays Telugu description, and speaks in te-IN',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..videoToReturn = XFile.fromData(
            Uint8List.fromList([0, 0, 0, 1]),
            name: 'walking_scene.mp4',
            path: 'walking_scene.mp4',
          );
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Telugu
        await tester.tap(find.text('తెలుగు (TELUGU)'));
        await tester.pumpAndSettle();

        // Tap record
        await tester.tap(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
        );
        await tester.pump();

        expect(fakeCamera.startVideoRecordingCallCount, 1);
        expect(find.text('రికార్డింగ్ ఆపు (STOP)'), findsOneWidget);

        // Stop recording
        await tester.tap(find.text('రికార్డింగ్ ఆపు (STOP)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakeCamera.stopVideoRecordingCallCount, 1);
        expect(fakePerception.perceiveVideoFileCallCount, 0);

        // Telugu review screen controls
        expect(find.text('రీటేక్ (RETAKE)'), findsOneWidget);
        expect(find.text('విశ్లేషించు (ANALYZE)'), findsOneWidget);

        // Tap Analyze Video
        await tester.tap(find.text('విశ్లేషించు (ANALYZE)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePerception.perceiveVideoFileCallCount, 1);
        expect(fakePerception.lastVideoLanguageReceived, 'te');

        // Verify TTS spoken in te-IN
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastLocale, 'te-IN');
        expect(
          fakeTts.lastSpokenText,
          'ఒక వ్యక్తి కుడి వైపుకు నడుస్తూ మెట్లు ఎక్కుతున్నారు.',
        );

        // Verify Telugu description on screen
        expect(find.text('వీడియో గుర్తించబడింది'), findsOneWidget);
        expect(
          find.text('ఒక వ్యక్తి కుడి వైపుకు నడుస్తూ మెట్లు ఎక్కుతున్నారు.'),
          findsOneWidget,
        );
        expect(find.text('కొత్త రికార్డింగ్ (NEW RECORDING)'), findsOneWidget);
      },
    );

    testWidgets(
      'Recording automatically stops at 10-second limit and transitions to review screen',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..videoToReturn = XFile.fromData(
            Uint8List.fromList([0, 0, 0, 1]),
            name: 'autostop_video.mp4',
            path: 'autostop_video.mp4',
          );

        await tester.pumpWidget(
          MaterialApp(home: CameraScreen(cameraService: fakeCamera)),
        );
        await tester.pumpAndSettle();

        // Start recording
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();

        expect(fakeCamera.isRecordingVideoFlag, isTrue);

        // Step through 10 seconds of periodic timer
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump(const Duration(milliseconds: 100));

        // Verify recording auto-stopped
        expect(fakeCamera.stopVideoRecordingCallCount, 1);
        expect(fakeCamera.isRecordingVideoFlag, isFalse);

        // Review screen is displayed
        expect(find.text('Video Recorded — Ready to Analyze'), findsOneWidget);
        expect(find.text('ANALYZE VIDEO'), findsOneWidget);
        expect(find.text('RETAKE'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping RETAKE from review screen discards video and returns to live camera view',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..videoToReturn = XFile.fromData(
            Uint8List.fromList([0, 0, 0, 1]),
            name: 'scene.mp4',
            path: 'scene.mp4',
          );
        final fakePerception = FakePerceptionApiService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Record video and stop
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.tap(find.text('STOP RECORDING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('RETAKE'), findsOneWidget);

        // Tap RETAKE
        await tester.tap(find.text('RETAKE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Returned safely to live camera state
        expect(find.text('CAPTURE SCENE'), findsOneWidget);
        expect(find.text('RECORD SHORT VIDEO (MAX 10s)'), findsOneWidget);
        expect(fakePerception.perceiveVideoFileCallCount, 0);
      },
    );

    testWidgets(
      'Switching language after video perception completes stops TTS, re-runs video perception, and speaks in new language',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..videoToReturn = XFile.fromData(
            Uint8List.fromList([0, 0, 0, 1]),
            name: 'scene.mp4',
            path: 'scene.mp4',
          );
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Record video
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.tap(find.text('STOP RECORDING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Analyze video in English
        await tester.tap(find.text('ANALYZE VIDEO'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePerception.perceiveVideoFileCallCount, 1);
        expect(fakePerception.lastVideoLanguageReceived, 'en');
        expect(fakeTts.speakCallCount, 1);

        // Now switch language to Telugu while video result is displayed
        await tester.tap(find.text('తెలుగు (TELUGU)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // TTS should be stopped before re-running
        expect(fakeTts.stopCallCount, greaterThanOrEqualTo(1));

        // Re-run video perception with language=te
        expect(fakePerception.perceiveVideoFileCallCount, 2);
        expect(fakePerception.lastVideoLanguageReceived, 'te');

        // Spoken in Telugu locale
        expect(fakeTts.speakCallCount, 2);
        expect(fakeTts.lastLocale, 'te-IN');
        expect(
          fakeTts.lastSpokenText,
          'ఒక వ్యక్తి కుడి వైపుకు నడుస్తూ మెట్లు ఎక్కుతున్నారు.',
        );
        expect(
          find.text('ఒక వ్యక్తి కుడి వైపుకు నడుస్తూ మెట్లు ఎక్కుతున్నారు.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Video perception shows loading indicator and does NOT speak while in-flight',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..videoToReturn = XFile.fromData(
            Uint8List.fromList([0, 0, 0, 1]),
            name: 'scene.mp4',
            path: 'scene.mp4',
          );
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();
        final completer = Completer<PerceptionResult>();
        fakePerception.pendingCompleter = completer;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Record video and stop
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.tap(find.text('STOP RECORDING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Tap analyze video
        await tester.tap(find.text('ANALYZE VIDEO'));
        await tester.pump();

        // Verify loading state
        expect(find.text('Analyzing Video...'), findsOneWidget);
        expect(find.text('Processing Video Scene...'), findsOneWidget);
        expect(find.text('Sending video to perception engine'), findsOneWidget);
        expect(fakeTts.speakCallCount, 0);

        // Complete perception
        completer.complete(
          PerceptionResult(
            description: 'A car is passing by on the street.',
            languageCode: 'en',
            timestamp: DateTime.now(),
            isSuccess: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // TTS spoken after completion
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastSpokenText, 'A car is passing by on the street.');
        expect(find.text('Video Understood'), findsOneWidget);
      },
    );

    testWidgets(
      'Video perception failure displays error UI and RETRY button, without speaking',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..videoToReturn = XFile.fromData(
            Uint8List.fromList([0, 0, 0, 1]),
            name: 'scene.mp4',
            path: 'scene.mp4',
          );
        final fakePerception = FakePerceptionApiService()
          ..resultToReturn = PerceptionResult.error(
            'Video duration exceeds maximum allowed (10.0s)',
          );
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Record video and stop
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.tap(find.text('STOP RECORDING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Tap Analyze Video
        await tester.tap(find.text('ANALYZE VIDEO'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify error UI
        expect(find.text('Analysis Error'), findsOneWidget);
        expect(find.text('Perception Failed'), findsOneWidget);
        expect(
          find.text('Video duration exceeds maximum allowed (10.0s)'),
          findsOneWidget,
        );
        expect(fakeTts.speakCallCount, 0);

        // Set success for retry
        fakePerception.resultToReturn = PerceptionResult(
          description: 'Clear sidewalk ahead.',
          languageCode: 'en',
          timestamp: DateTime.now(),
          isSuccess: true,
        );

        // Tap RETRY
        await tester.tap(find.text('RETRY'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePerception.perceiveVideoFileCallCount, 2);
        expect(fakeTts.speakCallCount, 1);
        expect(fakeTts.lastSpokenText, 'Clear sidewalk ahead.');
      },
    );

    testWidgets(
      'Client size validation rejects recorded video over 25 MB before calling backend',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()
          ..videoToReturn = XFile.fromData(
            Uint8List(26 * 1024 * 1024),
            name: 'huge_video.mp4',
            path: 'huge_video.mp4',
          );
        final fakePerception = FakePerceptionApiService();
        final fakeTts = FakeTtsService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              perceptionApiService: fakePerception,
              ttsService: fakeTts,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap record and then stop
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.tap(find.text('STOP RECORDING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Perception API must NOT have been called
        expect(fakePerception.perceiveVideoFileCallCount, 0);
        expect(fakeTts.speakCallCount, 0);

        // Error snackbar displayed
        expect(
          find.text(
            'Recorded video exceeds the 25 MB limit. Please record a shorter clip.',
          ),
          findsOneWidget,
        );
        // Returned to live camera state
        expect(find.text('RECORD SHORT VIDEO (MAX 10s)'), findsOneWidget);
      },
    );

    testWidgets(
      'Recording start failure handles gracefully and displays error SnackBar',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService();

        await tester.pumpWidget(
          MaterialApp(home: CameraScreen(cameraService: fakeCamera)),
        );
        await tester.pumpAndSettle();

        fakeCamera.error = 'Camera hardware error';
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Camera hardware error'), findsOneWidget);
      },
    );

    testWidgets(
      'Recording stop returning null handles gracefully and displays error SnackBar',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService()..videoToReturn = null;

        await tester.pumpWidget(
          MaterialApp(home: CameraScreen(cameraService: fakeCamera)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();

        await tester.tap(find.text('STOP RECORDING'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Failed to record video.'), findsOneWidget);
      },
    );
  });

  group('ImageCaptureService Unit Tests', () {
    test(
      'ImageCaptureService delegates capture to BaseCameraService',
      () async {
        final fakeCamera = FakeCameraService()
          ..fileToReturn = XFile('test_img.jpg');
        final captureService = ImageCaptureService(cameraService: fakeCamera);

        final result = await captureService.captureImage();
        expect(result, isNotNull);
        expect(result!.path, 'test_img.jpg');
        expect(fakeCamera.takePictureCallCount, 1);
      },
    );
  });

  group('Microphone Runtime Permission & Recording Security Tests', () {
    testWidgets(
      'Tapping RECORD SHORT VIDEO requests microphone permission; when granted, video recording begins and countdown starts',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService();
        final fakePermission = FakePermissionService()
          ..statusToReturn = AppPermissionStatus.granted;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              permissionService: fakePermission,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap RECORD SHORT VIDEO
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();

        // Verify microphone permission was requested
        expect(fakePermission.requestMicrophonePermissionCallCount, 1);

        // Verify video recording started
        expect(fakeCamera.startVideoRecordingCallCount, 1);
        expect(fakeCamera.isRecordingVideoFlag, isTrue);
        expect(find.text('STOP RECORDING'), findsOneWidget);
        expect(find.text('REC 00:10'), findsOneWidget);
      },
    );

    testWidgets(
      'When microphone permission is denied in English, recording does not start and high-contrast error SnackBar is shown without crashing',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService();
        final fakePermission = FakePermissionService()
          ..statusToReturn = AppPermissionStatus.denied;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              permissionService: fakePermission,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap RECORD SHORT VIDEO
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify permission was requested
        expect(fakePermission.requestMicrophonePermissionCallCount, 1);

        // Verify camera video recording was NEVER called
        expect(fakeCamera.startVideoRecordingCallCount, 0);
        expect(fakeCamera.isRecordingVideoFlag, isFalse);

        // Verify accessible error SnackBar is displayed in English
        expect(
          find.text(
            'Microphone permission is required to record video. Please allow microphone access.',
          ),
          findsOneWidget,
        );

        // User remains safely on live camera screen
        expect(find.text('CAPTURE SCENE'), findsOneWidget);
        expect(find.text('RECORD SHORT VIDEO (MAX 10s)'), findsOneWidget);
      },
    );

    testWidgets(
      'When microphone permission is denied in Telugu, recording does not start and Telugu error SnackBar is shown',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService();
        final fakePermission = FakePermissionService()
          ..statusToReturn = AppPermissionStatus.denied;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              permissionService: fakePermission,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Telugu
        await tester.tap(find.text('తెలుగు (TELUGU)'));
        await tester.pumpAndSettle();

        // Tap Record Video
        await tester.tap(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePermission.requestMicrophonePermissionCallCount, 1);
        expect(fakeCamera.startVideoRecordingCallCount, 0);
        expect(fakeCamera.isRecordingVideoFlag, isFalse);

        // Verify accessible error SnackBar is displayed in Telugu
        expect(
          find.text(
            'వీడియో రికార్డ్ చేయడానికి మైక్రోఫోన్ అనుమతి అవసరం. దయచేసి అనుమతించండి.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'When microphone permission is permanently denied in English, displays SETTINGS action SnackBar and opens settings on tap',
      (WidgetTester tester) async {
        final fakePermission = FakePermissionService()
          ..statusToReturn = AppPermissionStatus.permanentlyDenied;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: FakeCameraService(),
              permissionService: fakePermission,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap RECORD SHORT VIDEO
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePermission.requestMicrophonePermissionCallCount, 1);

        // Verify permanently denied message and SETTINGS action
        expect(
          find.text(
            'Microphone permission is permanently denied. Please enable it in Settings to record video.',
          ),
          findsOneWidget,
        );
        expect(find.text('SETTINGS'), findsOneWidget);

        // Tap SETTINGS action button
        await tester.tap(find.text('SETTINGS'));
        await tester.pump();

        expect(fakePermission.openAppSettingsCallCount, 1);
      },
    );

    testWidgets(
      'When microphone permission is permanently denied in Telugu, displays Telugu message with సెట్టింగ్స్ action',
      (WidgetTester tester) async {
        final fakePermission = FakePermissionService()
          ..statusToReturn = AppPermissionStatus.permanentlyDenied;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: FakeCameraService(),
              permissionService: fakePermission,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Telugu
        await tester.tap(find.text('తెలుగు (TELUGU)'));
        await tester.pumpAndSettle();

        // Tap Record Video
        await tester.tap(
          find.text('చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePermission.requestMicrophonePermissionCallCount, 1);

        // Verify Telugu message and action
        expect(
          find.text(
            'మైక్రోఫోన్ అనుమతి తిరస్కరించబడింది. వీడియో రికార్డ్ చేయడానికి సెట్టింగ్స్‌లో అనుమతించండి.',
          ),
          findsOneWidget,
        );
        expect(find.text('సెట్టింగ్స్'), findsOneWidget);

        // Tap సెట్టింగ్స్ action button
        await tester.tap(find.text('సెట్టింగ్స్'));
        await tester.pump();

        expect(fakePermission.openAppSettingsCallCount, 1);
      },
    );

    testWidgets(
      'Handles platform channel exception during permission request gracefully without crashing',
      (WidgetTester tester) async {
        final fakePermission = FakePermissionService()
          ..shouldThrowOnRequest = true;

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: FakeCameraService(),
              permissionService: fakePermission,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap record
        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakePermission.requestMicrophonePermissionCallCount, 1);
        expect(
          find.text('Failed to request microphone permission.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Camera recording error with AudioAccessDenied or SecurityException is handled safely',
      (WidgetTester tester) async {
        final fakeCamera = FakeCameraService();

        await tester.pumpWidget(
          MaterialApp(
            home: CameraScreen(
              cameraService: fakeCamera,
              permissionService: FakePermissionService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        fakeCamera.error =
            'Microphone permission is required to record video. Please allow microphone access.';

        await tester.tap(find.text('RECORD SHORT VIDEO (MAX 10s)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text(
            'Microphone permission is required to record video. Please allow microphone access.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('PermissionService Unit Tests', () {
    test('FakePermissionService reports granted and openAppSettings', () async {
      final perm = FakePermissionService();
      expect(
        await perm.checkMicrophonePermission(),
        AppPermissionStatus.granted,
      );
      expect(
        await perm.requestMicrophonePermission(),
        AppPermissionStatus.granted,
      );
      expect(await perm.openAppSettings(), isTrue);
      expect(perm.requestMicrophonePermissionCallCount, 1);
      expect(perm.checkMicrophonePermissionCallCount, 1);
      expect(perm.openAppSettingsCallCount, 1);
    });

    test(
      'FakePermissionService reports denied and permanentlyDenied',
      () async {
        final perm = FakePermissionService()
          ..statusToReturn = AppPermissionStatus.denied;
        expect(
          await perm.requestMicrophonePermission(),
          AppPermissionStatus.denied,
        );

        perm.statusToReturn = AppPermissionStatus.permanentlyDenied;
        expect(
          await perm.requestMicrophonePermission(),
          AppPermissionStatus.permanentlyDenied,
        );
      },
    );
  });
}
