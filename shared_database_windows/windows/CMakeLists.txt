# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "shared_database_windows")
project(${PROJECT_NAME} LANGUAGES C CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "shared_database_windows_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "shared_database_windows_plugin.cpp"
  "shared_database_windows_plugin.h"
  "shared_database_api.g.cpp"
  "shared_database_api.g.h"
  "shared_database_helper.cpp"
  "shared_database_helper.h"
)

include(FetchContent)
FetchContent_Declare(
  sqlite_amalgamation
  URL https://www.sqlite.org/2024/sqlite-amalgamation-3460100.zip
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_MakeAvailable(sqlite_amalgamation)

add_library(sqlite3 STATIC "${sqlite_amalgamation_SOURCE_DIR}/sqlite3.c")
target_include_directories(sqlite3 PUBLIC "${sqlite_amalgamation_SOURCE_DIR}")
target_compile_definitions(sqlite3 PRIVATE SQLITE_OMIT_LOAD_EXTENSION)

# nlohmann/json single header (used by shared_database_helper.cpp for JSON patching).
set(NLOHMANN_JSON_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/nlohmann_json")
set(NLOHMANN_JSON_HEADER "${NLOHMANN_JSON_INCLUDE_DIR}/nlohmann/json.hpp")
if(NOT EXISTS "${NLOHMANN_JSON_HEADER}")
  file(MAKE_DIRECTORY "${NLOHMANN_JSON_INCLUDE_DIR}/nlohmann")
  file(DOWNLOAD
    "https://raw.githubusercontent.com/nlohmann/json/v3.11.3/single_include/nlohmann/json.hpp"
    "${NLOHMANN_JSON_HEADER}"
    STATUS nlohmann_json_download_status
  )
  list(GET nlohmann_json_download_status 0 nlohmann_json_download_code)
  if(NOT nlohmann_json_download_code EQUAL 0)
    message(FATAL_ERROR "Failed to download nlohmann/json header")
  endif()
endif()

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/shared_database_windows/shared_database_windows_plugin_c_api.h"
  "shared_database_windows_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${NLOHMANN_JSON_INCLUDE_DIR}")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  sqlite3 shell32)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(shared_database_windows_bundled_libraries
  ""
  PARENT_SCOPE
)
