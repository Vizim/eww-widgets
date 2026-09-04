#!/bin/bash
# Launchers for the AI row on the profile card.
#
#   ai.sh claude    pick a recent Claude Code session, or start a new one
#   ai.sh hermes    same, for Hermes
#   ai.sh chatgpt   open ChatGPT in Firefox
#
# The pickers run in $AI_TERMINAL (default kitty); Warp cannot run a command.
set -u

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
TERMINAL="${AI_TERMINAL:-kitty}"
export PATH="$HOME/.local/bin:$PATH"   # claude and hermes both live here

spawn() { setsid -f "$@" >/dev/null 2>&1 & }

# Sessions come from scripts/claude-sessions.py, which reads every project's
# transcripts and caches a one-line title plus a preview per session.
pick_claude() {
  local cache rows out key sel sid dir
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-picker"
  rows=$(CLAUDE_PICKER_CACHE="$cache" python3 "$(dirname "$SELF")/claude-sessions.py") || exit 1
  # Field 3 is shown, field 4 is the hidden search text (title, project, prompts).
  out=$(fzf --delimiter='\t' --with-nth=3 --nth=3,4 --exact --ansi --reverse --height=100% \
            --prompt='claude > ' --expect=ctrl-n \
            --header='Enter resumes  |  Ctrl-N new session in that project  |  type to search prompts' \
            --preview="cat '$cache'/{1}.txt" \
            --preview-window='right,50%,wrap,<110(down,45%,wrap)' <<<"$rows")
  [ -z "$out" ] && exit 0
  key=$(head -n1 <<<"$out")
  sel=$(sed -n 2p <<<"$out")
  [ -z "$sel" ] && exit 0
  sid=$(cut -f1 <<<"$sel")
  dir=$(cut -f2 <<<"$sel")
  cd "$dir" 2>/dev/null || cd "$HOME" || exit 1
  if [ "$key" = "ctrl-n" ] || [ "$sid" = "__NEW__" ]; then exec claude; fi
  exec claude --resume "$sid"
}

# Hermes keeps its own session store; `sessions list` prints a table whose last
# column is the id.
pick_hermes() {
  local rows sel id
  rows=$(hermes sessions list --limit 40 2>/dev/null | awk 'NR > 2 && NF')
  sel=$( { printf '%-74s %s\n' '+ start a new chat' '__NEW__'; printf '%s\n' "$rows"; } \
        | fzf --reverse --height=100% --prompt='hermes > ' --header='Enter opens, Esc cancels')
  [ -z "$sel" ] && exit 0
  id=$(awk '{print $NF}' <<<"$sel")
  if [ "$id" = "__NEW__" ]; then exec hermes chat; else exec hermes --resume "$id"; fi
}

case "${1:-}" in
  claude)      spawn "$TERMINAL" -e bash "$SELF" pick-claude ;;
  hermes)      spawn "$TERMINAL" -e bash "$SELF" pick-hermes ;;
  chatgpt)     spawn firefox https://chatgpt.com ;;
  pick-claude) pick_claude ;;
  pick-hermes) pick_hermes ;;
  *) echo "usage: ${0##*/} claude|hermes|chatgpt" >&2; exit 2 ;;
esac
