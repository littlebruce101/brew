# Safety Checks

Validation steps that must pass before merging any change.

## Automated checks (run locally before pushing)

- `brew style --fix --changed` — lint and auto-fix formatting
- `brew typecheck` — Sorbet type verification
- `brew tests --changed` — RSpec unit tests for changed files

## Manual checks

- Does the change do exactly what the PR description says?
- Are there any new network calls, file writes, or destructive operations?
- Does the change touch any security-sensitive paths (credentials, tokens, permissions)?

## Before force-push or branch reset

- Confirm the branch has no unreviewed work from others.
- Check that CI has run at least once on the current HEAD.
- Do not use `--no-verify` unless explicitly approved.
