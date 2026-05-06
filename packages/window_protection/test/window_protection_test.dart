import 'package:flutter_test/flutter_test.dart';
import 'package:window_protection/window_protection.dart';
import 'package:window_protection/window_protection_platform_interface.dart';
import 'package:window_protection/window_protection_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockWindowProtectionPlatform
    with MockPlatformInterfaceMixin
    implements WindowProtectionPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> isProtectionEnabled() => Future.value(true);

  @override
  Future<bool> isProtectionSupported() => Future.value(true);

  @override
  Future<bool> setProtection({required bool enabled}) => Future.value(enabled);
}

void main() {
  final WindowProtectionPlatform initialPlatform = WindowProtectionPlatform.instance;

  test('$MethodChannelWindowProtection is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWindowProtection>());
  });

  test('getPlatformVersion', () async {
    WindowProtection windowProtectionPlugin = WindowProtection();
    MockWindowProtectionPlatform fakePlatform = MockWindowProtectionPlatform();
    WindowProtectionPlatform.instance = fakePlatform;

    expect(await windowProtectionPlugin.getPlatformVersion(), '42');
  });
}
