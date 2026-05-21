# Operating Procedures

Regular procedures for keeping this project healthy.

## Weekly

- Review open PRs older than 7 days and either merge, close, or leave a comment explaining the hold.
- Check for Dependabot alerts and update pinned dependencies if safe to do so.

## Before a release

- Run the full test suite (`brew tests --online`).
- Verify the changelog reflects all user-visible changes.
- Confirm the version bump is correct.
- Tag the release commit and push the tag.

## When CI is broken

1. Identify whether the failure is in the PR or on `main`.
2. If on `main`, stop merging PRs until it is fixed.
3. If in the PR, ask the author to investigate or investigate yourself.
4. Do not mark a PR as approved while CI is red.
