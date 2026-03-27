# Conventions

> 本文档回答：代码长什么样？git 操作怎么做？
>
> 收录标准：本文档只收录**靠 agent 自觉遵守**的风格性约束。被 linter / CI 机械执行的结构性规则归 `architecture.md`。

## 命名规范（待填写）

- 文件名：`kebab-case` / `snake_case`（二选一并固定）
- 类名：`PascalCase`
- 变量和函数：`camelCase` 或 `snake_case`（与语言习惯一致）
- 常量：`UPPER_SNAKE_CASE`

## 函数契约（待填写）

1. 函数输入输出必须可预测，错误路径可测试。
2. 公共函数需声明参数、返回值、异常语义。
3. 禁止隐式全局状态修改。

## 错误处理模式（待填写）

- 错误表示方式：（异常 / Result 类型 / 错误码）
- 日志级别约定：
- 重试策略：

## Git 规范（待填写）

### Commit Message

- 格式：`<type>(<scope>): <subject>`
- type 枚举：`feat / fix / refactor / docs / test / chore`
- subject 语言：（中文 / 英文）

### Branch 命名

- 格式：`<type>/<issue-id>-<short-description>`
- 示例：`feat/42-add-user-auth`

### PR 规范

- 标题格式：与 commit message 一致
- 描述必填项：背景、方案、测试、风险

## 维护规则

1. 风格冲突时，以本文件为准。
2. 引入新模式前先补充本文件再推广。
3. 当某条规则被 linter 强制执行后，从本文件迁移到 `architecture.md`。
