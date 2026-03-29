# Architecture

> This document answers: What lives where? What may depend on what?
>
> Inclusion criteria: Only structural constraints **mechanically enforced by a linter or CI** belong here. Style-based rules that rely on agent self-discipline belong in `conventions.md`.

## Layer Model (to be filled)

| Layer | Responsibility | May Depend On | Must Not Depend On |
| --- | --- | --- | --- |
| `interface` | External API/CLI | `application` | `infrastructure` |
| `application` | Use-case orchestration | `domain` | `interface` |
| `domain` | Business rules | none or `shared` | `infrastructure` |
| `infrastructure` | DB/HTTP/queue impl | `domain` | `interface` |

## Directory Structure (to be filled)

```
src/
├── interface/
├── application/
├── domain/
└── infrastructure/
```

## Import Boundary Rules (to be filled)

1. `interface` may only call `application`.
2. `application` must not depend on external SDKs directly — use interface abstractions.
3. `domain` must not contain IO, side effects, or framework types.
4. `infrastructure` must not import `interface` in reverse.

## Enforcement (to be filled)

- Static analysis tool:
- Rule file location:
- CI lint command:

## Maintenance Rules

1. Record a decision in `docs/decisions.md` before changing a boundary.
2. Lint rules must be updated in sync with boundary changes.
3. An architecture change is not complete until the lint rules are updated.
