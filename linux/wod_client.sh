#!/usr/bin/env bash
# 打包版 Linux 发布物的默认启动脚本。
# 确保二进制文件优先加载 ./lib 中随包附带的库，再回退到系统路径。
# 这样无需系统级安装，也能解析 libmpv 及其递归依赖。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_NAME="robomaster_custom_client_1"

export LD_LIBRARY_PATH="${SCRIPT_DIR}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

exec "${SCRIPT_DIR}/${BINARY_NAME}" "$@"
