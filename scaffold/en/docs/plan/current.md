# Current Plan

## Current Status

- No issue currently in progress.
- When starting a new task, the agent or a human will rewrite this file with a concrete task plan, and create `issue_test/<issue_id>.sh` first.

## Fields to Fill When Starting a New Task

1. Task name, source issue, start date, status
2. Test script path and coverage goal for the current issue
3. Step-by-step checkable execution steps
4. Verification records (must include at least the historical regression baseline and full regression result)

## Maintenance Notes

- This file records only the one issue currently in progress.
- The corresponding test script is always kept at `issue_test/<issue_id>.sh`; it remains in `issue_test/` after the task is complete.
- After completing a task, archive this file to `docs/plan/archive/`, then reset it to the "no issue in progress" state.
