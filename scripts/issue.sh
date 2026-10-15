#!/usr/bin/env bash
# Claude Code adapter: hands Claude's environment to the core as its CODDY_*
# inputs, each only when not already set, and runs bin/coddy with the
# arguments as they are. Sourced, not exec'd, so the core names this shim in
# its messages, as the skills' allowed-tools do.
: "${CODDY_ROOT=${CLAUDE_PROJECT_DIR-}}" "${CODDY_SESSION=${CLAUDE_CODE_SESSION_ID-}}" "${CODDY_PID=${CLAUDE_PID-}}" "${CODDY_AGENT_DIR=.claude}"
export CODDY_ROOT CODDY_SESSION CODDY_PID CODDY_AGENT_DIR
. "${0%/*}/../bin/coddy"
