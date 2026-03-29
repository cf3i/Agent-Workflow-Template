# Decisions

> This document answers: Why was this decided the way it was?
>
> Append in chronological order — do not organize by topic. Historical entries are immutable.

## Current Effective Decision Summary

> This area is maintained by Stage 6 (Entropy Check). When too many Superseded entries accumulate, the agent distills all Accepted decisions into one-line summaries and places them here. Agents only need to read this summary in daily use.

(automatically maintained by Entropy Check after project initialization)

## Maintenance Rules (mandatory)

1. **Append only — never modify** historical entry content.
2. If a decision becomes obsolete, add a new "superseding decision" referencing the old number, and mark the old entry's status as `Superseded by D-0XX`.
3. Every entry must include: background, decision, rationale, and rejected alternatives.
4. **Compaction rule**: When Superseded entries exceed 30% of total entries, perform compaction in Stage 6 — distill all Accepted entries into one-line summaries and update the "Current Effective Decision Summary" area. The history area remains unchanged.

## Entry Template

```markdown
## D-00X Title
- Date: YYYY-MM-DD
- Status: Proposed | Accepted | Superseded by D-0XX
- Background:
- Decision:
- Rationale:
- Rejected alternatives:
  - Option A: reason for rejection
  - Option B: reason for rejection
- Impact:
```

## Decision Records

## D-001 Initialize Agent Workflow documentation system
- Date: __INIT_DATE__
- Status: Accepted
- Background: __INIT_BACKGROUND__
- Decision: Adopt the Agent Workflow Template structure: AGENTS.md + docs/ + issue_test/ + scripts/.
- Rationale: Document-driven workflow architecture where each document has a single, decoupled responsibility. The state machine provides clear Stage transition logic. issue_test/ + scripts/run_issue_tests.sh provides deterministic cumulative regression checks by issue. build_context.py enforces that the agent executes under the correct context.
- Rejected alternatives:
  - Pure prompt constraints: lacks persistence and auditable process documentation
  - Single README carrying all rules: hard to maintain, cannot be structurally referenced
- Impact: All subsequent agent development follows this documentation system. stage.lock records global state, build_context.py mechanically assembles context, and issue_test/ continuously accumulates historical regression scripts.
