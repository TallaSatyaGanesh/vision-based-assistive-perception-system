import 'package:flutter/foundation.dart';

/// Voice navigation actions available to blind users.
enum VoiceAction {
  captureImage,
  recordVideo,
  analyze,
  retake,
  retry,
}

/// Matches spoken user inputs to [VoiceAction] for hands-free navigation.
class VoiceCommandMatcher {
  VoiceCommandMatcher._();

  static final RegExp _retryPatterns = RegExp(
    r'(^|\s|\b)(retry analysis|retry perception|retry photo|retry video|retry image|retry cheyi|retry cheyandi|retry|malli analyze cheyi|malli analyze cheyandi|malli vishleshana cheyi|రీట్రై)($|\s|\b)',
    caseSensitive: false,
  );

  static final RegExp _retakePatterns = RegExp(
    r'(^|\s|\b)(retake video|retake photo|retake cheyi|retake cheyandi|retake|record again|take again|try again|discard|record new video|new video|malli teeyi|malli theeyi|malli teeyandi|malli theeyandi|malli record cheyi|malli record cheyandi|malli try cheyi|malli try cheyyi|malli cheyi|marosari teeyi|marosari theeyi|marosari record cheyi|రీటేక్|రీటెక్|మళ్ళీ తీయి|మళ్లీ తీయి|మళ్ళీ రికార్డ్ చేయి|మళ్లీ రికార్డ్ చేయి|మరోసారి తీయి|మరోసారి రికార్డ్ చేయి|మళ్ళీ ప్రయత్నించు|మళ్లీ ప్రయత్నించు)($|\s|\b)',
    caseSensitive: false,
  );

  static final RegExp _analyzePatterns = RegExp(
    r'(^|\s|\b)(analyze video|analyze image|analyze cheyi|analyze cheyandi|analyze|analyse video|analyse image|analyse cheyi|analyse cheyandi|analyse|start analysis|run perception|inspect|video choodu|video chudu|choodalante choodu|choodu|chudu|చూడు|vishleshinchu|visleshinchu|vishleshana cheyi|visleshana cheyi|vishleshana cheyandi|visleshana cheyandi|vishleshinchandi|visleshinchandi|vishleshana|visleshana|విశ్లేషించు|విశ్లేషణ చేయి|విశ్లేషణ చేయండి|విశ్లేషించండి|విశ్లేషణ)($|\s|\b)',
    caseSensitive: false,
  );

  static final RegExp _capturePatterns = RegExp(
    r'(^|\s|\b)(capture an image|capture image|capture a photo|capture photo|capture a picture|capture picture|capture scene|take an image|take image|take a photo|take photo|take a picture|take picture|click a photo|click photo|click a picture|click picture|snap a photo|snap photo|photo please|photo theeyi|photo teeyi|photo teesuko|photo tisuko|photo theeyandi|photo teeyandi|photo teesukondi|photo tisukondi|photo theey|photo teey|photo thiyy|photo tiyy|photo capture cheyandi|photo capture cheyi|camera tho photo theeyi|camera tho photo teeyi|photo|first option|option 1|option one|modati option|number 1|number okati|okati|మొదటి ఆప్షన్|నెంబర్ 1|నెంబర్ ఒకటి|ఒకటి|కెమెరాతో ఫోటో తీయి|ఫోటో తీయి|ఫోటో తీయండి|ఫోటో తీసుకో|ఫోటో తీసుకోండి|ఫోటో|చిత్రాన్ని తీయి|దృశ్యం తీయి|క్యాప్చర్ ఇమేజ్|క్యాప్చర్ ఫోటో)($|\s|\b)',
    caseSensitive: false,
  );

  static final RegExp _recordPatterns = RegExp(
    r'(^|\s|\b)(record short video|record a video|record video|start recording|record a clip|record clip|shoot video|take a video|take video|start a video|start video|video recording|video record cheyandi|video record cheyi|video start cheyandi|video start cheyi|video theeyandi|video theeyi|video teeyandi|video teeyi|video cheyandi|video cheyi|record cheyandi|record cheyi|video|second option|option 2|option two|rendava option|number 2|number rendu|rendu|రెండవ ఆప్షన్|నెంబర్ 2|నెంబర్ రెండు|రెండు|వీడియో రికార్డ్ చేయండి|వీడియో రికార్డ్ చేయి|వీడియో రికార్డ్|వీడియో తీయండి|వీడియో తీయి|వీడియో చేయండి|వీడియో చేయి|వీడియో|రికార్డ్ చేయండి|రికార్డ్ చేయి)($|\s|\b)',
    caseSensitive: false,
  );

  /// Resolves spoken [transcript] to a [VoiceAction], or null if ambiguous or unrecognized.
  static VoiceAction? matchCommand(String transcript) {
    var cleaned = transcript.toLowerCase();
    // Normalize speech-recognition punctuation (periods, commas, question marks, quotes, hyphens, slashes, etc.)
    cleaned = cleaned.replaceAll(RegExp(r'''[\.,\?!:;"'\-_/\\`~@#$%^&*()\[\]{}|<>]'''), ' ');
    // Normalize multiple whitespace to single space and trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;

    final hasRetry = _retryPatterns.hasMatch(cleaned);
    final hasRetake = _retakePatterns.hasMatch(cleaned);
    final hasAnalyze = _analyzePatterns.hasMatch(cleaned);

    // If conflicting review/retry commands match, it is ambiguous
    if ((hasRetake && hasAnalyze) ||
        (hasRetry && hasRetake) ||
        (hasRetry && hasAnalyze && (cleaned.contains(' leda ') || cleaned.contains(' or ')))) {
      debugPrint('[VoiceCommandMatcher] Ambiguous input matching multiple actions: "$cleaned"');
      return null;
    }

    if (hasRetry) {
      debugPrint('[VoiceCommandMatcher] "$transcript" -> "$cleaned" -> matched: VoiceAction.retry');
      return VoiceAction.retry;
    }
    if (hasRetake) {
      debugPrint('[VoiceCommandMatcher] "$transcript" -> "$cleaned" -> matched: VoiceAction.retake');
      return VoiceAction.retake;
    }
    if (hasAnalyze) {
      debugPrint('[VoiceCommandMatcher] "$transcript" -> "$cleaned" -> matched: VoiceAction.analyze');
      return VoiceAction.analyze;
    }

    final hasCapture = _capturePatterns.hasMatch(cleaned);
    final hasRecord = _recordPatterns.hasMatch(cleaned);

    // If both capture and record match (e.g. "capture image or record video"), it is ambiguous
    if (hasCapture && hasRecord) {
      debugPrint('[VoiceCommandMatcher] Ambiguous input matching capture and record: "$cleaned"');
      return null;
    }

    if (hasCapture) {
      debugPrint('[VoiceCommandMatcher] "$transcript" -> "$cleaned" -> matched: VoiceAction.captureImage');
      return VoiceAction.captureImage;
    }
    if (hasRecord) {
      debugPrint('[VoiceCommandMatcher] "$transcript" -> "$cleaned" -> matched: VoiceAction.recordVideo');
      return VoiceAction.recordVideo;
    }

    debugPrint('[VoiceCommandMatcher] "$transcript" -> "$cleaned" -> matched: null (unrecognized)');
    return null;
  }
}
