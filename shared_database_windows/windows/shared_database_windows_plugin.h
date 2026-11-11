#ifndef FLUTTER_PLUGIN_SHARED_DATABASE_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_SHARED_DATABASE_WINDOWS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace shared_database_windows {

class SharedDatabaseWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  SharedDatabaseWindowsPlugin();

  virtual ~SharedDatabaseWindowsPlugin();

  SharedDatabaseWindowsPlugin(const SharedDatabaseWindowsPlugin &) = delete;
  SharedDatabaseWindowsPlugin &operator=(const SharedDatabaseWindowsPlugin &) =
      delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  bool is_host_ = false;
};

}  // namespace shared_database_windows

#endif  // FLUTTER_PLUGIN_SHARED_DATABASE_WINDOWS_PLUGIN_H_
