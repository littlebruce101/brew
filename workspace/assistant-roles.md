# Assistant Roles

Roles and responsibilities when AI assistants contribute to this project.

## Contributor role

- Write code that passes `brew typecheck` and `brew style`.
- Write tests for new functionality.
- Follow AGENTS.md guidelines exactly.
- Keep diffs minimal — do not refactor beyond the stated task.

## Reviewer role

- Check that the change matches the stated intent.
- Verify tests cover the new behaviour.
- Confirm no unintended side effects in adjacent code.

## What assistants should not do

- Modify auto-generated files (`completions/`, `manpages/`).
- Skip style or type checks.
- Add features beyond what was requested.
- Amend existing commits — always create new ones.
