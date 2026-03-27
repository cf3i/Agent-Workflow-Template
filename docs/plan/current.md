# Current Plan

## 任务元信息

- 任务名称：修复模板在 adopt 模式下暴露出的规则冲突与误导性文档
- 来源 issue：BacktrackKV 重跑后的 docs review 发现模板层级冲突
- 开始日期：2026-03-27
- 状态：In Progress

## 执行步骤

- [x] 审查 BacktrackKV docs review，识别出属于模板而非目标仓库自身的问题
- [x] 将“主路径功能 sanity check”补充为模板的最低功能正确性验证要求
- [x] 将 `init.sh` 调整为默认交互式向导，并保留 `--non-interactive` 与现有 flags
- [ ] 修正 `scaffold/AGENTS.md` 与 `scaffold/docs/workflow.md`，避免在未配置质量门/架构检查时仍声称由 lint/CI 拦截
- [ ] 修正 `scaffold/docs/decisions.md` 的维护规则，消除“只追加”与“回写旧状态”的矛盾
- [ ] 调整 `init.sh` 的生成 prompt 与本地审计，使其更好提示子模块未初始化、占位质量门和 adopt 语义
- [ ] 重新在 BacktrackKV 中从头执行初始化，验证新的模板不再产出同类冲突
- [ ] 记录决策并汇总残余问题

## 验证记录

- [x] `bash -n init.sh` 通过
- [x] `init.sh --skip-fill` 与 `init.sh --skip-fill --resume` 本地烟测通过
- [x] `codex` stub 回归通过：确认使用 `codex exec` 而非错误的 `-p`，且非 Git 仓库会追加 `--skip-git-repo-check`
- [x] `--single-call` 的 `codex` stub 回归通过：单次初始化只触发 1 次 `codex exec`，并保留最终审计报告
- [x] 默认模式与 `--ultra` 的命令分支验证
- [x] `--model` 与 `--reasoning-effort` 参数透传验证
- [x] 静态 scaffold 已恢复为空白模板，不再复制当前仓库的 `docs/plan/current.md` 和 `docs/decisions.md` 运行状态
- [x] 新增 adopt / greenfield 分支验证
- [x] 独立 docs review 触发与结果校验验证
- [x] BacktrackKV 重跑验证通过
- [x] 交互式向导烟测通过：TTY 下可选择 `adopt + skip-fill`，并能用 `--resume` 读取保存配置继续执行
- [ ] 模板冲突修复后 BacktrackKV docs review 二次验证通过
- [ ] `./scripts/check_quality.sh` 通过

## 备注

- `./scripts/check_quality.sh` 当前失败，原因是仓库内的 `scripts/check_lint.sh` 与 `scripts/check_tests.sh` 仍保留模板占位符，并非本次 `init.sh` 改动引入。
- 本轮完成后需要同步检查 `scaffold/` 中的模板语义是否仍偏向 greenfield。
- `BacktrackKV` 用新脚本从头重跑已完成，并额外产出 `docs-review.md`；该报告识别出了若干 repo 真实问题，例如假阳性质量门、未初始化子模块与文档事实不符、以及决策维护规则冲突。
- 这轮只修模板导致的误导；BacktrackKV 自身仓库事实问题仍可能继续出现在 review 中。
- 完成后由 agent 归档到 `docs/plan/archive/`，然后清空本文件。
