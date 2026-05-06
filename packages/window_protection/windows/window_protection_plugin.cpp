#include "window_protection_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace window_protection {

namespace {
constexpr DWORD kExcludeFromCapture = 0x00000011;
constexpr DWORD kMonitorOnly = 0x00000001;

HWND ResolveTopLevelWindow(HWND hwnd) {
  if (hwnd == nullptr) {
    return nullptr;
  }
  HWND root = GetAncestor(hwnd, GA_ROOT);
  return root != nullptr ? root : hwnd;
}
}

// static
void WindowProtectionPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "window_protection",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WindowProtectionPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WindowProtectionPlugin::WindowProtectionPlugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {}

WindowProtectionPlugin::~WindowProtectionPlugin() {}

bool WindowProtectionPlugin::IsExcludeFromCaptureSupported() const {
  return IsWindows10OrGreater();
}

HWND WindowProtectionPlugin::GetOverlayWindowHandle() const {
  if (registrar_ == nullptr || registrar_->GetView() == nullptr) {
    return nullptr;
  }
  return ResolveTopLevelWindow(registrar_->GetView()->GetNativeWindow());
}

void WindowProtectionPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method_call.method_name().compare("isProtectionSupported") == 0) {
    result->Success(flutter::EncodableValue(IsExcludeFromCaptureSupported()));
  } else if (method_call.method_name().compare("isProtectionEnabled") == 0) {
    HWND hwnd = GetOverlayWindowHandle();
    if (hwnd == nullptr) {
      result->Error("NO_WINDOW", "Could not get native window handle.");
      return;
    }

    DWORD current_affinity = WDA_NONE;
    BOOL success = GetWindowDisplayAffinity(hwnd, &current_affinity);
    if (!success) {
      std::ostringstream message;
      message << "Failed to read window display affinity. Win32 error: "
              << GetLastError();
      result->Error("WIN32_ERROR", message.str());
      return;
    }

    result->Success(
        flutter::EncodableValue(current_affinity == kExcludeFromCapture ||
                                current_affinity == kMonitorOnly));
  } else if (method_call.method_name().compare("setProtection") == 0) {
    bool enable = false;
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue("enable"));
      if (it != args->end() && std::holds_alternative<bool>(it->second)) {
        enable = std::get<bool>(it->second);
      }
    }

    HWND hwnd = GetOverlayWindowHandle();
    if (!hwnd) {
      result->Error("NO_WINDOW", "Could not get native window handle.");
      return;
    }

    if (enable && !IsExcludeFromCaptureSupported()) {
      result->Error(
          "UNSUPPORTED",
          "WDA_EXCLUDEFROMCAPTURE is not supported on this Windows version.");
      return;
    }

    DWORD affinity = enable ? kExcludeFromCapture : WDA_NONE;
    BOOL success = SetWindowDisplayAffinity(hwnd, affinity);
    if (!success && enable && GetLastError() == ERROR_INVALID_PARAMETER) {
      // Some Windows builds reject WDA_EXCLUDEFROMCAPTURE but support the
      // legacy monitor-only protection mode.
      affinity = kMonitorOnly;
      success = SetWindowDisplayAffinity(hwnd, affinity);
    }
    if (!success) {
      std::ostringstream message;
      message << "Failed to set window display affinity. Win32 error: "
              << GetLastError();
      result->Error("WIN32_ERROR", message.str());
      return;
    }

    DWORD current_affinity = WDA_NONE;
    BOOL read_back_success = GetWindowDisplayAffinity(hwnd, &current_affinity);
    if (!read_back_success) {
      std::ostringstream message;
      message << "Protection applied but state verification failed. Win32 error: "
              << GetLastError();
      result->Error("VERIFY_FAILED", message.str());
      return;
    }

    const bool expected_state = enable;
    const bool actual_state =
        current_affinity == kExcludeFromCapture || current_affinity == kMonitorOnly;
    if (expected_state != actual_state) {
      result->Error("VERIFY_FAILED", "Display affinity state does not match request.");
      return;
    }

    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

}  // namespace window_protection
