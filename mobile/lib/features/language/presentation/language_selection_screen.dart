import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/accessibility/semantics_helper.dart';
import '../../../../core/audio/haptic_feedback_service.dart';
import '../../../../core/audio/speech_recognition_service.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../camera/camera_service.dart';
import '../../camera/permission_service.dart';
import '../../camera/presentation/camera_screen.dart';
import '../../perception/services/perception_api_service.dart';
import '../app_language.dart';
import '../language_matcher.dart';
import '../language_preferences_service.dart';

/// Dedicated language selection screen presented on fresh app launch.
/// Enables hands-free voice selection for blind users with high-contrast button fallbacks.
class LanguageSelectionScreen extends StatefulWidget {
  final BasePermissionService? permissionService;
  final BaseSpeechRecognitionService? speechRecognitionService;
  final BaseTtsService? ttsService;
  final BaseLanguagePreferencesService? languagePreferencesService;
  final BaseCameraService? cameraService;
  final BasePerceptionApiService? perceptionApiService;
  final bool? enableVoiceNavigation;
  final void Function(AppLanguage language)? onLanguageSelected;

  const LanguageSelectionScreen({
    super.key,
    this.permissionService,
    this.speechRecognitionService,
    this.ttsService,
    this.languagePreferencesService,
    this.cameraService,
    this.perceptionApiService,
    this.enableVoiceNavigation,
    this.onLanguageSelected,
  });

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late final BasePermissionService _permissionService;
  late final BaseSpeechRecognitionService _speechRecognitionService;
  late final BaseTtsService _ttsService;
  late final BaseLanguagePreferencesService _languagePreferencesService;

  bool _isListening = false;
  String _statusText = 'Please select your language. Mee language select cheskondi.';
  int _retries = 0;
  static const int _maxRetries = 2;
  Timer? _listeningTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _permissionService = widget.permissionService ??
        CameraScreen.debugDefaultPermissionService ??
        const PermissionService();
    _speechRecognitionService = widget.speechRecognitionService ??
        CameraScreen.debugDefaultSpeechRecognitionService ??
        SpeechRecognitionService();
    _ttsService = widget.ttsService ?? TtsService();
    _languagePreferencesService = widget.languagePreferencesService ??
        CameraScreen.debugDefaultLanguagePreferencesService ??
        LanguagePreferencesService();

    _ttsService.initialize();
    _startLanguageSelectionFlow();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _listeningTimer?.cancel();
    _listeningTimer = null;
    _ttsService.stop();
    _speechRecognitionService.cancelListening();
    super.dispose();
  }

  Future<void> _startLanguageSelectionFlow() async {
    if (_isDisposed || !mounted) return;

    // 1. Request microphone permission
    final micStatus = await _permissionService.requestMicrophonePermission();
    if (_isDisposed || !mounted) return;

    if (micStatus != AppPermissionStatus.granted) {
      const deniedMsg =
          'Voice sahayam kosam microphone anumathi avasaram. Screen pai English leda Telugu select cheskondi. / Microphone permission needed. Please select English or Telugu on screen.';
      setState(() {
        _isListening = false;
        _statusText = deniedMsg;
      });
      SemanticsHelper.announce(deniedMsg);
      await _ttsService.speak(
        'Voice sahayam kosam microphone anumathi avasaram. Screen pai English leda Telugu select cheskondi.',
        locale: 'en-US',
      );
      return;
    }

    // 2. Initialize speech recognition
    await _speechRecognitionService.initialize();
    if (_isDisposed || !mounted) return;

    // 3. Speak bilingual initial prompt
    const bilingualPrompt = 'Please select your language. Mee language select cheskondi.';
    setState(() {
      _statusText = bilingualPrompt;
      _isListening = false;
    });
    SemanticsHelper.announce(bilingualPrompt);

    await _ttsService.speakAndWait(
      bilingualPrompt,
      locale: 'en-US',
    );
    await _ttsService.stop();

    if (_isDisposed || !mounted) return;

    await _listenForVoiceChoice();
  }

  Future<void> _listenForVoiceChoice() async {
    if (_isDisposed || !mounted) return;

    HapticFeedbackService.lightImpact();
    setState(() {
      _isListening = true;
      _statusText = 'Listening... Please say "English" or "Telugu" / "English" leda "Telugu" ani cheppandi';
    });
    SemanticsHelper.announce('Listening for language choice. Say English or Telugu.');

    bool handled = false;
    _listeningTimer?.cancel();
    _listeningTimer = Timer(const Duration(seconds: 8), () async {
      if (!handled && mounted && !_isDisposed && _isListening) {
        handled = true;
        _listeningTimer?.cancel();
        _listeningTimer = null;
        await _speechRecognitionService.stopListening();
        await _handleUnclearResponse();
      }
    });

    await _speechRecognitionService.startListening(
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      onResult: (String words, bool isFinal) async {
        if (handled || !mounted || _isDisposed) return;
        final matched = LanguageMatcher.matchLanguage(words);
        if (matched != null) {
          handled = true;
          _listeningTimer?.cancel();
          _listeningTimer = null;
          await _speechRecognitionService.stopListening();
          await _selectLanguage(matched);
        } else if (isFinal && words.trim().isNotEmpty) {
          handled = true;
          _listeningTimer?.cancel();
          _listeningTimer = null;
          await _speechRecognitionService.stopListening();
          await _handleUnclearResponse();
        }
      },
    );
  }

  Future<void> _handleUnclearResponse() async {
    if (_isDisposed || !mounted) return;

    _listeningTimer?.cancel();
    _listeningTimer = null;

    _retries++;
    if (_retries <= _maxRetries) {
      const retryMsg =
          'Malli cheppandi. "English" leda "Telugu" ani cheppandi. / Please say again. Say "English" or "Telugu".';
      setState(() {
        _isListening = false;
        _statusText = retryMsg;
      });
      HapticFeedbackService.errorAlert();
      SemanticsHelper.announce(retryMsg);

      await _ttsService.speakAndWait(
        'Malli cheppandi. "English" leda "Telugu" ani cheppandi.',
        locale: 'en-US',
      );
      await _ttsService.stop();

      if (_isDisposed || !mounted) return;
      await _listenForVoiceChoice();
    } else {
      const fallbackMsg =
          'Language selection timeout. Tap English or Telugu on screen. / Screen pai English leda Telugu button ni nokkandi.';
      setState(() {
        _isListening = false;
        _statusText = fallbackMsg;
      });
      SemanticsHelper.announce(fallbackMsg);
      await _ttsService.speak(
        'Please select English or Telugu on the screen.',
        locale: 'en-US',
      );
    }
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    _listeningTimer?.cancel();
    _listeningTimer = null;
    await _speechRecognitionService.stopListening();
    await _ttsService.stop();

    HapticFeedbackService.lightImpact();

    await _languagePreferencesService.setPreferredLanguage(language);

    if (_isDisposed || !mounted) return;

    final confirmation = language == AppLanguage.telugu
        ? 'Bhasha Telugu ga enpika cheyabadindi.'
        : 'Language set to English.';

    SemanticsHelper.announce(confirmation);
    await _ttsService.speak(confirmation, locale: language.ttsLocale);

    widget.onLanguageSelected?.call(language);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => CameraScreen(
            cameraService: widget.cameraService,
            perceptionApiService: widget.perceptionApiService,
            ttsService: widget.ttsService,
            initialLanguage: language,
            permissionService: widget.permissionService,
            speechRecognitionService: widget.speechRecognitionService,
            languagePreferencesService: widget.languagePreferencesService,
            enableVoiceNavigation: widget.enableVoiceNavigation,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Language Selection'),
        backgroundColor: AppColors.surface,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Voice / Accessibility Indicator Icon
                Center(
                  child: Container(
                    width: 96.0,
                    height: 96.0,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isListening
                            ? AppColors.primaryYellow
                            : AppColors.secondaryCyan,
                        width: 3.5,
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.language,
                      size: 48.0,
                      color: _isListening
                          ? AppColors.primaryYellow
                          : AppColors.secondaryCyan,
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),

                // Listening badge
                if (_isListening) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryYellow.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: AppColors.primaryYellow,
                          width: 2.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12.0,
                            height: 12.0,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryYellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          const Text(
                            'LISTENING FOR VOICE / వింటూ ఉంది...',
                            style: TextStyle(
                              color: AppColors.primaryYellow,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                ],

                // Accessible Heading
                Semantics(
                  header: true,
                  child: const Text(
                    'Select Language\nభాషను ఎంచుకోండి',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),

                // Spoken status text box
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: _isListening
                          ? AppColors.primaryYellow
                          : AppColors.surfaceBorder,
                      width: 2.0,
                    ),
                  ),
                  child: Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 15.0,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 32.0),

                // English Button (High Contrast)
                Semantics(
                  button: true,
                  label: 'Select English language',
                  hint: 'Double tap to use the app in English',
                  child: SizedBox(
                    height: 72.0,
                    child: ElevatedButton(
                      key: const Key('language_button_english'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryYellow,
                        foregroundColor: AppColors.background,
                        elevation: 4.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          side: const BorderSide(
                            color: AppColors.textLight,
                            width: 2.0,
                          ),
                        ),
                      ),
                      onPressed: () => _selectLanguage(AppLanguage.english),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 28.0),
                          SizedBox(width: 12.0),
                          Text(
                            'ENGLISH',
                            style: TextStyle(
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),

                // Telugu Button (High Contrast)
                Semantics(
                  button: true,
                  label: 'Select Telugu language',
                  hint: 'Double tap to use the app in Telugu',
                  child: SizedBox(
                    height: 72.0,
                    child: ElevatedButton(
                      key: const Key('language_button_telugu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryCyan,
                        foregroundColor: AppColors.background,
                        elevation: 4.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          side: const BorderSide(
                            color: AppColors.textLight,
                            width: 2.0,
                          ),
                        ),
                      ),
                      onPressed: () => _selectLanguage(AppLanguage.telugu),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 28.0),
                          SizedBox(width: 12.0),
                          Text(
                            'తెలుగు (TELUGU)',
                            style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),

                // Voice instruction footnote
                Semantics(
                  label: 'Voice instruction: Say English or Telugu to choose hands-free',
                  child: const Text(
                    'Say "English" or "Telugu" at any time\n"English" leda "Telugu" ani cheppandi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 13.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
