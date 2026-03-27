#!/usr/bin/env bash
# 组合质量检查：lint + tests + 文档更新检查。
# 所有检查通过输出 QUALITY: PASS，任一失败输出 QUALITY: FAIL。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAIL=0

echo "=== Quality Gate ==="
echo ""

# 1. Lint
echo "--- Step 1: Lint ---"
if bash "$SCRIPT_DIR/check_lint.sh"; then
    echo "Lint: PASS"
else
    echo "Lint: FAIL"
    FAIL=1
fi
echo ""

# 2. Tests
echo "--- Step 2: Tests ---"
if bash "$SCRIPT_DIR/check_tests.sh"; then
    echo "Tests: PASS"
else
    echo "Tests: FAIL"
    FAIL=1
fi
echo ""

# 3. 文档更新检查（可选，按需启用）
echo "--- Step 3: Doc Freshness ---"
# 检查 progress.md 是否在最近 24 小时内更新过
PROGRESS_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/docs/progress.md"
if [ -f "$PROGRESS_FILE" ]; then
    # 检查文件修改时间是否在 24 小时内
    if find "$PROGRESS_FILE" -mtime -1 | grep -q .; then
        echo "progress.md freshness: PASS"
    else
        echo "progress.md freshness: WARN (not updated in last 24h)"
    fi
else
    echo "progress.md freshness: SKIP (file not found)"
fi
echo ""

# 结果
echo "===================="
if [ $FAIL -eq 0 ]; then
    echo "QUALITY: PASS"
    exit 0
else
    echo "QUALITY: FAIL"
    exit 1
fi
