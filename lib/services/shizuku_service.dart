import 'package:shizuku_api/shizuku_api.dart';

class ShizukuNotRunningException implements Exception {
  final String message;
  ShizukuNotRunningException(this.message);
  @override
  String toString() => 'ShizukuNotRunningException: $message';
}

class ShizukuPermissionException implements Exception {
  final String message;
  ShizukuPermissionException(this.message);
  @override
  String toString() => 'ShizukuPermissionException: $message';
}

class AdbCommandException implements Exception {
  final String message;
  AdbCommandException(this.message);
  @override
  String toString() => 'AdbCommandException: $message';
}

class ShizukuService {
  final ShizukuApi _shizuku = ShizukuApi();
  bool _isAvailable = false;
  bool _hasPermission = false;

  bool get isAvailable => _isAvailable;
  bool get hasPermission => _hasPermission;

  /// Check if Shizuku is installed and running
  Future<bool> checkAvailability() async {
    try {
      _isAvailable = await _shizuku.pingBinder() ?? false;
      if (_isAvailable) {
        _hasPermission = await _shizuku.checkPermission() ?? false;
      }
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      _hasPermission = false;
      return false;
    }
  }

  /// Request Shizuku permission
  Future<bool> requestPermission() async {
    if (!_isAvailable) return false;
    try {
      _hasPermission = await _shizuku.requestPermission() ?? false;
      return _hasPermission;
    } catch (e) {
      return false;
    }
  }

  bool _isSafeCommand(String command) {
    // Block shell metacharacters used for command injection
    final dangerousChars = RegExp(r'[;&|`$><]');
    return !dangerousChars.hasMatch(command);
  }

  /// Run an ADB shell command via Shizuku
  Future<String> runCommand(String command) async {
    if (!_isSafeCommand(command)) {
      throw AdbCommandException('Security Alert: Command contains forbidden shell characters.');
    }
    if (!_isAvailable) {
      throw ShizukuNotRunningException('Shizuku is not running. Please start Shizuku first.');
    }
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        throw ShizukuPermissionException('Shizuku permission denied.');
      }
    }

    try {
      final result = await _shizuku.runCommand(command);
      return result ?? 'Command executed (no output)';
    } catch (e) {
      throw AdbCommandException('Error running command: $e');
    }
  }

  /// Toggle WiFi via Shizuku
  Future<String> toggleWifi(bool enable) async {
    return runCommand('svc wifi ${enable ? 'enable' : 'disable'}');
  }

  /// Toggle Bluetooth via Shizuku
  Future<String> toggleBluetooth(bool enable) async {
    return runCommand(
      'cmd bluetooth_manager ${enable ? 'enable' : 'disable'}',
    );
  }

  bool _isValidPackageName(String packageName) {
    return RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(packageName);
  }

  /// Force stop an app
  Future<String> forceStopApp(String packageName) async {
    if (!_isValidPackageName(packageName)) {
      throw AdbCommandException('Invalid package name format.');
    }
    return runCommand('am force-stop $packageName');
  }

  /// Clear app data
  Future<String> clearAppData(String packageName) async {
    if (!_isValidPackageName(packageName)) {
      throw AdbCommandException('Invalid package name format.');
    }
    return runCommand('pm clear $packageName');
  }
}
