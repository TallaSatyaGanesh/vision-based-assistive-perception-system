import 'package:camera/camera.dart';

/// Contract for camera hardware management and lifecycle operations.
abstract class BaseCameraService {
  List<CameraDescription> get availableCamerasList;
  CameraController? get controller;
  bool get isInitialized;
  bool get isTakingPicture;
  bool get isRecordingVideo;
  String? get errorMessage;
  CameraDescription? get currentCamera;

  Future<void> initialize();
  Future<XFile?> takePicture();
  Future<void> startVideoRecording();
  Future<XFile?> stopVideoRecording();
  Future<void> switchCamera();
  Future<void> dispose();
}

/// Production camera service managing CameraController lifecycle and device cameras.
class CameraService implements BaseCameraService {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isTakingPicture = false;
  String? _errorMessage;

  @override
  List<CameraDescription> get availableCamerasList => _cameras;

  @override
  CameraController? get controller => _controller;

  @override
  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;

  @override
  bool get isTakingPicture => _isTakingPicture;

  @override
  bool get isRecordingVideo =>
      _controller != null &&
      _controller!.value.isInitialized &&
      _controller!.value.isRecordingVideo;

  @override
  String? get errorMessage => _errorMessage;

  @override
  CameraDescription? get currentCamera {
    if (_cameras.isEmpty || _selectedCameraIndex >= _cameras.length) {
      return null;
    }
    return _cameras[_selectedCameraIndex];
  }

  @override
  Future<void> initialize() async {
    _errorMessage = null;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _errorMessage = 'No camera available on this device.';
        return;
      }

      // Prefer back-facing camera for assistive perception of environment
      final backCameraIndex = _cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );
      _selectedCameraIndex = backCameraIndex != -1 ? backCameraIndex : 0;

      await _initController(_cameras[_selectedCameraIndex]);
    } on CameraException catch (e) {
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt') {
        _errorMessage =
            'Camera permission was denied. Please allow camera access in settings.';
      } else if (e.code == 'CameraAccessRestricted') {
        _errorMessage = 'Camera access is restricted on this device.';
      } else {
        _errorMessage = 'Camera error: ${e.description ?? e.code}';
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize camera: $e';
    }
  }

  Future<void> _initController(CameraDescription cameraDescription) async {
    final previousController = _controller;
    final newController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _controller = newController;
    if (previousController != null) {
      await previousController.dispose();
    }

    await newController.initialize();
  }

  @override
  Future<XFile?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _errorMessage = 'Camera is not ready yet.';
      return null;
    }

    if (_isTakingPicture ||
        _controller!.value.isTakingPicture ||
        _controller!.value.isRecordingVideo) {
      return null;
    }

    try {
      _isTakingPicture = true;
      final file = await _controller!.takePicture();
      return file;
    } on CameraException catch (e) {
      _errorMessage = 'Capture failed: ${e.description ?? e.code}';
      return null;
    } catch (e) {
      _errorMessage = 'Capture error: $e';
      return null;
    } finally {
      _isTakingPicture = false;
    }
  }

  @override
  Future<void> startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _errorMessage = 'Camera is not ready yet.';
      return;
    }

    if (_isTakingPicture ||
        _controller!.value.isTakingPicture ||
        _controller!.value.isRecordingVideo) {
      return;
    }

    try {
      _errorMessage = null;
      await _controller!.startVideoRecording();
    } on CameraException catch (e) {
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt') {
        _errorMessage =
            'Camera permission was denied. Please allow camera access in settings.';
      } else if (e.code == 'AudioAccessDenied' ||
          e.code.toLowerCase().contains('audio') ||
          (e.description?.toLowerCase().contains('record_audio') ?? false) ||
          (e.description?.toLowerCase().contains('securityexception') ??
              false)) {
        _errorMessage =
            'Microphone permission is required to record video. Please allow microphone access.';
      } else {
        _errorMessage =
            'Failed to start video recording: ${e.description ?? e.code}';
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('record_audio') ||
          msg.contains('securityexception') ||
          msg.contains('audioaccessdenied')) {
        _errorMessage =
            'Microphone permission is required to record video. Please allow microphone access.';
      } else {
        _errorMessage = 'Failed to start video recording: $e';
      }
    }
  }

  @override
  Future<XFile?> stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _errorMessage = 'Camera is not ready yet.';
      return null;
    }

    if (!_controller!.value.isRecordingVideo) {
      return null;
    }

    try {
      final file = await _controller!.stopVideoRecording();
      return file;
    } on CameraException catch (e) {
      _errorMessage =
          'Failed to stop video recording: ${e.description ?? e.code}';
      return null;
    } catch (e) {
      _errorMessage = 'Failed to stop video recording: $e';
      return null;
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_cameras.length <= 1) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    try {
      await _initController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      _errorMessage = 'Failed to switch camera: $e';
    }
  }

  @override
  Future<void> dispose() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      await c.dispose();
    }
  }
}
