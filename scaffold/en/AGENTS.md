# AGENTS.md

## Startup Protocol

On every startup, execute the following loop in order. Do not skip steps or change their order.

> Prerequisite: `docs/stage.lock` must already exist. It is a bootstrap file generated during initialization. If it is missing, the repository has not been fully initialized or the file is corrupted — a human must re-run `init.sh` or restore it manually.

**Step 1: Confirm Current Stage**

Read `docs/stage.lock` and retrieve the `current` field.

**Step 2: Call build_context.py**

> Prerequisite: `build_context.py` requires PyYAML. If not installed, run:
> ```bash
> python3 -m pip install pyyaml
> ```

```bash
python scripts/build_context.py --stage <current>
```

On exit 0, the script outputs the list of files to load for the current Stage — read all of them.
On exit 1, a required file is missing — do not continue. Write to `docs/blockers.md` and stop.

**Step 3: Execute**

After reading all files, follow the instructions in `docs/workflow/<current>.md`.

**Step 4: Decide Whether to Continue**

After each Stage, re-read `docs/stage.lock`:

- If `status == failed` → **Stop**, wait for a human to handle the blocker
- If `current == stage1` and `status == done` and `previous == stage6` → **Stop successfully**
  - This means one complete issue loop has finished
  - Do not pick the next backlog task in the same run
- Otherwise → Return to Step 1 and continue to the next Stage

---

## Document Index

| Document | Responsibility |
|------|------|
| `docs/workflow/stage1.md` | Stage 1 instructions: Context Loading / Router |
| `docs/workflow/stage2.md` | Stage 2 instructions: Task Planning |
| `docs/workflow/stage3.md` | Stage 3 instructions: Implementation |
| `docs/workflow/stage4.md` | Stage 4 instructions: Delivery & Verification |
| `docs/workflow/stage5.md` | Stage 5 instructions: Reflection |
| `docs/workflow/stage6.md` | Stage 6 instructions: Entropy Check |
| `docs/stage.lock` | Global state register: current Stage + status + meta |
| `docs/overview.md` | Project goals and scope |
| `docs/architecture.md` | Module boundaries and dependency rules |
| `docs/conventions.md` | Naming, code style, and git conventions |
| `docs/decisions.md` | Append-only design decision log |
| `docs/quality.md` | Definition of Done and verification methods |
| `docs/security.md` | Sensitive data and security boundaries |
| `docs/progress.md` | Project snapshot |
| `docs/blockers.md` | Agent blockers (human intervention points) |
| `docs/wisdom.md` | Reusable patterns validated across issues |
| `docs/antipatterns.md` | Failure patterns validated across issues |
| `docs/plan/backlog.md` | Issue queue |
| `docs/plan/current.md` | Execution steps for the current issue |
| `issue_test/README.md` | Issue-level regression script conventions |
| `scripts/run_issue_tests.sh` | Cumulative regression runner for `issue_test/*.sh` |

---

## Global Hard Rules

1. The three-step startup protocol must execute; it cannot be skipped.
2. When Stage routing is unclear, use `stage.lock` as the source of truth — do not guess.
3. Every Stage must complete its Exit Checklist before proceeding; it cannot be skipped.
4. Every `stage.lock` update must be a separate git commit, not mixed with business code. Format: `chore(stage): <from> → <to> [<reason>]`, e.g. `chore(stage): stage2 → stage3 [done]` or `chore(stage): stage3 [failed]`.
5. Architecture boundary violations must be fixed first. If `docs/architecture.md` says a rule is "enforced by static check or CI", use the tool output as the source of truth. If no automated check is configured yet, the agent self-enforces and records the constraint as manually enforced in `docs/decisions.md`.
6. Read `docs/security.md` before touching credentials, authentication, or sensitive files.
7. Important technical trade-offs must be appended to `docs/decisions.md` (overwriting history is forbidden).
8. Before entering Stage 3, the corresponding `issue_test/<meta.issue_id>.sh` must exist. Subsequent issues must not delete, skip, or weaken historical issue tests to avoid regressions.
9. A single run may complete only one issue loop. If `current: stage1`, `status: done`, `previous: stage6` is detected, stop — do not pick a new issue in the same run.
10. When an unresolvable problem is encountered, write to `docs/blockers.md` and stop. Do not bypass the blocker.
11. Stage 4 creates or updates the PR; it does not perform the final merge. Stage 6 handles the final merge / auto-merge. If remote delivery in Stage 4 or Stage 6 is blocked by network, permissions, or environment constraints, it may fall back to "local delivery + manual handoff", but the local commit hash, failed command, and required human next steps must be written into the archive record.
