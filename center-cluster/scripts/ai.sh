#!/bin/bash
# Launchers for the AI row on the profile card.
#
#   ai.sh picker    open the session picker (aisp: Claude Code, Codex, Hermes)
#   ai.sh chatgpt   open ChatGPT in Firefox
#
# The picker runs in $AI_TERMINAL (default kitty); Warp cannot run a command.
set -u

TERMINAL="${AI_TERMINAL:-kitty}"
export PATH="$HOME/.local/bin:$PATH"

spawn() { setsid -f "$@" >/dev/null 2>&1; }

case "${1:-}" in
  picker|claude|hermes) spawn "$TERMINAL" -e aisp ;;
  chatgpt)  spawn firefox https://chatgpt.com ;;
  *) echo "usage: ${0##*/} picker|chatgpt" >&2; exit 2 ;;
esac
