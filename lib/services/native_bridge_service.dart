import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_protection/window_protection.dart';

/// Bridge to the native Windows plugin layer.
class NativeBridgeService {
  NativeBridgeService({WindowProtection? windowProtection})
      : _windowProtection = windowProtection ?? WindowProtection();

  final WindowProtection _windowProtection;

  Future<bool> isProtectionSupported() async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      return await _windowProtection.isProtectionSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<bool> setCaptureProtection(bool enabled) async {
    _assertWindows();
    try {
      return await _windowProtection.setProtection(enabled: enabled);
    } on PlatformException catch (e) {
      throw NativeBridgeException(
        code: e.code,
        message: e.message ?? 'Failed to set capture protection.',
      );
    }
  }

  Future<bool> isCaptureProtectionEnabled() async {
    _assertWindows();
    try {
      return await _windowProtection.isProtectionEnabled();
    } on PlatformException catch (e) {
      throw NativeBridgeException(
        code: e.code,
        message: e.message ?? 'Failed to read capture protection state.',
      );
    }
  }

  void _assertWindows() {
    if (!Platform.isWindows) {
      throw const NativeBridgeException(
        code: 'UNSUPPORTED_PLATFORM',
        message: 'Native screen capture protection is only available on Windows.',
      );
    }
  }
}

class NativeBridgeException implements Exception {
  const NativeBridgeException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => 'NativeBridgeException($code): $message';
}
