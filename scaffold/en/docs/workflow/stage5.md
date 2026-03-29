# Stage 5 — Reflection

> Answers: What was learned? What can be crystallized into rules?

## Execution Steps

### Step 1: Write the REFLECT file (hard constraint — cannot be skipped)

Create `docs/plan/archive/REFLECT-<meta.issue_id>.md`, which must contain the following three required answers:

```markdown
# REFLECT-<issue-id>

## 1. Problems encountered in this issue
<!-- State clearly; "none" is acceptable, but the field must not be empty -->

## 2. Is there a new wisdom entry?
<!-- Give a conclusion (yes/no) and reason -->
<!-- If yes: describe the pattern; it will be written to wisdom.md in Step 2 -->

## 3. Is there a new antipattern entry?
<!-- Give a conclusion (yes/no) and reason -->
<!-- If yes: describe the failure pattern; it will be written to antipatterns.md in Step 3 -->
```

### Step 2: Update wisdom.md (if applicable)

If Step 1 identified a new reusable success pattern, append to `docs/wisdom.md`:

- Must include the source `issue_id`
- Must include the applicable scenario
- Must include a counter-example (when not applicable)

### Step 3: Update antipatterns.md (if applicable)

If Step 1 identified a new failure pattern, append to `docs/antipatterns.md`:

- Must include the source blocker or `issue_id`
- Must include the failure signal (early symptom)
- Must include the correct alternative approach

### Step 4: Update other documents (if changes occurred)

- Important design decisions → append to `docs/decisions.md`
- Architecture boundary changes → update `docs/architecture.md`
- Convention changes → update `docs/conventions.md`

### Step 5: Update stage.lock

```yaml
current: stage6
status: in_progress
previous: stage5
```

## Exit Checklist

- [ ] `docs/plan/archive/REFLECT-<meta.issue_id>.md` created (must exist)
- [ ] REFLECT file contains all three required answers, with no empty fields
- [ ] `docs/wisdom.md` handled (appended or explicitly written "none" in REFLECT)
- [ ] `docs/antipatterns.md` handled (appended or explicitly written "none" in REFLECT)
- [ ] `stage.lock` updated (current: stage6)
- [ ] `stage.lock` update committed separately (format: `chore(stage): stage5 → stage6 [done]`)

## Failure Path

- REFLECT file does not exist or is missing required answers → cannot enter Stage 6; complete it and re-check
- Update stage.lock (status: failed), stop, notify human
