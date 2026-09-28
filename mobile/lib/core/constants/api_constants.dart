/// Backend API networking constants and endpoints.
class ApiConstants {
  ApiConstants._();

  /// Default local backend address.
  /// 10.0.2.2 points to host machine from standard Android Emulator.
  /// 127.0.0.1 or local network IP can be used for physical devices.
  static const String defaultBaseUrl = 'https://vision-based-assistive-perception-system.onrender.com';

  // Endpoints
  static const String healthEndpoint = '/health';
  static const String perceiveEndpoint = '/api/v1/perceive';
  static const String perceiveVideoEndpoint = '/api/v1/perceive/video';
  static const String ttsEndpoint = '/api/v1/tts';
}
