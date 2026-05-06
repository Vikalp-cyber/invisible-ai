#ifndef FLUTTER_PLUGIN_WINDOW_PROTECTION_PLUGIN_H_
#define FLUTTER_PLUGIN_WINDOW_PROTECTION_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace window_protection {

class WindowProtectionPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  WindowProtectionPlugin(flutter::PluginRegistrarWindows *registrar);

  virtual ~WindowProtectionPlugin();

  // Disallow copy and assign.
  WindowProtectionPlugin(const WindowProtectionPlugin&) = delete;
  WindowProtectionPlugin& operator=(const WindowProtectionPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  bool IsExcludeFromCaptureSupported() const;
  HWND GetOverlayWindowHandle() const;
  flutter::PluginRegistrarWindows *registrar_;
};

}  // namespace window_protection

#endif  // FLUTTER_PLUGIN_WINDOW_PROTECTION_PLUGIN_H_
