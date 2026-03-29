# Backlog

> All pending issues, sorted by priority. Use `- [ ]` / `- [x]` to track status.

## Entry Writing Guidelines

Every backlog entry should answer at least 4 questions:

1. What result is being delivered?
2. What is the scope of impact?
3. How is completion verified?
4. Why does this task exist?

Mapped to fixed fields:

- Goal: what needs to be accomplished this time
- Scope: what is changed, what is affected
- Acceptance: what result counts as done — ideally maps to `issue_test/<issue_id>.sh`
- Source: where this task came from (e.g. bug, user feedback, code comment, product requirement, documentation gap)

## Recommended Templates

### Minimal Version

Suitable for most day-to-day tasks. Keep it one line for easy maintenance.

```md
- [ ] <task title> (goal: ...; scope: ...; acceptance: ...; source: ...)
```

Example:

```md
- [ ] Add dry-run preview to init.sh (goal: see which template files will be overwritten before initializing; scope: init.sh output layer; acceptance: running `init.sh --skip-fill --non-interactive` first shows the list of files to be written; source: risk-confirmation requirement before initialization)
```

### Expanded Version

Suitable for cross-module tasks, those with many dependencies, or those with more than one acceptance criterion.

```md
- [ ] <task title>
  - Goal: ...
  - Scope: ...
  - Acceptance: ...
  - Source: ...
  - Non-goals: (optional)
  - Risks/dependencies: (optional)
```

## Writing Rules

1. Write "results" in the title, not "process".
2. Backlog defines only "what to do", not "how to do it" — specific execution steps go in `docs/plan/current.md`.
3. Each entry should correspond to one closeable issue; split overly large tasks first.
4. "Acceptance" must be deterministic and ideally convertible to an issue test — not "looks about right".
5. When information is incomplete, write at least "goal + scope + source" to avoid Stage 2 being unable to select a task.
6. If a task exceeds the current scope in `docs/overview.md`, update the scope definition first, then proceed.

## Priority Definitions

- `P0`: Blocks core functionality, production availability, or a critical delivery
- `P1`: Important features, experience improvements, critical efficiency gains
- `P2`: Technical debt, documentation, cleanup, low-risk optimization

## Maintenance Notes

- Humans and agents may both add to the backlog.
- Stage 2 selects one `- [ ]` entry from here and generates an `issue_id`, `issue_test/<issue_id>.sh`, and `docs/plan/current.md`.
- Stage 4 marks the corresponding entry `- [x]` after completing delivery.

## P0 (Highest Priority)

- [ ] (to be filled)

## P1

- [ ] (to be filled)

## P2

- [ ] (to be filled)
