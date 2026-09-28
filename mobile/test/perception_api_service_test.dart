import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/perception/services/perception_api_service.dart';

void main() {
  group('PerceptionApiService Unit Tests', () {
    test(
      'perceiveImage sends multipart request and parses 200 OK response',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/v1/perceive');
          expect(request.method, 'POST');
          expect(
            request.headers['content-type'],
            contains('multipart/form-data'),
          );

          final jsonResponse = {
            'request_id': 'req-test-999',
            'status': 'success',
            'language': 'en',
            'description':
                'A person is standing in front of you. A paved sidewalk is nearby.',
            'scene_data': {'objects': [], 'context': {}},
            'processing_time_ms': 512.4,
            'warnings': [],
          };

          return http.Response(
            jsonEncode(jsonResponse),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = PerceptionApiService(client: mockClient);
        final result = await service.perceiveImage(
          imagePath: 'sample.jpg',
          imageBytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        );

        expect(result.isSuccess, isTrue);
        expect(
          result.description,
          'A person is standing in front of you. A paved sidewalk is nearby.',
        );
        expect(result.requestId, 'req-test-999');
        expect(result.processingTimeMs, 512.4);
      },
    );

    test('perceiveImage handles backend error JSON (HTTP 422)', () async {
      final mockClient = MockClient((request) async {
        final errorResponse = {
          'request_id': 'req-err-422',
          'status': 'error',
          'error_code': 'INVALID_IMAGE',
          'message': 'Image bytes corrupted or unreadable.',
        };
        return http.Response(
          jsonEncode(errorResponse),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = PerceptionApiService(client: mockClient);
      final result = await service.perceiveImage(
        imagePath: 'corrupt.jpg',
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'Image bytes corrupted or unreadable.');
    });

    test(
      'perceiveFile fallback to bytes when file does not exist on disk',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'request_id': 'req-file-1',
              'status': 'success',
              'language': 'en',
              'description': 'View of a clear corridor.',
              'scene_data': {'objects': [], 'context': {}},
              'processing_time_ms': 300.0,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = PerceptionApiService(client: mockClient);
        final xfile = XFile.fromData(
          Uint8List.fromList([1, 2, 3, 4]),
          name: 'test_photo.jpg',
          path: 'virtual_test_photo.jpg',
        );

        final result = await service.perceiveFile(file: xfile, language: 'en');

        expect(result.isSuccess, isTrue);
        expect(result.description, 'View of a clear corridor.');
      },
    );

    test('perceiveImage handles client connection error gracefully', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final service = PerceptionApiService(client: mockClient);
      final result = await service.perceiveImage(
        imagePath: 'photo.jpg',
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Connection error'));
    });

    test(
      'perceiveVideoFile sends multipart request with video field and parses 200 response',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/v1/perceive/video');
          expect(request.method, 'POST');
          expect(
            request.headers['content-type'],
            contains('multipart/form-data'),
          );

          final jsonResponse = {
            'request_id': 'req-video-200',
            'status': 'success',
            'language': 'te',
            'description':
                'ఒక వ్యక్తి కుడి వైపుకు నడుస్తూ మెట్లు ఎక్కుతున్నారు.',
            'scene_data': {'objects': [], 'context': {}},
            'processing_time_ms': 1240.5,
            'warnings': [],
          };

          return http.Response(
            jsonEncode(jsonResponse),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = PerceptionApiService(client: mockClient);
        final xfile = XFile.fromData(
          Uint8List.fromList([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70]),
          name: 'sample_video.mp4',
          path: 'sample_video.mp4',
        );

        final result = await service.perceiveVideoFile(
          file: xfile,
          language: 'te',
        );

        expect(result.isSuccess, isTrue);
        expect(
          result.description,
          'ఒక వ్యక్తి కుడి వైపుకు నడుస్తూ మెట్లు ఎక్కుతున్నారు.',
        );
        expect(result.requestId, 'req-video-200');
        expect(result.processingTimeMs, 1240.5);
      },
    );

    test(
      'perceiveVideoFile handles backend 413 video size limit error',
      () async {
        final mockClient = MockClient((request) async {
          final errorResponse = {
            'request_id': 'req-video-413',
            'status': 'error',
            'error_code': 'VIDEO_TOO_LARGE',
            'message': 'Video exceeds 25 MiB limit.',
          };
          return http.Response(
            jsonEncode(errorResponse),
            413,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = PerceptionApiService(client: mockClient);
        final xfile = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'large_video.mp4',
        );

        final result = await service.perceiveVideoFile(file: xfile);

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, 'Video exceeds 25 MiB limit.');
      },
    );

    test(
      'perceiveVideoFile handles backend 422 duration error via detail field',
      () async {
        final mockClient = MockClient((request) async {
          final errorResponse = {
            'detail': 'Video duration exceeds maximum allowed (10.0s)',
          };
          return http.Response(
            jsonEncode(errorResponse),
            422,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = PerceptionApiService(client: mockClient);
        final xfile = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'long_video.mp4',
        );

        final result = await service.perceiveVideoFile(file: xfile);

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('exceeds maximum allowed'));
      },
    );

    test('perceiveVideoFile handles client timeout error gracefully', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Client socket closed');
      });

      final service = PerceptionApiService(client: mockClient);
      final xfile = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'test.mp4',
      );

      final result = await service.perceiveVideoFile(file: xfile);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Connection error'));
    });
  });
}
