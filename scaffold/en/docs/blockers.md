# Blockers

> This document answers: Where is the agent stuck? What does a human need to do?
>
> When the agent encounters a problem it cannot resolve on its own, it writes here and stops. Humans clear the entry after resolving it.

## Record Template

```markdown
### B-00X Title
- Date: YYYY-MM-DD
- Blocked at Stage:
- Problem description:
- Attempted fixes:
  - Attempt 1: result
  - Attempt 2: result
- What the human needs to do:
```

## Current Blockers

(none)

## Maintenance Rules

1. After writing a blocker, the agent must stop — it must not work around the blocker.
2. Humans delete the entry after resolving it.
3. Stage 1 must check this file on startup; if unresolved entries exist, a new task must not begin.
