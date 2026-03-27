#!/usr/bin/env bash
# 运行 lint 检查，输出 PASS 或 FAIL。
# 使用前请替换 <lint-command> 为项目实际的 lint 命令。
set -euo pipefail

echo "=== Lint Check ==="

# TODO: 替换为项目实际的 lint 命令，例如：
# npx eslint src/
# ruff check .
# golangci-lint run
<lint-command>

echo "RESULT: PASS"
