cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "desktop_window_bridge.cpp"
  "school_web_session_bridge.cpp"
  "main.cpp"
  "single_instance.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "window_placement_store.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_BINARY_DIR}/packages/Microsoft.Web.WebView2/build/native/include")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
add_dependencies(${BINARY_NAME} flutter_inappwebview_windows_DEPS)

target_link_libraries(${BINARY_NAME} PRIVATE comctl32 dwmapi)

# Acceptance binaries must not share the production registry or instance
# namespace. This is a build-only setting, never a runtime environment override.
set(SKED_WINDOWS_TEST_NAMESPACE "" CACHE STRING "Isolated native acceptance namespace")
if(NOT SKED_WINDOWS_TEST_NAMESPACE STREQUAL "")
  if(NOT SKED_WINDOWS_TEST_NAMESPACE MATCHES "^[A-Za-z0-9_.-]+$")
    message(FATAL_ERROR "SKED_WINDOWS_TEST_NAMESPACE must contain only letters, digits, dots, dashes or underscores")
  endif()
  target_compile_definitions(${BINARY_NAME} PRIVATE
    "SKED_WINDOWS_TEST_NAMESPACE=\"${SKED_WINDOWS_TEST_NAMESPACE}\"")
endif()

option(SKED_BUILD_WINDOWS_RUNNER_TESTS "Build isolated native runner tests" OFF)
if(SKED_BUILD_WINDOWS_RUNNER_TESTS)
  add_executable(sked_window_placement_tests
    "tests/window_placement_store_test.cpp"
    "window_placement_store.cpp")
  apply_standard_settings(sked_window_placement_tests)
  set_target_properties(sked_window_placement_tests PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/native-tests")
  target_include_directories(sked_window_placement_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(sked_window_placement_tests PRIVATE user32 advapi32)
  add_executable(sked_single_instance_tests
    "tests/single_instance_test.cpp"
    "single_instance.cpp")
  apply_standard_settings(sked_single_instance_tests)
  set_target_properties(sked_single_instance_tests PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/native-tests")
  target_include_directories(sked_single_instance_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(sked_single_instance_tests PRIVATE user32 comctl32)
  add_executable(sked_native_window_drag_tests "tests/native_window_drag_test.cpp")
  apply_standard_settings(sked_native_window_drag_tests)
  set_target_properties(sked_native_window_drag_tests PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/native-tests")
  target_include_directories(sked_native_window_drag_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(sked_native_window_drag_tests PRIVATE user32)
endif()
