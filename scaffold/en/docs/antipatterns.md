# Antipatterns

> Approaches validated as failure-causing across historical issues.
>
> Record "why this type of approach fails", not "where it got stuck" (that belongs in blockers.md).

## Maintenance Rules

1. Write only during Stage 5 (Reflection); appending in other Stages is forbidden.
2. Every entry must cite a blocker number or `issue_id` — hypothetical warnings are not allowed.
3. The failure signal (early symptom) field is required — it lets the agent recognize failure before it happens.
4. The correct alternative field is required — "don't do X" alone is not enough; a concrete alternative must be given.
5. Append only; modifying historical entries is forbidden.

## Entry Template

```markdown
## A-00X Title

- Source: <B-00X blocker> / <issue_id>
- Failure signal (early symptom):
- Root cause:
- Correct alternative:
```

## Antipattern Records

(none yet — accumulated through Stage 5 Reflection over time)
