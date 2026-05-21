# Assistant Configuration

Settings and constraints for AI assistants working in this repository.

## Scope

- Work only on the task described in the current issue or PR.
- Do not refactor, rename, or reorganise code outside the immediate change.
- Do not add features that were not requested.

## Required tools before committing

```
brew style --fix --changed
brew typecheck
brew tests --changed
```

## Files that must not be edited directly

- `completions/` — regenerate with `brew generate-man-completions`
- `manpages/` — regenerate with `brew generate-man-completions`

## Commit message format

- First line: short imperative description (under 72 characters)
- Body (if needed): explain the why, not the what
- No co-author lines, no AI attribution in the message

## When to stop and ask

- The change requires modifying more than 5 files unexpectedly.
- The task description is ambiguous about intended behaviour.
- A test is failing for a reason unrelated to the current change.
