import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/accessibility/accessibility_constants.dart';
import '../../../../core/accessibility/semantics_helper.dart';
import '../../../../core/audio/haptic_feedback_service.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/audio/speech_recognition_service.dart';
import '../../language/app_language.dart';
import '../../language/language_matcher.dart';
import '../../language/language_preferences_service.dart';
import '../../perception/models/perception_result.dart';
import '../../perception/services/perception_api_service.dart';
import '../../voice/voice_command.dart';
import '../camera_service.dart';
import '../permission_service.dart';

/// Accessible Camera Screen designed for visually impaired users.
/// Integrates live camera capture, camera-based short video recording (up to 10s),
/// multilingual backend perception (English & Telugu), voice-first navigation, and text-to-speech.
class CameraScreen extends StatefulWidget {
  final BaseCameraService? cameraService;
  final BasePerceptionApiService? perceptionApiService;
  final BaseTtsService? ttsService;
  final AppLanguage? initialLanguage;
  final BasePermissionService? permissionService;
  final BaseSpeechRecognitionService? speechRecognitionService;
  final BaseLanguagePreferencesService? languagePreferencesService;
  final bool? isFirstLaunchOverride;
  final bool? enableVoiceNavigation;

  static BasePermissionService? debugDefaultPermissionService;
  static BaseSpeechRecognitionService? debugDefaultSpeechRecognitionService;
  static BaseLanguagePreferencesService? debugDefaultLanguagePreferencesService;
  static bool? debugDefaultEnableVoiceNavigation;

  const CameraScreen({
    super.key,
    this.cameraService,
    this.perceptionApiService,
    this.ttsService,
    this.initialLanguage,
    this.permissionService,
    this.speechRecognitionService,
    this.languagePreferencesService,
    this.isFirstLaunchOverride,
    this.enableVoiceNavigation,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late final BaseCameraService _cameraService;
  late final BasePerceptionApiService _perceptionApiService;
  late final BaseTtsService _ttsService;
  late final BasePermissionService _permissionService;
  late final BaseSpeechRecognitionService _speechRecognitionService;
  late final BaseLanguagePreferencesService _languagePreferencesService;

  bool get _effectiveEnableVoiceNavigation =>
      widget.enableVoiceNavigation ??
      CameraScreen.debugDefaultEnableVoiceNavigation ??
      true;

  bool _isInitializing = true;
  bool _isTakingPicture = false;
  XFile? _capturedFile;

  // Video State (Camera Recording)
  bool _isRecordingVideo = false;
  int _recordingSecondsRemaining = 10;
  Timer? _recordingTimer;
  XFile? _recordedVideoFile;
  int? _recordedVideoSizeBytes;

  // First-Launch Language Voice Setup State
  bool _isFirstLaunchLanguagePrompt = false;
  bool _isListeningForLanguage = false;
  String _firstLaunchStatusText = '';
  int _languagePromptRetries = 0;
  static const int _maxLanguagePromptRetries = 2;
  Timer? _listeningTimeoutTimer;

  // Voice Navigation State
  bool _isVoiceNavigating = false;
  bool _isListeningForCommand = false;
  String _voiceStatusText = '';
  int _voiceCommandRetries = 0;
  static const int _maxVoiceCommandRetries = 2;
  Timer? _voiceListeningTimeoutTimer;
  bool _isActionInProgress = false;

  // Language State
  late AppLanguage _selectedLanguage;

  // Perception State
  bool _isPerceiving = false;
  PerceptionResult? _perceptionResult;
  String? _perceptionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService = widget.cameraService ?? CameraService();
    _perceptionApiService =
        widget.perceptionApiService ?? PerceptionApiService();
    _ttsService = widget.ttsService ?? TtsService();
    _permissionService =
        widget.permissionService ??
        CameraScreen.debugDefaultPermissionService ??
        const PermissionService();
    _speechRecognitionService =
        widget.speechRecognitionService ??
        CameraScreen.debugDefaultSpeechRecognitionService ??
        SpeechRecognitionService();
    _languagePreferencesService =
        widget.languagePreferencesService ??
        CameraScreen.debugDefaultLanguagePreferencesService ??
        LanguagePreferencesService();

    _selectedLanguage = widget.initialLanguage ?? AppLanguage.english;
    _ttsService.initialize();
    _checkFirstLaunchLanguageSetup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _ttsService.stop();
      _listeningTimeoutTimer?.cancel();
      _listeningTimeoutTimer = null;
      _voiceListeningTimeoutTimer?.cancel();
      _voiceListeningTimeoutTimer = null;
      if (_isListeningForLanguage || _isListeningForCommand) {
        _speechRecognitionService.cancelListening();
        _isListeningForLanguage = false;
        _isListeningForCommand = false;
      }
      _isVoiceNavigating = false;
      if (_isRecordingVideo) {
        _recordingTimer?.cancel();
        _recordingTimer = null;
        _cameraService.stopVideoRecording();
        _isRecordingVideo = false;
      }
      if (_cameraService.isInitialized) {
        _cameraService.dispose();
      }
    } else if (state == AppLifecycleState.resumed &&
        _capturedFile == null &&
        _recordedVideoFile == null &&
        !_isRecordingVideo &&
        !_isFirstLaunchLanguagePrompt) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = null;
    _voiceListeningTimeoutTimer?.cancel();
    _voiceListeningTimeoutTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _ttsService.stop();
    _ttsService.dispose();
    _speechRecognitionService.cancelListening();
    _speechRecognitionService.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
    });

    SemanticsHelper.announce('Starting camera. Please wait.');
    await _cameraService.initialize();

    if (!mounted) return;

    setState(() {
      _isInitializing = false;
    });

    if (_cameraService.isInitialized) {
      SemanticsHelper.announce(
        _selectedLanguage == AppLanguage.telugu
            ? 'Camera siddhamga undi. Photo theeyadaniki leda video record cheyadaniki kindha unna button ni nokkandi.'
            : 'Camera is active. Tap Capture Scene for photo or Record Video for short clip.',
      );
      if (!_isFirstLaunchLanguagePrompt && _effectiveEnableVoiceNavigation) {
        _startVoiceNavigation();
      }
    } else if (_cameraService.errorMessage != null) {
      SemanticsHelper.announce(_cameraService.errorMessage!);
    }
  }

  Future<void> _checkFirstLaunchLanguageSetup() async {
    if (widget.initialLanguage != null) {
      _selectedLanguage = widget.initialLanguage!;
      await _languagePreferencesService.setPreferredLanguage(_selectedLanguage);
      _initCamera();
      return;
    }

    final hasPreference = widget.isFirstLaunchOverride != null
        ? !widget.isFirstLaunchOverride!
        : await _languagePreferencesService.hasLanguagePreference();

    if (hasPreference) {
      final savedLang = await _languagePreferencesService
          .getPreferredLanguage();
      if (mounted && savedLang != null) {
        setState(() {
          _selectedLanguage = savedLang;
          _isFirstLaunchLanguagePrompt = false;
        });
      }
      _initCamera();
    } else {
      if (mounted) {
        setState(() {
          _isFirstLaunchLanguagePrompt = true;
          _firstLaunchStatusText =
              'Please select your language. Mee language select cheskondi.';
        });
        _startFirstLaunchVoiceFlow();
      }
    }
  }

  Future<void> _startFirstLaunchVoiceFlow() async {
    if (!mounted || !_isFirstLaunchLanguagePrompt) return;

    // 1. Check and request microphone permission accessibly
    final micStatus = await _permissionService.requestMicrophonePermission();
    if (!mounted || !_isFirstLaunchLanguagePrompt) return;

    if (micStatus != AppPermissionStatus.granted) {
      if (mounted) {
        setState(() {
          _isListeningForLanguage = false;
          _firstLaunchStatusText =
              'Voice sahayam kosam microphone anumathi avasaram. Dayachesi screen pai bhashanu enchukondi. / Microphone permission needed. Please select language on screen.';
        });
      }
      SemanticsHelper.announce(_firstLaunchStatusText);
      await _ttsService.speak(
        'Voice sahayam kosam microphone anumathi avasaram. Dayachesi screen pai Telugu leda English enchukondi.',
        locale: 'te-IN',
      );
      if (mounted && _isFirstLaunchLanguagePrompt) {
        await _ttsService.speak(
          'Microphone permission is needed for voice assistance. Please select Telugu or English on the screen.',
          locale: 'en-US',
        );
      }
      return;
    }

    // 2. Initialize speech recognition
    await _speechRecognitionService.initialize();
    if (!mounted || !_isFirstLaunchLanguagePrompt) return;

    await _promptAndListenForLanguage();
  }

  Future<void> _promptAndListenForLanguage() async {
    if (!mounted || !_isFirstLaunchLanguagePrompt) return;

    if (mounted) {
      setState(() {
        _firstLaunchStatusText =
            'Please select your language. Mee language select cheskondi.';
        _isListeningForLanguage = false;
      });
    }
    SemanticsHelper.announce(_firstLaunchStatusText);
    await _ttsService.speakAndWait(
      'Please select your language.',
      locale: 'en-US',
    );
    if (!mounted || !_isFirstLaunchLanguagePrompt) return;

    await _ttsService.speakAndWait(
      'Mee language select cheskondi.',
      locale: 'te-IN',
    );
    if (!mounted || !_isFirstLaunchLanguagePrompt) return;

    await _listenForLanguageResponse();
  }

  Future<void> _listenForLanguageResponse() async {
    if (!mounted || !_isFirstLaunchLanguagePrompt) return;

    HapticFeedbackService.lightImpact();
    if (mounted) {
      setState(() {
        _isListeningForLanguage = true;
        _firstLaunchStatusText =
            'Listening... Please say "Telugu" or "English" / "Telugu" leda "English" ani cheppandi';
      });
    }
    SemanticsHelper.announce(
      'Listening for your choice. Please say Telugu or English.',
    );

    bool handled = false;
    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = Timer(const Duration(seconds: 8), () async {
      if (!handled &&
          mounted &&
          _isFirstLaunchLanguagePrompt &&
          _isListeningForLanguage) {
        handled = true;
        _listeningTimeoutTimer?.cancel();
        _listeningTimeoutTimer = null;
        await _speechRecognitionService.stopListening();
        await _handleUnclearLanguageResponse();
      }
    });

    await _speechRecognitionService.startListening(
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      onResult: (String words, bool isFinal) async {
        if (handled || !mounted || !_isFirstLaunchLanguagePrompt) return;
        final matched = LanguageMatcher.matchLanguage(words);
        if (matched != null) {
          handled = true;
          _listeningTimeoutTimer?.cancel();
          _listeningTimeoutTimer = null;
          await _speechRecognitionService.stopListening();
          await _applyLanguageSelection(matched, fromVoice: true);
        } else if (isFinal && words.trim().isNotEmpty) {
          handled = true;
          _listeningTimeoutTimer?.cancel();
          _listeningTimeoutTimer = null;
          await _speechRecognitionService.stopListening();
          await _handleUnclearLanguageResponse();
        }
      },
    );
  }

  Future<void> _handleUnclearLanguageResponse() async {
    if (!mounted || !_isFirstLaunchLanguagePrompt) return;

    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = null;

    _languagePromptRetries++;
    if (_languagePromptRetries <= _maxLanguagePromptRetries) {
      if (mounted) {
        setState(() {
          _isListeningForLanguage = false;
          _firstLaunchStatusText =
              'Mee samadhanam ardham kaaledu. Dayachesi Telugu leda English ani cheppandi. / Could not understand. Please say Telugu or English.';
        });
      }
      HapticFeedbackService.errorAlert();
      await _ttsService.speakAndWait(
        'Mee samadhanam ardham kaaledu. Dayachesi Telugu leda English ani cheppandi.',
        locale: 'te-IN',
      );
      if (!mounted || !_isFirstLaunchLanguagePrompt) return;

      await _ttsService.speakAndWait(
        'I could not understand. Please say Telugu or English.',
        locale: 'en-US',
      );
      if (!mounted || !_isFirstLaunchLanguagePrompt) return;

      await _listenForLanguageResponse();
    } else {
      // Max retries reached: default to English gracefully to avoid infinite loops
      if (mounted) {
        setState(() {
          _isListeningForLanguage = false;
          _firstLaunchStatusText =
              'Defaulting to English. You can change language anytime.';
        });
      }
      HapticFeedbackService.errorAlert();
      await _ttsService.speakAndWait(
        'Bhasha spashtamga vinabadaledu. Prathamikamga English enpika cheyabadindi. Meeru eppudaina marchavachu.',
        locale: 'te-IN',
      );
      if (!mounted || !_isFirstLaunchLanguagePrompt) return;

      await _ttsService.speakAndWait(
        'Could not understand language. Defaulting to English. You can switch to Telugu anytime.',
        locale: 'en-US',
      );
      if (!mounted) return;

      await _applyLanguageSelection(AppLanguage.english, isFallback: true);
    }
  }

  Future<void> _applyLanguageSelection(
    AppLanguage language, {
    bool fromVoice = false,
    bool isFallback = false,
  }) async {
    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = null;
    await _speechRecognitionService.stopListening();
    await _ttsService.stop();

    await _languagePreferencesService.setPreferredLanguage(language);

    if (!mounted) return;

    setState(() {
      _selectedLanguage = language;
      _isFirstLaunchLanguagePrompt = false;
      _isListeningForLanguage = false;
    });

    final confirmation = language == AppLanguage.telugu
        ? 'Bhasha Telugu ga enpika cheyabadindi.'
        : 'Language set to English.';
    SemanticsHelper.announce(confirmation);

    if (!isFallback) {
      await _ttsService.speak(confirmation, locale: language.ttsLocale);
    }

    await _initCamera();
  }

  void _handleLanguageSelect(AppLanguage language) {
    if (_selectedLanguage == language || _isRecordingVideo) return;
    HapticFeedbackService.lightImpact();
    _ttsService.stop();
    setState(() {
      _selectedLanguage = language;
    });

    _languagePreferencesService.setPreferredLanguage(language);

    SemanticsHelper.announce(language.accessibilityAnnouncement);

    if (_recordedVideoFile != null &&
        !_isPerceiving &&
        !_isTakingPicture &&
        !_isRecordingVideo) {
      // Re-run video perception if result was already displayed
      if (_perceptionResult != null) {
        _runVideoPerception(_recordedVideoFile!);
      }
    } else if (_capturedFile != null &&
        !_isPerceiving &&
        !_isTakingPicture &&
        !_isRecordingVideo) {
      _runPerception(_capturedFile!);
    } else if (_effectiveEnableVoiceNavigation &&
        !_isPerceiving &&
        !_isTakingPicture &&
        !_isRecordingVideo) {
      _startVoiceNavigation();
    }
  }

  Future<void> _startVoiceNavigation({
    bool isReviewScreen = false,
    bool isAfterAnalysis = false,
    bool isError = false,
    String? customPrompt,
  }) async {
    if (!mounted ||
        !_effectiveEnableVoiceNavigation ||
        _isFirstLaunchLanguagePrompt ||
        _isRecordingVideo ||
        _isPerceiving ||
        _isTakingPicture) {
      return;
    }

    var micStatus = await _permissionService.checkMicrophonePermission();
    if (micStatus != AppPermissionStatus.granted) {
      debugPrint('[VoiceNavigation] Microphone permission not yet granted ($micStatus). Requesting...');
      micStatus = await _permissionService.requestMicrophonePermission();
      if (micStatus != AppPermissionStatus.granted) {
        debugPrint('[VoiceNavigation] Microphone permission not granted ($micStatus). Aborting voice navigation.');
        return;
      }
    }

    if (!_speechRecognitionService.isAvailable) {
      debugPrint('[VoiceNavigation] Pre-initializing speech recognition service...');
      await _speechRecognitionService.initialize();
    }

    _voiceListeningTimeoutTimer?.cancel();
    _voiceListeningTimeoutTimer = null;
    await _speechRecognitionService.stopListening();
    await _ttsService.stop();

    final String promptText;
    if (customPrompt != null && customPrompt.isNotEmpty) {
      promptText = customPrompt;
    } else if (isReviewScreen) {
      promptText = _selectedLanguage == AppLanguage.telugu
          ? 'Video ayindi. Choodalante "Choodu" ani cheppu. Malli video teeyalante "Malli teeyi" ani cheppu.'
          : 'Video recorded. Say "Analyze" to analyze the video, or "Retake" to record again.';
    } else if (isAfterAnalysis) {
      promptText = _selectedLanguage == AppLanguage.telugu
          ? 'Malli choodataniki, "Photo teeyi" leda "Video record cheyi" ani cheppavachu.'
          : 'To perceive again, you can say "Take a photo" or "Record video".';
    } else {
      promptText = _selectedLanguage == AppLanguage.telugu
          ? 'Meeru "Photo teeyi" leda "Video record cheyi" ani cheppavachu.'
          : 'You can say "Take a photo" or "Record video".';
    }

    if (!mounted) return;

    setState(() {
      _isVoiceNavigating = true;
      _isListeningForCommand = false;
      _voiceStatusText = promptText;
    });

    SemanticsHelper.announce(promptText);

    debugPrint('[VoiceNavigation] Speaking prompt: "$promptText"');
    await _ttsService.speakAndWait(
      promptText,
      locale: _selectedLanguage.ttsLocale,
    );
    await _ttsService.stop();
    debugPrint('[VoiceNavigation] Prompt playback finished.');

    if (!mounted ||
        !_isVoiceNavigating ||
        _isRecordingVideo ||
        _isPerceiving ||
        _isTakingPicture) {
      debugPrint('[VoiceNavigation] Navigation state changed after TTS prompt. Aborting listen.');
      return;
    }

    await _listenForVoiceCommand(isReviewScreen: isReviewScreen, isError: isError);
  }

  Future<void> _listenForVoiceCommand({
    bool isReviewScreen = false,
    bool isError = false,
  }) async {
    if (!mounted ||
        !_effectiveEnableVoiceNavigation ||
        _isFirstLaunchLanguagePrompt ||
        _isRecordingVideo ||
        _isPerceiving ||
        _isTakingPicture) {
      debugPrint('[VoiceNavigation] _listenForVoiceCommand cancelled by state guard.');
      return;
    }

    HapticFeedbackService.lightImpact();
    final listeningText = isError
        ? (_selectedLanguage == AppLanguage.telugu
              ? 'Vintoo undi... "Retry" leda "Photo teeyi"'
              : 'Listening... e.g. "Retry" or "Take a photo"')
        : (isReviewScreen
              ? (_selectedLanguage == AppLanguage.telugu
                    ? 'Vintoo undi... "Choodu" leda "Malli teeyi" ani cheppandi'
                    : 'Listening... Say "Analyze" or "Retake"')
              : (_selectedLanguage == AppLanguage.telugu
                    ? 'Vintoo undi... "Photo teeyi" leda "Video record cheyi"'
                    : 'Listening... e.g. "Take a photo" or "Record video"'));

    setState(() {
      _isListeningForCommand = true;
      _voiceStatusText = listeningText;
    });

    SemanticsHelper.announce(listeningText);

    bool handled = false;
    _voiceListeningTimeoutTimer?.cancel();
    _voiceListeningTimeoutTimer = Timer(const Duration(seconds: 10), () async {
      if (!handled && mounted && _isListeningForCommand) {
        debugPrint('[VoiceNavigation] Listening timer (10s) expired with no command handled.');
        handled = true;
        _voiceListeningTimeoutTimer?.cancel();
        _voiceListeningTimeoutTimer = null;
        await _speechRecognitionService.stopListening();
        await _handleUnclearVoiceCommand(isReviewScreen: isReviewScreen, isError: isError);
      }
    });

    final localeId =
        _selectedLanguage == AppLanguage.telugu ? 'te_IN' : 'en_US';

    debugPrint('[VoiceNavigation] Calling startListening(locale: $localeId)...');
    await _speechRecognitionService.startListening(
      localeId: localeId,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      onStatus: (status) async {
        debugPrint('[VoiceNavigation] onStatus callback: "$status"');
        if (!mounted) return;
        if (status == 'listening') {
          if (!_isListeningForCommand) {
            setState(() {
              _isListeningForCommand = true;
            });
          }
        } else if (status == 'notListening' || status == 'done') {
          if (!handled && _isListeningForCommand) {
            debugPrint('[VoiceNavigation] Recognizer ended without recognized command.');
            handled = true;
            _voiceListeningTimeoutTimer?.cancel();
            _voiceListeningTimeoutTimer = null;
            setState(() {
              _isListeningForCommand = false;
            });
            await _handleUnclearVoiceCommand(isReviewScreen: isReviewScreen, isError: isError);
          }
        }
      },
      onError: (errorMsg) async {
        debugPrint('[VoiceNavigation] onError callback: "$errorMsg"');
        if (!handled && mounted && _isListeningForCommand) {
          handled = true;
          _voiceListeningTimeoutTimer?.cancel();
          _voiceListeningTimeoutTimer = null;
          setState(() {
            _isListeningForCommand = false;
          });
          await _handleUnclearVoiceCommand(isReviewScreen: isReviewScreen, isError: isError);
        }
      },
      onResult: (String words, bool isFinal) async {
        debugPrint('[VoiceNavigation] onResult received: "$words" (isFinal: $isFinal, handled: $handled)');
        if (handled || !mounted || !_isListeningForCommand) return;
        final action = VoiceCommandMatcher.matchCommand(words);
        if (action != null) {
          debugPrint('[VoiceNavigation] Action matched: $action');
          if (isError || _capturedFile != null) {
            // When recovering from error or when reviewing an image, allow all relevant actions
            if (action == VoiceAction.retry ||
                action == VoiceAction.retake ||
                action == VoiceAction.captureImage ||
                action == VoiceAction.recordVideo ||
                action == VoiceAction.analyze) {
              handled = true;
              _voiceListeningTimeoutTimer?.cancel();
              _voiceListeningTimeoutTimer = null;
              await _speechRecognitionService.stopListening();
              await _executeVoiceAction(action, isReviewScreen: isReviewScreen);
            } else if (isFinal) {
              handled = true;
              _voiceListeningTimeoutTimer?.cancel();
              _voiceListeningTimeoutTimer = null;
              await _speechRecognitionService.stopListening();
              await _handleUnclearVoiceCommand(isReviewScreen: isReviewScreen, isError: isError);
            }
          } else if (isReviewScreen) {
            if (action == VoiceAction.analyze ||
                action == VoiceAction.retake ||
                action == VoiceAction.retry) {
              handled = true;
              _voiceListeningTimeoutTimer?.cancel();
              _voiceListeningTimeoutTimer = null;
              await _speechRecognitionService.stopListening();
              await _executeVoiceAction(action, isReviewScreen: isReviewScreen);
            } else if (isFinal) {
              handled = true;
              _voiceListeningTimeoutTimer?.cancel();
              _voiceListeningTimeoutTimer = null;
              await _speechRecognitionService.stopListening();
              await _handleUnclearVoiceCommand(isReviewScreen: isReviewScreen, isError: isError);
            }
          } else {
            if (action == VoiceAction.captureImage ||
                action == VoiceAction.recordVideo ||
                action == VoiceAction.retry) {
              handled = true;
              _voiceListeningTimeoutTimer?.cancel();
              _voiceListeningTimeoutTimer = null;
              await _speechRecognitionService.stopListening();
              await _executeVoiceAction(action, isReviewScreen: isReviewScreen);
            } else if (isFinal) {
              handled = true;
              _voiceListeningTimeoutTimer?.cancel();
              _voiceListeningTimeoutTimer = null;
              await _speechRecognitionService.stopListening();
              await _handleUnclearVoiceCommand(isReviewScreen: isReviewScreen, isError: isError);
            }
          }
        } else if (isFinal && words.trim().isNotEmpty) {
          debugPrint('[VoiceNavigation] Final unrecognized phrase: "$words"');
          handled = true;
          _voiceListeningTimeoutTimer?.cancel();
          _voiceListeningTimeoutTimer = null;
          await _speechRecognitionService.stopListening();
          await _handleUnclearVoiceCommand(isReviewScreen: isReviewScreen, isError: isError);
        }
      },
    );
  }

  Future<void> _executeVoiceAction(
    VoiceAction action, {
    bool isReviewScreen = false,
  }) async {
    if (!mounted || _isActionInProgress) return;
    _isActionInProgress = true;
    _voiceCommandRetries = 0;

    setState(() {
      _isListeningForCommand = false;
      _isVoiceNavigating = false;
    });

    switch (action) {
      case VoiceAction.retry:
        debugPrint('[VoiceNavigation] Executing VoiceAction.retry...');
        if (mounted) {
          _handleRetry();
        }
        break;

      case VoiceAction.captureImage:
        debugPrint('[VoiceNavigation] Executing VoiceAction.captureImage...');
        if (_capturedFile != null) {
          setState(() {
            _capturedFile = null;
            _perceptionResult = null;
            _perceptionError = null;
          });
        }
        final captureMsg = _selectedLanguage == AppLanguage.telugu
            ? 'Photo theestunnamu...'
            : 'Capturing image...';
        SemanticsHelper.announce(captureMsg);
        await _ttsService.speak(
          captureMsg,
          locale: _selectedLanguage.ttsLocale,
        );
        if (mounted) {
          await _handleCapture();
        }
        break;

      case VoiceAction.recordVideo:
        debugPrint('[VoiceNavigation] Executing VoiceAction.recordVideo...');
        if (_capturedFile != null) {
          setState(() {
            _capturedFile = null;
            _perceptionResult = null;
            _perceptionError = null;
          });
        }
        if (mounted) {
          await _handleStartRecording();
        }
        break;

      case VoiceAction.analyze:
        debugPrint('[VoiceNavigation] Executing VoiceAction.analyze...');
        if (mounted) {
          if (_recordedVideoFile != null) {
            await _runVideoPerception(_recordedVideoFile!);
          } else if (_capturedFile != null) {
            await _runPerception(_capturedFile!);
          }
        }
        break;

      case VoiceAction.retake:
        debugPrint('[VoiceNavigation] Executing VoiceAction.retake...');
        if (mounted) {
          _handleRetake();
        }
        break;
    }

    _isActionInProgress = false;
  }

  Future<void> _handleUnclearVoiceCommand({
    bool isReviewScreen = false,
    bool isError = false,
  }) async {
    if (!mounted || _isRecordingVideo || _isPerceiving || _isTakingPicture) {
      return;
    }

    _voiceCommandRetries++;
    if (_voiceCommandRetries <= _maxVoiceCommandRetries) {
      final retryMsg = isError
          ? (_selectedLanguage == AppLanguage.telugu
                ? 'Meeru cheppinadi ardham kaaledu. Meeru "Retry" leda "Photo teeyi" ani cheppavachu.'
                : 'I did not understand. You can say "Retry" or "Take a photo".')
          : (isReviewScreen
                ? (_selectedLanguage == AppLanguage.telugu
                      ? 'Meeru cheppinadi ardham kaaledu. Dayachesi "Choodu" leda "Malli teeyi" ani cheppandi.'
                      : 'I could not understand. Please say "Analyze" or "Retake".')
                : (_selectedLanguage == AppLanguage.telugu
                      ? 'Meeru cheppinadi ardham kaaledu. Meeru "Photo teeyi" leda "Video record cheyi" ani cheppavachu.'
                      : 'I did not understand. You can say "Take a photo" or "Record video".'));

      setState(() {
        _isListeningForCommand = false;
        _voiceStatusText = retryMsg;
      });

      HapticFeedbackService.errorAlert();
      SemanticsHelper.announce(retryMsg);
      await _ttsService.speakAndWait(
        retryMsg,
        locale: _selectedLanguage.ttsLocale,
      );
      await _ttsService.stop();

      if (!mounted || _isRecordingVideo || _isPerceiving || _isTakingPicture) {
        return;
      }

      await _listenForVoiceCommand(isReviewScreen: isReviewScreen, isError: isError);
    } else {
      final fallbackMsg = _selectedLanguage == AppLanguage.telugu
          ? 'Voice command gurtinchabadaledu. Meeru screen pai unna buttons ni use cheyavachu.'
          : 'Voice command not detected. You can use the buttons on screen.';

      setState(() {
        _isListeningForCommand = false;
        _isVoiceNavigating = false;
        _voiceCommandRetries = 0;
        _voiceStatusText = fallbackMsg;
      });

      HapticFeedbackService.errorAlert();
      SemanticsHelper.announce(fallbackMsg);
      await _ttsService.speak(fallbackMsg, locale: _selectedLanguage.ttsLocale);
    }
  }

  Future<void> _handleCapture() async {
    if (_isTakingPicture ||
        _isRecordingVideo ||
        !_cameraService.isInitialized) {
      debugPrint('[CameraCapture] _handleCapture rejected: takingPic=$_isTakingPicture, rec=$_isRecordingVideo, init=${_cameraService.isInitialized}');
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    HapticFeedbackService.heavyImpact();
    SemanticsHelper.announce(
      _selectedLanguage == AppLanguage.telugu
          ? 'Photo capture avtondi...'
          : 'Capturing photo...',
    );

    debugPrint('[CameraCapture] Taking picture via CameraService...');
    final file = await _cameraService.takePicture();
    debugPrint('[CameraCapture] Picture taken: ${file?.path}');

    if (!mounted) return;

    setState(() {
      _isTakingPicture = false;
      _capturedFile = file;
      _recordedVideoFile = null;
      _recordedVideoSizeBytes = null;
    });

    if (file != null) {
      SemanticsHelper.announce(
        _selectedLanguage == AppLanguage.telugu
            ? 'Photo capture ayindi. Perception engine ki pampabaduthondi...'
            : 'Photo captured. Sending to perception engine...',
      );
      _runPerception(file);
    } else {
      HapticFeedbackService.errorAlert();
      final err = _cameraService.errorMessage ?? 'Failed to capture photo.';
      debugPrint('[CameraCapture] Failed to capture photo: $err');
      SemanticsHelper.announce(err);
    }
  }

  Future<void> _handleStartRecording() async {
    if (_isRecordingVideo ||
        _isTakingPicture ||
        _isPerceiving ||
        !_cameraService.isInitialized) {
      return;
    }

    _ttsService.stop();
    HapticFeedbackService.heavyImpact();

    // 1. Request microphone permission at runtime before starting video recording
    final AppPermissionStatus micStatus;
    try {
      micStatus = await _permissionService.requestMicrophonePermission();
    } catch (e) {
      HapticFeedbackService.errorAlert();
      final err = _selectedLanguage == AppLanguage.telugu
          ? 'Microphone anumathi pondadam vifalamaindi.'
          : 'Failed to request microphone permission.';
      SemanticsHelper.announce(err);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.alertRed),
        );
      }
      return;
    }

    if (!mounted) return;

    if (micStatus == AppPermissionStatus.denied) {
      HapticFeedbackService.errorAlert();
      final errorMsg = _selectedLanguage == AppLanguage.telugu
          ? 'వీడియో రికార్డ్ చేయడానికి మైక్రోఫోన్ అనుమతి అవసరం. దయచేసి అనుమతించండి.'
          : 'Microphone permission is required to record video. Please allow microphone access.';
      SemanticsHelper.announce(errorMsg);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.alertRed,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (micStatus == AppPermissionStatus.permanentlyDenied) {
      HapticFeedbackService.errorAlert();
      final errorMsg = _selectedLanguage == AppLanguage.telugu
          ? 'మైక్రోఫోన్ అనుమతి తిరస్కరించబడింది. వీడియో రికార్డ్ చేయడానికి సెట్టింగ్స్‌లో అనుమతించండి.'
          : 'Microphone permission is permanently denied. Please enable it in Settings to record video.';
      final actionLabel = _selectedLanguage == AppLanguage.telugu
          ? 'సెట్టింగ్స్'
          : 'SETTINGS';
      SemanticsHelper.announce(errorMsg);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.alertRed,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: actionLabel,
            textColor: AppColors.primaryYellow,
            onPressed: () {
              _permissionService.openAppSettings();
            },
          ),
        ),
      );
      return;
    }

    _voiceListeningTimeoutTimer?.cancel();
    _voiceListeningTimeoutTimer = null;
    await _speechRecognitionService.stopListening();
    _isListeningForCommand = false;
    _isVoiceNavigating = false;
    _ttsService.stop();

    // 2. Safe start video recording
    try {
      await _cameraService.startVideoRecording();
    } catch (e) {
      HapticFeedbackService.errorAlert();
      final err = _selectedLanguage == AppLanguage.telugu
          ? 'Video recording start cheyadam vifalamaindi.'
          : 'Failed to start video recording: $e';
      SemanticsHelper.announce(err);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.alertRed),
        );
      }
      return;
    }

    if (!mounted) return;

    if (_cameraService.errorMessage != null &&
        !_cameraService.isRecordingVideo) {
      HapticFeedbackService.errorAlert();
      final err = _cameraService.errorMessage!;
      SemanticsHelper.announce(err);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.alertRed),
      );
      return;
    }

    setState(() {
      _isRecordingVideo = true;
      _recordingSecondsRemaining = 10;
      _capturedFile = null;
      _recordedVideoFile = null;
      _recordedVideoSizeBytes = null;
      _perceptionResult = null;
      _perceptionError = null;
    });

    final startMsg = _selectedLanguage == AppLanguage.telugu
        ? 'Video recording start avtondi. Maximum 10 seconds.'
        : 'Starting video recording for up to 10 seconds.';
    SemanticsHelper.announce(startMsg);

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_recordingSecondsRemaining <= 1) {
        timer.cancel();
        _handleStopRecording(autoStopped: true);
      } else {
        setState(() {
          _recordingSecondsRemaining--;
        });
      }
    });
  }

  Future<void> _handleStopRecording({bool autoStopped = false}) async {
    if (!_isRecordingVideo) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    HapticFeedbackService.heavyImpact();
    final stopMsg = autoStopped
        ? (_selectedLanguage == AppLanguage.telugu
              ? '10 seconds limit reach ayindi. Recording aagindi.'
              : '10 second limit reached. Stopping recording.')
        : (_selectedLanguage == AppLanguage.telugu
              ? 'Recording aagutondi...'
              : 'Stopping recording...');
    SemanticsHelper.announce(stopMsg);

    final file = await _cameraService.stopVideoRecording();

    if (!mounted) return;

    if (file == null) {
      setState(() {
        _isRecordingVideo = false;
      });
      HapticFeedbackService.errorAlert();
      final err =
          _cameraService.errorMessage ??
          (_selectedLanguage == AppLanguage.telugu
              ? 'Video recording vifalamaindi.'
              : 'Failed to record video.');
      SemanticsHelper.announce(err);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.alertRed),
      );
      return;
    }

    // Client-side validations
    // 1. File size check (max 25 MiB)
    final int sizeInBytes = await file.length();
    if (!mounted) return;
    const int maxSizeBytes = 25 * 1024 * 1024; // 25 MiB

    if (sizeInBytes > maxSizeBytes) {
      HapticFeedbackService.errorAlert();
      final errorMsg = _selectedLanguage == AppLanguage.telugu
          ? 'Record chesina video 25 MB parimithini minchipoindi. Dayachesi malli record cheyandi.'
          : 'Recorded video exceeds the 25 MB limit. Please record a shorter clip.';
      SemanticsHelper.announce(errorMsg);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.alertRed,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() {
        _isRecordingVideo = false;
      });
      return;
    }

    setState(() {
      _isRecordingVideo = false;
      _recordedVideoFile = file;
      _recordedVideoSizeBytes = sizeInBytes;
      _capturedFile = null;
      _perceptionResult = null;
      _perceptionError = null;
    });

    SemanticsHelper.announce(
      _selectedLanguage == AppLanguage.telugu
          ? 'Video ayindi. Choodalante "Choodu" ani cheppu. Malli video teeyalante "Malli teeyi" ani cheppu.'
          : 'Video recorded. Tap Analyze Video to run perception, or Retake to record again.',
    );

    if (_effectiveEnableVoiceNavigation) {
      _startVoiceNavigation(isReviewScreen: true);
    }
  }

  void _handleAnalyzeVideo() {
    if (_recordedVideoFile != null && !_isPerceiving) {
      HapticFeedbackService.lightImpact();
      _runVideoPerception(_recordedVideoFile!);
    }
  }

  Future<void> _runVideoPerception(XFile file) async {
    _voiceListeningTimeoutTimer?.cancel();
    _voiceListeningTimeoutTimer = null;
    await _speechRecognitionService.stopListening();

    setState(() {
      _isPerceiving = true;
      _perceptionError = null;
      _perceptionResult = null;
    });

    final loadingMsg = _selectedLanguage == AppLanguage.telugu
        ? 'Video nu vishleshistondi. Dayachesi vechi undandi.'
        : 'Analyzing video. Please wait.';
    SemanticsHelper.announce(loadingMsg);

    final result = await _perceptionApiService.perceiveVideoFile(
      file: file,
      language: _selectedLanguage.code,
    );

    if (!mounted) return;

    setState(() {
      _isPerceiving = false;
      if (result.isSuccess) {
        _perceptionResult = result;
        _perceptionError = null;
      } else {
        _perceptionError = result.errorMessage ?? 'Failed to analyze video.';
        _perceptionResult = null;
      }
    });

    if (result.isSuccess && result.description.isNotEmpty) {
      try {
        if (_effectiveEnableVoiceNavigation) {
          await _ttsService.speakAndWait(
            result.description,
            locale: _selectedLanguage.ttsLocale,
          );
        } else {
          await _ttsService.speak(
            result.description,
            locale: _selectedLanguage.ttsLocale,
          );
        }
      } catch (_) {
        // Gracefully handle TTS failures
      }
      SemanticsHelper.announce(
        _selectedLanguage == AppLanguage.telugu
            ? 'Video drushya vivarana: ${result.description}'
            : 'Video description received: ${result.description}',
      );
      if (_effectiveEnableVoiceNavigation) {
        _startVoiceNavigation(isAfterAnalysis: true);
      }
    } else {
      HapticFeedbackService.errorAlert();
      final err = _perceptionError ?? 'Failed to analyze video.';
      final errorVoiceText = _selectedLanguage == AppLanguage.telugu
          ? 'Video analysis fail ayindi: $err. Malli try cheyadaniki "Retry" ani, malli record cheyadaniki "Malli teeyi" ani cheppandi.'
          : 'Video analysis failed: $err. Say "Retry" to try again, or "Retake" to record again.';
      SemanticsHelper.announce(errorVoiceText);
      if (_effectiveEnableVoiceNavigation) {
        _startVoiceNavigation(
          isAfterAnalysis: true,
          isError: true,
          isReviewScreen: true,
          customPrompt: errorVoiceText,
        );
      }
    }
  }

  Future<void> _runPerception(XFile file) async {
    _voiceListeningTimeoutTimer?.cancel();
    _voiceListeningTimeoutTimer = null;
    await _speechRecognitionService.stopListening();

    setState(() {
      _isPerceiving = true;
      _perceptionError = null;
      _perceptionResult = null;
    });

    final loadingMsg = _selectedLanguage == AppLanguage.telugu
        ? 'Parisaralanu vishleshistondi. Dayachesi vechi undandi.'
        : 'Analyzing image. Please wait.';
    SemanticsHelper.announce(loadingMsg);

    debugPrint('[Perception] Sending file ${file.path} to perception API (lang: ${_selectedLanguage.code})...');
    final result = await _perceptionApiService.perceiveFile(
      file: file,
      language: _selectedLanguage.code,
    );
    debugPrint('[Perception] API result: isSuccess=${result.isSuccess}, desc="${result.description}"');

    if (!mounted) return;

    setState(() {
      _isPerceiving = false;
      if (result.isSuccess) {
        _perceptionResult = result;
        _perceptionError = null;
      } else {
        _perceptionError =
            result.errorMessage ?? 'Failed to analyze environment.';
        _perceptionResult = null;
      }
    });

    if (result.isSuccess && result.description.isNotEmpty) {
      try {
        if (_effectiveEnableVoiceNavigation) {
          await _ttsService.speakAndWait(
            result.description,
            locale: _selectedLanguage.ttsLocale,
          );
        } else {
          await _ttsService.speak(
            result.description,
            locale: _selectedLanguage.ttsLocale,
          );
        }
      } catch (_) {
        // Gracefully handle TTS failures
      }
      SemanticsHelper.announce(
        _selectedLanguage == AppLanguage.telugu
            ? 'Drushya vivarana: ${result.description}'
            : 'Scene description received: ${result.description}',
      );
      if (_effectiveEnableVoiceNavigation) {
        _startVoiceNavigation(isAfterAnalysis: true);
      }
    } else {
      HapticFeedbackService.errorAlert();
      final err = _perceptionError ?? 'Failed to analyze environment.';
      final errorVoiceText = _selectedLanguage == AppLanguage.telugu
          ? 'Analysis fail ayindi: $err. Malli try cheyadaniki "Retry" ani, kotha photo kosam "Photo teeyi" ani cheppandi.'
          : 'Analysis failed: $err. Say "Retry" to try again, or "Take a photo" to take a new photo.';
      SemanticsHelper.announce(errorVoiceText);
      if (_effectiveEnableVoiceNavigation) {
        _startVoiceNavigation(
          isAfterAnalysis: true,
          isError: true,
          customPrompt: errorVoiceText,
        );
      }
    }
  }

  void _handleRetake() {
    _voiceListeningTimeoutTimer?.cancel();
    _voiceListeningTimeoutTimer = null;
    _speechRecognitionService.stopListening();
    _ttsService.stop();
    _recordingTimer?.cancel();
    _recordingTimer = null;
    HapticFeedbackService.lightImpact();
    final wasVideo = _recordedVideoFile != null;
    setState(() {
      _capturedFile = null;
      _recordedVideoFile = null;
      _recordedVideoSizeBytes = null;
      _isRecordingVideo = false;
      _isPerceiving = false;
      _perceptionResult = null;
      _perceptionError = null;
    });
    SemanticsHelper.announce(
      _selectedLanguage == AppLanguage.telugu
          ? (wasVideo
                ? 'Video discard ayindi. Live camera preview malli open ayindi.'
                : 'Photo discard ayindi. Live camera preview malli open ayindi.')
          : (wasVideo
                ? 'Video discarded. Camera live preview reopened.'
                : 'Photo discarded. Camera live preview reopened.'),
    );
    if (_effectiveEnableVoiceNavigation) {
      _startVoiceNavigation();
    }
  }

  void _handleRetry() {
    _ttsService.stop();
    if (_recordedVideoFile != null) {
      HapticFeedbackService.lightImpact();
      _runVideoPerception(_recordedVideoFile!);
    } else if (_capturedFile != null) {
      HapticFeedbackService.lightImpact();
      _runPerception(_capturedFile!);
    }
  }

  void _handleStopSpeech() {
    HapticFeedbackService.lightImpact();
    _ttsService.stop();
    SemanticsHelper.announce(
      _selectedLanguage == AppLanguage.telugu
          ? 'Maatallu aapabadayi.'
          : 'Speech stopped.',
    );
  }

  Future<void> _handleSwitchCamera() async {
    HapticFeedbackService.lightImpact();
    SemanticsHelper.announce('Switching camera...');
    await _cameraService.switchCamera();
    if (mounted) {
      setState(() {});
      final lens = _cameraService.currentCamera?.lensDirection.name ?? 'camera';
      SemanticsHelper.announce('Switched to $lens.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(splashFactory: InkRipple.splashFactory),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Semantics(
            header: true,
            label: 'Assistive Vision Camera',
            child: const Text('Assistive Camera'),
          ),
          actions: [
            if (!_isFirstLaunchLanguagePrompt &&
                _capturedFile == null &&
                _recordedVideoFile == null &&
                !_isRecordingVideo &&
                _cameraService.availableCamerasList.length > 1)
              IconButton(
                icon: const Icon(Icons.flip_camera_ios, size: 30),
                color: AppColors.primaryYellow,
                tooltip: 'Switch camera',
                onPressed: _handleSwitchCamera,
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isFirstLaunchLanguagePrompt) {
      return _buildFirstLaunchLanguageSetup();
    }

    if (_isInitializing) {
      return _buildLoadingState();
    }

    if (!_cameraService.isInitialized &&
        _capturedFile == null &&
        _recordedVideoFile == null &&
        !_isRecordingVideo) {
      return _buildErrorState();
    }

    if (_recordedVideoFile != null) {
      return _buildRecordedVideoPreviewState();
    }

    if (_capturedFile != null) {
      return _buildCapturedPreviewState();
    }

    return _buildLiveCameraState();
  }

  Widget _buildFirstLaunchLanguageSetup() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Voice Assistive Icon Header
            Semantics(
              header: true,
              label:
                  'First-time setup: Select your preferred language by voice or button.',
              child: Center(
                child: Container(
                  width: 90.0,
                  height: 90.0,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListeningForLanguage
                          ? AppColors.primaryYellow
                          : AppColors.secondaryCyan,
                      width: 3.0,
                    ),
                  ),
                  child: Icon(
                    _isListeningForLanguage
                        ? Icons.mic
                        : Icons.record_voice_over,
                    size: 50.0,
                    color: _isListeningForLanguage
                        ? AppColors.primaryYellow
                        : AppColors.secondaryCyan,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18.0),

            // Main Title
            const Text(
              'Select Language\nభాషను ఎంచుకోండి',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: AccessibilityConstants.titleFontSize,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 16.0),

            // Live Prompt / Listening Status Banner
            Semantics(
              liveRegion: true,
              label: _firstLaunchStatusText,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(
                    AccessibilityConstants.borderRadius,
                  ),
                  border: Border.all(
                    color: _isListeningForLanguage
                        ? AppColors.primaryYellow
                        : AppColors.secondaryCyan,
                    width: 2.0,
                  ),
                ),
                child: Column(
                  children: [
                    if (_isListeningForLanguage)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.mic,
                            color: AppColors.primaryYellow,
                            size: 24.0,
                          ),
                          SizedBox(width: 8.0),
                          Text(
                            'LISTENING FOR VOICE / వింటూ ఉంది...',
                            style: TextStyle(
                              color: AppColors.primaryYellow,
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.volume_up,
                            color: AppColors.secondaryCyan,
                            size: 24.0,
                          ),
                          SizedBox(width: 8.0),
                          Text(
                            'VOICE PROMPT / వివరిస్తోంది...',
                            style: TextStyle(
                              color: AppColors.secondaryCyan,
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10.0),
                    Text(
                      _firstLaunchStatusText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: AccessibilityConstants.bodyFontSize,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24.0),

            // Instruction subtitle
            const Text(
              'Speak "Telugu" or "English", or tap a button below:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryCyan,
                fontSize: AccessibilityConstants.captionFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16.0),

            // Large Accessible Button: Telugu
            Semantics(
              button: true,
              label: 'తెలుగు (Telugu)',
              hint: 'డబుల్ ట్యాప్ చేసి తెలుగు భాషను ఎంచుకోండి',
              child: SizedBox(
                height: 72.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: AppColors.textDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius,
                      ),
                    ),
                    elevation: 4.0,
                  ),
                  onPressed: () {
                    HapticFeedbackService.heavyImpact();
                    _applyLanguageSelection(AppLanguage.telugu);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.translate,
                        size: 30.0,
                        color: AppColors.textDark,
                      ),
                      SizedBox(width: 12.0),
                      Text(
                        'తెలుగు (TELUGU)',
                        style: TextStyle(
                          fontSize: AccessibilityConstants.titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14.0),

            // Large Accessible Button: English
            Semantics(
              button: true,
              label: 'English',
              hint: 'Double tap to select English language',
              child: SizedBox(
                height: 72.0,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primaryYellow,
                    side: const BorderSide(
                      color: AppColors.primaryYellow,
                      width: AccessibilityConstants.borderWidth,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius,
                      ),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedbackService.heavyImpact();
                    _applyLanguageSelection(AppLanguage.english);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.language,
                        size: 30.0,
                        color: AppColors.primaryYellow,
                      ),
                      SizedBox(width: 12.0),
                      Text(
                        'ENGLISH',
                        style: TextStyle(
                          fontSize: AccessibilityConstants.titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryYellow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          AccessibilityConstants.borderRadius,
        ),
        border: Border.all(color: AppColors.primaryYellow, width: 2.0),
      ),
      child: Row(
        children: [
          // English Option Button
          Expanded(
            child: Semantics(
              button: true,
              selected: _selectedLanguage == AppLanguage.english,
              label: 'English language',
              hint: 'Double tap to select English for scene perception',
              child: SizedBox(
                height: 48.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedLanguage == AppLanguage.english
                        ? AppColors.primaryYellow
                        : AppColors.surface,
                    foregroundColor: _selectedLanguage == AppLanguage.english
                        ? AppColors.textDark
                        : AppColors.textLight,
                    elevation: _selectedLanguage == AppLanguage.english
                        ? 2.0
                        : 0.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius - 4.0,
                      ),
                    ),
                  ),
                  onPressed: _isRecordingVideo
                      ? null
                      : () => _handleLanguageSelect(AppLanguage.english),
                  child: const Text(
                    'ENGLISH',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6.0),
          // Telugu Option Button
          Expanded(
            child: Semantics(
              button: true,
              selected: _selectedLanguage == AppLanguage.telugu,
              label: 'Telugu language (తెలుగు)',
              hint: 'Double tap to select Telugu for scene perception',
              child: SizedBox(
                height: 48.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedLanguage == AppLanguage.telugu
                        ? AppColors.primaryYellow
                        : AppColors.surface,
                    foregroundColor: _selectedLanguage == AppLanguage.telugu
                        ? AppColors.textDark
                        : AppColors.textLight,
                    elevation: _selectedLanguage == AppLanguage.telugu
                        ? 2.0
                        : 0.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius - 4.0,
                      ),
                    ),
                  ),
                  onPressed: _isRecordingVideo
                      ? null
                      : () => _handleLanguageSelect(AppLanguage.telugu),
                  child: const Text(
                    'తెలుగు (TELUGU)',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceStatusBanner() {
    if (!_effectiveEnableVoiceNavigation ||
        (!_isListeningForCommand && _voiceStatusText.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Semantics(
      liveRegion: true,
      label: 'Voice Status: $_voiceStatusText',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(
            AccessibilityConstants.borderRadius,
          ),
          border: Border.all(
            color: _isListeningForCommand
                ? AppColors.primaryYellow
                : AppColors.secondaryCyan,
            width: 2.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isListeningForCommand ? Icons.mic : Icons.mic_none,
              color: _isListeningForCommand
                  ? AppColors.primaryYellow
                  : AppColors.secondaryCyan,
              size: 24.0,
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                _voiceStatusText,
                style: TextStyle(
                  color: _isListeningForCommand
                      ? AppColors.primaryYellow
                      : AppColors.textLight,
                  fontSize: AccessibilityConstants.captionFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Initializing camera. Please wait.',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
              strokeWidth: 5.0,
              color: AppColors.primaryYellow,
            ),
            SizedBox(height: 24.0),
            Text(
              'Starting Camera...',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: AccessibilityConstants.titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final message =
        _cameraService.errorMessage ??
        'Camera is not available or permission was denied.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 80.0,
              color: AppColors.alertRed,
            ),
            const SizedBox(height: 20.0),
            Semantics(
              liveRegion: true,
              label: 'Error: $message',
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: AccessibilityConstants.bodyFontSize,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 32.0),
            Semantics(
              button: true,
              label: 'Retry Camera',
              hint: 'Double tap to retry initializing the camera',
              child: SizedBox(
                height: AccessibilityConstants.minTouchTargetDimension,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primaryYellow,
                    side: const BorderSide(
                      color: AppColors.primaryYellow,
                      width: AccessibilityConstants.borderWidth,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 30),
                  label: const Text(
                    'RETRY CAMERA',
                    style: TextStyle(
                      fontSize: AccessibilityConstants.bodyFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _initCamera,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCameraState() {
    final controller = _cameraService.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Language Selector
        _buildLanguageSelector(),

        const SizedBox(height: 10.0),

        _buildVoiceStatusBanner(),

        // 2. Top Status Header Banner
        Semantics(
          liveRegion: true,
          label: _isRecordingVideo
              ? (_selectedLanguage == AppLanguage.telugu
                    ? 'Video record avtondi. $_recordingSecondsRemaining seconds migili unnayi.'
                    : 'Recording video. $_recordingSecondsRemaining seconds remaining.')
              : 'Status: Camera Active. Point at your surroundings.',
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 14.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(
                AccessibilityConstants.borderRadius,
              ),
              border: Border.all(
                color: _isRecordingVideo
                    ? AppColors.alertRed
                    : AppColors.secondaryCyan,
                width: 2.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isRecordingVideo
                      ? Icons.fiber_manual_record
                      : Icons.remove_red_eye_outlined,
                  color: _isRecordingVideo
                      ? AppColors.alertRed
                      : AppColors.secondaryCyan,
                  size: 26.0,
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    _isRecordingVideo
                        ? (_selectedLanguage == AppLanguage.telugu
                              ? 'Video record avtondi (${_recordingSecondsRemaining}s migili undi)'
                              : 'RECORDING VIDEO (${_recordingSecondsRemaining}s remaining)')
                        : (_selectedLanguage == AppLanguage.telugu
                              ? 'Camera Active — Parisaralanu choodandi'
                              : 'Camera Active — Point at surroundings'),
                    style: TextStyle(
                      color: _isRecordingVideo
                          ? AppColors.alertRed
                          : AppColors.textLight,
                      fontSize: AccessibilityConstants.captionFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10.0),

        // 3. Live Camera Preview Frame
        Expanded(
          child: Semantics(
            label: _isRecordingVideo
                ? 'Recording live camera viewfinder.'
                : 'Live camera viewfinder.',
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(
                  AccessibilityConstants.borderRadius,
                ),
                border: Border.all(
                  color: _isRecordingVideo
                      ? AppColors.alertRed
                      : AppColors.primaryYellow,
                  width: AccessibilityConstants.borderWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AccessibilityConstants.borderRadius -
                      AccessibilityConstants.borderWidth,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    controller != null && controller.value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width:
                                  controller.value.previewSize?.height ?? 300,
                              height:
                                  controller.value.previewSize?.width ?? 400,
                              child: CameraPreview(controller),
                            ),
                          )
                        : const Center(
                            child: Text(
                              'Live Camera Viewfinder',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: AccessibilityConstants.bodyFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    if (_isRecordingVideo)
                      Positioned(
                        top: 12.0,
                        right: 12.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xBF000000),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: AppColors.alertRed,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.fiber_manual_record,
                                color: AppColors.alertRed,
                                size: 16.0,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                'REC 00:${_recordingSecondsRemaining.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14.0),

        // 4. Action Controls: Recording vs Normal Capture & Record
        if (_isRecordingVideo)
          Semantics(
            button: true,
            label: 'Stop Recording',
            hint: 'Double tap to stop video recording now',
            child: SizedBox(
              height: 84.0,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.alertRed,
                  foregroundColor: AppColors.textLight,
                  elevation: 4.0,
                  side: const BorderSide(
                    color: AppColors.textLight,
                    width: AccessibilityConstants.borderWidth,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AccessibilityConstants.borderRadius,
                    ),
                  ),
                ),
                onPressed: _handleStopRecording,
                icon: const Icon(
                  Icons.stop_rounded,
                  size: 38.0,
                  color: AppColors.textLight,
                ),
                label: Text(
                  _selectedLanguage == AppLanguage.telugu
                      ? 'రికార్డింగ్ ఆపు (STOP)'
                      : 'STOP RECORDING',
                  style: const TextStyle(
                    fontSize: AccessibilityConstants.titleFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ),
          )
        else ...[
          // Normal: Large Accessible Capture Button
          Semantics(
            button: true,
            label: 'Capture Scene',
            hint: 'Double tap to capture photo for scene perception',
            child: SizedBox(
              height: 84.0,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: AppColors.textDark,
                  elevation: 4.0,
                  side: const BorderSide(
                    color: AppColors.surfaceBorder,
                    width: AccessibilityConstants.borderWidth,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AccessibilityConstants.borderRadius,
                    ),
                  ),
                ),
                onPressed: _isTakingPicture ? null : _handleCapture,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isTakingPicture)
                      const SizedBox(
                        width: 28.0,
                        height: 28.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: AppColors.textDark,
                        ),
                      )
                    else
                      const Icon(
                        Icons.camera_alt,
                        size: 36.0,
                        color: AppColors.textDark,
                      ),
                    const SizedBox(width: 14.0),
                    Text(
                      _isTakingPicture
                          ? 'CAPTURING...'
                          : (_selectedLanguage == AppLanguage.telugu
                                ? 'క్యాప్చర్ (CAPTURE)'
                                : 'CAPTURE SCENE'),
                      style: const TextStyle(
                        fontSize: AccessibilityConstants.titleFontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10.0),

          // Accessible Secondary Action 1: Record Short Video
          Semantics(
            button: true,
            label: 'Record Short Video (max 10s)',
            hint:
                'Double tap to start recording an MP4 video up to 10 seconds for perception',
            child: SizedBox(
              height: 54.0,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.secondaryCyan,
                  side: const BorderSide(
                    color: AppColors.secondaryCyan,
                    width: 2.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AccessibilityConstants.borderRadius,
                    ),
                  ),
                ),
                onPressed: _isTakingPicture ? null : _handleStartRecording,
                icon: const Icon(
                  Icons.videocam_rounded,
                  size: 28.0,
                  color: AppColors.secondaryCyan,
                ),
                label: Text(
                  _selectedLanguage == AppLanguage.telugu
                      ? 'చిన్న వీడియో రికార్డ్ చేయండి (గరిష్టం 10సె)'
                      : 'RECORD SHORT VIDEO (MAX 10s)',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordedVideoPreviewState() {
    final file = _recordedVideoFile!;

    // Status Banner Info
    final String statusText;
    final Color statusColor;
    final IconData statusIcon;

    if (_isPerceiving) {
      statusText = _selectedLanguage == AppLanguage.telugu
          ? 'వీడియోను విశ్లేషిస్తోంది...'
          : 'Analyzing Video...';
      statusColor = AppColors.secondaryCyan;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (_perceptionError != null) {
      statusText = _selectedLanguage == AppLanguage.telugu
          ? 'విశ్లేషణ లోపం'
          : 'Analysis Error';
      statusColor = AppColors.alertRed;
      statusIcon = Icons.error_outline;
    } else if (_perceptionResult != null) {
      statusText = _selectedLanguage == AppLanguage.telugu
          ? 'వీడియో గుర్తించబడింది'
          : 'Video Understood';
      statusColor = AppColors.primaryYellow;
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusText = _selectedLanguage == AppLanguage.telugu
          ? 'Video record ayindi — choodadaniki siddhamga undi'
          : 'Video Recorded — Ready to Analyze';
      statusColor = AppColors.primaryYellow;
      statusIcon = Icons.check_circle_rounded;
    }

    final fileSizeMb = _recordedVideoSizeBytes != null
        ? (_recordedVideoSizeBytes! / (1024 * 1024)).toStringAsFixed(1)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Language Selector
        _buildLanguageSelector(),

        const SizedBox(height: 8.0),

        _buildVoiceStatusBanner(),

        // 2. Top Status Banner
        Semantics(
          liveRegion: true,
          label: 'Status: $statusText',
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 14.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(
                AccessibilityConstants.borderRadius,
              ),
              border: Border.all(color: statusColor, width: 2.0),
            ),
            child: Row(
              children: [
                if (_isPerceiving)
                  const SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.secondaryCyan,
                    ),
                  )
                else
                  Icon(statusIcon, color: statusColor, size: 22.0),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: AccessibilityConstants.captionFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8.0),

        // 3. Video Info Card (Distinct from Captured Photo)
        Semantics(
          label:
              'Recorded video: ${file.name}${fileSizeMb != null ? ', size: $fileSizeMb megabytes' : ''}. Tap retake to record again.',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 14.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(
                AccessibilityConstants.borderRadius,
              ),
              border: Border.all(
                color: AppColors.secondaryCyan,
                width: AccessibilityConstants.borderWidth,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.video_file_rounded,
                  size: 36.0,
                  color: AppColors.secondaryCyan,
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedLanguage == AppLanguage.telugu
                            ? 'రికార్డ్ చేసిన వీడియో'
                            : 'Recorded Short Video',
                        style: const TextStyle(
                          color: AppColors.primaryYellow,
                          fontSize: AccessibilityConstants.bodyFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: AccessibilityConstants.captionFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (fileSizeMb != null) ...[
                        const SizedBox(height: 2.0),
                        Text(
                          '$fileSizeMb MB (Max 10s)',
                          style: const TextStyle(
                            color: AppColors.secondaryCyan,
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8.0),

        // 4. Perception Result / Loading / Error Area
        Expanded(child: _buildPerceptionResultPanel(isVideo: true)),

        const SizedBox(height: 8.0),

        // 5. Video Action Buttons
        _buildRecordedVideoActionButtons(),
      ],
    );
  }

  Widget _buildRecordedVideoActionButtons() {
    // 1. Initial Review state: RETAKE and ANALYZE VIDEO buttons
    if (_perceptionResult == null &&
        _perceptionError == null &&
        !_isPerceiving) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: Semantics(
              button: true,
              label: 'Retake Video',
              hint: 'Double tap to discard this video and return to camera',
              child: SizedBox(
                height: AccessibilityConstants.minTouchTargetDimension,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primaryYellow,
                    side: const BorderSide(
                      color: AppColors.primaryYellow,
                      width: AccessibilityConstants.borderWidth,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 26),
                  label: Text(
                    _selectedLanguage == AppLanguage.telugu
                        ? 'రీటేక్ (RETAKE)'
                        : 'RETAKE',
                    style: const TextStyle(
                      fontSize: AccessibilityConstants.bodyFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _handleRetake,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            flex: 3,
            child: Semantics(
              button: true,
              label: 'Analyze Video',
              hint: 'Double tap to send recorded video to perception engine',
              child: SizedBox(
                height: AccessibilityConstants.minTouchTargetDimension,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: AppColors.textDark,
                    elevation: 4.0,
                    side: const BorderSide(
                      color: AppColors.surfaceBorder,
                      width: AccessibilityConstants.borderWidth,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.visibility, size: 28),
                  label: Text(
                    _selectedLanguage == AppLanguage.telugu
                        ? 'విశ్లేషించు (ANALYZE)'
                        : 'ANALYZE VIDEO',
                    style: const TextStyle(
                      fontSize: AccessibilityConstants.bodyFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: _handleAnalyzeVideo,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 2. Perception Error: RETRY and RETAKE buttons
    if (_perceptionError != null) {
      return Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Retry Video Analysis',
              hint: 'Double tap to send video to perception engine again',
              child: SizedBox(
                height: AccessibilityConstants.minTouchTargetDimension,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: AppColors.textDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 28),
                  label: Text(
                    _selectedLanguage == AppLanguage.telugu
                        ? 'మళ్ళీ ప్రయత్నించు (RETRY)'
                        : 'RETRY',
                    style: const TextStyle(
                      fontSize: AccessibilityConstants.bodyFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _handleRetry,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Discard Video and return to camera',
              hint: 'Double tap to discard video and return to camera',
              child: SizedBox(
                height: AccessibilityConstants.minTouchTargetDimension,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primaryYellow,
                    side: const BorderSide(
                      color: AppColors.primaryYellow,
                      width: AccessibilityConstants.borderWidth,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back, size: 26),
                  label: Text(
                    _selectedLanguage == AppLanguage.telugu
                        ? 'రద్దు (CANCEL)'
                        : 'CANCEL',
                    style: const TextStyle(
                      fontSize: AccessibilityConstants.bodyFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _handleRetake,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 3. In-flight or Success: Return / Cancel Button
    return Semantics(
      button: true,
      label: 'Discard Video and return to camera',
      hint: 'Double tap to discard video and return to live camera',
      child: SizedBox(
        height: AccessibilityConstants.minTouchTargetDimension,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primaryYellow,
            side: const BorderSide(
              color: AppColors.primaryYellow,
              width: AccessibilityConstants.borderWidth,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AccessibilityConstants.borderRadius,
              ),
            ),
          ),
          icon: const Icon(Icons.arrow_back, size: 30),
          label: Text(
            _isPerceiving
                ? (_selectedLanguage == AppLanguage.telugu
                      ? 'రద్దు చేయి (CANCEL)'
                      : 'CANCEL & RETAKE')
                : (_selectedLanguage == AppLanguage.telugu
                      ? 'కొత్త రికార్డింగ్ (NEW RECORDING)'
                      : 'RECORD NEW VIDEO'),
            style: const TextStyle(
              fontSize: AccessibilityConstants.bodyFontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          onPressed: _handleRetake,
        ),
      ),
    );
  }

  Widget _buildCapturedPreviewState() {
    final file = _capturedFile!;

    // Status Banner Info
    final String statusText;
    final Color statusColor;
    final IconData statusIcon;

    if (_isPerceiving) {
      statusText = _selectedLanguage == AppLanguage.telugu
          ? 'పరిసరాలను విశ్లేషిస్తోంది...'
          : 'Analyzing Environment...';
      statusColor = AppColors.secondaryCyan;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (_perceptionError != null) {
      statusText = _selectedLanguage == AppLanguage.telugu
          ? 'విశ్లేషణ లోపం'
          : 'Analysis Error';
      statusColor = AppColors.alertRed;
      statusIcon = Icons.error_outline;
    } else if (_perceptionResult != null) {
      statusText = _selectedLanguage == AppLanguage.telugu
          ? 'దృశ్యం గుర్తించబడింది'
          : 'Scene Understood';
      statusColor = AppColors.primaryYellow;
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusText = 'Photo Captured';
      statusColor = AppColors.primaryYellow;
      statusIcon = Icons.check_circle_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Language Selector
        _buildLanguageSelector(),

        const SizedBox(height: 8.0),

        _buildVoiceStatusBanner(),

        // 2. Top Status Banner
        Semantics(
          liveRegion: true,
          label: 'Status: $statusText',
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 14.0,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(
                AccessibilityConstants.borderRadius,
              ),
              border: Border.all(color: statusColor, width: 2.0),
            ),
            child: Row(
              children: [
                if (_isPerceiving)
                  const SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.secondaryCyan,
                    ),
                  )
                else
                  Icon(statusIcon, color: statusColor, size: 22.0),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: AccessibilityConstants.captionFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8.0),

        // 3. Captured Photo Preview Display (Always Visible)
        Expanded(
          flex: 3,
          child: Semantics(
            label: 'Captured image preview. Tap retake to take another photo.',
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(
                  AccessibilityConstants.borderRadius,
                ),
                border: Border.all(
                  color: AppColors.primaryYellow,
                  width: AccessibilityConstants.borderWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AccessibilityConstants.borderRadius -
                      AccessibilityConstants.borderWidth,
                ),
                child: kIsWeb
                    ? Image.network(file.path, fit: BoxFit.contain)
                    : File(file.path).existsSync()
                    ? Image.file(
                        File(file.path),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            'Image preview error ($error)',
                            style: const TextStyle(color: AppColors.textLight),
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              size: 48.0,
                              color: AppColors.primaryYellow,
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              'Photo captured: ${file.name}',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize:
                                    AccessibilityConstants.captionFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8.0),

        // 4. Perception Result / Loading / Error Area
        Expanded(flex: 4, child: _buildPerceptionResultPanel()),

        const SizedBox(height: 8.0),

        // 5. Action Buttons Area
        _buildCapturedActionButtons(),
      ],
    );
  }

  Widget _buildPerceptionResultPanel({bool isVideo = false}) {
    if (_isPerceiving) {
      final loadingLabel = isVideo
          ? (_selectedLanguage == AppLanguage.telugu
                ? 'పర్సెప్షన్ ఇంజిన్‌తో వీడియోను విశ్లేషిస్తోంది. దయచేసి వేచి ఉండండి.'
                : 'Analyzing video with perception engine. Please wait.')
          : (_selectedLanguage == AppLanguage.telugu
                ? 'పర్సెప్షన్ ఇంజిన్‌తో దృశ్యాన్ని విశ్లేషిస్తోంది. దయచేసి వేచి ఉండండి.'
                : 'Analyzing scene with perception engine. Please wait.');

      final title = isVideo
          ? (_selectedLanguage == AppLanguage.telugu
                ? 'వీడియో దృశ్యాన్ని విశ్లేషిస్తోంది...'
                : 'Processing Video Scene...')
          : (_selectedLanguage == AppLanguage.telugu
                ? 'దృశ్యాన్ని విశ్లేషిస్తోంది...'
                : 'Analyzing Scene...');

      final subtitle = isVideo
          ? (_selectedLanguage == AppLanguage.telugu
                ? 'సర్వర్‌కు వీడియో పంపబడుతోంది'
                : 'Sending video to perception engine')
          : (_selectedLanguage == AppLanguage.telugu
                ? 'సర్వర్‌కు చిత్రం పంపబడుతోంది'
                : 'Sending image to perception engine');

      return Semantics(
        liveRegion: true,
        label: loadingLabel,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(
              AccessibilityConstants.borderRadius,
            ),
            border: Border.all(color: AppColors.secondaryCyan, width: 2.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 4.0,
                color: AppColors.primaryYellow,
              ),
              const SizedBox(height: 12.0),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: AccessibilityConstants.bodyFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.secondaryCyan,
                  fontSize: 14.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_perceptionError != null) {
      return Semantics(
        liveRegion: true,
        label: 'Analysis Error: $_perceptionError. Tap Retry to try again.',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(
              AccessibilityConstants.borderRadius,
            ),
            border: Border.all(color: AppColors.alertRed, width: 2.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.alertRed,
                    size: 26.0,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    _selectedLanguage == AppLanguage.telugu
                        ? 'విశ్లేషణ విఫలమైంది'
                        : 'Perception Failed',
                    style: const TextStyle(
                      color: AppColors.alertRed,
                      fontSize: AccessibilityConstants.bodyFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _perceptionError!,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: AccessibilityConstants.captionFontSize,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_perceptionResult != null) {
      return Semantics(
        label: 'Scene Description: ${_perceptionResult!.description}',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(
              AccessibilityConstants.borderRadius,
            ),
            border: Border.all(color: AppColors.primaryYellow, width: 2.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.visibility,
                    color: AppColors.primaryYellow,
                    size: 24.0,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    _selectedLanguage == AppLanguage.telugu
                        ? 'దృశ్య వివరణ (Description)'
                        : 'Scene Description',
                    style: const TextStyle(
                      color: AppColors.primaryYellow,
                      fontSize: AccessibilityConstants.bodyFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Small accessible STOP SPEECH control
                  Semantics(
                    button: true,
                    label: 'Stop speech',
                    hint: 'Double tap to stop audio speech playback',
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.primaryYellow,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 4.0,
                        ),
                        side: const BorderSide(
                          color: AppColors.primaryYellow,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      icon: const Icon(Icons.volume_off, size: 18.0),
                      label: Text(
                        _selectedLanguage == AppLanguage.telugu
                            ? 'ఆపు (STOP)'
                            : 'STOP SPEECH',
                        style: const TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: _handleStopSpeech,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _perceptionResult!.description,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: AccessibilityConstants.bodyFontSize,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default placeholder if perception hasn't started
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          AccessibilityConstants.borderRadius,
        ),
        border: Border.all(color: AppColors.secondaryCyan, width: 1.5),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isVideo ? Icons.videocam : Icons.photo_camera,
                size: 32.0,
                color: AppColors.secondaryCyan,
              ),
              const SizedBox(height: 8.0),
              Text(
                isVideo
                    ? (_selectedLanguage == AppLanguage.telugu
                          ? 'Video choodadaniki siddhamga undi.\nChoodadaniki kinda unna button nokkandi.'
                          : 'Video ready for analysis.\nTap ANALYZE VIDEO below to perceive scene.')
                    : (_selectedLanguage == AppLanguage.telugu
                          ? 'Photo choodadaniki siddhamga undi'
                          : 'Photo ready for analysis'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: AccessibilityConstants.bodyFontSize,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapturedActionButtons() {
    if (_perceptionError != null) {
      // Two tactile buttons: RETRY and RETAKE
      return Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Retry Analysis',
              hint: 'Double tap to send image to perception engine again',
              child: SizedBox(
                height: AccessibilityConstants.minTouchTargetDimension,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: AppColors.textDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 28),
                  label: Text(
                    _selectedLanguage == AppLanguage.telugu
                        ? 'మళ్ళీ ప్రయత్నించు (RETRY)'
                        : 'RETRY',
                    style: const TextStyle(
                      fontSize: AccessibilityConstants.bodyFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _handleRetry,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Retake Photo',
              hint: 'Double tap to discard photo and return to camera',
              child: SizedBox(
                height: AccessibilityConstants.minTouchTargetDimension,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primaryYellow,
                    side: const BorderSide(
                      color: AppColors.primaryYellow,
                      width: AccessibilityConstants.borderWidth,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AccessibilityConstants.borderRadius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 26),
                  label: Text(
                    _selectedLanguage == AppLanguage.telugu
                        ? 'రీటేక్ (RETAKE)'
                        : 'RETAKE',
                    style: const TextStyle(
                      fontSize: AccessibilityConstants.bodyFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _handleRetake,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Default full-width RETAKE button
    return Semantics(
      button: true,
      label: 'Retake Photo',
      hint: 'Double tap to discard captured photo and return to live camera',
      child: SizedBox(
        height: AccessibilityConstants.minTouchTargetDimension,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primaryYellow,
            side: const BorderSide(
              color: AppColors.primaryYellow,
              width: AccessibilityConstants.borderWidth,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AccessibilityConstants.borderRadius,
              ),
            ),
          ),
          icon: const Icon(Icons.refresh, size: 30),
          label: Text(
            _isPerceiving
                ? (_selectedLanguage == AppLanguage.telugu
                      ? 'రద్దు చేయి (CANCEL)'
                      : 'CANCEL & RETAKE')
                : (_selectedLanguage == AppLanguage.telugu
                      ? 'మళ్ళీ తీయి (RETAKE PHOTO)'
                      : 'RETAKE PHOTO'),
            style: const TextStyle(
              fontSize: AccessibilityConstants.bodyFontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          onPressed: _handleRetake,
        ),
      ),
    );
  }
}
