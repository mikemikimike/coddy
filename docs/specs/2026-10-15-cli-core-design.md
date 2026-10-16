# Agent-agnostic coddy CLI core (#27)

## Goal

Move coddy's mechanics into a `coddy` command with no Claude Code dependency, so later adapters (#31-#33) call the same core. Claude Code becomes the first adapter.

## Decisions

- `selftest.sh` is not edited. It keeps calling `scripts/{issue,config,detect}.sh` with `CLAUDE_*` variables and `.claude/coddy.yml`, and passes.
- `scripts/*.sh` stay as Claude shims, so `hooks/hooks.json` and every skill's `allowed-tools` stay byte-identical.
- `.claude/coddy.yml` is a read fallback; projects move to `.coddy.yml` explicitly through `/coddy:config`, never from a hook.
- `.coddy.yml` gets no Claude Code sensitive-file prompt, so `guard` asks the user on every Edit or Write of it.
- `coddy start` and `coddy ship` cover the local halves only; tracker and PR calls stay MCP steps in the skills.

## Layout

- `bin/coddy`: the core. Today's `scripts/issue.sh` body plus `scripts/root.sh`, and the verbs `config` (today's `config.sh`) and `detect` (today's `detect.sh`). Executable. Claude Code puts a plugin's `bin/` on the Bash tool's `PATH`; other agents need a symlink or a `PATH` entry.
- `scripts/root.sh`: deleted.
- `scripts/issue.sh`, `scripts/config.sh`, `scripts/detect.sh`: Claude shims. Each sets, from Claude's environment alone, ignoring any inherited `CODDY_*` value (a settings `env`, a hostile shell),
  - `CODDY_ROOT` from `CLAUDE_PROJECT_DIR`
  - `CODDY_SESSION` from `CLAUDE_CODE_SESSION_ID`
  - `CODDY_PID` from `CLAUDE_PID`
  - `CODDY_AGENT_DIR=.claude`

  then sources `bin/coddy` (`issue.sh` passes its arguments through; `config.sh` and `detect.sh` call the `config` and `detect` verbs).

The core reads no `CLAUDE_*` variable. The only `.claude` string left in it is the legacy config path.

## Core inputs

| Variable | Meaning | Absent |
|---|---|---|
| `CODDY_ROOT` | Directory to start root resolution from | `$PWD` |
| `CODDY_SESSION` | Session id written to and compared with the lock's owner line | Caller not held to the owner, as today |
| `CODDY_PID` | Pid written to and compared with the owner line | As today without `CLAUDE_PID` |
| `CODDY_AGENT_DIR` | The agent's own directory, relative to the root | No agent-dir rules |

Root resolution is unchanged apart from its start point: `git rev-parse --git-common-dir`, keeping the caller's spelling, and stripping `/.worktrees/*` outside git.

## Verbs

| Verb | Does |
|---|---|
| `start <issue> <branch> [base]` | Today's `create`; `create` stays as an alias |
| `claim <issue> [--take]` | Unchanged; runs after the skill's tracker transition |
| `ship <issue>` | `verify` then `push`; `push` stays as an alias for push alone |
| `sweep`, `guard`, `status` | Unchanged |
| `snap`, `trip`, `state`, `verify`, `diff`, `log` | Unchanged |
| `config` | Today's `config.sh`: the config, or `NOT_ONBOARDED` |
| `detect` | Today's `detect.sh` |

The agent-dir rules in `guard` and `snap`, today written as `.claude/`:

- Paths under `$CODDY_AGENT_DIR/` are allowed, and skipped by `snap`.
- `$CODDY_AGENT_DIR/worktrees/<name>/` is held to `<name>`'s lock, as `.claude/worktrees/` is today.

## Config

- `conf` is `.coddy.yml` when it exists at the root, else `.claude/coddy.yml`.
- `guard` on `.coddy.yml` at the root prints `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask", "permissionDecisionReason": "..."}}` and exits 0, with `guard: warn` too. Without `jq` it exits 2 (fails closed, as today).
- Config lock:
  - `snap` records both paths, including whether each exists.
  - `trip` restores either one that a shell command deleted or changed.
  - `trip` deletes a `.coddy.yml` that the command created while only `.claude/coddy.yml` existed, so a new file cannot shadow the live config.
  - A changed config stands only when identical to what `origin` holds at `default_branch` as `git ls-remote` reports it, per path: `origin` is asked with system and global git config ignored (`GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null`, since a `url.insteadOf` there would answer in `origin`'s name), with that config's `credential.*` keys alone passed back as `-c`, in order and whole (a helper supplies a password and cannot move the URL), and `safe.directory` set to the root; the exact `refs/heads/<default_branch>` line is taken, since `ls-remote` matches its pattern against the tail of every ref; that commit must be local and is read with replace objects ignored (`GIT_NO_REPLACE_OBJECTS=1`); no local ref is trusted or moved; a path the tip does not hold, or a file git cannot hash, is no match; a deletion is always restored.
- `/coddy:config` gains a migrate step when only the legacy file exists: write `.coddy.yml` with the Edit tool (the guard asks), then delete `.claude/coddy.yml`. A change to any other key offers the move first.
- `/coddy:onboard` writes `.coddy.yml`.
- `detect` reports `.coddy.yml` and the legacy file.
- The three schema copies keep the same keys.

## Tests

- `scripts/selftest.sh`: unchanged, passes through the shims.
- `scripts/selftest-core.sh` (new) calls `bin/coddy` with no `CLAUDE_*` set and covers:
  - root resolution from `CODDY_ROOT` and from `$PWD`;
  - a claim and push held to the owner through `CODDY_SESSION` and `CODDY_PID`;
  - `.coddy.yml` preferred over the legacy file, and the fallback;
  - the guard's ask on `.coddy.yml`, in both guard modes;
  - the shadowing restore, plus the delete and change restores on `.coddy.yml`;
  - no agent-dir rules without `CODDY_AGENT_DIR`;
  - `start` and `ship` (including `ship` stopping on a failing verify) next to their aliases.
- `selftest.sh` does not call `selftest-core.sh`, so it stays literally unchanged. This repo's `verify` becomes `bash scripts/selftest.sh && bash scripts/selftest-core.sh && claude plugin validate .` through `/coddy:config`, and the Commands section of `CLAUDE.md` lists both tests.

## Docs

- `CLAUDE.md`: the core/adapter split, the `CODDY_*` inputs, the config path and its lock, the commands section.
- `README.md`: `.coddy.yml` and how to put `coddy` on `PATH`.
- `ROADMAP.md`: #27 under M2.

## Out of scope

- Hook output per agent: the `warn` and `ask` JSON is Claude Code's format, emitted from the core. #31-#33 adapt it.
- Session identity for agents without one (#34 reports it).
- AGENTS.md and portable skills (#28).
