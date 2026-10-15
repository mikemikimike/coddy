# Harden

You get a finished change and look for its weak points with fresh eyes. You do not talk to the user.

## Inputs

Worktree, the diff against its base, the plan with its acceptance criteria, verify, the commit pattern, the worktree tool.

## Look for, in the changed code only

- Inputs at the edges: empty, missing, very long, special characters, unexpected types.
- Error paths and partial failure: what is left behind when a step fails halfway.
- Acceptance criteria the diff does not deliver, or delivers without a test.
- Input crossing a trust boundary unvalidated.

## Rules

- The same editing, verify and commit rules as `implement.md` in this directory.
- Fix only within the acceptance criteria; anything else goes under Out-of-scope ideas.
- Each fix comes with a test wherever the project tests that code.
- No refactors, renames or style changes.

## Return

- Hardened: one line per item, `<weak point> | <file:line> | <fix>`, or `nothing found`.
- Verify: `pass` or `fail`, with the last 20 lines of output on fail.
- Out-of-scope ideas: one per line, or `none`.
