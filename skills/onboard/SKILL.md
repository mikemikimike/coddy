---
name: onboard
description: Bring the current project into the coddy workflow by writing .coddy.yml
when_to_use: Use when the user asks to onboard a project or set coddy up in it for the first time. Changing a setting later is the config skill.
allowed-tools: Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect.sh"), mcp__plugin_github_github__get_me
---

# Onboard this project

## Detected
!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect.sh"`

Detected shows a `bash` command rather than its output → this host does not inject: run `coddy detect` and read its output as Detected. `CLAUDE_PLUGIN_ROOT` unexpanded in a command → it is the coddy plugin's directory, the one `bin/coddy` is in; `detect.sh` there is `coddy detect`.

`jq: missing` → stop before asking anything and write nothing: the edit guard blocks every edit without it. `brew install jq` or `apt install jq`, then run `/coddy:onboard` again.
`remote` is on GitHub → `get_me`. The tool is not available or fails → stop and write nothing: the GitHub plugin must be enabled and signed in with a token that can read and write the repository's issues and pull requests, then run `/coddy:onboard` again.

## Config schema: `.coddy.yml`

```yaml
tracker: github              # github | jira
repo: owner/name             # github only
jira:                        # jira only
  site: https://acme.atlassian.net
  project: KEY
worktree: jj                 # jj | git; tool that creates each issue's worktree
default_branch: main
branch: "{type}/{issue}-{slug}"
commit: "{type}({issue}): {summary}"
verify: "make check"         # must exit 0 before /coddy:ship
roadmap: docs/ROADMAP.md     # optional; /coddy:next reads it
guard: block                 # optional; block (default) | warn. warn lets an edit outside a claimed worktree, or inside one another session claimed, through with a notice to Claude
tiers:                       # model per difficulty, per agent; start picks one per issue
  claude: {low: haiku, medium: sonnet, high: opus}
review_block: high           # optional; critical | high | medium | low (default high); findings at or above it trigger another fix round
review_rounds: 3             # optional; 1-5 (default 3); review rounds before start hands the rest to the user
```

## Steps

1. `config: present` → show it and ask whether to overwrite. "No" ends the skill.
2. Pre-fill from the detection block: `tracker`/`repo` from the remote, `branch`/`commit` from recent branches and commits when a pattern is visible, `verify` from make targets or package scripts, `roadmap` from the detected file.
3. Ask for the rest in ONE AskUserQuestion call: every key you could not infer, plus confirmation of the guessed patterns, plus the `worktree` tool with `jj` as the default first option and `git` as the other (`jj: missing` → say so in the `jj` option). Also `tiers` for the agent running this skill only, keyed by its lower-case name (`claude`, `codex`, `gemini`, `cursor`, `copilot`): one option with its own cheap, default and strongest models as low, medium and high (Claude Code: `haiku`, `sonnet`, `opus`), marked recommended. `review_block` and `review_rounds` are not asked for: leave them out, their defaults apply. A non-GitHub remote means asking for the tracker; `tracker: jira` means asking for site and project key. `guard` is not asked for: leave it out, `/coddy:config` sets it later. `tracker: github` → also ask whether `default_branch` already requires a pull request (a branch rule or ruleset; nothing here can read it), so that nothing reaches it without one, even from a shell. `tracker: github` and `pr_check: none` → also ask whether to add coddy's PR check workflow, which fails every pull request that does not close an open, assigned issue.
4. PR check accepted → `config: present` → the hooks are live and the tripwire would report the copy, so print `mkdir -p .github/workflows && cp "${CLAUDE_PLUGIN_ROOT}/templates/coddy.yml" .github/workflows/coddy.yml` for the user to run in their own terminal. `config: none` → run it yourself, before the config exists: the hooks go live with it. Say the file is uncommitted and to commit it; once the check is required, through a PR that closes an open, assigned issue, since the workflow runs from the PR's merge ref and checks that PR too.
5. `AGENTS.md` at the root, before the config, whether the config will be personal or shared: the block below, verbatim and unindented. One `<!-- coddy:begin -->` with one `<!-- coddy:end -->` after it → replace what is between them, the rest of the file as it was; neither → append the block after a blank line; no file → create it with the block alone; any other marker layout (lone, repeated, end before begin) → leave the file as it is, print the block and name the stray marker. `config: present` → the guard rejects every write at the root once a config exists, so print the block and say to put it there by hand, between the markers when they exist, else at the end.

   ```markdown
   <!-- coddy:begin -->
   ## coddy

   This repository uses [coddy](https://github.com/mnsami/coddy): every change is tied to a claimed issue, lives in its own worktree and lands through a pull request.

   - Never edit the main checkout. Issue work happens only in `.worktrees/<issue>`, which the `start` skill creates once it has claimed the issue.
   - Before acting, run `coddy config` and `coddy status`: the config (or `NOT_ONBOARDED`), then the root and the claimed worktrees.
   - Ship only through the `ship` skill: it runs verify, commits, pushes and opens the pull request. Never merge.
   - The skills (`onboard`, `config`, `next`, `start`, `ship`, `triage`) come from the coddy plugin, `skills/<name>/SKILL.md`, and `coddy` is its `bin/coddy`.
   <!-- coddy:end -->
   ```

6. Write `.coddy.yml`. `legacy_config: present` → say `.claude/coddy.yml` is ignored from now on and can be removed.
7. `config_ignored: no` → ask whether the config is personal (add `.coddy.yml` to `.git/info/exclude`) or shared (leave it for commit).
8. `tracker: github` and `default_branch` does not yet require a pull request (step 3) → no MCP tool reads or writes branch protection, so say what to set by hand at `https://github.com/<repo>/settings/branches`: a rule for `<default_branch>` that requires a pull request before merging (0 approvals is enough) and applies to administrators, plus, when the PR check is accepted or `pr_check: present`, the required status check `closes a claimed issue`. `tracker: github`, PR check accepted or present, and the branch already required a pull request → say in one line that the workflow blocks a merge only once `closes a claimed issue` is a required check under that rule, and to add it there by hand. `tracker: jira` and `pr_check: present` → say the workflow fails every Jira PR (no closing reference) and to remove it.
9. Print the final config, say `AGENTS.md` is uncommitted when step 5 wrote it, and stop.

This skill changes nothing else: no code, no CI beyond `.github/workflows/coddy.yml`, nothing in `AGENTS.md` outside the markers, no CLAUDE.md or planning docs.
