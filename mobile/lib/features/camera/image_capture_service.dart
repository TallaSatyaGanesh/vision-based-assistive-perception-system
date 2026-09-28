import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'camera_service.dart';

/// Abstract contract for capturing frames and image data.
abstract class BaseImageCaptureService {
  Future<XFile?> captureImage();
  Future<Uint8List?> captureBytes();
}

/// Image capture service leveraging BaseCameraService to retrieve captured files and bytes.
class ImageCaptureService implements BaseImageCaptureService {
  final BaseCameraService _cameraService;

  ImageCaptureService({BaseCameraService? cameraService})
    : _cameraService = cameraService ?? CameraService();

  @override
  Future<XFile?> captureImage() async {
    return _cameraService.takePicture();
  }

  @override
  Future<Uint8List?> captureBytes() async {
    final file = await _cameraService.takePicture();
    if (file == null) return null;
    return file.readAsBytes();
  }
}
