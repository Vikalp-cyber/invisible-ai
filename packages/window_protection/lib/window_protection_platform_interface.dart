import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'window_protection_method_channel.dart';

abstract class WindowProtectionPlatform extends PlatformInterface {
  /// Constructs a WindowProtectionPlatform.
  WindowProtectionPlatform() : super(token: _token);

  static final Object _token = Object();

  static WindowProtectionPlatform _instance = MethodChannelWindowProtection();

  /// The default instance of [WindowProtectionPlatform] to use.
  ///
  /// Defaults to [MethodChannelWindowProtection].
  static WindowProtectionPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WindowProtectionPlatform] when
  /// they register themselves.
  static set instance(WindowProtectionPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  Future<bool> setProtection({required bool enabled}) {
    throw UnimplementedError('setProtection() has not been implemented.');
  }

  Future<bool> isProtectionEnabled() {
    throw UnimplementedError('isProtectionEnabled() has not been implemented.');
  }

  Future<bool> isProtectionSupported() {
    throw UnimplementedError('isProtectionSupported() has not been implemented.');
  }
}
