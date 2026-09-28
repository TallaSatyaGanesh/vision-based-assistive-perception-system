import 'package:flutter/material.dart';
import '../../../../core/accessibility/accessibility_constants.dart';
import '../../../../core/accessibility/semantics_helper.dart';
import '../../../../core/audio/haptic_feedback_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../language/app_language.dart';
import '../../language/language_service.dart';
import 'widgets/accessible_touch_card.dart';

/// Accessibility-first foundation screen for the Assistive Perception System.
class PerceptionScreen extends StatefulWidget {
  const PerceptionScreen({super.key});

  @override
  State<PerceptionScreen> createState() => _PerceptionScreenState();
}

class _PerceptionScreenState extends State<PerceptionScreen> {
  final LanguageService _languageService = LanguageService();
  final ApiClient _apiClient = ApiClient();

  String _statusMessage = 'Foundation initialized. Ready for user interaction.';
  bool? _isBackendConnected;

  @override
  void initState() {
    super.initState();
    _checkBackendStatus();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _checkBackendStatus() async {
    final isHealthy = await _apiClient.checkBackendHealth();
    if (mounted) {
      setState(() {
        _isBackendConnected = isHealthy;
        _statusMessage = isHealthy
            ? 'Backend connected (Health: OK).'
            : 'Backend standby (Start FastAPI server at localhost:8000).';
      });
    }
  }

  void _handleLanguageToggle() {
    final newLanguage = _languageService.toggleLanguage();
    setState(() {});
    SemanticsHelper.announce(newLanguage.accessibilityAnnouncement);
  }

  void _handlePerceptionAction() {
    HapticFeedbackService.heavyImpact();
    final currentLang = _languageService.currentLanguage;
    final message = currentLang == AppLanguage.english
        ? 'Perception trigger activated. Camera pipeline will connect in next phase.'
        : 'పర్సెప్షన్ ట్రిగ్గర్ చేయబడింది. కెమెరా తదుపరి దశలో అనుసంధానించబడుతుంది.';

    setState(() {
      _statusMessage = message;
    });
    SemanticsHelper.announce(message);
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = _languageService.currentLanguage;

    final screenTitle = currentLang == AppLanguage.english
        ? 'Assistive Vision'
        : 'సహాయక దృష్టి';

    final languageTitle = currentLang == AppLanguage.english
        ? 'Language: English'
        : 'భాష: తెలుగు';

    final languageSubtitle = currentLang == AppLanguage.english
        ? 'Double-tap to switch to Telugu'
        : 'ఇంగ్లీషుకు మారడానికి రెండుసార్లు నొక్కండి';

    final captureTitle = currentLang == AppLanguage.english
        ? 'Perceive Environment'
        : 'పరిసరాలను గుర్తించు';

    final captureSubtitle = currentLang == AppLanguage.english
        ? 'Double-tap to test perception trigger'
        : 'పర్సెప్షన్ ట్రిగ్గర్ పరీక్షించడానికి రెండుసార్లు నొక్కండి';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Semantics(
          header: true,
          label: '$screenTitle - Assistive Perception System',
          child: Text(screenTitle),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Language Toggle Card (Accessible large touch target)
              AccessibleTouchCard(
                title: languageTitle,
                subtitle: languageSubtitle,
                icon: Icons.language,
                semanticLabel: '$languageTitle. $languageSubtitle',
                semanticHint:
                    'Switches the spoken output language between English and Telugu',
                borderColor: AppColors.primaryYellow,
                backgroundColor: AppColors.surface,
                textColor: AppColors.primaryYellow,
                onTap: _handleLanguageToggle,
              ),

              const SizedBox(height: 16.0),

              // 2. Main Perception Action Foundation Card
              Expanded(
                child: AccessibleTouchCard(
                  title: captureTitle,
                  subtitle: captureSubtitle,
                  icon: Icons.center_focus_strong,
                  semanticLabel: '$captureTitle. $captureSubtitle',
                  semanticHint:
                      'Triggers environment capture and speech description',
                  borderColor: AppColors.secondaryCyan,
                  backgroundColor: AppColors.surface,
                  textColor: AppColors.textLight,
                  minHeight: 180.0,
                  onTap: _handlePerceptionAction,
                ),
              ),

              const SizedBox(height: 16.0),

              // 3. Status and Feedback Banner
              Semantics(
                liveRegion: true,
                label: 'System Status: $_statusMessage',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 14.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      AccessibilityConstants.borderRadius,
                    ),
                    border: Border.all(
                      color: _isBackendConnected == true
                          ? AppColors.primaryYellow
                          : AppColors.alertRed,
                      width: 2.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isBackendConnected == true
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        color: _isBackendConnected == true
                            ? AppColors.primaryYellow
                            : AppColors.alertRed,
                        size: 28.0,
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: AccessibilityConstants.bodyFontSize,
                          ),
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
    );
  }
}
