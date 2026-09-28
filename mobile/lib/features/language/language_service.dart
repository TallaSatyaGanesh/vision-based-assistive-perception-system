import 'app_language.dart';

/// Language selection manager interface and implementation.
abstract class BaseLanguageService {
  AppLanguage get currentLanguage;
  void setLanguage(AppLanguage language);
  AppLanguage toggleLanguage();
}

class LanguageService implements BaseLanguageService {
  AppLanguage _currentLanguage = AppLanguage.english;

  @override
  AppLanguage get currentLanguage => _currentLanguage;

  @override
  void setLanguage(AppLanguage language) {
    _currentLanguage = language;
  }

  @override
  AppLanguage toggleLanguage() {
    _currentLanguage = _currentLanguage.next;
    return _currentLanguage;
  }
}
