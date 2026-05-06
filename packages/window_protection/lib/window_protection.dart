
import 'window_protection_platform_interface.dart';

class WindowProtection {
  Future<String?> getPlatformVersion() {
    return WindowProtectionPlatform.instance.getPlatformVersion();
  }

  Future<bool> setProtection({required bool enabled}) {
    return WindowProtectionPlatform.instance.setProtection(enabled: enabled);
  }

  Future<bool> isProtectionEnabled() {
    return WindowProtectionPlatform.instance.isProtectionEnabled();
  }

  Future<bool> isProtectionSupported() {
    return WindowProtectionPlatform.instance.isProtectionSupported();
  }
}
