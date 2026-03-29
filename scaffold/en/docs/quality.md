# Quality

> This document answers: What does "done" mean? How do you verify it?

## Definition of Done

### Code Quality

- [ ] Implementation matches `docs/plan/current.md`
- [ ] No obvious duplicate logic or dead code
- [ ] Changes touching architecture/security/decision boundaries are reflected in the corresponding documents

### Issue Regression Quality

- [ ] The corresponding `issue_test/<issue_id>.sh` exists and covers the target behavior
- [ ] Historical regression baseline was run before implementation: `bash scripts/run_issue_tests.sh --exclude issue_test/<issue_id>.sh`
- [ ] Full regression was run before committing: `bash scripts/run_issue_tests.sh`
- [ ] If any historical `issue_test/*.sh` was modified, the reason and impact are recorded

### Documentation Sync

- [ ] Changes are reflected in relevant documents
- [ ] Important decisions are written to `docs/decisions.md`
- [ ] `docs/progress.md` reflects the current state
- [ ] Delivery status is recorded: archive contains a PR URL and Stage 6 completed merge / auto-merge, or a "local delivery / merge handoff" entry is present

### Security

- [ ] No sensitive information leaked
- [ ] Authentication/authorization changes have been reviewed (if applicable)
- [ ] If a PR exists, change risks are noted in the PR description

## issue_test Mechanism (fixed)

- Directory: `issue_test/`
- Naming: `issue_test/<issue_id>.sh`
- Runner: `bash scripts/run_issue_tests.sh`
- History policy: scripts are retained indefinitely; all subsequent issues must pass all of them

## Project-Native Checks (to be filled)

- Unit/integration test framework:
- Static analysis tool:
- Other pre-delivery commands:

## Common Verification Commands

```bash
# Run all issue regressions
bash scripts/run_issue_tests.sh

# Run historical regression baseline before implementing the current issue
bash scripts/run_issue_tests.sh --exclude issue_test/<issue_id>.sh

# Project-native check (if any)
<command>
```

## Failure Handling

1. Fix deterministic issue regression failures first, then address flaky scenarios.
2. Passing regressions by deleting, skipping, or weakening historical `issue_test/*.sh` is forbidden.
3. Temporary skips must include a recorded reason and a recovery plan.

## Maintenance Rules

1. New quality gates must be written here before being added to CI.
2. This document is the mandatory pre-commit self-review checklist and must not be weakened.
3. Every issue must add or bind to a reproducible `issue_test/<issue_id>.sh`.
