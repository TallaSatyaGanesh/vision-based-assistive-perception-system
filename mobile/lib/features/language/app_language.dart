/// Supported languages for speech output and perception narratives.
enum AppLanguage {
  english(
    code: 'en',
    displayName: 'English',
    nativeName: 'English',
    accessibilityAnnouncement: 'Language set to English',
    ttsLocale: 'en-US',
  ),
  telugu(
    code: 'te',
    displayName: 'Telugu',
    nativeName: 'తెలుగు',
    accessibilityAnnouncement: 'భాష తెలుగుకు మార్చబడింది',
    ttsLocale: 'te-IN',
  );

  final String code;
  final String displayName;
  final String nativeName;
  final String accessibilityAnnouncement;
  final String ttsLocale;

  const AppLanguage({
    required this.code,
    required this.displayName,
    required this.nativeName,
    required this.accessibilityAnnouncement,
    required this.ttsLocale,
  });

  /// Toggle between English and Telugu
  AppLanguage get next {
    switch (this) {
      case AppLanguage.english:
        return AppLanguage.telugu;
      case AppLanguage.telugu:
        return AppLanguage.english;
    }
  }
}
