# Workflows

Standard development workflows for this project.

## Starting a session

1. Pull the latest changes from the active branch.
2. Read any open issues or review comments.
3. Confirm the task scope before writing code.

## Making changes

1. Write new code with Sorbet type signatures for new files.
2. Run `brew style --fix --changed` to lint.
3. Run `brew typecheck` to verify types.
4. Write or update tests for the changed behaviour.
5. Run `brew tests --changed` before committing.

## Ending a session

1. Commit all in-progress work with a clear message describing what changed and why.
2. Push to the feature branch.
3. Open a draft PR if one does not exist.
4. Note any open questions or blockers in the PR description.
