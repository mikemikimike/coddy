#!/usr/bin/env bash
# Installs coddy for any agent and the terminal: a checkout of main and the
# coddy command on PATH.
#   curl -fsSL https://raw.githubusercontent.com/mnsami/coddy/main/get.sh | bash
# Inputs, all optional: CODDY_REPO_URL (the repository), CODDY_HOME (the
# checkout, ~/.coddy), CODDY_BIN (where coddy is linked, ~/.local/bin).
# A rerun updates the checkout by fast-forward. Every refusal comes before
# any change. Reads nothing from stdin, which is this script under curl.
# Wrapped in main so a download cut short runs nothing.
set -u
main() {
  local url="${CODDY_REPO_URL:-https://github.com/mnsami/coddy}" home="${CODDY_HOME:-$HOME/.coddy}" bin="${CODDY_BIN:-$HOME/.local/bin}"
  local link state sha top v
  # Absolute, so the link's target resolves from CODDY_BIN and the PATH line works anywhere.
  case "$home" in /*) ;; *) home="$PWD/$home" ;; esac
  case "$bin" in /*) ;; *) bin="$PWD/$bin" ;; esac
  # A GIT_DIR or GIT_CONFIG_* from the caller would point git at another repository or config.
  for v in "${!GIT_@}"; do case $v in GIT_AUTHOR_*|GIT_COMMITTER_*|GIT_SSH*|GIT_ASKPASS) ;; *) unset "$v" ;; esac; done
  export GIT_TERMINAL_PROMPT=0
  die() { echo "coddy install: $*" >&2; exit 1; }
  # The same repository however its URL is spelled: ssh or https, with or
  # without a trailing / or .git.
  norm() { local u="${1%/}"; u="${u%.git}"; u="${u%/}"; case "$u" in git@github.com:*) u="https://github.com/${u#git@github.com:}" ;; esac; printf %s "$u"; }

  [ "$(id -u)" != 0 ] || die "refusing to run as root: run it as the user who will use coddy"
  command -v git >/dev/null || die "git is needed: install it, then run this again"
  if [ -e "$home" ] || [ -L "$home" ]; then
    top=$(git -C "$home" rev-parse --show-toplevel 2>/dev/null)
    [ -n "$top" ] && [ "$top" -ef "$home" ] || die "$home is not a git checkout: move it aside, then run this again"
    [ "$(norm "$(git -C "$home" remote get-url origin 2>/dev/null)")" = "$(norm "$url")" ] || die "$home's origin is not $url: move it aside, then run this again"
    [ "$(git -C "$home" symbolic-ref -q --short HEAD)" = main ] || die "$home is not on main: switch it back (git -C $home switch main), then run this again"
    [ -z "$(git -C "$home" status --porcelain --untracked-files=no)" ] || die "$home has changes to tracked files: commit, stash or drop them, then run this again"
  fi
  link="$bin/coddy"
  if [ -e "$link" ] || [ -L "$link" ]; then
    [ -L "$link" ] && { [ "$(readlink "$link")" = "$home/bin/coddy" ] || [ "$link" -ef "$home/bin/coddy" ]; } ||
      die "$link is there already and is not a link to $home/bin/coddy: remove it, then run this again"
  fi
  mkdir -p "$bin" 2>/dev/null || die "could not create $bin: make it a directory, then run this again"

  if [ -e "$home" ]; then
    sha=$(git -C "$home" rev-parse -q --verify --short HEAD)
    git -C "$home" fetch -q origin main || die "could not fetch from $url"
    local out; out=$(git -C "$home" merge --ff-only origin/main 2>&1) ||
      die "could not update $home (not a fast-forward, or an untracked file is in the way); nothing changed. git says:
$out"
    if [ "$(git -C "$home" rev-parse --short HEAD)" = "$sha" ]; then state="up to date"; else state=updated; fi
  else
    git clone -q -b main "$url" "$home" || die "could not clone $url"
    state=cloned
  fi
  [ -L "$link" ] || ln -s "$home/bin/coddy" "$link" || die "could not link $link"
  echo "$state: $home at $(git -C "$home" rev-parse --short HEAD)"
  echo "linked: $link"
  case ":$PATH:" in *":$bin:"*) ;; *) echo "$bin is not on your PATH. Add this line to your shell's rc file:"; echo "  export PATH=\"$bin:\$PATH\"" ;; esac
  cat <<EOF

Next:
  Claude Code: install the plugin, which keeps its own copy and does not use $home:
    claude plugin marketplace add mnsami/coddy
    claude plugin install coddy@coddy
  Any other agent: in your project, have it read $home/skills/onboard/SKILL.md
    and follow it; the other skills are next to it under $home/skills/.
    The coddy command is $link.
EOF
}
main "$@"
