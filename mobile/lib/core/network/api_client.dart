import 'dart:convert';
import 'dart:io';
import '../constants/api_constants.dart';

/// Abstract API client for backend communication.
abstract class BaseApiClient {
  Future<bool> checkBackendHealth({
    String baseUrl = ApiConstants.defaultBaseUrl,
  });
}

/// Core API Client implementation using dart:io HttpClient (zero external dependencies).
class ApiClient implements BaseApiClient {
  final HttpClient _client;

  ApiClient({HttpClient? client}) : _client = client ?? HttpClient();

  @override
  Future<bool> checkBackendHealth({
    String baseUrl = ApiConstants.defaultBaseUrl,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl${ApiConstants.healthEndpoint}');
      final request = await _client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == HttpStatus.ok) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        return data['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void close() {
    _client.close();
  }
}
