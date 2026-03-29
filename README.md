# Agent Workflow Template

一个把 AI agent 开发流程拆成“初始化脚手架 + 文档状态机 + issue 级累积回归”的模板仓库。

它解决的不是“怎么写 prompt”，而是“怎么把 agent 的工作流程变成可重复执行、可验证、可中断恢复的工程系统”。

## 这个项目怎么用

### 1. 用 `init.sh` 初始化你的目标仓库

前提：

- 目标目录必须已经是 Git 仓库。
- 目标目录不能是本模板仓库自身。
- 本机需要 `python3` 和 `PyYAML`，因为 `scripts/build_context.py` 依赖它。
- 如果要自动填充文档，需要可用的 AI CLI，例如 `codex` 或 `claude`。

典型用法：

```bash
# 在你的目标项目里执行，不是在本模板仓库里执行
cd /path/to/your-repo

# 交互式初始化
bash /path/to/Agent-Workflow-Template/init.sh

# 非交互式 adopt 模式
bash /path/to/Agent-Workflow-Template/init.sh \
  --adopt \
  --cli codex \
  --ultra \
  --non-interactive

# 只复制骨架，不自动填文档
bash /path/to/Agent-Workflow-Template/init.sh \
  --skip-fill \
  --non-interactive
```

`init.sh` 支持的核心参数：

| 参数 | 作用 |
| --- | --- |
| `--adopt` | 接入一个已经存在的仓库，文档优先描述“当前事实” |
| `--greenfield` | 面向全新项目初始化 |
| `--skip-fill` | 只复制骨架，不调用 AI 填充文档 |
| `--cli <claude|codex>` | 指定初始化时调用的 CLI |
| `--model <name>` | 给 `codex` 指定模型 |
| `--reasoning-effort <level>` | 给 `codex` 指定推理强度 |
| `--single-call` | 用一次 AI 调用填完所有文档 |
| `--ultra` | 按文件分步调用 AI 填文档 |
| `--docs-review` / `--no-docs-review` | 是否额外做一轮只读文档复核 |
| `--non-interactive` | 禁用交互式向导 |

补充说明：

- 脚本内建默认值是 `claude + gpt-5.4 + xhigh`。
- 如果你使用 `codex` 且没有显式指定执行模式，脚本会默认切到 `--ultra`，并默认跳过独立 docs review。
- `init.sh` 会拒绝在非 Git 仓库中运行，因为这个 workflow 依赖 `stage.lock` commit、分支和 PR 交付。

### 2. 初始化后怎么开始跑

初始化成功后，目标仓库里会得到：

- `AGENTS.md`：Agent 启动协议和硬规则
- `docs/`：状态机、项目上下文、计划、阻塞、决策
- `issue_test/`：每个 issue 对应的独立回归脚本
- `scripts/`：上下文装载器和 issue test 运行器

日常运行方式：

```bash
# Agent 启动入口
codex "读 AGENTS.md，然后开始工作。"

# 手工查看某个 Stage 会加载哪些上下文
python3 scripts/build_context.py --stage stage3

# 跑历史 + 当前 issue 的累积回归
bash scripts/run_issue_tests.sh

# 跑历史回归，但排除当前 issue 的脚本
bash scripts/run_issue_tests.sh --exclude issue_test/<issue_id>.sh
```

### 3. `init.sh` 实际做了什么

`init.sh` 不是简单复制文件。它把模板初始化分成四类动作：

| 类别 | 处理方式 | 文件 |
| --- | --- | --- |
| 固定骨架 | 直接从 `scaffold/` 复制 | `docs/stage.lock`、`docs/workflow/stage*.md`、`docs/wisdom.md`、`docs/antipatterns.md`、`docs/blockers.md`、`docs/plan/current.md`、`docs/plan/archive/README.md`、`issue_test/README.md`、`scripts/build_context.py`、`scripts/run_issue_tests.sh` |
| AI 填充 | 先复制模板，再调用 AI 按目标仓库事实填充 | `docs/overview.md`、`docs/architecture.md`、`docs/conventions.md`、`docs/quality.md`、`docs/security.md`、`docs/progress.md`、`docs/plan/backlog.md` |
| 脚本直写 | 复制后由脚本替换占位符 | `docs/decisions.md` 中的 `D-001` 日期和初始化背景 |
| 延后复制 | 在 AI 填充结束后再复制，避免影响初始化 prompt | `AGENTS.md` |

初始化过程中，脚本还会在目标仓库的 `.git/.agent-workflow-init/` 目录下生成运行产物：

- `logs/*.log`：每一步 AI 调用日志
- `final-review.md`：本地规则生成的人工补充清单
- `docs-review.md`：可选的只读文档复核报告

## 项目架构

这个仓库本质上由两层组成：

1. 模板层：`init.sh + scaffold/`
2. 运行层：被初始化到目标仓库中的 `AGENTS.md + docs/ + issue_test/ + scripts/`

模板层负责“生成运行系统”，运行层负责“驱动 agent 工作”。

### 顶层结构

```text
Agent-Workflow-Template/
├── init.sh
├── scaffold/
│   ├── AGENTS.md
│   ├── docs/
│   ├── issue_test/
│   └── scripts/
├── docs/
├── issue_test/
└── scripts/
```

这里要注意两点：

- `scaffold/` 是模板源文件，给别的仓库复制用。
- 仓库根目录下当前的 `docs/`、`issue_test/`、`scripts/` 是这个模板仓库自己的一份工作副本，用来维护和验证模板本身。

### 运行时分层

| 层 | 组件 | 职责 |
| --- | --- | --- |
| Bootstrap 层 | `init.sh`、`scaffold/` | 初始化目标仓库，复制骨架并填充首批文档 |
| Control 层 | `AGENTS.md`、`docs/stage.lock`、`docs/workflow/stage*.md` | 定义 agent 启动协议、当前状态和 Stage 跳转规则 |
| Context 层 | `docs/overview.md`、`architecture.md`、`conventions.md`、`quality.md`、`security.md`、`progress.md`、`decisions.md`、`blockers.md`、`wisdom.md`、`antipatterns.md`、`docs/plan/*` | 提供项目事实、规则、计划、历史和阻塞信息 |
| Harness 层 | `scripts/build_context.py`、`issue_test/*.sh`、`scripts/run_issue_tests.sh` | 机械装载上下文，机械执行累积回归 |
| Delivery 层 | `git commit`、`git push`、`gh pr create`、`docs/plan/archive/*` | 把变更转成可交付结果，并沉淀归档 |

### 架构关系图

```mermaid
flowchart LR
    subgraph Template["模板层"]
        INIT["init.sh"]
        SCF["scaffold/"]
    end

    subgraph Runtime["目标仓库运行层"]
        AG["AGENTS.md"]
        LOCK["docs/stage.lock"]
        WF["docs/workflow/stage1..6.md"]
        CTX["scripts/build_context.py"]
        DOCS["docs/*.md"]
        IT["issue_test/*.sh"]
        SUITE["scripts/run_issue_tests.sh"]
        GIT["git / push / PR / archive"]
    end

    INIT --> SCF
    INIT --> DOCS
    INIT --> CTX
    INIT --> IT
    INIT --> SUITE
    INIT --> AG
    AG --> LOCK
    LOCK --> CTX
    CTX --> WF
    WF --> DOCS
    WF --> IT
    IT --> SUITE
    SUITE --> WF
    WF --> GIT
    GIT --> DOCS
```

## `scaffold/` 是什么

`scaffold/` 不是示例代码目录，它是初始化时的“文件母版”。

初始化目标仓库时，`init.sh` 不会读取根目录下当前运行中的 `docs/` 作为源，而是严格从 `scaffold/` 拿模板文件。

`scaffold/` 里的内容可以分成三类：

| 类别 | 典型文件 | 用途 |
| --- | --- | --- |
| 状态机骨架 | `scaffold/AGENTS.md`、`scaffold/docs/stage.lock`、`scaffold/docs/workflow/stage*.md` | 定义 agent 的固定运行协议 |
| 项目事实模板 | `scaffold/docs/overview.md`、`scaffold/docs/architecture.md`、`scaffold/docs/conventions.md`、`scaffold/docs/quality.md`、`scaffold/docs/security.md`、`scaffold/docs/progress.md`、`scaffold/docs/plan/backlog.md` | 初始化时由 AI 根据目标仓库内容填充 |
| Harness 脚本 | `scaffold/scripts/build_context.py`、`scaffold/scripts/run_issue_tests.sh`、`scaffold/issue_test/README.md` | 把“读什么”和“怎么验证”变成固定脚本 |

换句话说：

- `scaffold/` 决定“新仓库会被初始化成什么样”
- `docs/` 决定“当前这个仓库现在是什么状态”

## 运行模型

单次 agent run 只允许完成一个 issue 闭环。

标准循环是：

1. 读 `AGENTS.md`
2. 读 `docs/stage.lock`
3. 执行 `python3 scripts/build_context.py --stage <current>`
4. 按输出读取全部上下文文件
5. 执行 `docs/workflow/<current>.md`
6. 更新 `docs/stage.lock`
7. 如果回到 `current: stage1` 且 `status: done` 且 `previous: stage6`，本次 run 结束

这意味着：

- 不允许在同一次 run 里连续领取多个 backlog issue。
- 任何 Stage 失败都要写 `docs/blockers.md` 并停止。
- 每次 `stage.lock` 更新都要求单独 git commit。

## Stage 输入模型

`scripts/build_context.py` 会先注入全局上下文，再按 Stage 注入增量上下文。

所有 Stage 都会加载：

- `docs/overview.md`
- `docs/architecture.md`
- `docs/conventions.md`
- `issue_test/README.md`
- `docs/wisdom.md`、`docs/antipatterns.md`（如果存在）

各 Stage 的增量输入如下：

| Stage | 额外输入 |
| --- | --- |
| Stage 1 | `docs/stage.lock`、`docs/progress.md`、`docs/blockers.md`、`docs/plan/current.md`、`docs/workflow/stage1.md` |
| Stage 2 | `docs/plan/backlog.md`、`docs/decisions.md`、`docs/workflow/stage2.md` |
| Stage 3 | `docs/plan/current.md`、`docs/security.md`、`issue_test/<issue_id>.sh`、`docs/workflow/stage3.md` |
| Stage 4 | `docs/plan/current.md`、`docs/quality.md`、`issue_test/<issue_id>.sh`、`docs/workflow/stage4.md` |
| Stage 5 | `docs/decisions.md`、`docs/plan/archive/<issue_id>.md`、`docs/workflow/stage5.md` |
| Stage 6 | `docs/progress.md`、`docs/decisions.md`、`docs/workflow/stage6.md` |

这个设计的重点是：每个 Stage 只读它真正需要的文件，不让 agent 在无关文档里游走。

## Stage 之间的流程图

```mermaid
flowchart TD
    S1["Stage 1<br/>Context Loading / Router"] -->|current.md 为空或已完成| S2["Stage 2<br/>Task Planning"]
    S1 -->|current.md 有未完成步骤| S3["Stage 3<br/>Implementation"]
    S1 -->|status=failed 或 blockers 未清| STOP["停止并等待人类处理"]
    S1 -->|stage1/done 且 previous=stage6| END["本次 run 成功结束"]

    S2 --> S3

    S3 -->|完整 issue 回归通过| S4["Stage 4<br/>Delivery & Verification"]
    S3 -->|同一错误修复超过 3 次<br/>或 issue test 有效性无法判断| STOP

    S4 -->|最终回归失败| S3
    S4 -->|交付完成| S5["Stage 5<br/>Reflection"]
    S4 -->|无法形成可交付本地 commit| STOP

    S5 --> S6["Stage 6<br/>Entropy Check"]
    S5 -->|REFLECT 缺失或不完整| STOP

    S6 -->|只改文档| END
    S6 -->|熵检查中改了代码| S3
    S6 -->|无法判断文档和代码谁对| STOP
```

## 每个 Stage 的输入、输出、修改面

| Stage | 输入 | 输出 | 修改什么 |
| --- | --- | --- | --- |
| Stage 1 | `stage.lock`、`progress.md`、`blockers.md`、`plan/current.md` | 路由结果：结束当前 run，或进入 Stage 2 / Stage 3 | `docs/stage.lock` |
| Stage 2 | `plan/backlog.md`、`decisions.md`、`overview.md`、`antipatterns.md` | 确定 `issue_id`、创建当前 issue test、写好 `current.md`、把状态推进到 Stage 3 | `issue_test/<issue_id>.sh`、`docs/plan/current.md`、`docs/stage.lock`，必要时改 `docs/overview.md` 和 `docs/decisions.md` |
| Stage 3 | `plan/current.md`、`security.md`、当前 issue test、历史 issue tests、业务代码 | 代码实现完成，完整回归通过，推进到 Stage 4 | 业务代码、测试、`docs/plan/current.md`、`docs/stage.lock`，必要时改 `docs/architecture.md` 和 `docs/decisions.md` |
| Stage 4 | `plan/current.md`、`quality.md`、完整回归结果、git 远端状态 | 本地 commit、远端 PR 或人工 handoff、进度更新、计划归档、推进到 Stage 5 | Git 历史、`docs/progress.md`、`docs/plan/archive/<issue_id>.md`、`docs/plan/current.md`、`docs/plan/backlog.md`、`docs/stage.lock` |
| Stage 5 | `decisions.md`、归档计划、当前 issue 上下文 | 反思结果、REFLECT 文件、可复用经验或反模式、推进到 Stage 6 | `docs/plan/archive/REFLECT-<issue_id>.md`、`docs/wisdom.md`、`docs/antipatterns.md`、`docs/stage.lock`，必要时改 `docs/decisions.md`、`docs/architecture.md`、`docs/conventions.md` |
| Stage 6 | 全局文档、`progress.md`、`decisions.md`、代码现状 | 文档与代码对齐；若只改文档则结束 run，若改了代码则回到 Stage 3 | `docs/*.md`、`docs/stage.lock`，必要时也会改代码和测试 |

## 每个 Stage 的流程

### Stage 1: Context Loading / Router

目标：判断当前 run 应该结束、恢复未完成 issue，还是开始挑选新 issue。

流程：

1. 先读 `docs/stage.lock`
2. 如果 `status == failed`，直接停止，等待人类处理
3. 如果已经是 `stage1 + done + previous=stage6`，说明上一个 issue 闭环刚完成，本次 run 成功结束
4. 如果 `status == in_progress`，直接跳到 `stage.lock.current`
5. 如果 `status == done`，再检查 `docs/blockers.md`
6. blockers 清空后，检查 `docs/plan/current.md`
7. `current.md` 有未完成 checkbox，就去 Stage 3；否则去 Stage 2

这一阶段只负责路由，不负责任务实现。

### Stage 2: Task Planning

目标：从 backlog 中选一个 issue，把它转成“可执行计划 + 可执行测试”。

流程：

1. 先读 `docs/antipatterns.md`，看当前任务是否命中过往失败模式
2. 从 `docs/plan/backlog.md` 里按 P0 → P1 → P2 选择一个未完成任务
3. 对照 `docs/overview.md` 检查这个任务是否仍在项目范围内
4. 生成 `issue_id`
5. 创建 `issue_test/<issue_id>.sh`
6. 把执行步骤写进 `docs/plan/current.md`
7. 如果发生范围变化或关键技术选择，追加写入 `docs/decisions.md`
8. 更新 `docs/stage.lock` 到 Stage 3

这个阶段的核心约束是：没有 issue test，就不能进入实现阶段。

### Stage 3: Implementation

目标：先守住历史，再实现当前 issue，并让完整回归重新变绿。

流程：

1. 先跑历史 issue 回归基线：排除当前 issue test
2. 再跑当前 issue 的测试脚本，确认它真的在验证目标行为
3. 按 `docs/plan/current.md` 实现代码，并在完成后勾选步骤
4. 如果涉及敏感内容，先读 `docs/security.md`
5. 如果实现过程改变了架构边界，要同步更新 `docs/architecture.md` 并追加 `docs/decisions.md`
6. 跑完整 issue 回归套件
7. 全通过后，把状态推进到 Stage 4

这个阶段真正修改的是业务代码和测试，同时保证历史 issue 不被回归破坏。

### Stage 4: Delivery & Verification

目标：把“代码能跑”变成“可以交付”。

流程：

1. 再跑一次完整 issue 回归，作为最终 gate
2. 按 `docs/quality.md` 做人工自查
3. 创建可交付的本地 commit
4. 尝试 `git push` 和 `gh pr create`
5. 如果远端交付受网络、权限或宿主环境限制，可以降级为“本地交付 + 人工 handoff”
6. 更新 `docs/progress.md`
7. 归档 `docs/plan/current.md` 到 `docs/plan/archive/<issue_id>.md`
8. 清空并重置 `docs/plan/current.md`
9. 把对应 backlog 条目标为 `[x]`
10. 更新 `docs/stage.lock` 到 Stage 5

这里的关键不是“必须成功开 PR”，而是“必须形成可复现、可 handoff 的交付状态”。

### Stage 5: Reflection

目标：把本次 issue 中真正可复用的经验沉淀下来。

流程：

1. 必须创建 `docs/plan/archive/REFLECT-<issue_id>.md`
2. 回答三个固定问题：遇到了什么问题、是否产生新 wisdom、是否产生新 antipattern
3. 如有必要，追加 `docs/wisdom.md`
4. 如有必要，追加 `docs/antipatterns.md`
5. 如有必要，补充 `docs/decisions.md`、`docs/architecture.md`、`docs/conventions.md`
6. 更新 `docs/stage.lock` 到 Stage 6

这个阶段的产出不是功能，而是“下次做类似问题时不要重新踩坑”。

### Stage 6: Entropy Check

目标：检查代码和文档是否重新漂移。

流程：

1. 对比文档描述和代码现实是否一致
2. 如果只是文档落后，就只改文档
3. 如果发现代码和文档记录的意图冲突，就修代码并补测试
4. 检查 `docs/decisions.md` 中是否需要做 compaction
5. 如果只改文档，写回 `stage1/done/previous=stage6`，本次 run 结束
6. 如果改了代码，跳回 Stage 3，再走一遍实现到交付的闭环

因此，Stage 6 不是“收尾文书工作”，而是整个状态机里最后一道一致性检查。

## 这个模板的核心约束

- 单次 run 只做一个 issue。
- 每个 issue 都必须绑定一个 `issue_test/<issue_id>.sh`。
- 历史 issue tests 默认长期保留，不允许靠删除或弱化旧测试掩盖回归。
- 每次 `docs/stage.lock` 更新都必须单独 commit。
- 遇到 blocker 必须写 `docs/blockers.md` 并停止。
- 文档不是说明书，而是 agent 的运行输入。

如果你只想记一句话，可以记这一句：

> `init.sh` 负责把模板装进目标仓库，`stage.lock` 负责驱动状态机，`build_context.py` 负责喂上下文，`issue_test/*.sh` 负责把每个 issue 的验收变成可执行脚本。
