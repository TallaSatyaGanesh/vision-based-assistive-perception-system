import 'app_language.dart';

/// Matches spoken user inputs to [AppLanguage] based on phonetic, transliterated,
/// and native script patterns.
class LanguageMatcher {
  LanguageMatcher._();

  static final RegExp _teluguPatterns = RegExp(
    r'(^|\b)(తెలుగు|తెలుగులో|తెలుగుభాష|telugu select cheyyi|telugu select cheyi|telugu select|telugu kavali|telugu choose cheyyi|telugu choose cheyi|telugu bhasha|telugu|thelugu|telgu|telugulo|first option|option 1|option one)(\b|$)',
    caseSensitive: false,
  );

  static final RegExp _englishPatterns = RegExp(
    r'(^|\b)(english select cheyyi|english select cheyi|english select|english kavali|english choose cheyyi|english choose cheyi|english bhasha|english|inglish|ఇంగ్లీష్|ఇంగ్లిష్|ఇంగ్లీషు|second option|option 2|option two)(\b|$)',
    caseSensitive: false,
  );

  /// Resolves spoken [transcript] to [AppLanguage], or null if ambiguous or unrecognized.
  static AppLanguage? matchLanguage(String transcript) {
    var cleaned = transcript.trim().toLowerCase();
    cleaned = cleaned.replaceAll(RegExp(r'[\.,\?!:;"\-_]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;

    final hasTelugu = _teluguPatterns.hasMatch(cleaned);
    final hasEnglish = _englishPatterns.hasMatch(cleaned);

    // If both or neither match, it is ambiguous/unclear
    if (hasTelugu && hasEnglish) {
      return null;
    }
    if (hasTelugu) {
      return AppLanguage.telugu;
    }
    if (hasEnglish) {
      return AppLanguage.english;
    }

    return null;
  }
}
