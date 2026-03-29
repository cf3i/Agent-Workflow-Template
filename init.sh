#!/usr/bin/env bash
# ============================================================
# init.sh — 在目标仓库中初始化 Agent Workflow 文档体系
#
# 用法：
#   cd /path/to/your-repo
#   bash /path/to/Agent-Workflow-Template/init.sh \
#     [--cli <claude|codex>] [--model <name>] [--reasoning-effort <level>] \
#     [--skip-fill] [--greenfield] [--ultra] [--no-docs-review] \
#     [--non-interactive]
#
# 选项：
#   --cli <name>    指定 CLI 工具（默认：claude）
#   --model <name>  指定 AI 模型（默认：gpt-5.4）
#   --reasoning-effort <level> 指定推理强度（默认：xhigh）
#   --skip-fill        只复制骨架，不调用 AI 填充文档
#   --greenfield       按全新 agent 主导项目初始化（默认是存量仓库 adopt 模式）
#   --ultra            使用逐文件多次 AI 调用完成初始化填充
#   --no-docs-review   跳过独立 docs review 步骤
#   --non-interactive  禁用交互式向导，仅按 flags / 默认值执行
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD_DIR="${SCRIPT_DIR}/scaffold"
TARGET_DIR="$(pwd)"
CLI_TOOL="claude"
MODEL="gpt-5.4"
REASONING_EFFORT="xhigh"
SKIP_FILL=false
INIT_MODE="adopt"
SINGLE_CALL=true
ULTRA=false
DOCS_REVIEW_ENABLED=true
NON_INTERACTIVE=false

STATE_DIR_NAME=".git/.agent-workflow-init"
STATE_DIR=""
LOG_DIR=""
REPORT_FILE=""
DOCS_REVIEW_FILE=""

CLI_TOOL_EXPLICIT=false
MODEL_EXPLICIT=false
REASONING_EFFORT_EXPLICIT=false
SKIP_FILL_EXPLICIT=false
INIT_MODE_EXPLICIT=false
EXECUTION_MODE_EXPLICIT=false
DOCS_REVIEW_EXPLICIT=false
NON_INTERACTIVE_EXPLICIT=false

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MANAGED_FILES=(
    "AGENTS.md"
    "docs/stage.lock"
    "docs/workflow/stage1.md"
    "docs/workflow/stage2.md"
    "docs/workflow/stage3.md"
    "docs/workflow/stage4.md"
    "docs/workflow/stage5.md"
    "docs/workflow/stage6.md"
    "docs/wisdom.md"
    "docs/antipatterns.md"
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
    "issue_test/README.md"
    "scripts/build_context.py"
    "scripts/run_issue_tests.sh"
    "scripts/deliver_pr.sh"
)

usage() {
    cat <<EOF
用法：
  cd /path/to/your-repo
  bash /path/to/Agent-Workflow-Template/init.sh [--cli <claude|codex>] [--model <name>] [--reasoning-effort <level>] [--skip-fill] [--greenfield] [--ultra] [--no-docs-review] [--non-interactive]

选项：
  --cli <name>    指定 CLI 工具（默认：claude）
  --model <name>  指定 AI 模型（默认：gpt-5.4）
  --reasoning-effort <level>
                   指定推理强度（默认：xhigh）
  --skip-fill        只复制骨架，不调用 AI 填充文档
  --greenfield       按全新 agent 主导项目初始化（默认是存量仓库 adopt 模式）
  --single-call      兼容别名；默认已经是单次 AI 调用
  --ultra            使用逐文件多次 AI 调用完成初始化填充
  --no-docs-review   跳过独立 docs review 步骤
  --non-interactive  禁用交互式向导，仅按 flags / 默认值执行
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

is_interactive_session() {
    [[ "$NON_INTERACTIVE" != true ]] && [[ -t 0 && -t 1 ]]
}

default_cli_tool() {
    if command -v codex >/dev/null 2>&1; then
        printf 'codex\n'
    elif command -v claude >/dev/null 2>&1; then
        printf 'claude\n'
    else
        printf '%s\n' "$CLI_TOOL"
    fi
}

prompt_mode_choice() {
    local reply=""
    while true; do
        echo "请选择初始化模式："
        echo "  1) adopt (推荐，存量仓库接入)"
        echo "  2) greenfield (全新 agent 主导项目)"
        read -r -p "选择 [1]: " reply
        case "${reply:-1}" in
            1)
                INIT_MODE="adopt"
                return
                ;;
            2)
                INIT_MODE="greenfield"
                return
                ;;
            *)
                warn "无效选择，请输入 1 或 2。"
                ;;
        esac
    done
}

prompt_fill_choice() {
    local reply=""
    while true; do
        read -r -p "是否调用 AI 自动填充文档？ (Y/n) " reply
        case "${reply:-Y}" in
            Y|y)
                SKIP_FILL=false
                return
                ;;
            N|n)
                SKIP_FILL=true
                return
                ;;
            *)
                warn "无效选择，请输入 y 或 n。"
                ;;
        esac
    done
}

prompt_cli_choice() {
    local reply=""
    local recommended
    recommended="$(default_cli_tool)"

    while true; do
        echo "请选择 AI CLI："
        echo "  1) codex"
        echo "  2) claude"
        if [[ "$recommended" == "codex" ]]; then
            read -r -p "选择 [1]: " reply
            reply="${reply:-1}"
        elif [[ "$recommended" == "claude" ]]; then
            read -r -p "选择 [2]: " reply
            reply="${reply:-2}"
        else
            read -r -p "选择 [1]: " reply
            reply="${reply:-1}"
        fi

        case "$reply" in
            1)
                CLI_TOOL="codex"
                return
                ;;
            2)
                CLI_TOOL="claude"
                return
                ;;
            *)
                warn "无效选择，请输入 1 或 2。"
                ;;
        esac
    done
}

prompt_execution_mode_choice() {
    local reply=""
    while true; do
        echo "请选择填充方式："
        echo "  1) single-call (推荐，单次 AI 调用)"
        echo "  2) ultra (逐文件多次 AI 调用)"
        read -r -p "选择 [1]: " reply
        case "${reply:-1}" in
            1)
                ULTRA=false
                SINGLE_CALL=true
                return
                ;;
            2)
                ULTRA=true
                SINGLE_CALL=false
                return
                ;;
            *)
                warn "无效选择，请输入 1 或 2。"
                ;;
        esac
    done
}

prompt_docs_review_choice() {
    local reply=""
    while true; do
        read -r -p "是否在生成后执行独立 docs review？ (Y/n) " reply
        case "${reply:-Y}" in
            Y|y)
                DOCS_REVIEW_ENABLED=true
                return
                ;;
            N|n)
                DOCS_REVIEW_ENABLED=false
                return
                ;;
            *)
                warn "无效选择，请输入 y 或 n。"
                ;;
        esac
    done
}

prompt_codex_profile_choice() {
    local reply=""
    while true; do
        read -r -p "是否使用推荐的 Codex 配置 gpt-5.4 / xhigh？ (Y/n) " reply
        case "${reply:-Y}" in
            Y|y)
                MODEL="gpt-5.4"
                REASONING_EFFORT="xhigh"
                return
                ;;
            N|n)
                read -r -p "请输入 model [${MODEL}]: " reply
                MODEL="${reply:-$MODEL}"
                read -r -p "请输入 reasoning effort [${REASONING_EFFORT}]: " reply
                REASONING_EFFORT="${reply:-$REASONING_EFFORT}"
                return
                ;;
            *)
                warn "无效选择，请输入 y 或 n。"
                ;;
        esac
    done
}

print_configuration_summary() {
    echo ""
    echo "将使用以下配置："
    echo "  - 目标目录: ${TARGET_DIR}"
    echo "  - 模式: ${INIT_MODE}"
    if [[ "$SKIP_FILL" == true ]]; then
        echo "  - 自动填充: 关闭 (--skip-fill)"
    else
        echo "  - CLI: ${CLI_TOOL}"
        echo "  - 填充方式: $([[ "$ULTRA" == true ]] && printf 'ultra' || printf 'single-call')"
        echo "  - docs review: $([[ "$DOCS_REVIEW_ENABLED" == true ]] && printf '开启' || printf '关闭')"
        if [[ "$(detect_cli_kind)" == "codex" ]]; then
            echo "  - model: ${MODEL}"
            echo "  - reasoning: ${REASONING_EFFORT}"
        fi
    fi
    echo ""
}

run_interactive_setup() {
    if ! is_interactive_session; then
        return
    fi

    info "未提供完整参数，进入交互式初始化向导。"

    if [[ "$INIT_MODE_EXPLICIT" != true ]]; then
        prompt_mode_choice
    fi

    if [[ "$SKIP_FILL_EXPLICIT" != true ]]; then
        prompt_fill_choice
    fi

    if [[ "$SKIP_FILL" != true ]]; then
        if [[ "$CLI_TOOL_EXPLICIT" != true ]]; then
            CLI_TOOL="$(default_cli_tool)"
            prompt_cli_choice
        fi

        if [[ "$EXECUTION_MODE_EXPLICIT" != true ]]; then
            prompt_execution_mode_choice
        fi

        if [[ "$DOCS_REVIEW_EXPLICIT" != true ]]; then
            prompt_docs_review_choice
        fi

        if [[ "$(detect_cli_kind)" == "codex" ]] && [[ "$MODEL_EXPLICIT" != true && "$REASONING_EFFORT_EXPLICIT" != true ]]; then
            prompt_codex_profile_choice
        fi
    fi

    print_configuration_summary
    confirm_or_abort "是否按以上配置开始初始化？"
}

init_state_paths() {
    STATE_DIR="${TARGET_DIR}/${STATE_DIR_NAME}"
    LOG_DIR="${STATE_DIR}/logs"
    REPORT_FILE="${STATE_DIR}/final-review.md"
    DOCS_REVIEW_FILE="${STATE_DIR}/docs-review.md"
}

ensure_state_dirs() {
    mkdir -p "$LOG_DIR"
}

reset_run_artifacts() {
    ensure_state_dirs
    rm -f "$REPORT_FILE" "$DOCS_REVIEW_FILE" "$LOG_DIR"/*.log
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

relative_to_target() {
    local path="$1"
    printf '%s\n' "${path#"$TARGET_DIR"/}"
}

file_differs_from_scaffold() {
    local relative_path="$1"
    local scaffold_path="$SCAFFOLD_DIR/$relative_path"
    local target_path="$TARGET_DIR/$relative_path"

    if [[ ! -f "$target_path" ]]; then
        return 1
    fi

    if [[ ! -f "$scaffold_path" ]]; then
        return 0
    fi

    ! cmp -s "$scaffold_path" "$target_path"
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

ensure_scaffold_is_valid() {
    local required_files=(
        "AGENTS.md"
        "docs/stage.lock"
        "docs/workflow/stage1.md"
        "docs/workflow/stage2.md"
        "docs/workflow/stage3.md"
        "docs/workflow/stage4.md"
        "docs/workflow/stage5.md"
        "docs/workflow/stage6.md"
        "docs/wisdom.md"
        "docs/antipatterns.md"
        "docs/plan/current.md"
        "issue_test/README.md"
        "scripts/build_context.py"
        "scripts/run_issue_tests.sh"
        "scripts/deliver_pr.sh"
    )
    local f=""
    for f in "${required_files[@]}"; do
        if [[ ! -f "$SCAFFOLD_DIR/$f" ]]; then
            error "缺少初始化骨架文件：$SCAFFOLD_DIR/$f"
            exit 1
        fi
    done
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

mode_label() {
    if [[ "$INIT_MODE" == "greenfield" ]]; then
        printf 'greenfield'
    else
        printf 'adopt'
    fi
}

mode_intro_prompt() {
    if [[ "$INIT_MODE" == "greenfield" ]]; then
        cat <<'EOF'
当前初始化模式：`greenfield`

- 这是一个准备按 Agent Workflow 长期维护的新项目。
- 文档可以明确写出后续工作流约束，但仍然只能基于仓库中已经存在的代码和配置陈述事实。
- 不要把尚未存在的 lint/test/CI/安全机制写成已经配置完成。
EOF
    else
        cat <<'EOF'
当前初始化模式：`adopt`

- 这是一个已经存在的仓库，正在接入 Agent Workflow Template。
- 优先描述仓库当前真实状态，而不是理想中的 future state。
- 如果质量门、CI、边界规则尚未建立，要明确写“当前未配置”或等价事实描述，不要假装已经具备。
- 不要把历史开发过程回填成“此前一直按此 workflow 执行”。
EOF
    fi
}

bootstrap_edit_guard_prompt() {
    cat <<'EOF'
这是初始化文档填充任务，不是正常的 Stage workflow。

- 不要读取 `AGENTS.md`
- 不要读取 `docs/stage.lock`
- 不要读取 `docs/workflow/stage*.md`
- 不要读取 `docs/plan/current.md`，除非当前 prompt 明确要求
- 只做完成当前目标文件所必需的读取
- 读到足够事实后，必须立刻修改目标文件，不要停留在分析阶段
- 最多执行 8 个只读命令后，必须开始编辑
- 若信息仍无法确认，按模板要求写 `（待填写）` 或 `当前未配置`，不要为了“再确认一点”继续扩展搜索
- 必须直接落盘修改目标文件，然后结束；不要输出方案后停止
EOF
}

run_cli_prompt() {
    local prompt="$1"
    local cli_kind=""

    cli_kind="$(detect_cli_kind)"

    case "$cli_kind" in
        codex)
            local codex_args=(
                "exec"
                "--full-auto"
                "--color" "never"
                "--model" "$MODEL"
                "-c" "model_reasoning_effort=\"$REASONING_EFFORT\""
                "-C" "$TARGET_DIR"
            )
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

    case "$step_id" in
        single_call)
            local file=""
            local relative_path=""
            for file in "${files[@]}"; do
                relative_path="$(relative_to_target "$file")"
                file_differs_from_scaffold "$relative_path" || return 1
            done
            ;;
        audit)
            [[ -s "$REPORT_FILE" ]]
            ;;
        docs_review)
            [[ -s "$DOCS_REVIEW_FILE" ]] &&
            grep -q '^# 文档复核报告$' "$DOCS_REVIEW_FILE"
            ;;
        *)
            [[ "$changed_count" -gt 0 ]] &&
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
        return 1
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
        if [[ "$step_id" == "single_call" ]]; then
            return 11
        fi
        return 1
    fi
}

run_audit_step() {
    local title="最终扫描并生成人工补充清单"

    ensure_state_dirs

    info "  → ${title}"

    generate_audit_report >"$REPORT_FILE"

    if ! validate_edit_step "audit" 1 "$REPORT_FILE"; then
        error "步骤未通过结果校验：${title}"
        error "报告文件为空：$REPORT_FILE"
        exit 1
    fi
}

run_docs_review_step() {
    local step_id="docs_review"
    local title="独立复核生成后的文档"
    local review_scope=()
    local before_states=()
    local after_state=""
    local index=0

    if [[ "$DOCS_REVIEW_ENABLED" != true ]]; then
        warn "  → 跳过 ${title}（已禁用）"
        return 0
    fi

    ensure_state_dirs

    for path in "${MANAGED_FILES[@]}"; do
        review_scope+=("$TARGET_DIR/$path")
    done

    for path in "${review_scope[@]}"; do
        before_states+=("$(capture_fingerprint "$path")")
    done

    info "  → ${title}"

    if ! (
        cd "$TARGET_DIR"
        run_cli_prompt "$(docs_review_prompt)"
    ) >"$DOCS_REVIEW_FILE" 2>"$LOG_DIR/${step_id}.log"; then
        error "步骤失败：${title}"
        error "日志：$LOG_DIR/${step_id}.log"
        tail -n 20 "$LOG_DIR/${step_id}.log" || true
        exit 1
    fi

    for index in "${!review_scope[@]}"; do
        after_state="$(capture_fingerprint "${review_scope[$index]}")"
        if [[ "$after_state" != "${before_states[$index]}" ]]; then
            error "步骤未通过结果校验：${title}"
            error "Docs review 是只读步骤，但检测到生成文件被修改。"
            error "日志：$LOG_DIR/${step_id}.log"
            exit 1
        fi
    done

    if ! validate_edit_step "$step_id" 1 "$DOCS_REVIEW_FILE"; then
        error "步骤未通过结果校验：${title}"
        error "报告文件为空或缺少预期标题：$DOCS_REVIEW_FILE"
        exit 1
    fi
}

copy_template_skeleton() {
    info "[1/2] 复制模板骨架到 ${TARGET_DIR}"
    check_existing_managed_files
    ensure_state_dirs

    # ── 直接从 scaffold 复制，无需 Agent ──────────────────────────
    mkdir -p "$TARGET_DIR/docs/workflow"
    copy_managed_file "docs/stage.lock"
    copy_managed_file "docs/workflow/stage1.md"
    copy_managed_file "docs/workflow/stage2.md"
    copy_managed_file "docs/workflow/stage3.md"
    copy_managed_file "docs/workflow/stage4.md"
    copy_managed_file "docs/workflow/stage5.md"
    copy_managed_file "docs/workflow/stage6.md"

    # 长期记忆文件：初始为空模板，由 Stage 5 逐步积累
    copy_managed_file "docs/wisdom.md"
    copy_managed_file "docs/antipatterns.md"

    # 运行时状态文件：固定初始状态
    mkdir -p "$TARGET_DIR/docs/plan/archive"
    copy_managed_file "docs/blockers.md"
    copy_managed_file "docs/plan/current.md"
    copy_managed_file "docs/plan/archive/README.md"
    mkdir -p "$TARGET_DIR/issue_test"
    copy_managed_file "issue_test/README.md"

    # 脚本：Harness 工具，内容固定，直接复制
    mkdir -p "$TARGET_DIR/scripts"
    copy_managed_file "scripts/build_context.py"
    copy_managed_file "scripts/run_issue_tests.sh"
    copy_managed_file "scripts/deliver_pr.sh"

    # ── 需要 Agent 填充的模板文件 ──────────────────────────────────
    # 以下文件以空白模板复制，init.sh 后续步骤会调用 Agent 填充。
    # 内容依赖目标仓库的代码事实，不能直接复制 scaffold 内容。
    copy_managed_file "docs/overview.md"
    copy_managed_file "docs/architecture.md"
    copy_managed_file "docs/conventions.md"
    copy_managed_file "docs/quality.md"
    copy_managed_file "docs/security.md"
    copy_managed_file "docs/progress.md"
    copy_managed_file "docs/plan/backlog.md"

    # ── decisions.md：D-001 内容固定，sed 填入日期和背景，无需 Agent ──
    copy_managed_file "docs/decisions.md"
    local today
    today="$(date '+%Y-%m-%d')"
    local d001_background=""
    if [[ "$INIT_MODE" == "greenfield" ]]; then
        d001_background="项目需要建立结构化的 agent 工作流文档体系，以支持 AI agent 自主开发。"
    else
        d001_background="该仓库在已有代码和实验资产的基础上接入 Agent Workflow Template，需要先把当前事实沉淀为可维护文档，再逐步收敛到统一流程。"
    fi
    sed -i.bak \
        -e "s/__INIT_DATE__/${today}/" \
        -e "s|__INIT_BACKGROUND__|${d001_background}|" \
        "$TARGET_DIR/docs/decisions.md"
    rm -f "$TARGET_DIR/docs/decisions.md.bak"

    chmod +x "$TARGET_DIR/scripts/"*.sh
    info "模板骨架已复制。"
}

copy_post_fill_scaffold_files() {
    # AGENTS.md 会影响 codex 的仓库级指令解析。
    # 初始化自动填充期间先不复制，避免 codex 偏离 bootstrap prompt。
    copy_managed_file "AGENTS.md"
}

overview_prompt() {
    mode_intro_prompt
    bootstrap_edit_guard_prompt
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
    mode_intro_prompt
    bootstrap_edit_guard_prompt
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
- 如果项目没有 lint 或 CI，明确写"当前未配置（手动执行）"，不要写成已有机械护栏

## 规则
- 只收录被工具机械执行的结构性约束。风格性规则不写在这里
- "维护规则"部分不要修改
- 无法确认的信息保留"（待填写）"
PROMPT
}

conventions_prompt() {
    mode_intro_prompt
    bootstrap_edit_guard_prompt
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
    mode_intro_prompt
    bootstrap_edit_guard_prompt
    cat <<'PROMPT'
分析当前代码库的测试设置，填充 docs/quality.md。不要修改任何其他文件。

## 分析步骤

1. 查找仓库已有测试目录：常见位置有 tests/、test/、__tests__/、spec/、*_test.go 等
2. 打开 1-2 个测试文件，确认是否存在原生测试框架
3. 查找测试/静态检查配置文件（如 jest.config、pytest.ini、vitest.config、eslint 配置等）
4. 查找包管理文件中的 test/lint scripts（如 package.json 的 scripts.test）
5. 检查 CI 配置中的测试或静态检查命令

## 填写要求

打开 docs/quality.md，只修改以下"待填写"区域，Definition of Done、issue_test 机制、失败处理流程和维护规则保持不动：

**项目原生检查**：
- 单元/集成测试框架：写出仓库实际使用的原生测试框架；如没有，写"当前未配置"
- 静态检查工具：写出仓库实际使用的 lint/type check/static analysis；如没有，写"当前未配置"
- 其他交付前命令：写出仓库里确实存在且建议交付前运行的命令；如没有，写"当前未配置"

**常用验证命令**：
- 保留前两条 `scripts/run_issue_tests.sh` 命令不变
- 仅替换最后一个 `<command>` 占位符
- 若仓库存在额外的项目原生检查，写出一个最有代表性的实际命令
- 若仓库当前没有额外的项目原生检查，写 `当前未配置`

## 规则
- "Definition of Done"部分不要修改
- "issue_test 机制（固定）"部分不要修改
- "失败处理流程"部分不要修改
- "维护规则"部分不要修改
- 若仓库尚未建立统一原生测试/静态检查体系，必须明确写出“当前未配置”或等价事实描述，不要把理想状态写成既有能力
- 无法确认的信息保留"（待填写）"
PROMPT
}

security_prompt() {
    mode_intro_prompt
    bootstrap_edit_guard_prompt
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
- 若仓库存在硬编码本地路径、模型目录、实验机专属脚本，应作为环境耦合风险写入相关区域
- 无法确认的信息保留"（待填写）"
PROMPT
}

progress_prompt() {
    mode_intro_prompt
    bootstrap_edit_guard_prompt
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
    mode_intro_prompt
    bootstrap_edit_guard_prompt
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

audit_prompt() {
    cat <<PROMPT
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

docs_review_prompt() {
    mode_intro_prompt
    cat <<'PROMPT'
你正在执行一个独立的文档复核 session。目标是审查刚由初始化流程生成的 Agent Workflow 文档，而不是补写或改写这些文档。

这是只读任务。不要修改仓库中的任何文件，不要创建文件，不要运行会写文件的命令。只读取仓库和文档，然后把复核结论输出到 stdout。

请重点检查以下对象（Agent 填充的文档）：
- docs/overview.md
- docs/architecture.md
- docs/conventions.md
- docs/decisions.md
- docs/quality.md
- docs/security.md
- docs/progress.md
- docs/plan/backlog.md

以下文件由初始化脚本直接复制，无需检查内容正确性，只需确认文件存在：
- AGENTS.md
- docs/stage.lock
- docs/workflow/stage1.md ~ stage6.md
- docs/wisdom.md
- docs/antipatterns.md
- issue_test/README.md
- scripts/build_context.py
- scripts/run_issue_tests.sh

请优先寻找这些问题：
1. 文档与代码事实不一致
2. 文档之间互相矛盾
3. 模板占位符、空白模板或初始化后仍不该残留的样板文本
4. 把“理想状态/建议状态”误写成“当前已经存在的状态”
5. 会误导后续 agent 行为的流程文档问题

输出格式必须是以下 Markdown 结构：

# 文档复核报告

## Blocking inconsistencies
- 只列会直接误导后续 agent 或明显与仓库事实冲突的问题
- 如果没有，写 `- 无`

## Needs human confirmation
- 列出需要人类拍板或补充背景的信息
- 如果没有，写 `- 无`

## Nice-to-fix
- 列出不影响初始化完成、但值得清理的文档问题
- 如果没有，写 `- 无`

## Summary
- 用 2-4 条总结整体质量和主要风险

规则：
- 不要改文件
- 不要替作者解释意图
- 只基于仓库中能读到的事实给出结论
- 每条尽量带文件路径
PROMPT
}

single_call_prompt() {
    mode_intro_prompt
    bootstrap_edit_guard_prompt
    cat <<'PROMPT'
你正在为一个刚初始化 Agent Workflow Template 的仓库执行一次“初始化 bootstrap”任务。

这是一次特殊初始化操作，本条 prompt 的要求优先于仓库内尚未填充完成的 `docs/workflow/stage*.md`、`docs/plan/current.md` 等模板流程文件。不要因为模板中的进行中状态、空白计划或流程冲突而停止、提问或等待确认。不要输出方案后停止，直接完成文件修改。

只允许修改以下文件：
- `docs/overview.md`
- `docs/architecture.md`
- `docs/conventions.md`
- `docs/quality.md`
- `docs/security.md`
- `docs/progress.md`
- `docs/plan/backlog.md`

不要修改以下文件（已由初始化脚本直接处理，无需 AI）：
- `AGENTS.md`
- `docs/stage.lock`
- `docs/workflow/stage*.md`
- `docs/wisdom.md`
- `docs/antipatterns.md`
- `docs/decisions.md`（D-001 已由 init.sh 直接写入）
- `issue_test/README.md`
- `scripts/build_context.py`
- `scripts/run_issue_tests.sh`

不要修改任何其他文件。

## 目标

请基于当前代码库事实，一次性完成以下初始化：

1. 填充 `docs/overview.md`
2. 填充 `docs/architecture.md`
3. 填充 `docs/conventions.md`
4. 填充 `docs/quality.md`
5. 填充 `docs/security.md`
6. 填充 `docs/progress.md`
7. 填充 `docs/plan/backlog.md`

## 分析要求

- 先检查根目录结构、README、包管理文件、主代码目录、测试目录、CI/脚本配置、git 历史和分支命名
- 只基于代码库中能确认的事实填写，不要编造信息
- 无法可靠确认的信息保留“（待填写）”或按模板中的保守表达处理
- 对 adopt 模式，文档应首先陈述当前事实，不要把理想治理状态写成既有事实
- `docs/progress.md` 必须基于实际代码、git 活动和 TODO/FIXME/HACK/XXX 注释填写
- `docs/plan/backlog.md` 必须基于代码注释、`docs/progress.md` 和 `docs/overview.md` 中可确认线索填写

## 各文件要求

### `docs/overview.md`
- 填写项目名称、一句话目标、目标用户、业务价值
- 填写 In Scope / Out of Scope
- 填写核心概念
- 成功标准无法确认时保留“（待填写）”
- 保持“维护规则”不变

### `docs/architecture.md`
- 填写实际分层模型、目录结构、Import Boundary 规则、执行方式
- 只写被工具机械执行的结构性约束
- 保持“维护规则”不变

### `docs/conventions.md`
- 填写命名规范、函数契约、错误处理模式、Git 规范
- 只写靠 agent 自觉遵守的风格性规则
- 保持“维护规则”不变

### `docs/quality.md`
- 只修改“项目原生检查（待填写）”和“常用验证命令”中的最后一个 `<command>` 占位符
- 不要修改 Definition of Done、issue_test 机制、失败处理流程、维护规则
- 如果仓库当前没有额外的项目原生检查，明确写 `当前未配置`

### `docs/security.md`
- 只从 `.env.example`、代码中的环境变量引用、认证代码、CI secrets 引用等提取信息
- 绝不读取或输出 `.env` 实际值
- 不要修改安全变更规则

### `docs/progress.md`
- 只记录事实状态，不写未来意图
- 更新时间填今天日期

### `docs/plan/backlog.md`
- 每条任务用 `- [ ]`
- 包含来源信息
- 若无可靠线索则保留“（待填写）”

## 输出要求

- 直接完成文件修改
- 不要停下来问问题
- 最终不要额外修改列表之外的文件
PROMPT
}

generate_audit_report() {
    # 只审计 Agent 填充的文件，Harness 层文件（直接复制）不在审计范围
    local files=(
        "docs/overview.md"
        "docs/architecture.md"
        "docs/conventions.md"
        "docs/quality.md"
        "docs/security.md"
        "docs/progress.md"
        "docs/plan/backlog.md"
    )
    local file=""
    local relative_path=""
    local has_followups=false
    local line=""
    local -a findings=()

    echo "# 初始化后人工补充清单"
    echo ""
    echo "## 已完成概览"
    echo "- 自动初始化已复制模板骨架，并完成文档/脚本状态扫描。"
    echo "- 本报告由本地规则生成，用于标出仍需人工补充或确认的项目。"
    echo ""
    echo "## 仍需人工补充"

    for file in "${files[@]}"; do
        relative_path="$file"
        findings=()

        if [[ ! -f "$TARGET_DIR/$relative_path" ]]; then
            findings+=("文件缺失")
        else
            if [[ -f "$SCAFFOLD_DIR/$relative_path" ]] && cmp -s "$SCAFFOLD_DIR/$relative_path" "$TARGET_DIR/$relative_path"; then
                findings+=("看起来仍是模板原样内容")
            fi

            while IFS= read -r line; do
                findings+=("仍包含占位内容：${line}")
            done < <(grep -nE '（待填写）|YYYY-MM-DD|Not Started / In Progress / Done|（示例：' "$TARGET_DIR/$relative_path" || true)

            if grep -n '<command>' "$TARGET_DIR/$relative_path" >/dev/null 2>&1; then
                findings+=("仍包含 `<command>` 占位符")
            fi

            if grep -n '当前未配置' "$TARGET_DIR/$relative_path" >/dev/null 2>&1; then
                findings+=("包含“当前未配置”，建议人工确认是否确实缺失")
            fi
        fi

        if [[ ${#findings[@]} -gt 0 ]]; then
            has_followups=true
            echo "- \`$relative_path\`"
            printf '  - %s\n' "${findings[@]}"
        fi
    done

    if [[ "$has_followups" == false ]]; then
        echo "- 未发现明显占位内容或 fallback 配置。"
    fi

    echo ""
    echo "## 风险提示"
    echo "- Git 历史、分支命名和 PR 规范经常无法仅从本地仓库完整推断，相关文档需人工复核。"
    echo "- 安全边界、受保护路径和认证模式可能隐藏在部署环境或私有配置中，本地扫描只能给出保守结论。"
    echo '- 若仓库没有显式原生测试/静态检查配置，quality.md 中可能仍保留“当前未配置”或 `<command>` 占位，需要人工确认。'
    echo "- 业务范围与 Out of Scope 往往需要产品/项目背景信息，代码扫描只能提取当前可见边界。"
}

run_single_call_sequence() {
    local step_status=0

    info "[2/2] 调用 ${CLI_TOOL} 单次完成全部填充（$(mode_label) 模式，默认）..."
    echo ""

    if run_edit_step "single_call" "单次填充全部文档" \
        "$TARGET_DIR/docs/overview.md" \
        "$TARGET_DIR/docs/architecture.md" \
        "$TARGET_DIR/docs/conventions.md" \
        "$TARGET_DIR/docs/quality.md" \
        "$TARGET_DIR/docs/security.md" \
        "$TARGET_DIR/docs/progress.md" \
        "$TARGET_DIR/docs/plan/backlog.md" -- <<<"$(single_call_prompt)"; then
        :
    else
        step_status=$?
        if [[ "$step_status" -eq 11 ]] && [[ "$(detect_cli_kind)" == "codex" ]]; then
            warn "单次填充未成功落盘；对 codex 自动回退到 ultra 逐文件模式。"
            ULTRA=true
            SINGLE_CALL=false
            run_fill_sequence
            return
        fi
        exit "$step_status"
    fi

    run_docs_review_step
    run_audit_step
}

run_fill_sequence() {
    info "[2/2] 调用 ${CLI_TOOL} 逐个填充文档（$(mode_label) 模式）..."
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

    run_docs_review_step
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
            CLI_TOOL_EXPLICIT=true
            shift 2
            ;;
        --model)
            if [[ $# -lt 2 ]]; then
                error "参数 --model 需要一个值。"
                usage
                exit 1
            fi
            MODEL="$2"
            MODEL_EXPLICIT=true
            shift 2
            ;;
        --reasoning-effort)
            if [[ $# -lt 2 ]]; then
                error "参数 --reasoning-effort 需要一个值。"
                usage
                exit 1
            fi
            REASONING_EFFORT="$2"
            REASONING_EFFORT_EXPLICIT=true
            shift 2
            ;;
        --skip-fill)
            SKIP_FILL=true
            SKIP_FILL_EXPLICIT=true
            shift
            ;;
        --adopt)
            INIT_MODE="adopt"
            INIT_MODE_EXPLICIT=true
            shift
            ;;
        --greenfield)
            INIT_MODE="greenfield"
            INIT_MODE_EXPLICIT=true
            shift
            ;;
        --single-call)
            SINGLE_CALL=true
            ULTRA=false
            EXECUTION_MODE_EXPLICIT=true
            shift
            ;;
        --ultra)
            ULTRA=true
            SINGLE_CALL=false
            EXECUTION_MODE_EXPLICIT=true
            shift
            ;;
        --no-docs-review)
            DOCS_REVIEW_ENABLED=false
            DOCS_REVIEW_EXPLICIT=true
            shift
            ;;
        --docs-review)
            DOCS_REVIEW_ENABLED=true
            DOCS_REVIEW_EXPLICIT=true
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            NON_INTERACTIVE_EXPLICIT=true
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

init_state_paths
ensure_scaffold_is_valid

run_interactive_setup

if [[ "$SKIP_FILL" == false ]] && [[ "$(detect_cli_kind)" == "codex" ]]; then
    if [[ "$EXECUTION_MODE_EXPLICIT" != true ]]; then
        ULTRA=true
        SINGLE_CALL=false
    fi
    if [[ "$DOCS_REVIEW_EXPLICIT" != true ]]; then
        DOCS_REVIEW_ENABLED=false
        warn "检测到 codex；默认跳过独立文档复核（可用 --docs-review 显式启用）。"
    fi
fi

if [[ "$ULTRA" == true ]]; then
    SINGLE_CALL=false
else
    SINGLE_CALL=true
fi

if [[ "$SKIP_FILL" == false ]] && ! command -v "$CLI_TOOL" >/dev/null 2>&1; then
    error "错误：未找到 ${CLI_TOOL} CLI。"
    echo "可用 --skip-fill 跳过自动填充，或 --cli <name> 指定其他工具。"
    exit 1
fi

if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    info "检测到目标目录是 Git 仓库。"
else
    error "错误：目标目录不是 Git 仓库。"
    echo "Agent Workflow 的核心机制（stage.lock commit、branch 管理、PR 流程）强依赖 Git。"
    echo "请先在目标目录执行 git init && git commit，再重新运行 init.sh。"
    exit 1
fi

if ! python3 -c "import yaml" >/dev/null 2>&1; then
    error "错误：未找到 PyYAML（scripts/build_context.py 的必须依赖）。"
    echo "请先执行：python3 -m pip install pyyaml"
    exit 1
fi

reset_run_artifacts
copy_template_skeleton

if [[ "$SKIP_FILL" == true ]]; then
    copy_post_fill_scaffold_files
    warn "已跳过自动填充（--skip-fill）。"
else
    if [[ "$ULTRA" == true ]]; then
        run_fill_sequence
    else
        run_single_call_sequence
    fi
    copy_post_fill_scaffold_files
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

if [[ -s "$DOCS_REVIEW_FILE" ]]; then
    echo "独立文档复核报告：$DOCS_REVIEW_FILE"
    echo ""
    cat "$DOCS_REVIEW_FILE"
    echo ""
fi

if [[ "$SKIP_FILL" == true ]]; then
    echo "下一步（--skip-fill 模式，文档仍包含模板占位，需人工补充）："
    echo "  1. 填充 docs/ 下所有标记为（待填写）的文档"
    echo "  2. 检查 issue_test/README.md 与 scripts/run_issue_tests.sh，确认符合你的仓库习惯"
    echo "  3. 在 docs/plan/backlog.md 中补充你的第一批 issue"
    echo "  4. 启动 agent：${CLI_TOOL} \"读 AGENTS.md，然后开始工作。\""
else
    echo "下一步："
    echo "  1. 检查 docs/ 下的文档，补充仍需人工确认的内容"
    echo "  2. 开始第一个 issue 时，先创建 issue_test/<issue_id>.sh，再实现代码"
    echo "  3. 完成实现后，运行 bash scripts/run_issue_tests.sh 确认所有历史 issue test 都通过"
    echo "  4. 在 docs/plan/backlog.md 中补充你的第一批 issue"
    echo "  5. 启动 agent：${CLI_TOOL} \"读 AGENTS.md，然后开始工作。\""
fi
