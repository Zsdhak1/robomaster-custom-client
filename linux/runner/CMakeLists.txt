cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# 定义应用 target。若要更改名称，请修改顶层 CMakeLists.txt 中的 BINARY_NAME，
# 不要修改这里的值，否则 `flutter run` 将无法工作。
#
# 添加到应用的任何新源文件都应列在这里。
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# 应用标准构建设置；需要不同构建设置的应用可以移除它。
apply_standard_settings(${BINARY_NAME})

# 添加应用 ID 使用的预处理器定义。
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# 添加依赖库；应用专属依赖也放在这里。
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
