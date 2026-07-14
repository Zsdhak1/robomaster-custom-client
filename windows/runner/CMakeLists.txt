cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# 定义应用 target。若要更改名称，请修改顶层 CMakeLists.txt 中的 BINARY_NAME，
# 不要修改这里的值，否则 `flutter run` 将无法工作。
#
# 添加到应用的任何新源文件都应列在这里。
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# 应用标准构建设置；需要不同构建设置的应用可以移除它。
apply_standard_settings(${BINARY_NAME})
target_compile_options(${BINARY_NAME} PRIVATE /utf-8)

# 添加构建版本使用的预处理器定义。
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# 禁用会与 C++ 标准库函数冲突的 Windows 宏。
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# 添加依赖库和 include 目录；应用专属依赖也放在这里。
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# 运行构建中的 Flutter 工具步骤；不要移除。
add_dependencies(${BINARY_NAME} flutter_assemble)
