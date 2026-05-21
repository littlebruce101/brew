# Consistency Checks

Checks to catch drift before it becomes technical debt.

## Code consistency

- New Ruby files use `# typed: strict` and Sorbet `sig` signatures.
- Test files (`*_spec.rb`) do not use Sorbet annotations.
- No duplicate logic — check for existing helpers before writing new ones.
- Command files follow the same structure as existing commands in `Library/Homebrew/cmd/`.

## Documentation consistency

- Public API changes are reflected in `docs/`.
- Man page changes require regenerating `manpages/` via `brew generate-man-completions`.
- Shell completions require regenerating `completions/` via the same command.

## Naming consistency

- Follow existing naming conventions in the file being edited.
- Use snake_case for Ruby variables and methods.
- Use SCREAMING_SNAKE_CASE for constants.
- Keep file names consistent with the class or module they define.
