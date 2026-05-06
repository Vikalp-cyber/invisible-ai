import 'package:flutter/foundation.dart';

import 'native_bridge_service.dart';

/// Coordinates screen-capture protection for the overlay window.
class OverlayProtectionManager {
  OverlayProtectionManager({NativeBridgeService? bridgeService})
    : _bridgeService = bridgeService ?? NativeBridgeService();

  final NativeBridgeService _bridgeService;
  bool _supported = false;
  bool _enabled = false;

  bool get isSupported => _supported;
  bool get isEnabled => _enabled;

  /// Auto-applies protection at startup when available.
  Future<void> initialize({
    bool autoApplyOnStartup = true,
    bool startupEnabled = true,
  }) async {
    _supported = await _bridgeService.isProtectionSupported();
    if (!_supported) {
      debugPrint(
        'OverlayProtectionManager: capture protection not supported on this Windows build.',
      );
      return;
    }

    if (!autoApplyOnStartup) {
      _enabled = await _bridgeService.isCaptureProtectionEnabled();
      return;
    }

    final shouldEnable = startupEnabled;
    await setProtectionEnabled(shouldEnable);
  }

  Future<bool> setProtectionEnabled(bool enabled) async {
    if (!_supported) {
      return false;
    }
    final applied = await _bridgeService.setCaptureProtection(enabled);
    if (!applied) {
      return false;
    }
    _enabled = await _bridgeService.isCaptureProtectionEnabled();
    return _enabled == enabled;
  }

  Future<bool> toggleProtection() async {
    return setProtectionEnabled(!_enabled);
  }

  Future<bool> refreshState() async {
    if (!_supported) {
      _enabled = false;
      return _enabled;
    }
    _enabled = await _bridgeService.isCaptureProtectionEnabled();
    return _enabled;
  }
}
