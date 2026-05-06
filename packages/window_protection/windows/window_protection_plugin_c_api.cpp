#include "include/window_protection/window_protection_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "window_protection_plugin.h"

void WindowProtectionPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  window_protection::WindowProtectionPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
