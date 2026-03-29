# Stage 1 — Context Loading / Router

> Answers: Where should I go right now?

## Execution Steps

Execute in order; no steps may be skipped.

### Step 1: Read stage.lock — route first

Read `docs/stage.lock` and check the `status` field:

- `status == failed` → **Stop, notify human** (previous execution failed; human intervention required)
- `current == stage1 && status == done && previous == stage6` → **Stop this run successfully**
  - A complete issue loop just finished and returned from Stage 6 to Stage 1
  - Do not pick the next backlog task in the same run
- `status == in_progress` → **Jump directly to the Stage specified by `stage.lock.current`; do not continue evaluating below**
- `status == done` → Continue to Step 2

### Step 2: Check blockers (only when status == done)

Read `docs/blockers.md`:

- Unresolved entries exist → **Stop, notify human** (blockers must be resolved first)
- No unresolved entries → Continue to Step 3

### Step 3: Check current task status (only when status == done)

Read `docs/plan/current.md`:

- Has unchecked steps (unchecked `- [ ]` items exist) → Go to **Stage 3**
- Empty or all steps completed → Go to **Stage 2**

## Exit Checklist

- [ ] `stage.lock` has been read
- [ ] Determined whether this run is "stop successfully" or "continue routing"
- [ ] If continuing: `stage.lock` updated (current points to next Stage, status: in_progress)
- [ ] If continuing: `stage.lock` update committed separately (format: `chore(stage): stage1 → <next> [done]`)
- [ ] If stopping successfully: confirmed `current: stage1`, `status: done`, `previous: stage6`

## Failure Path

- `stage.lock` file does not exist → Stop, notify human to run `init.sh` or restore the default `stage.lock`
- `status == failed` → Stop, notify human; do not modify status on your own
- `blockers.md` has unresolved entries → Stop, notify human
