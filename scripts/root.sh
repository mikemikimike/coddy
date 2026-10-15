# Sourced by every script: sets root to the project's main checkout, from the
# session's directory: the root, a subdirectory, an issue worktree (git or jj,
# whose workspace has no .git and so reaches the main one) or a Claude Code
# worktree. git names a linked worktree's common dir by its real path, so the
# session's own spelling of it is put back: hook payloads use that one.
# Outside git, an issue worktree is still stripped back to the root.
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
if common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) && root=$(cd "$dir" && cd "$common/.." && pwd); then
  rel=$(cd "$dir" && pwd -P); rel="${rel#"$root"/}"
  case "$dir" in */"$rel") root="${dir%/"$rel"}" ;; esac
else
  root="$dir"
  case "$root" in */.worktrees/*) root="${root%%/.worktrees/*}" ;; esac
fi
