# Conventions

> This document answers: What does code look like? How are git operations handled?
>
> Inclusion criteria: Only style-based constraints that **rely on agent self-discipline** belong here. Structural rules mechanically enforced by a linter or CI belong in `architecture.md`.

## Naming Conventions (to be filled)

- File names: `kebab-case` / `snake_case` (pick one and be consistent)
- Class names: `PascalCase`
- Variables and functions: `camelCase` or `snake_case` (follow language idiom)
- Constants: `UPPER_SNAKE_CASE`

## Function Contract (to be filled)

1. Function inputs and outputs must be predictable; error paths must be testable.
2. Public functions must declare parameters, return values, and exception semantics.
3. Implicit global state mutation is forbidden.

## Error Handling Pattern (to be filled)

- Error representation: (exceptions / Result type / error codes)
- Log level conventions:
- Retry strategy:

## Git Conventions (to be filled)

### Commit Message

- Format: `<type>(<scope>): <subject>`
- Type enum: `feat / fix / refactor / docs / test / chore`
- Subject language: (Chinese / English)

### Branch Naming

- Default format: `codex/<issue_id>`
- Example: `codex/42-add-user-auth`
- Teams may substitute their own prefix for `codex`, but must keep the one-issue-one-branch rule

### PR Conventions

- Title format: matches commit message format
- Required description fields: background, approach, testing, risks

## Maintenance Rules

1. When style conflicts arise, this document takes precedence.
2. Add a new pattern here before rolling it out.
3. Once a rule is enforced by a linter, migrate it to `architecture.md`.
