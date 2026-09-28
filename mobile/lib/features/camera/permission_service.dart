import 'package:permission_handler/permission_handler.dart' as ph;

/// Permission status enumeration representing runtime permission states.
enum AppPermissionStatus { granted, denied, permanentlyDenied }

/// Contract for managing runtime device permissions.
abstract class BasePermissionService {
  Future<AppPermissionStatus> requestMicrophonePermission();
  Future<AppPermissionStatus> checkMicrophonePermission();
  Future<bool> openAppSettings();
}

/// Production implementation of [BasePermissionService] using permission_handler.
class PermissionService implements BasePermissionService {
  const PermissionService();

  @override
  Future<AppPermissionStatus> requestMicrophonePermission() async {
    final status = await ph.Permission.microphone.request();
    return _mapStatus(status);
  }

  @override
  Future<AppPermissionStatus> checkMicrophonePermission() async {
    final status = await ph.Permission.microphone.status;
    return _mapStatus(status);
  }

  @override
  Future<bool> openAppSettings() async {
    return ph.openAppSettings();
  }

  AppPermissionStatus _mapStatus(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return AppPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return AppPermissionStatus.permanentlyDenied;
    }
    return AppPermissionStatus.denied;
  }
}
