import 'package:flutter/material.dart';
import 'core/audio/speech_recognition_service.dart';
import 'core/audio/tts_service.dart';
import 'core/theme/accessible_theme.dart';
import 'features/camera/camera_service.dart';
import 'features/camera/permission_service.dart';
import 'features/camera/presentation/camera_screen.dart';
import 'features/language/app_language.dart';
import 'features/language/language_preferences_service.dart';
import 'features/language/presentation/language_selection_screen.dart';
import 'features/perception/services/perception_api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AssistivePerceptionApp());
}

/// Root application widget configured for high-contrast accessibility.
class AssistivePerceptionApp extends StatelessWidget {
  final BaseCameraService? cameraService;
  final BasePerceptionApiService? perceptionApiService;
  final BaseTtsService? ttsService;
  final AppLanguage? initialLanguage;
  final BasePermissionService? permissionService;
  final BaseSpeechRecognitionService? speechRecognitionService;
  final BaseLanguagePreferencesService? languagePreferencesService;
  final bool? isFirstLaunchOverride;

  const AssistivePerceptionApp({
    super.key,
    this.cameraService,
    this.perceptionApiService,
    this.ttsService,
    this.initialLanguage,
    this.permissionService,
    this.speechRecognitionService,
    this.languagePreferencesService,
    this.isFirstLaunchOverride,
  });

  @override
  Widget build(BuildContext context) {
    // Show dedicated LanguageSelectionScreen on fresh launch unless initialLanguage is passed
    // or test setup explicitly configures debugDefaultLanguagePreferencesService without isFirstLaunchOverride: true
    final bool shouldShowLanguageSelection = initialLanguage == null &&
        (isFirstLaunchOverride == true ||
            (isFirstLaunchOverride == null &&
                CameraScreen.debugDefaultLanguagePreferencesService == null));

    return MaterialApp(
      title: 'Assistive Perception',
      debugShowCheckedModeBanner: false,
      theme: AccessibleTheme.highContrastTheme,
      home: shouldShowLanguageSelection
          ? LanguageSelectionScreen(
              cameraService: cameraService,
              perceptionApiService: perceptionApiService,
              ttsService: ttsService,
              permissionService: permissionService,
              speechRecognitionService: speechRecognitionService,
              languagePreferencesService: languagePreferencesService,
            )
          : CameraScreen(
              cameraService: cameraService,
              perceptionApiService: perceptionApiService,
              ttsService: ttsService,
              initialLanguage: initialLanguage,
              permissionService: permissionService,
              speechRecognitionService: speechRecognitionService,
              languagePreferencesService: languagePreferencesService,
              isFirstLaunchOverride: isFirstLaunchOverride,
            ),
    );
  }
}
