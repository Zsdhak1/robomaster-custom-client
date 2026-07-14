#!/bin/bash
# Session Start Hook — 加载项目上下文
# 此脚本在每次 Claude Code 会话开始时执行

set -e

echo "🚀 机甲数据监控客户端 — 开发会话启动"
echo ""

# 检查项目结构
echo "📁 项目结构检查:"
if [ -f "AGENTS.md" ]; then
    echo "  ✅ AGENTS.md 已加载"
else
    echo "  ⚠️ AGENTS.md 未找到"
fi

if [ -f "feature_spec.md" ]; then
    echo "  ✅ feature_spec.md 已加载"
else
    echo "  ⚠️ feature_spec.md 未找到"
fi

if [ -f "pubspec.yaml" ]; then
    PROJECT_NAME=$(grep "^name:" pubspec.yaml | sed 's/name: //' | tr -d ' ')
    echo "  ✅ 项目: $PROJECT_NAME"
fi

# 检查 flutter 环境
echo ""
echo "🔧 Flutter 环境:"
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -1)
    echo "  ✅ $FLUTTER_VERSION"
else
    echo "  ⚠️ Flutter 未安装或不在 PATH 中"
fi

# 显示当前 feature_spec 进度
echo ""
echo "📋 开发进度:"
if [ -f "feature_spec.md" ]; then
    COMPLETED=$(grep -c '\[x\]' feature_spec.md || true)
    TOTAL=$(grep -c '\[ \]' feature_spec.md || true)
    TOTAL=$((COMPLETED + TOTAL))
    if [ "$TOTAL" -gt 0 ]; then
        PERCENTAGE=$((COMPLETED * 100 / TOTAL))
        echo "  已完成: $COMPLETED / $TOTAL ($PERCENTAGE%)"
    fi
fi

echo ""
echo "💡 提示: 使用 feature_spec.md 中的任务列表跟踪进度。"
echo "   每完成一个 Task，运行 flutter analyze 并标记 [x]。"

exit 0
