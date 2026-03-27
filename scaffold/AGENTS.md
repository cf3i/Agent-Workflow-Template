# AGENTS.md

## Workflow 入口

在执行任何任务前，先阅读并遵循 [docs/workflow.md](docs/workflow.md)。

## 文档索引

| 文档 | 职责 |
|------|------|
| [docs/workflow.md](docs/workflow.md) | 6 Stage 状态机：何时做什么 + Exit Checklist + Failure Path |
| [docs/overview.md](docs/overview.md) | 项目目标与范围 |
| [docs/architecture.md](docs/architecture.md) | 模块划分 + 依赖边界（工具强制执行） |
| [docs/conventions.md](docs/conventions.md) | 命名 + 代码风格 + git 规范（agent 自觉） |
| [docs/decisions.md](docs/decisions.md) | 时间线追加式设计决策日志（带 compaction） |
| [docs/quality.md](docs/quality.md) | Definition of Done + 验证方法 |
| [docs/security.md](docs/security.md) | 敏感信息 + 安全边界 |
| [docs/progress.md](docs/progress.md) | 项目快照 |
| [docs/blockers.md](docs/blockers.md) | agent 阻塞记录（人类介入点） |
| [docs/plan/backlog.md](docs/plan/backlog.md) | issue 队列 |
| [docs/plan/current.md](docs/plan/current.md) | 当前 issue 执行步骤 |

## 全局硬规则

1. Stage 判断不明确时，先按 `docs/workflow.md` 自行判断；仍不明确时必须先问 user，澄清前不得进行代码修改或高风险操作。
2. 架构边界违规必须先修复（由 lint/CI 拦截）。
3. 开发前先写 `docs/plan/current.md`，开发中持续勾选。
4. 提交前必须运行 `./scripts/check_quality.sh` 并确认 PASS。
5. 每个 Stage 结束前必须完成该 Stage 的 Exit Checklist，不得跳过。
6. 涉及凭据、认证、敏感文件前先读 `docs/security.md`。
7. 重要技术取舍必须追加到 `docs/decisions.md`（禁止覆写历史条目）。
8. 遇到无法自行解决的问题，写入 `docs/blockers.md` 后停止，不得绕过阻塞继续执行。
