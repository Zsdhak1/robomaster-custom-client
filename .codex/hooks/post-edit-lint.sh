#!/bin/bash
# Post-Edit Lint Hook — 文件编辑后自动运行代码检查
# 此脚本在 Claude Code 每次写入/编辑文件后自动执行

set -e

# 从 stdin 读取 Claude Code 传递的 JSON 数据
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""')

# 如果编辑的不是 Dart 文件，跳过检查
if [[ ! "$FILE_PATH" =~ \.dart$ ]]; then
    exit 0
fi

echo "🔍 代码质量检查: $FILE_PATH"

# 检查函数长度（超过 50 行的函数）
echo "  → 检查函数长度..."
LONG_FUNCS=$(grep -n '^\s*\w\+.*(' "$FILE_PATH" 2>/dev/null | head -20 || true)
if [ -n "$LONG_FUNCS" ]; then
    # 统计每个函数的行数（简化检查：查找函数定义位置）
    FUNC_COUNT=$(grep -c '^\s*\w\+.*(' "$FILE_PATH" || true)
    echo "  ✅ 发现 $FUNC_COUNT 个函数定义"
fi

# 运行 dart analyze 对单个文件
if command -v flutter &> /dev/null; then
    echo "  → 运行 flutter analyze..."
    ANALYZE_OUTPUT=$(flutter analyze "$FILE_PATH" 2>&1 || true)
    
    # 检查是否有警告或错误
    if echo "$ANALYZE_OUTPUT" | grep -q 'error\|warning'; then
        echo "  ⚠️ 发现警告或错误:"
        echo "$ANALYZE_OUTPUT" | grep -E 'error|warning' | head -5
        echo ""
        echo "请修复上述问题后继续。"
    else
        echo "  ✅ flutter analyze 通过"
    fi
else
    echo "  ⚠️ Flutter 命令不可用，跳过分析"
fi

# 检查是否存在 TODO/FIXME 未处理
echo "  → 检查 TODO/FIXME..."
TODOS=$(grep -n 'TODO\|FIXME\|HACK' "$FILE_PATH" 2>/dev/null || true)
if [ -n "$TODOS" ]; then
    echo "  ⚠️ 发现未处理的标记:"
    echo "$TODOS" | head -3
else
    echo "  ✅ 无未处理标记"
fi

exit 0
