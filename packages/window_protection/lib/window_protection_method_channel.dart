import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'window_protection_platform_interface.dart';

/// An implementation of [WindowProtectionPlatform] that uses method channels.
class MethodChannelWindowProtection extends WindowProtectionPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('window_protection');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<bool> setProtection({required bool enabled}) async {
    final applied = await methodChannel.invokeMethod<bool>(
      'setProtection',
      <String, Object?>{'enable': enabled},
    );
    return applied ?? false;
  }

  @override
  Future<bool> isProtectionEnabled() async {
    final enabled = await methodChannel.invokeMethod<bool>('isProtectionEnabled');
    return enabled ?? false;
  }

  @override
  Future<bool> isProtectionSupported() async {
    final supported = await methodChannel.invokeMethod<bool>('isProtectionSupported');
    return supported ?? false;
  }
}
