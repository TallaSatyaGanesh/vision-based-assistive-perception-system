/// Data model for environmental perception analysis result.
class PerceptionResult {
  final String description;
  final String languageCode;
  final DateTime timestamp;
  final bool isSuccess;
  final String? errorMessage;
  final String? requestId;
  final double? processingTimeMs;
  final List<String> warnings;
  final String status;

  const PerceptionResult({
    required this.description,
    required this.languageCode,
    required this.timestamp,
    this.isSuccess = true,
    this.errorMessage,
    this.requestId,
    this.processingTimeMs,
    this.warnings = const [],
    this.status = 'success',
  });

  factory PerceptionResult.fromJson(Map<String, dynamic> json) {
    return PerceptionResult(
      description: json['description'] as String? ?? '',
      languageCode: json['language'] as String? ?? 'en',
      requestId: json['request_id'] as String?,
      status: json['status'] as String? ?? 'success',
      processingTimeMs: (json['processing_time_ms'] as num?)?.toDouble(),
      warnings:
          (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      timestamp: DateTime.now(),
      isSuccess: (json['status'] as String? ?? 'success') != 'error',
    );
  }

  factory PerceptionResult.empty() {
    return PerceptionResult(
      description: '',
      languageCode: 'en',
      timestamp: DateTime.now(),
      isSuccess: true,
      status: 'empty',
    );
  }

  factory PerceptionResult.error(
    String message, {
    String languageCode = 'en',
    String? requestId,
  }) {
    return PerceptionResult(
      description: '',
      languageCode: languageCode,
      timestamp: DateTime.now(),
      isSuccess: false,
      errorMessage: message,
      requestId: requestId,
      status: 'error',
    );
  }
}
