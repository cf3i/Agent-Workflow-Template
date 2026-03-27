# Agent Workflow

每个 Stage 完成后，必须先完成该 Stage 的 Exit Checklist，然后重新阅读本文件判断下一步跳转。

---

## Stage 1：Context Loading

> 回答：项目现在什么状态？我有没有正在进行的任务？

读取顺序：

1. `docs/overview.md` — 了解项目是什么
2. `docs/progress.md` — 了解项目当前状态
3. `docs/blockers.md` — 是否有未解决的阻塞（如有，优先处理或等待人类指示）
4. `docs/plan/current.md` — 是否有正在进行的 issue

判断：

- `blockers.md` 有未解决条目 → 停止，通知人类
- `current.md` 有未完成的步骤 → 进入 **Stage 3**（继续实现）
- `current.md` 为空或已完成 → 进入 **Stage 2**（规划新任务）

### Exit Checklist

- [ ] 已读完 overview.md、progress.md、blockers.md、plan/current.md
- [ ] 已明确下一步进入哪个 Stage

### Failure Path

- 无法判断项目状态（文档缺失或矛盾）→ 停止，通知人类

---

## Stage 2：Task Planning

> 回答：下一个 issue 是什么？怎么拆解执行？

执行流程：

1. 读取 `docs/plan/backlog.md`，选择一个 `- [ ]` 任务
2. 分析需求，考虑实现方案
3. 将执行步骤写入 `docs/plan/current.md`（使用 checkbox 格式）
4. 如果涉及重要技术选型，先记录到 `docs/decisions.md`

### Exit Checklist

- [ ] `docs/plan/current.md` 已写入清晰的、可逐步勾选的执行计划
- [ ] 涉及的技术决策已追加到 `docs/decisions.md`

### Failure Path

- backlog 为空 → 停止，通知人类补充任务
- 需求不清晰无法拆解 → 停止，通知人类澄清

→ 全部通过，进入 **Stage 3**。

---

## Stage 3：Implementation

> 回答：代码写完了吗？能通过验证吗？

读取：`docs/architecture.md` + `docs/conventions.md`

执行循环：

1. 按 `docs/plan/current.md` 的步骤实现代码
2. 运行 lint → 有报错 → 修复 → 重跑，直到零报错
3. 运行 tests → 有失败 → 修复 → 重跑，直到全部通过
4. 每完成一个步骤，在 `docs/plan/current.md` 中勾选

涉及敏感内容时：读取 `docs/security.md`。

### Exit Checklist

- [ ] `docs/plan/current.md` 中所有实现步骤已勾选
- [ ] `./scripts/check_lint.sh` 通过（附输出）
- [ ] `./scripts/check_tests.sh` 通过（附输出）

### Failure Path

- 同一个 lint/test 错误修复超过 3 次仍未解决 → 写入 `docs/blockers.md`，停止，通知人类
- 不确定实现方向是否正确 → 停止，通知人类确认

→ 全部通过，进入 **Stage 4**。

---

## Stage 4：PR & Verification

> 回答：能交付了吗？

执行流程：

1. 运行 `./scripts/check_quality.sh`，确认全部通过
2. 逐条对照 `docs/quality.md` 中脚本无法覆盖的条目，人工自查
3. 执行 git 操作（具体规范见 `docs/conventions.md`）：
   - `git add` 相关文件
   - `git commit`（message 格式见 conventions）
   - `git push`
4. 开 PR（描述格式见 conventions）

### Exit Checklist

- [ ] `./scripts/check_quality.sh` 通过（附输出）
- [ ] `docs/quality.md` 人工自查条目全部通过
- [ ] git commit + push 完成
- [ ] PR 已创建
- [ ] `docs/progress.md` 已更新（反映新完成的功能 / 修复的问题）
- [ ] `docs/plan/current.md` 已归档到 `docs/plan/archive/XXX-feature-name.md`
- [ ] `docs/plan/current.md` 已清空重置
- [ ] `docs/plan/backlog.md` 中对应任务已标记 `[x]`

### Failure Path

- quality 自查不通过 → 回到 **Stage 3** 修复
- git push 失败 → 检查原因，修复后重试；3 次失败 → 写入 `docs/blockers.md`，停止

→ 全部通过，进入 **Stage 5**。

---

## Stage 5：Reflection

> 回答：这次学到了什么？有什么可以沉淀为规则？

执行流程：

1. 这次遇到了什么重复出现的问题？→ 能否加一条 linter 规则让它不再发生？
2. 做了什么重要的设计决策？→ 追加到 `docs/decisions.md`
3. 架构边界有变化？→ 更新 `docs/architecture.md`
4. 代码规范或 git 规范有变化？→ 更新 `docs/conventions.md`

### Exit Checklist

- [ ] 新的设计决策已追加到 `docs/decisions.md`（如有）
- [ ] `docs/architecture.md` 或 `docs/conventions.md` 已更新（如有变化）
- [ ] 新的 linter 规则已添加（如有）

### Failure Path

- 无（Reflection 是尽力而为的，没有硬性失败条件）

→ 完成后进入 **Stage 6** 或回到 **Stage 1**。

---

## Stage 6：Entropy Check（定期执行）

> 回答：文档和代码还同步吗？

执行流程：

1. 对比 `docs/` 与代码实现，找出所有偏差
2. 默认更新文档以匹配代码
3. 若确认代码与文档记录的意图矛盾，修代码并补测试
4. 检查 `docs/decisions.md`：如果 `Superseded` 条目过多，执行 compaction（提炼当前有效决策摘要到文件顶部）

### Exit Checklist

- [ ] 文档与代码一致
- [ ] `docs/decisions.md` 摘要已更新（如执行了 compaction）

### Failure Path

- 发现文档和代码的矛盾无法判断谁对 → 写入 `docs/blockers.md`，停止，通知人类

→ 全部通过，回到 **Stage 1**。
