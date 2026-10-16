#!/usr/bin/env bash
# Claude Code adapter for the detect verb: facts about the current project
# that /coddy:onboard uses to pre-fill the config.
CODDY_ROOT="${CLAUDE_PROJECT_DIR-}" CODDY_SESSION="${CLAUDE_CODE_SESSION_ID-}" CODDY_PID="${CLAUDE_PID-}" CODDY_AGENT_DIR=.claude
export CODDY_ROOT CODDY_SESSION CODDY_PID CODDY_AGENT_DIR
. "${0%/*}/../bin/coddy" detect
