import 'package:shared_preferences/shared_preferences.dart';
import 'app_language.dart';

/// Contract for persisting user language preferences across app launches.
abstract class BaseLanguagePreferencesService {
  Future<AppLanguage?> getPreferredLanguage();
  Future<void> setPreferredLanguage(AppLanguage language);
  Future<bool> hasLanguagePreference();
  Future<void> clearPreference();
}

/// Production implementation of [BaseLanguagePreferencesService] using SharedPreferences.
class LanguagePreferencesService implements BaseLanguagePreferencesService {
  static const String _keyLanguage = 'preferred_language';
  static const String _keyFirstLaunchCompleted = 'first_launch_completed';

  final SharedPreferences? _prefs;

  LanguagePreferencesService({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  @override
  Future<AppLanguage?> getPreferredLanguage() async {
    try {
      final prefs = await _getPrefs();
      final code = prefs.getString(_keyLanguage);
      if (code == null) return null;
      return AppLanguage.values.firstWhere(
        (lang) => lang.code == code,
        orElse: () => AppLanguage.english,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setPreferredLanguage(AppLanguage language) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_keyLanguage, language.code);
      await prefs.setBool(_keyFirstLaunchCompleted, true);
    } catch (_) {}
  }

  @override
  Future<bool> hasLanguagePreference() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_keyFirstLaunchCompleted) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearPreference() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keyLanguage);
      await prefs.remove(_keyFirstLaunchCompleted);
    } catch (_) {}
  }
}
