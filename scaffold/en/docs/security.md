# Security

> This document answers: What must not be touched? What requires extra care?

## Sensitive Information (to be filled)

| Type | Example | Storage | Forbidden Action |
| --- | --- | --- | --- |
| API Key | `OPENAI_API_KEY` | Env var / Secret Manager | Commit to repository |
| Database credentials | `DB_PASSWORD` | Env var / Vault | Print to logs |
| Private key | `PRIVATE_KEY` | Key management service | Send to third-party IM |

## Protected Paths (to be filled)

- `infra/`
- `.github/workflows/`
- `secrets/` (if present)

## Authentication & Authorization (to be filled)

- Authentication method:
- Token lifecycle:
- Permission model:

## Security Change Rules

1. Changes touching authentication, permissions, or credentials must be labeled `security-impact` in the PR.
2. All sensitive values must be injected via environment — hardcoding is forbidden.
3. On discovering a leak, rotate the credential first, then fix the code and documentation.
