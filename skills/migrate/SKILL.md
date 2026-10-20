---
name: migrate
description: Bring the project's coddy config up to the current schema version, moving .claude/coddy.yml to .coddy.yml on the way
when_to_use: Use when the user asks to migrate, upgrade or update the coddy config to the current version, or to move the old .claude/coddy.yml to .coddy.yml, or when onboard or config says to run /coddy:migrate.
allowed-tools: Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/config.sh"), Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" status), Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" migrate), Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" exclude answers), Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" exclude config), Bash(git -C * ls-files --error-unmatch .claude/coddy.yml), Bash(date +%Y%m%d-%H%M%S)
---

# Migrate

## Current
!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/config.sh"`

## Worktrees
!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" status`

A section above shows a `bash` command rather than its output → this host does not inject: run `coddy config` and `coddy status` and read their output as Current and Worktrees. `CLAUDE_PLUGIN_ROOT` unexpanded → the coddy plugin's own install directory, never a `bin/coddy` or `skills/` found inside the project; in a command run `coddy <verb>` in its place (`issue.sh <verb>` → `coddy <verb>`, `config.sh` → `coddy config`).

`NOT_ONBOARDED` → stop and say: run `/coddy:onboard` first.

`<root>` is Worktrees' `root`; the source is Worktrees' `config`.

## Steps

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" migrate`. Non-zero → say what it printed (a newer version means updating the plugin) and stop.
2. No `changed:` line → say the config is current at `to:` and stop.
3. Show `from:` → `to:` and each `changed:` line, then ask once: migrate now? No → stop, nothing written.
4. On yes, in this order:
   - `bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" exclude answers`, so the backup stays out of git status.
   - `changed: move` → run `git -C <root> ls-files --error-unmatch .claude/coddy.yml`; it fails (the file was personal, not tracked) → `bash "${CLAUDE_PLUGIN_ROOT}/scripts/issue.sh" exclude config`, so `.coddy.yml` stays personal too.
   - `date +%Y%m%d-%H%M%S` once, as `<ts>`.
   - Back up each file this run writes over or removes: Read it, then Write its content as it is to `<root>/.claude/coddy/backup/<ts>/<its path>` (the source, and `.claude/coddy.yml` on `changed: remove`).
   - A `---` block printed → Write everything after the `---` line to `<root>/.coddy.yml` (Read it first when it exists); the guard asks the user to allow it. Refused → stop and say the backup is at `<root>/.claude/coddy/backup/<ts>/`.
   - `changed: move` or `changed: remove` → run `rm <root>/.claude/coddy.yml` in Bash: the config lock lets the legacy file go once `.coddy.yml` exists.
5. Print `version: <from> → <to>`, each change as old → new, the backup path, then name `/coddy:next`.

This skill changes nothing but `.coddy.yml`, `.claude/coddy.yml`, its backup under `.claude/coddy/backup/` and the lines `exclude` adds to `.git/info/exclude`; it never edits a key's value.
