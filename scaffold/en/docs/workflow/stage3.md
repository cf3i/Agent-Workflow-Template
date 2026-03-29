# Stage 3 — Implementation

> Answers: Is the code written? Does it pass verification?

## Execution Steps

### Step 1: Run historical issue regression baseline

```bash
bash scripts/run_issue_tests.sh --exclude issue_test/<meta.issue_id>.sh
```

- FAIL → Fix the existing regression first, then continue with the current issue
- Same error not resolved after 3 fix attempts → enter **Failure Path A**

### Step 2: Run the current issue test script to confirm baseline

```bash
bash issue_test/<meta.issue_id>.sh
```

- If the issue represents new or fixed behavior, the ideal result is usually "not yet passing" or a clear demonstration of the missing behavior
- If the issue is refactoring, cleanup, or a non-behavioral change, the script may pass before implementation — but you must be able to explain what invariant it is protecting
- If the script fails but does not provide sufficient diagnostic info, fix the test output first, then continue
- If the script result clearly does not match the issue goal (e.g. should fail but passes and there is no visible target-behavior assertion) → fix the test script first, then continue
- Cannot determine whether the script is valid → enter **Failure Path B**

### Step 3: Implement code

Implement step by step following `docs/plan/current.md`, checking off each step immediately after completion (`- [x]`).

When touching sensitive content (authentication, credentials, permissions), read `docs/security.md` first.

If during implementation you discover that architecture boundaries need adjustment (new modules, dependency changes, layer responsibility changes):

1. Update `docs/architecture.md` immediately — do not wait until Stage 6
2. Append a decision to `docs/decisions.md` explaining why the adjustment is needed
3. If the change involves lint rules, update the corresponding rule file at the same time

### Step 4: Run the full issue regression suite

```bash
bash scripts/run_issue_tests.sh
```

- FAIL → Fix and re-run until all pass
- Same error not resolved after 3 fix attempts → enter **Failure Path A**

### Step 5: Update stage.lock

```yaml
current: stage4
status: in_progress
previous: stage3
```

## Exit Checklist

- [ ] All steps in `docs/plan/current.md` are checked
- [ ] `bash scripts/run_issue_tests.sh --exclude issue_test/<meta.issue_id>.sh` passed
- [ ] `issue_test/<meta.issue_id>.sh` was executed before implementation; result matches the issue goal and produces sufficient diagnostic info on failure
- [ ] When architecture boundaries changed, `docs/architecture.md` was updated and decisions.md was appended
- [ ] `bash scripts/run_issue_tests.sh` outputs `ISSUE TESTS: PASS`
- [ ] `stage.lock` updated (current: stage4)
- [ ] `stage.lock` update committed separately (format: `chore(stage): stage3 → stage4 [done]`)

## Failure Path

### Failure Path A: Same error not resolved after 3 fix attempts

- Write to `docs/blockers.md`, clearly recording:
  - Fix approaches already attempted
  - Most recent failed command and error summary
  - Questions the human needs to answer
- Update stage.lock (status: failed), stop, notify human

### Failure Path B: Cannot determine whether the current issue test is valid

Write to `docs/blockers.md`, update stage.lock (status: failed), stop, ask human to confirm.
