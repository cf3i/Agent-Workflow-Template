#!/usr/bin/env bash
# ============================================================
# init.sh — 在目标仓库中初始化 Agent Workflow 文档体系
#
# 用法：
#   cd /path/to/your-repo
#   bash /path/to/Agent-Workflow-Template/init.sh \
#     [--cli <claude|codex>] [--skip-fill] [--resume]
#
# 选项：
#   --cli <name>    指定 CLI 工具（默认：claude）
#   --skip-fill     只复制骨架，不调用 AI 填充文档
#   --resume        从上次失败的步骤继续执行，不重跑已完成步骤
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD_DIR="${SCRIPT_DIR}/scaffold"
TARGET_DIR="$(pwd)"
CLI_TOOL="claude"
SKIP_FILL=false
RESUME=false
TARGET_IS_GIT_REPO=false

STATE_DIR_NAME=".agent-workflow-init"
STATE_DIR=""
STEP_DIR=""
LOG_DIR=""
REPORT_FILE=""
FAILED_STEP_FILE=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MANAGED_FILES=(
    "AGENTS.md"
    "docs/workflow.md"
    "docs/overview.md"
    "docs/architecture.md"
    "docs/conventions.md"
    "docs/decisions.md"
    "docs/quality.md"
    "docs/security.md"
    "docs/progress.md"
    "docs/blockers.md"
    "docs/plan/backlog.md"
    "docs/plan/current.md"
    "docs/plan/archive/README.md"
    "scripts/check_lint.sh"
    "scripts/check_tests.sh"
    "scripts/check_quality.sh"
)

usage() {
    cat <<EOF
用法：
  cd /path/to/your-repo
  bash /path/to/Agent-Workflow-Template/init.sh [--cli <claude|codex>] [--skip-fill] [--resume]

选项：
  --cli <name>    指定 CLI 工具（默认：claude）
  --skip-fill     只复制骨架，不调用 AI 填充文档
  --resume        从上次失败的步骤继续执行，不重跑已完成步骤
EOF
}

info() {
    echo -e "${GREEN}$*${NC}"
}

warn() {
    echo -e "${YELLOW}$*${NC}"
}

error() {
    echo -e "${RED}$*${NC}" >&2
}

confirm_or_abort() {
    local message="$1"

    if [[ ! -t 0 ]]; then
        error "${message}"
        error "当前会话不是交互式终端，已停止。"
        exit 1
    fi

    read -r -p "${message} (y/N) " reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        echo "取消操作。"
        exit 0
    fi
}

init_state_paths() {
    STATE_DIR="${TARGET_DIR}/${STATE_DIR_NAME}"
    STEP_DIR="${STATE_DIR}/steps"
    LOG_DIR="${STATE_DIR}/logs"
    REPORT_FILE="${STATE_DIR}/final-review.md"
    FAILED_STEP_FILE="${STATE_DIR}/last_failed_step.txt"
}

ensure_state_dirs() {
    mkdir -p "$STEP_DIR" "$LOG_DIR"
}

step_file() {
    printf '%s/%s.done' "$STEP_DIR" "$1"
}

is_step_done() {
    [[ -f "$(step_file "$1")" ]]
}

mark_step_done() {
    local step_id="$1"
    date '+%Y-%m-%d %H:%M:%S %z' > "$(step_file "$step_id")"
    rm -f "$FAILED_STEP_FILE"
}

mark_step_failed() {
    local step_id="$1"
    local reason="$2"
    cat > "$FAILED_STEP_FILE" <<EOF
step=${step_id}
reason=${reason}
EOF
}

get_mtime() {
    local path="$1"

    if stat -c '%Y' "$path" >/dev/null 2>&1; then
        stat -c '%Y' "$path"
    else
        stat -f '%m' "$path"
    fi
}

capture_fingerprint() {
    local path="$1"

    if [[ ! -f "$path" ]]; then
        printf 'missing\n'
        return
    fi

    printf 'file|%s|%s\n' "$(get_mtime "$path")" "$(cksum < "$path" | awk '{print $1 ":" $2}')"
}

copy_managed_file() {
    local relative_path="$1"
    mkdir -p "$TARGET_DIR/$(dirname "$relative_path")"
    cp "$SCAFFOLD_DIR/$relative_path" "$TARGET_DIR/$relative_path"
}

check_existing_managed_files() {
    local conflicts=()
    local relative_path=""

    for relative_path in "${MANAGED_FILES[@]}"; do
        if [[ -e "$TARGET_DIR/$relative_path" ]]; then
            conflicts+=("$relative_path")
        fi
    done

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        warn "检测到目标目录中已存在以下受 init.sh 管理的文件："
        printf '  - %s\n' "${conflicts[@]}"
        confirm_or_abort "继续将覆盖这些文件，是否继续？"
    elif [[ -d "$TARGET_DIR/docs" ]]; then
        warn "目标目录已存在 docs/ 目录。init.sh 只会写入模板管理的文件，不会清理其他文档。"
    fi
}

ensure_resume_mode_is_valid() {
    if [[ "$RESUME" == true ]]; then
        if [[ ! -d "$STATE_DIR" ]]; then
            error "未找到可恢复的状态目录：$STATE_DIR"
            error "请先执行一次普通初始化，或移除 --resume。"
            exit 1
        fi
        return
    fi

    if [[ -d "$STATE_DIR" ]]; then
        error "检测到已有初始化状态目录：$STATE_DIR"
        error "如果要从断点继续，请使用 --resume；如果要重头开始，请先手动删除该目录。"
        exit 1
    fi
}

print_resume_hint() {
    warn "可使用以下命令从断点继续："
    echo "  cd \"$TARGET_DIR\""
    echo "  bash \"$SCRIPT_DIR/init.sh\" --cli \"$CLI_TOOL\" --resume"
}

ensure_scaffold_is_valid() {
    if [[ ! -f "$SCAFFOLD_DIR/AGENTS.md" ]]; then
        error "缺少初始化骨架文件：$SCAFFOLD_DIR/AGENTS.md"
        exit 1
    fi

    if [[ ! -f "$SCAFFOLD_DIR/docs/plan/current.md" ]]; then
        error "缺少初始化骨架文件：$SCAFFOLD_DIR/docs/plan/current.md"
        exit 1
    fi
}

detect_cli_kind() {
    case "$(basename "$CLI_TOOL")" in
        codex)
            echo "codex"
            ;;
        claude)
            echo "claude"
            ;;
        *)
            echo "generic"
            ;;
    esac
}

run_cli_prompt() {
    local prompt="$1"
    local cli_kind=""

    cli_kind="$(detect_cli_kind)"

    case "$cli_kind" in
        codex)
            local codex_args=("exec" "--full-auto" "--color" "never" "-C" "$TARGET_DIR")
            if [[ "$TARGET_IS_GIT_REPO" != true ]]; then
                codex_args+=("--skip-git-repo-check")
            fi
            codex_args+=("-")
            printf '%s' "$prompt" | "$CLI_TOOL" "${codex_args[@]}"
            ;;
        claude|generic)
            "$CLI_TOOL" -p "$prompt"
            ;;
    esac
}

validate_edit_step() {
    local step_id="$1"
    shift

    local changed_count="$1"
    shift
    local files=("$@")
    local target_file="${files[0]}"

    if [[ "$changed_count" -eq 0 ]]; then
        return 1
    fi

    case "$step_id" in
        decisions)
            grep -q '^## D-001 初始化 Agent Workflow 文档体系$' "$target_file"
            ;;
        scripts)
            ! grep -q '<lint-command>' "$TARGET_DIR/scripts/check_lint.sh" &&
            ! grep -q '<test-command>' "$TARGET_DIR/scripts/check_tests.sh"
            ;;
        audit)
            [[ -s "$REPORT_FILE" ]]
            ;;
        *)
            [[ -f "$target_file" ]]
            ;;
    esac
}

run_edit_step() {
    local step_id="$1"
    local title="$2"
    shift 2
    local files=()
    local path=""
    local prompt=""
    local log_file="$LOG_DIR/${step_id}.log"
    local before_states=()
    local after_state=""
    local index=0
    local changed_count=0

    while [[ $# -gt 0 ]]; do
        path="$1"
        shift
        if [[ "$path" == "--" ]]; then
            break
        fi
        files+=("$path")
    done

    prompt="$(cat)"

    ensure_state_dirs

    if [[ "$RESUME" == true && -f "$(step_file "$step_id")" ]]; then
        warn "  → 跳过 ${title}（已完成）"
        return 0
    fi

    for path in "${files[@]}"; do
        before_states+=("$(capture_fingerprint "$path")")
    done

    info "  → ${title}"
    if ! (
        cd "$TARGET_DIR"
        run_cli_prompt "$prompt"
    ) >"$log_file" 2>&1; then
        error "步骤失败：${title}"
        error "日志：$log_file"
        tail -n 20 "$log_file" || true
        mark_step_failed "$step_id" "command_failed"
        print_resume_hint
        exit 1
    fi

    for index in "${!files[@]}"; do
        after_state="$(capture_fingerprint "${files[$index]}")"
        if [[ "$after_state" != "${before_states[$index]}" ]]; then
            changed_count=$((changed_count + 1))
        fi
    done

    if ! validate_edit_step "$step_id" "$changed_count" "${files[@]}"; then
        error "步骤未通过结果校验：${title}"
        error "CLI 已成功返回，但目标文件没有按预期落盘。"
        error "日志：$log_file"
        mark_step_failed "$step_id" "validation_failed"
        print_resume_hint
        exit 1
    fi

    mark_step_done "$step_id"
}

run_audit_step() {
    local step_id="audit"
    local title="最终扫描并生成人工补充清单"
    local log_file="$LOG_DIR/${step_id}.log"

    ensure_state_dirs

    if [[ "$RESUME" == true && -f "$(step_file "$step_id")" && -s "$REPORT_FILE" ]]; then
        warn "  → 跳过 ${title}（已完成）"
        return 0
    fi

    info "  → ${title}"
    if ! (
        cd "$TARGET_DIR"
        run_cli_prompt "$(audit_prompt)"
    ) >"$REPORT_FILE" 2>"$log_file"; then
        error "步骤失败：${title}"
        error "日志：$log_file"
        mark_step_failed "$step_id" "command_failed"
        print_resume_hint
        exit 1
    fi

    if ! validate_edit_step "$step_id" 1 "$REPORT_FILE"; then
        error "步骤未通过结果校验：${title}"
        error "报告文件为空：$REPORT_FILE"
        mark_step_failed "$step_id" "validation_failed"
        print_resume_hint
        exit 1
    fi

    mark_step_done "$step_id"
}

copy_template_skeleton() {
    local step_id="copy_skeleton"

    if [[ "$RESUME" == true && -f "$(step_file "$step_id")" ]]; then
        warn "[1/2] 跳过模板骨架复制（已完成）"
        return
    fi

    info "[1/2] 复制模板骨架到 ${TARGET_DIR}"
    check_existing_managed_files
    ensure_state_dirs

    copy_managed_file "AGENTS.md"
    mkdir -p "$TARGET_DIR/docs/plan/archive"
    copy_managed_file "docs/workflow.md"
    copy_managed_file "docs/overview.md"
    copy_managed_file "docs/architecture.md"
    copy_managed_file "docs/conventions.md"
    copy_managed_file "docs/decisions.md"
    copy_managed_file "docs/quality.md"
    copy_managed_file "docs/security.md"
    copy_managed_file "docs/progress.md"
    copy_managed_file "docs/blockers.md"
    copy_managed_file "docs/plan/backlog.md"
    copy_managed_file "docs/plan/current.md"
    copy_managed_file "docs/plan/archive/README.md"

    mkdir -p "$TARGET_DIR/scripts"
    copy_managed_file "scripts/check_lint.sh"
    copy_managed_file "scripts/check_tests.sh"
    copy_managed_file "scripts/check_quality.sh"
    chmod +x "$TARGET_DIR/scripts/"*.sh

    mark_step_done "$step_id"
    info "模板骨架已复制。"
}

overview_prompt() {
    cat <<'PROMPT'
分析当前代码库，填充 docs/overview.md。不要修改任何其他文件。

## 分析步骤

1. 读取项目根目录文件列表，识别项目类型（web app、CLI tool、library、API service 等）
2. 读取现有 README（如有），提取项目描述和背景
3. 读取包管理文件（如有），了解依赖和项目元信息
4. 浏览 src/ 或主代码目录，理解项目做什么

## 填写要求

打开 docs/overview.md，按以下结构填写：

**项目摘要**：
- 项目名称：从 package.json / pyproject.toml / go.mod / Cargo.toml / README 中提取
- 一句话目标：用一句话概括项目解决什么问题
- 目标用户：谁会用这个项目
- 业务价值：为什么要做这个项目

**范围定义**：
- In Scope：列出项目当前实际在做的 3-5 个核心能力（从代码中推断，不是猜测）
- Out of Scope：列出项目明确不做的事（从 README 或代码边界推断）

**核心概念**：
- 列出代码中反复出现的核心实体/概念（如 User、Order、Pipeline 等），给出一句话定义

**成功标准**：如果无法从代码中推断，保留"（待填写）"

## 规则
- "维护规则"部分不要修改
- 无法确认的信息保留"（待填写）"
- 不要编造信息
PROMPT
}

architecture_prompt() {
    cat <<'PROMPT'
分析当前代码库的结构和依赖关系，填充 docs/architecture.md。不要修改任何其他文件。

## 分析步骤

1. 运行 find 或 ls 列出完整的目录树（排除 node_modules、.git、__pycache__ 等）
2. 识别项目的分层方式：是按功能分（routes/、models/、services/）还是按领域分（user/、order/）还是其他方式
3. 分析 import/require 语句，找出模块间的依赖方向
4. 查找 lint 配置文件（.eslintrc、pylintrc、.golangci.yml、rustfmt.toml 等）
5. 查找 CI 配置文件（.github/workflows/、.gitlab-ci.yml、Jenkinsfile 等）

## 填写要求

打开 docs/architecture.md，按以下结构填写：

**分层模型**：
- 替换模板中的示例层级为项目实际的层级
- 每一层写清楚：层级名称、职责、允许依赖谁、禁止依赖谁
- 如果项目没有明确分层，按实际目录描述模块边界

**目录结构**：
- 替换模板中的示例目录树为项目实际的顶层目录结构
- 只列到第二层，每个目录用注释说明用途

**Import Boundary 规则**：
- 替换模板中的示例规则为项目实际的依赖规则
- 每条规则格式：谁可以 import 谁、谁禁止 import 谁
- 只写你能从代码中确认的规则

**执行方式**：
- 静态检查工具：写出实际使用的 lint 工具名称和版本
- 规则文件位置：写出 lint 配置文件的路径
- CI 校验命令：写出 CI 中实际运行 lint 的命令
- 如果项目没有 lint 或 CI，明确写"当前未配置"

## 规则
- 只收录被工具机械执行的结构性约束。风格性规则不写在这里
- "维护规则"部分不要修改
- 无法确认的信息保留"（待填写）"
PROMPT
}

conventions_prompt() {
    cat <<'PROMPT'
分析当前代码库的代码风格和 git 习惯，填充 docs/conventions.md。不要修改任何其他文件。

## 分析步骤

1. 打开 3-5 个代码文件，观察命名风格（变量、函数、类、文件名的 case 方式）
2. 查找代码格式化配置（.prettierrc、.editorconfig、black.toml、rustfmt.toml 等）
3. 观察函数的签名风格：参数怎么传、返回值怎么表示、错误怎么处理
4. 运行 git log --oneline -20 查看最近 20 条 commit message 的格式
5. 运行 git branch -a 查看分支命名习惯

## 填写要求

打开 docs/conventions.md，按以下结构填写：

**命名规范**：
- 根据实际代码替换模板中的示例。明确写出：
  - 文件名用什么 case（从实际文件名推断）
  - 类名用什么 case（从代码中推断）
  - 变量和函数用什么 case（从代码中推断）
  - 常量用什么 case（从代码中推断）

**函数契约**：
- 从代码中观察实际的函数风格，替换模板中的通用描述
- 如果项目使用 TypeScript/Python type hints/Rust types，写明类型声明的要求
- 如果项目有统一的错误返回模式，写明

**错误处理模式**：
- 从代码中推断项目用什么方式处理错误（异常 try/catch、Result 类型、错误码、Promise rejection 等）
- 写明日志级别约定（如果能推断）

**Git 规范**：
- Commit Message：从 git log 推断实际格式。如果用 conventional commits，写明具体的 type 枚举。如果是自由格式，也如实描述
- Branch 命名：从 git branch 推断实际格式
- PR 规范：如果有 PR template，读取并总结

## 规则
- 只收录靠 agent 自觉遵守的风格性约束。被 linter 强制执行的规则不写在这里
- "维护规则"部分不要修改
- 无法确认的信息保留"（待填写）"
PROMPT
}

quality_prompt() {
    cat <<'PROMPT'
分析当前代码库的测试设置，填充 docs/quality.md。不要修改任何其他文件。

## 分析步骤

1. 查找测试目录：常见位置有 tests/、test/、__tests__/、spec/、*_test.go 等
2. 打开 1-2 个测试文件，确认使用的测试框架
3. 查找测试配置文件（jest.config、pytest.ini、vitest.config 等）
4. 查找覆盖率配置（.nycrc、coverage 配置段等）
5. 查找包管理文件中的 test scripts（如 package.json 的 scripts.test）
6. 检查 CI 配置中的测试命令

## 填写要求

打开 docs/quality.md，只修改以下"待填写"区域，Definition of Done 和失败处理流程保持不动：

**测试栈**：
- 单元测试框架：写出实际使用的框架名称和版本
- 集成测试框架：如有，写出；如没有，写"当前未配置"
- Mock 工具：如有，写出
- 覆盖率工具：如有，写出

**测试目录**：
- 替换模板中的示例路径为项目实际的测试目录
- 如果测试文件和源码放在一起（如 Go 或 colocated tests），说明这种模式

**测试命令**：
- 替换模板中的 <command> 为实际可执行的命令
- 全量测试命令
- 仅单元测试命令（如果能区分）
- 覆盖率命令（如果有）
- 确保命令可以直接复制粘贴到终端执行

## 规则
- "Definition of Done"部分不要修改
- "失败处理流程"部分不要修改
- "维护规则"部分不要修改
- 无法确认的信息保留"（待填写）"
PROMPT
}

security_prompt() {
    cat <<'PROMPT'
分析当前代码库的安全相关配置，填充 docs/security.md。不要修改任何其他文件。

## 分析步骤

1. 读取 .gitignore，识别被排除的敏感文件模式
2. 查找 .env 文件或 .env.example，列出所有环境变量名（不要读取实际的 .env 值）
3. 在代码中搜索 process.env、os.environ、os.Getenv 等环境变量读取语句
4. 查找 CI 配置中的 secrets 引用
5. 查找认证相关代码（auth、login、token、jwt、oauth 等关键词）
6. 识别不应该被 agent 修改的基础设施文件

## 填写要求

打开 docs/security.md，按以下结构填写：

**敏感信息清单**：
- 替换模板中的示例行为项目实际使用的敏感变量
- 每行包含：类型、变量名示例、存储方式、禁止行为
- 从 .env.example 和代码中的环境变量引用提取

**受保护路径**：
- 列出不应该被 agent 随意修改的路径
- 通常包括：CI 配置、部署脚本、密钥目录、基础设施配置

**认证与授权**：
- 如果代码中有认证逻辑，描述认证方式（JWT、Session、OAuth 等）
- 如果无法从代码中确认，保留"（待填写）"

## 规则
- 绝不读取或输出 .env 文件中的实际值，只读 .env.example 或代码中的变量名
- "安全变更规则"部分不要修改
- 无法确认的信息保留"（待填写）"
PROMPT
}

progress_prompt() {
    cat <<'PROMPT'
分析当前代码库的完成状态，填充 docs/progress.md。不要修改任何其他文件。

## 分析步骤

1. 读取 docs/overview.md（刚填充的），了解项目目标
2. 浏览主代码目录，判断哪些功能已经实现
3. 运行 git log --oneline -30 了解最近的开发活动
4. 搜索代码中的 TODO、FIXME、HACK、XXX 注释
5. 检查是否有已知的 bug 或未完成的功能

## 填写要求

打开 docs/progress.md，按以下结构填写：

**更新时间**：填入今天的日期

**项目阶段**：
- 当前阶段：根据代码成熟度判断（初始化 / 开发中 / Beta / 生产）
- 当前里程碑：如果能从 git history 或 README 推断

**已完成功能**：
- 列出代码中已经实现的主要功能，每个功能一行 `- [x]` 格式
- 只列确实已实现的，不要猜测

**已知问题**：
- 从 TODO/FIXME 注释中提取已知问题
- 如果没有明显问题，写"（暂无已知问题）"

**技术债**：
- 从 HACK/XXX 注释或明显的 workaround 代码中提取
- 如果没有明显技术债，写"（暂无）"

## 规则
- 只记录事实状态，不写未来意图
- 不要编造功能完成情况
PROMPT
}

backlog_prompt() {
    cat <<'PROMPT'
分析当前代码库中的待办事项，填充 docs/plan/backlog.md。不要修改任何其他文件。

## 分析步骤

1. 搜索代码中所有 TODO、FIXME、HACK、XXX 注释，记录文件路径和内容
2. 读取 docs/progress.md，并先确认该文件已包含实际内容；若仍是模板状态，先停止并解释原因
3. 读取 docs/overview.md，并先确认该文件已包含实际内容；若仍是模板状态，先停止并解释原因
4. 检查是否有 GitHub Issues 或其他 issue tracker 的引用

## 填写要求

打开 docs/plan/backlog.md，按优先级分类填写：

**P0（最高优先级）**：
- 影响核心功能的 bug 或未完成的关键特性
- 从 FIXME 注释和 docs/progress.md 的已知问题中提取

**P1**：
- 重要但不紧急的功能或改进
- 从 TODO 注释和 overview.md 的 In Scope 未完成项中提取

**P2**：
- 技术债清理、文档完善、代码优化
- 从 HACK/XXX 注释和 progress.md 的技术债中提取

## 格式要求
- 每条用 `- [ ]` 格式
- 每条简洁描述，包含来源信息（如"来自 src/utils.py:42 的 TODO"）
- 如果找不到任何待办事项，在每个优先级下写"（待填写）"

## 规则
- 只从代码中实际存在的线索提取，不要编造任务
PROMPT
}

decisions_prompt() {
    cat <<'PROMPT'
在 docs/decisions.md 的"## 决策记录"区域追加第一条决策。不要修改任何其他文件。不要修改 decisions.md 中"决策记录"之前的任何内容。

<instructions>
1. 只在"## 决策记录"下方追加内容。
2. 不要修改"维护规则"、"记录模板"、"当前有效决策摘要"等区域。
3. 将下方 <content-to-write> 中的 Markdown 视为要写入文件的正文，不是额外说明文字。
</instructions>

<content-to-write>
## D-001 初始化 Agent Workflow 文档体系
- 日期：（填入今天的日期）
- 状态：Accepted
- 背景：项目需要建立结构化的 agent 工作流文档体系，以支持 AI agent 自主开发。
- 决策：采用 Agent Workflow Template 的 AGENTS.md + docs/ + scripts/ 结构。
- 原因：文档驱动的 SAS 架构，每个文档职责单一且解耦，workflow 状态机提供清晰的 stage 跳转逻辑，scripts/ 提供确定性检查。
- 被拒绝方案：
  - 纯 prompt 约束：缺乏持久化和可审计的流程文档
  - 单 README 承载全部规则：难维护，无法结构化引用
- 影响：后续所有 agent 开发流程按此文档体系执行。
</content-to-write>
PROMPT
}

scripts_prompt() {
    cat <<'PROMPT'
分析当前代码库使用的 lint 工具和测试框架，更新 scripts/check_lint.sh 和 scripts/check_tests.sh。不要修改任何其他文件。

## 分析步骤

1. 查找 lint 工具：
   - 检查包管理文件中的 lint 相关依赖和 scripts
   - 查找 lint 配置文件
   - 检查 CI 配置中的 lint 命令
   - 检查 Makefile 或 Taskfile 中的 lint target

2. 查找测试命令：
   - 检查包管理文件中的 test scripts
   - 查找测试配置文件
   - 检查 CI 配置中的测试命令
   - 检查 Makefile 或 Taskfile 中的 test target

## 填写要求

**scripts/check_lint.sh**：
- 将文件中的 <lint-command> 替换为实际的 lint 命令
- 如果项目有多个 lint 工具（如 eslint + prettier），依次运行
- 如果项目没有 lint 工具，将 <lint-command> 替换为 `echo "WARN: No lint tool configured"`

**scripts/check_tests.sh**：
- 将文件中的 <test-command> 替换为实际的测试命令
- 如果项目没有测试，将 <test-command> 替换为 `echo "WARN: No test framework configured"`

## 规则
- 确保替换后的命令可以直接在项目根目录执行
- 不要修改脚本的其他结构（echo、set -euo pipefail 等保持不变）
- 不要修改 scripts/check_quality.sh（它只是组合调用另外两个脚本）
PROMPT
}

audit_prompt() {
    cat <<'PROMPT'
扫描当前仓库中由 Agent Workflow Template 初始化的文档，输出一个 Markdown 清单，列出仍需要人类手动补充或确认的内容。不要修改任何文件。

## 检查范围

1. AGENTS.md
2. docs/overview.md
3. docs/architecture.md
4. docs/conventions.md
5. docs/decisions.md
6. docs/quality.md
7. docs/security.md
8. docs/progress.md
9. docs/plan/backlog.md
10. docs/plan/current.md
11. scripts/check_lint.sh
12. scripts/check_tests.sh

## 输出要求

请输出以下结构：

# 初始化后人工补充清单

## 已完成概览
- 简述已经由自动流程完成的部分

## 仍需人工补充
- 按文件列出仍存在的"（待填写）"、占位内容、需要人工判断的模糊项
- 如果某文件看起来仍是模板状态，明确指出
- 如果某些命令只是 fallback（例如 WARN: No lint tool configured），明确指出需要人工确认

## 风险提示
- 列出自动初始化无法可靠推断、因此最容易出错的 3-5 项

## 规则
- 仅输出 Markdown 到 stdout
- 不要修改仓库中的任何文件
- 不要省略仍需人工处理的空白项
PROMPT
}

run_fill_sequence() {
    info "[2/2] 调用 ${CLI_TOOL} 逐个填充文档..."
    echo ""

    cd "$TARGET_DIR"

    run_edit_step "overview" "填充 docs/overview.md" \
        "$TARGET_DIR/docs/overview.md" -- <<<"$(overview_prompt)"
    run_edit_step "architecture" "填充 docs/architecture.md" \
        "$TARGET_DIR/docs/architecture.md" -- <<<"$(architecture_prompt)"
    run_edit_step "conventions" "填充 docs/conventions.md" \
        "$TARGET_DIR/docs/conventions.md" -- <<<"$(conventions_prompt)"
    run_edit_step "quality" "填充 docs/quality.md" \
        "$TARGET_DIR/docs/quality.md" -- <<<"$(quality_prompt)"
    run_edit_step "security" "填充 docs/security.md" \
        "$TARGET_DIR/docs/security.md" -- <<<"$(security_prompt)"
    run_edit_step "progress" "填充 docs/progress.md" \
        "$TARGET_DIR/docs/progress.md" -- <<<"$(progress_prompt)"
    run_edit_step "backlog" "填充 docs/plan/backlog.md" \
        "$TARGET_DIR/docs/plan/backlog.md" -- <<<"$(backlog_prompt)"
    run_edit_step "decisions" "填充 docs/decisions.md" \
        "$TARGET_DIR/docs/decisions.md" -- <<<"$(decisions_prompt)"
    run_edit_step "scripts" "配置 scripts/check_lint.sh 和 check_tests.sh" \
        "$TARGET_DIR/scripts/check_lint.sh" \
        "$TARGET_DIR/scripts/check_tests.sh" -- <<<"$(scripts_prompt)"

    run_audit_step
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cli)
            if [[ $# -lt 2 ]]; then
                error "参数 --cli 需要一个值。"
                usage
                exit 1
            fi
            CLI_TOOL="$2"
            shift 2
            ;;
        --skip-fill)
            SKIP_FILL=true
            shift
            ;;
        --resume)
            RESUME=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            error "未知参数: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ "$SCRIPT_DIR" == "$TARGET_DIR" ]]; then
    error "错误：不能在模板仓库自身运行 init.sh"
    echo "请 cd 到你的目标项目目录后再运行。"
    exit 1
fi

if [[ "$SKIP_FILL" == false ]] && ! command -v "$CLI_TOOL" >/dev/null 2>&1; then
    error "错误：未找到 ${CLI_TOOL} CLI。"
    echo "可用 --skip-fill 跳过自动填充，或 --cli <name> 指定其他工具。"
    exit 1
fi

init_state_paths
ensure_scaffold_is_valid
ensure_resume_mode_is_valid

if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    TARGET_IS_GIT_REPO=true
    info "检测到目标目录是 Git 仓库。"
else
    warn "警告：目标目录不是 Git 仓库。后续 AI prompt 中若依赖 git log / git branch，结果可能退化。"
fi

copy_template_skeleton

if [[ "$SKIP_FILL" == true ]]; then
    warn "已跳过自动填充（--skip-fill）。"
else
    run_fill_sequence
fi

echo ""
info "============================================================"
info "初始化完成！"
info "============================================================"
echo ""

if [[ -s "$REPORT_FILE" ]]; then
    echo "自动审计报告：$REPORT_FILE"
    echo ""
    cat "$REPORT_FILE"
    echo ""
fi

echo "下一步："
echo "  1. 检查 docs/ 下的文档，补充标记为（待填写）的内容"
echo "  2. 运行 ./scripts/check_quality.sh 确认脚本可以正常执行"
echo "  3. 在 docs/plan/backlog.md 中补充你的第一批 issue"
echo "  4. 启动 agent：${CLI_TOOL} \"读 AGENTS.md，然后开始工作。\""
