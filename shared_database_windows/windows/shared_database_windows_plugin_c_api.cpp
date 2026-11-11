#include "include/shared_database_windows/shared_database_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "shared_database_windows_plugin.h"

void SharedDatabaseWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  shared_database_windows::SharedDatabaseWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
