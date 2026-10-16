#!/usr/bin/env bash
# Claude Code adapter for the config verb: the project's coddy config, or
# NOT_ONBOARDED. Every skill except onboard injects this and stops on it.
CODDY_ROOT="${CLAUDE_PROJECT_DIR-}" CODDY_SESSION="${CLAUDE_CODE_SESSION_ID-}" CODDY_PID="${CLAUDE_PID-}" CODDY_AGENT_DIR=.claude
export CODDY_ROOT CODDY_SESSION CODDY_PID CODDY_AGENT_DIR
. "${0%/*}/../bin/coddy" config
