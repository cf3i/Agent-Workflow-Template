# Issue Tests

Every issue must have a corresponding independent regression script placed in the `issue_test/` directory.

## Naming Convention

- File name: `issue_test/<issue_id>.sh`
- `issue_id` must match `docs/plan/current.md` and `docs/plan/archive/<issue_id>.md`

## Contract

1. Every issue must add or explicitly bind to a test script that covers the target behavior or deliverable of that issue.
2. The test script must be executable from the repository root and express results via exit codes: exit 0 = PASS, non-zero = FAIL.
3. On failure, the test script must output sufficient diagnostic information — at minimum: what was expected, what actually happened, and which command or check failed. Returning only a non-zero exit code without context is not acceptable.
4. The test script must be deterministic and must not depend on human interaction. If it depends on external services or special environments, prerequisites must be documented inside the script with a local alternative where possible.
5. The test script may invoke existing project test commands, but must not merely check "does the command exist" — it must provide a reproducible assertion about the target behavior of the current issue.
6. Historical `issue_test/*.sh` are retained permanently by default. All subsequent issues must pass all of them. Hiding regressions by deleting, skipping, or weakening old scripts is forbidden.
7. If a historical issue test must be modified, the reason must be recorded in `docs/plan/current.md`. If the modification changes the long-term verification semantics, it must also be appended to `docs/decisions.md`.

## Common Commands

```bash
# Run all issue regression scripts
bash scripts/run_issue_tests.sh

# Run historical regression baseline before implementing the current issue
bash scripts/run_issue_tests.sh --exclude issue_test/<issue_id>.sh
```

## Minimal Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Verify the target behavior of <issue_id>
# On failure: print expected value, actual result, and relevant command, then exit non-zero
```
