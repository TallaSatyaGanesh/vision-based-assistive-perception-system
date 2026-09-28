import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../models/perception_result.dart';

/// Contract for perception API operations.
abstract class BasePerceptionApiService {
  Future<PerceptionResult> perceiveImage({
    required String imagePath,
    String language = 'en',
    Uint8List? imageBytes,
  });

  Future<PerceptionResult> perceiveFile({
    required XFile file,
    String language = 'en',
  });

  Future<PerceptionResult> perceiveVideoFile({
    required XFile file,
    String language = 'en',
    Uint8List? videoBytes,
  });
}

/// Service communicating with the FastAPI perception backend via multipart/form-data.
class PerceptionApiService implements BasePerceptionApiService {
  final http.Client _client;
  final String baseUrl;

  PerceptionApiService({
    http.Client? client,
    this.baseUrl = ApiConstants.defaultBaseUrl,
  }) : _client = client ?? http.Client();

  @override
  Future<PerceptionResult> perceiveImage({
    required String imagePath,
    String language = 'en',
    Uint8List? imageBytes,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl${ApiConstants.perceiveEndpoint}');
      final request = http.MultipartRequest('POST', uri);

      // 1. Language field (default "en")
      request.fields['language'] = language;

      // 2. Attach image file
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final filename = imagePath.isNotEmpty
            ? imagePath.split(RegExp(r'[\\/]')).last
            : 'captured_scene.jpg';
        request.files.add(
          http.MultipartFile.fromBytes('image', imageBytes, filename: filename),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );
      }

      // 3. Send request with timeout (45 seconds)
      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 45));

      final response = await http.Response.fromStream(streamedResponse);

      // 4. Handle response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return PerceptionResult.fromJson(data);
      } else {
        String errorMessage = 'Server error (${response.statusCode})';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData is Map) {
            if (errorData.containsKey('message')) {
              errorMessage = errorData['message'].toString();
            } else if (errorData.containsKey('detail')) {
              errorMessage = errorData['detail'].toString();
            }
          }
        } catch (_) {}
        return PerceptionResult.error(errorMessage, languageCode: language);
      }
    } on SocketException catch (_) {
      return PerceptionResult.error(
        'Unable to reach backend server. Please verify the server is running.',
        languageCode: language,
      );
    } on http.ClientException catch (e) {
      return PerceptionResult.error(
        'Connection error: ${e.message}',
        languageCode: language,
      );
    } on TimeoutException catch (_) {
      return PerceptionResult.error(
        'Perception request timed out. Please try again.',
        languageCode: language,
      );
    } catch (e) {
      return PerceptionResult.error(
        'Failed to analyze image: $e',
        languageCode: language,
      );
    }
  }

  @override
  Future<PerceptionResult> perceiveFile({
    required XFile file,
    String language = 'en',
  }) async {
    Uint8List? bytes;
    if (kIsWeb) {
      bytes = await file.readAsBytes();
    } else {
      try {
        final f = File(file.path);
        if (!f.existsSync()) {
          bytes = await file.readAsBytes();
        }
      } catch (_) {
        bytes = await file.readAsBytes();
      }
    }

    return perceiveImage(
      imagePath: file.path,
      language: language,
      imageBytes: bytes,
    );
  }

  @override
  Future<PerceptionResult> perceiveVideoFile({
    required XFile file,
    String language = 'en',
    Uint8List? videoBytes,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl${ApiConstants.perceiveVideoEndpoint}');
      final request = http.MultipartRequest('POST', uri);

      // 1. Language field (default "en")
      request.fields['language'] = language;

      // 2. Attach video file with field name 'video'
      final filename = file.name.isNotEmpty
          ? file.name
          : (file.path.isNotEmpty
                ? file.path.split(RegExp(r'[\\/]')).last
                : 'short_video.mp4');

      if (videoBytes != null && videoBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes('video', videoBytes, filename: filename),
        );
      } else if (!kIsWeb && file.path.isNotEmpty) {
        try {
          final f = File(file.path);
          if (f.existsSync()) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'video',
                file.path,
                filename: filename,
              ),
            );
          } else {
            final bytes = await file.readAsBytes();
            request.files.add(
              http.MultipartFile.fromBytes('video', bytes, filename: filename),
            );
          }
        } catch (_) {
          final bytes = await file.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes('video', bytes, filename: filename),
          );
        }
      } else {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('video', bytes, filename: filename),
        );
      }

      // 3. Send request with video-appropriate timeout (60 seconds)
      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));

      final response = await http.Response.fromStream(streamedResponse);

      // 4. Handle response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return PerceptionResult.fromJson(data);
      } else {
        String errorMessage = 'Server error (${response.statusCode})';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData is Map) {
            if (errorData.containsKey('message')) {
              errorMessage = errorData['message'].toString();
            } else if (errorData.containsKey('detail')) {
              errorMessage = errorData['detail'].toString();
            }
          }
        } catch (_) {}
        return PerceptionResult.error(errorMessage, languageCode: language);
      }
    } on SocketException catch (_) {
      return PerceptionResult.error(
        'Unable to reach backend server. Please verify the server is running.',
        languageCode: language,
      );
    } on http.ClientException catch (e) {
      return PerceptionResult.error(
        'Connection error: ${e.message}',
        languageCode: language,
      );
    } on TimeoutException catch (_) {
      return PerceptionResult.error(
        'Video perception request timed out. Please try again with a shorter video.',
        languageCode: language,
      );
    } catch (e) {
      return PerceptionResult.error(
        'Failed to analyze video: $e',
        languageCode: language,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
