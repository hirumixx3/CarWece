cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "carwece_graphics")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "carwece_graphics_plugin")

list(APPEND PLUGIN_SOURCES
  "carwece_graphics_plugin.cpp"
  "carwece_graphics_plugin_c_api.cpp"
  "renderer.cpp"
)

add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  d3d11
  dxgi
  d3dcompiler
)

# List of absolute paths to libraries that should be bundled with the plugin.
set(carwece_graphics_bundled_libraries
  ""
  PARENT_SCOPE
)
