#ifndef FLUTTER_PLUGIN_SHARED_DATABASE_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_SHARED_DATABASE_WINDOWS_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#include <memory>

#include "shared_database_api.g.h"

namespace shared_database_windows {

class SharedDatabaseWindowsPlugin final
    : public flutter::Plugin,
      public shared_database_windows_pigeon::SharedDatabaseApi {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  SharedDatabaseWindowsPlugin();

  virtual ~SharedDatabaseWindowsPlugin();

  SharedDatabaseWindowsPlugin(const SharedDatabaseWindowsPlugin &) = delete;
  SharedDatabaseWindowsPlugin &operator=(const SharedDatabaseWindowsPlugin &) =
      delete;

  // — shared_database_windows_pigeon::SharedDatabaseApi —

  std::optional<shared_database_windows_pigeon::FlutterError> Initialize() override;
  std::optional<shared_database_windows_pigeon::FlutterError> EnsureCollection(
      const std::string &name) override;
  shared_database_windows_pigeon::ErrorOr<flutter::EncodableList>
  GetCollections() override;
  std::optional<shared_database_windows_pigeon::FlutterError> RenameCollection(
      const std::string &from, const std::string &to) override;
  std::optional<shared_database_windows_pigeon::FlutterError> RemoveCollection(
      const std::string &name) override;
  shared_database_windows_pigeon::ErrorOr<flutter::EncodableList>
  GetCollectionsDetailed() override;
  shared_database_windows_pigeon::ErrorOr<std::string> Put(
      const std::string &collection, const std::string *id,
      const std::string &data_json) override;
  shared_database_windows_pigeon::ErrorOr<flutter::EncodableList> PutMany(
      const std::string &collection,
      const flutter::EncodableList &records) override;
  shared_database_windows_pigeon::ErrorOr<std::string> Patch(
      const std::string &collection, const std::string &id,
      const std::string &data_json) override;
  shared_database_windows_pigeon::ErrorOr<
      std::optional<shared_database_windows_pigeon::RecordData>>
  GetById(const std::string &collection, const std::string &id) override;
  shared_database_windows_pigeon::ErrorOr<flutter::EncodableList> GetAll(
      const std::string &collection, const int64_t *limit,
      const int64_t *offset) override;
  std::optional<shared_database_windows_pigeon::FlutterError> RemoveById(
      const std::string &collection, const std::string &id) override;
  std::optional<shared_database_windows_pigeon::FlutterError> RemoveAll(
      const std::string &collection) override;
  shared_database_windows_pigeon::ErrorOr<std::optional<std::string>>
  GetPreferenceValue(const std::string &key) override;
  std::optional<shared_database_windows_pigeon::FlutterError> SetPreferenceValue(
      const std::string &key, const std::string &value) override;
  std::optional<shared_database_windows_pigeon::FlutterError> RemovePreference(
      const std::string &key) override;
  shared_database_windows_pigeon::ErrorOr<flutter::EncodableList>
  GetPreferences() override;
  shared_database_windows_pigeon::ErrorOr<
      shared_database_windows_pigeon::CollectionsWatchToken>
  GetCollectionsWatchToken() override;
  shared_database_windows_pigeon::ErrorOr<
      shared_database_windows_pigeon::CollectionWatchToken>
  GetCollectionWatchToken(const std::string &collection) override;
  shared_database_windows_pigeon::ErrorOr<
      shared_database_windows_pigeon::RecordWatchToken>
  GetRecordWatchToken(const std::string &collection,
                      const std::string &id) override;
  shared_database_windows_pigeon::ErrorOr<
      shared_database_windows_pigeon::PreferenceWatchToken>
  GetPreferenceWatchToken(const std::string &key) override;

 private:
  // Every caller may create the shared store, so the plugin always
  // initializes the store in "host" mode internally.
};

}  // namespace shared_database_windows

#endif  // FLUTTER_PLUGIN_SHARED_DATABASE_WINDOWS_PLUGIN_H_
