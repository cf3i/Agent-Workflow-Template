# Architecture

> 本文档回答：什么东西在哪里？什么能依赖什么？
>
> 收录标准：本文档只收录**被 linter / CI 机械执行**的结构性约束。靠 agent 自觉遵守的风格性规则归 `conventions.md`。

## 分层模型（待填写）

| 层级 | 职责 | 允许依赖 | 禁止依赖 |
| --- | --- | --- | --- |
| `interface` | 对外 API/CLI | `application` | `infrastructure` |
| `application` | 用例编排 | `domain` | `interface` |
| `domain` | 业务规则 | 无或 `shared` | `infrastructure` |
| `infrastructure` | DB/HTTP/队列实现 | `domain` | `interface` |

## 目录结构（待填写）

```
src/
├── interface/
├── application/
├── domain/
└── infrastructure/
```

## Import Boundary 规则（待填写）

1. `interface` 只调用 `application`。
2. `application` 不得直接依赖外部 SDK，需通过接口抽象。
3. `domain` 禁止出现 IO、副作用和框架类型。
4. `infrastructure` 不得反向 import `interface`。

## 执行方式（待填写）

- 静态检查工具：
- 规则文件位置：
- CI 校验命令：

## 维护规则

1. 修改边界前先记录决策到 `docs/decisions.md`。
2. 边界变化必须同步更新 lint 规则。
3. lint 规则未更新前，不算架构更新完成。
