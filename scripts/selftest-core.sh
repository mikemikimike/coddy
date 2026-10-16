#!/usr/bin/env bash
# Runs bin/coddy as any agent would: no CLAUDE_* variable set, its inputs
# from CODDY_ROOT, CODDY_SESSION, CODDY_PID and CODDY_AGENT_DIR, the config
# at .coddy.yml with .claude/coddy.yml as the fallback. The Claude Code shims
# under scripts/ and the full lifecycle are selftest.sh's.
# Usage: bash scripts/selftest-core.sh
set -u
unset $(compgen -v CLAUDE_) CODDY_AGENT_DIR 2>/dev/null
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"; fail=0
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export CODDY_ROOT="$repo" CODDY_SESSION=sess-a CODDY_PID=$$

# t <expected exit> <name> <command...>
t() {
  want=$1 name=$2; shift 2
  "$@" >/dev/null 2>&1; got=$?
  if [ "$got" = "$want" ]; then echo "ok   $name"; else echo "FAIL $name (exit $got, want $want)"; fail=1; fi
}
run() { "$here/bin/coddy" "$@"; } # by its exec bit, as PATH would run it
as() { CODDY_SESSION=$1 CODDY_PID=$2 run "${@:3}"; }
says() { "${@:2}" 2>&1 | grep -q "$1"; }
holds() { read -r a b _ < "$2" && [ "$a $b" = "$1" ]; }
# guard <path> [session]: the edit hook's payload; another session runs in another process
guard() { local s=${2-sess-a} p=1; [ "$s" != sess-a ] || p=$$; printf '{"session_id":"%s","tool_input":{"file_path":"%s"}}' "$s" "$1" | CODDY_PID=$p run guard; }
# asks <path>: guard exits 0 and asks the user, as hook JSON
asks() { out=$(guard "$1") && printf %s "$out" | jq -e '.hookSpecificOutput | .hookEventName == "PreToolUse" and .permissionDecision == "ask" and (.permissionDecisionReason | contains(".coddy.yml"))'; }
wire() { printf '{"tool_use_id":"%s"}' "$2" | run "$1"; }
tripped() { wire snap w; (cd "$repo" && eval "$3") >/dev/null 2>&1; t "$1" "$2" wire trip w; }
# rooted <dir> [VAR=value...]: status run from that directory prints the project root
rooted() { d=$1; shift; (cd "$d" && env "$@" "$here/bin/coddy" status | grep -qx "root: $repo"); }
# A PATH with everything the guard needs but jq.
mkdir "$tmp/nojq"; for x in bash sh sed awk cat grep git cmp ps sort comm tr cut cksum mkdir cp rm head; do p=$(command -v "$x") && ln -s "$p" "$tmp/nojq/$x"; done

git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$repo" 2>/dev/null
cd "$repo" || exit 1
git checkout -q -b main; echo hi > README.md; git add -A; git commit -q -m init; git push -q -u origin main
mkdir .claude sub

t 1 "the core reads no CLAUDE_ variable" grep -q CLAUDE_ "$here/bin/coddy"
t 0 "root: from CODDY_ROOT" rooted /
t 0 "root: from the working directory without CODDY_ROOT" rooted "$repo" -u CODDY_ROOT
t 0 "root: from a subdirectory without CODDY_ROOT" rooted "$repo/sub" -u CODDY_ROOT
t 0 "config: NOT_ONBOARDED before onboarding" says '^NOT_ONBOARDED$' run config
t 0 "status: no config before onboarding" says '^config: none$' run status
t 0 "detect: no config" says '^config: none$' run detect
t 0 "detect: no legacy config" says '^legacy_config: none$' run detect
t 0 "guard allows everything before onboarding" guard "$repo/README.md"
t 0 "guard asks nothing for .coddy.yml before onboarding" test -z "$(guard "$repo/.coddy.yml")"

printf 'tracker: github\nworktree: git\ndefault_branch: main\nverify: test -f ok.txt\n' > .claude/coddy.yml
t 0 "config: the legacy file is read when it is the only one" says '^worktree: git$' run config
t 0 "status names the legacy file" says '^config: .claude/coddy.yml$' run status
t 0 "detect: config present with the legacy file alone" says '^config: present$' run detect
t 0 "detect: and reports it as legacy" says '^legacy_config: present$' run detect
printf 'tracker: github\nworktree: git\ndefault_branch: main\nverify: test -f ok.txt\nroadmap: R.md\n' > .coddy.yml
t 0 "config: .coddy.yml is read before the legacy file" says '^roadmap: R.md$' run config
t 0 "status names .coddy.yml" says '^config: .coddy.yml$' run status
rm .claude/coddy.yml
t 0 "config: .coddy.yml alone" says '^roadmap: R.md$' run config
t 0 "detect: no legacy config next to .coddy.yml" says '^legacy_config: none$' run detect
t 0 "detect: .coddy.yml is not ignored" says '^config_ignored: no$' run detect
echo .coddy.yml >> .git/info/exclude
t 0 "detect: .coddy.yml is ignored once excluded" says '^config_ignored: yes$' run detect

# Editing .coddy.yml is for the user to allow, in both guard modes; without
# jq the guard cannot tell which path is edited and fails closed.
t 0 "guard asks on .coddy.yml" asks "$repo/.coddy.yml"
t 2 "guard blocks the main checkout" guard "$repo/README.md"
PATH="$tmp/nojq" t 2 "guard without jq fails closed" guard "$repo/.coddy.yml"
echo 'guard: warn' >> .coddy.yml
t 0 "warn: guard still asks on .coddy.yml" asks "$repo/.coddy.yml"
t 0 "warn: guard lets the main checkout through" guard "$repo/README.md"
PATH="$tmp/nojq" t 2 "warn: guard without jq fails closed" guard "$repo/.coddy.yml"
sed -i.bak '/^guard:/d' .coddy.yml && rm .coddy.yml.bak
wire snap flow

# The config lock holds both paths: .coddy.yml is restored, and one created
# while .claude/coddy.yml was the live config is removed, so it cannot shadow it.
cp .coddy.yml "$tmp/conf.orig"
same() { cmp -s "$repo/$1" "$tmp/conf.orig"; }
tripped 2 "config: deleting .coddy.yml trips" 'rm .coddy.yml'
t 0 "config: restored after the deletion" same .coddy.yml
tripped 2 "config: rewriting .coddy.yml trips" 'echo "verify: true" >> .coddy.yml'
t 0 "config: restored after the rewrite" same .coddy.yml
t 0 "config: that report names the file" says 'changed .coddy.yml' sh -c "cd '$repo' && printf '{\"tool_use_id\":\"w\"}' | '$here/bin/coddy' snap && echo x >> .coddy.yml && printf '{\"tool_use_id\":\"w\"}' | '$here/bin/coddy' trip"
mv .coddy.yml .claude/coddy.yml
tripped 2 "config: a .coddy.yml created next to the live legacy file trips" 'cp .claude/coddy.yml .coddy.yml'
t 1 "config: and is removed" test -e .coddy.yml
t 0 "config: the legacy file stands" same .claude/coddy.yml
tripped 2 "config: deleting the legacy file trips" 'rm .claude/coddy.yml'
t 0 "config: the legacy file is restored" same .claude/coddy.yml
# Once .coddy.yml is live the legacy file is ignored, so the lock lets it go.
# .claude is the agent dir here, as from the shims, so the tripwire skips it too.
cp .claude/coddy.yml .coddy.yml
CODDY_AGENT_DIR=.claude tripped 0 "config: changing the legacy file next to a live .coddy.yml is quiet" 'echo "verify: true" >> .claude/coddy.yml'
t 0 "config: and the change stands" grep -q '^verify: true$' .claude/coddy.yml
CODDY_AGENT_DIR=.claude tripped 0 "config: deleting the legacy file next to a live .coddy.yml is quiet" 'rm .claude/coddy.yml'
t 1 "config: and it is not restored" test -e .claude/coddy.yml
git add -f .coddy.yml && git commit -q -m conf && git push -q origin main
echo 'roadmap: X.md' >> .coddy.yml
tripped 0 "config: a checkout of the committed .coddy.yml stands" 'git checkout -- .coddy.yml'
t 0 "config: and left it at HEAD" same .coddy.yml

# No agent-dir rules without CODDY_AGENT_DIR; with it, its directory is free
# and its worktrees/ held to the lock.
t 2 "no agent dir: .claude/ is the main checkout" guard "$repo/.claude/notes.md"
t 2 "no agent dir: so is .claude/worktrees/" guard "$repo/.claude/worktrees/5/a.txt"
tripped 2 "no agent dir: a change under .claude/ trips" 'echo x > .claude/notes.md'; rm .claude/notes.md
export CODDY_AGENT_DIR=.codex
t 0 "agent dir: edits under it are allowed" guard "$repo/.codex/notes.md"
t 2 "agent dir: its worktrees/ is held to the lock" guard "$repo/.codex/worktrees/5/a.txt"
t 0 "agent dir: that rejection names the claim" says "issue 5 is not In Progress" guard "$repo/.codex/worktrees/5/a.txt"
t 2 "agent dir: .claude/ is not it" guard "$repo/.claude/notes.md"
tripped 0 "agent dir: a change under it is quiet" 'mkdir -p .codex && echo x > .codex/notes.md'; rm -r .codex
unset CODDY_AGENT_DIR

# start is create, ship is verify then push; the aliases stay.
t 0 "start makes the worktree" says 'created: .worktrees/1 on feat/1-thing' run start 1 feat/1-thing
t 0 "create is its alias" says 'exists: .worktrees/1' run create 1 feat/1-thing
t 0 "root: from inside an issue worktree without CODDY_ROOT" rooted "$repo/.worktrees/1" -u CODDY_ROOT
t 0 "root: from CODDY_ROOT naming a worktree" rooted / CODDY_ROOT="$repo/.worktrees/1"
t 1 "ship refuses before the claim" run ship 1
t 0 "claim" run claim 1
t 0 "the lock names CODDY_SESSION and CODDY_PID" holds "sess-a $$" .git/coddy/1/owner
t 1 "another session's claim is refused" as sess-b 1 claim 1
t 0 "that refusal names the owner" says "session sess-a" as sess-b 1 claim 1
t 0 "the owner's process re-claims under another session id" as sess-b $$ claim 1
t 0 "and the lock followed it" holds "sess-b $$" .git/coddy/1/owner
run claim 1 >/dev/null 2>&1
t 0 "guard allows the owner's edit" guard "$repo/.worktrees/1/a.txt"
t 2 "guard blocks another session's edit" guard "$repo/.worktrees/1/a.txt" sess-b
CODDY_AGENT_DIR=.codex t 0 "agent dir: its worktree of a claimed issue is editable" guard "$repo/.codex/worktrees/1/a.txt"
echo x > .worktrees/1/a.txt
t 1 "push refuses another session" as sess-b 1 push 1 "feat(1): thing"
t 1 "ship stops on a failing verify" run ship 1 "feat(1): thing"
t 0 "and says so" says "verify" run ship 1 "feat(1): thing"
t 2 "and pushed nothing" git ls-remote --exit-code origin refs/heads/feat/1-thing
t 0 "push alone pushes without verify" says 'pushed: feat/1-thing' run push 1 "feat(1): thing"
t 0 "the branch reached the remote" git ls-remote --exit-code origin refs/heads/feat/1-thing
was=$(git ls-remote origin refs/heads/feat/1-thing)
echo ok > .worktrees/1/ok.txt
t 0 "verify passes now" run verify 1
t 1 "ship refuses another session" as sess-b 1 ship 1 "feat(1): ok"
t 0 "ship verifies then pushes" says 'pushed: feat/1-thing' run ship 1 "feat(1): ok"
t 1 "ship moved the branch on the remote" test "$(git ls-remote origin refs/heads/feat/1-thing)" = "$was"
t 0 "status lists the claimed issue as mine" says '^owners: 1=me' run status
t 0 "sweep keeps the unmerged worktree" sh -c "'$here/bin/coddy' sweep; test -d '$repo/.worktrees/1'"
t 0 "the whole flow left the main checkout alone" wire trip flow

exit $fail
