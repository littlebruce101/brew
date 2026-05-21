# Review Process

How changes are reviewed before merging.

## Opening a PR

1. Target the correct base branch (usually `main`).
2. Write a clear title (under 70 characters).
3. Summarise what changed and why in the PR body.
4. List any manual testing steps.
5. Open as a draft until ready for review.

## Reviewing a PR

1. Read the PR description before reading the diff.
2. Check that tests exist and cover the new behaviour.
3. Confirm style and type checks passed in CI.
4. Leave specific, actionable comments — not general opinions.
5. Approve only when all concerns are addressed.

## Merging

- Only merge when CI is green and at least one approval exists.
- Prefer squash merge for single-purpose changes.
- Delete the feature branch after merging.
