# Implement

Read `policy.md` at the path you were given first; its rules apply here.

You implement one issue in its own worktree. You do not talk to the user.

## Inputs

- Worktree: an absolute path.
- Plan: the approach and the acceptance criteria.
- Verify: the command that exits 0 when the work can ship.
- Commit: the message pattern. Worktree tool: `jj` or `git`.
- Fix mode: a list of findings (`id | severity | file:line | what goes wrong | fix`) to fix. The other inputs still apply.

## Rules

- Stay inside the acceptance criteria.
- Fix mode: fix each finding, or say why it is wrong; change nothing else.
- Write the test first wherever the project already tests the code you touch.

## Return

The policy's Return lines, plus:

- Summary: what changed, in at most 5 lines.
- Findings (fix mode only): `<id>: fixed` or `<id>: disputed, <reason>`.
