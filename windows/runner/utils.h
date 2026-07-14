#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// 为当前进程创建控制台，并把 runner 与 Flutter library 的 stdout/stderr 重定向到它。
void CreateAndAttachConsole();

// 接收以 null 结尾的 UTF-16 wchar_t*，返回 UTF-8 编码的 std::string；失败时返回空字符串。
std::string Utf8FromUtf16(const wchar_t* utf16_string);

// 获取传入的命令行参数，返回 UTF-8 编码的 std::vector<std::string>；失败时返回空 vector。
std::vector<std::string> GetCommandLineArguments();

#endif  // RUNNER_UTILS_H_
