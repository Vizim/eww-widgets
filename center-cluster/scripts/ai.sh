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
# The picker's control port: a fixed obscure port on 127.0.0.1, guarded by a
# random per-launch key so nothing else can send it actions. It has to be
# 127.0.0.1: fzf refuses reload/execute actions on any other address.
PICKER_ADDR="${AI_PICKER_ADDR:-127.0.0.1}"
PICKER_PORT="${AI_PICKER_PORT:-44144}"
export PATH="$HOME/.local/bin:$PATH"   # claude and hermes both live here

spawn() { setsid -f "$@" >/dev/null 2>&1 & }

# Sessions come from scripts/claude-sessions.py, which reads every project's
# transcripts and caches a one-line title plus a preview per session.
pick_claude() {
  local cache list out key sel sid dir port=$PICKER_PORT
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-picker"
  # A second picker already holds the fixed port: take any free one on our address.
  ss -Hltn "src $PICKER_ADDR:$port" 2>/dev/null | grep -q . && port=0
  FZF_API_KEY=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'); export FZF_API_KEY
  list="CLAUDE_PICKER_CACHE='$cache' python3 '$(dirname "$SELF")/claude-sessions.py'"
  # fzf does no matching itself: every keystroke re-runs the indexer with the
  # query, which searches titles, prompts and replies and keeps time order.
  # The watcher reloads the list the same way when a transcript changes.
  out=$(eval "$list" | fzf --delimiter='\t' --with-nth=3 --ansi --reverse --height=100% --disabled \
            --prompt='claude > ' --expect=ctrl-n,ctrl-t --listen "$PICKER_ADDR:$port" --track \
            --bind "start:execute-silent(setsid -f bash '$SELF' watch-claude \$FZF_PORT \$PPID)" \
            --bind "change:reload($list {q})" --bind "ctrl-r:reload($list {q})" \
            --header='Enter resumes | Ctrl-N new session there | Ctrl-T cloud sessions there | Ctrl-R refresh | type to search' \
            --preview="cat '$cache'/{1}.txt" \
            --preview-window='right,50%,wrap,<110(down,45%,wrap)') || exit 0
  key=$(head -n1 <<<"$out")
  sel=$(sed -n 2p <<<"$out")
  [ -z "$sel" ] && exit 0
  sid=$(cut -f1 <<<"$sel")
  dir=$(cut -f2 <<<"$sel")
  cd "$dir" 2>/dev/null || cd "$HOME" || exit 1
  case "$key:$sid" in
    ctrl-n:*)     exec claude ;;
    ctrl-t:*)     exec claude --teleport ;;
    *:__NEW__)    exec claude ;;
    *:__CLOUD__)  teleport_by_link ;;
  esac
  exec claude --resume "$sid"
}

# Read a claude.ai/code link (or bare session id) and resume it locally.
teleport_by_link() {
  local link id
  printf 'claude.ai/code link or session id: '
  IFS= read -r link
  id=$(grep -oE 'session_[A-Za-z0-9]+' <<<"$link" | head -n1)
  [ -z "$id" ] && { echo "no session id in that" >&2; sleep 2; exit 1; }
  exec claude --teleport "$id"
}

# Poll transcript mtimes and push a reload to the picker on $PICKER_ADDR:$1,
# authenticated with the FZF_API_KEY inherited from fzf. Runs while fzf (pid $2) lives.
watch_claude() {
  local port=$1 fzf=$2 cache seen="" now
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-picker"
  while kill -0 "$fzf" 2>/dev/null; do
    now=$(ls -l --time-style=+%s ~/.claude/projects/*/*.jsonl 2>/dev/null | md5sum)
    if [ -n "$seen" ] && [ "$now" != "$seen" ]; then
      curl -sf --max-time 2 -H "x-api-key: ${FZF_API_KEY:-}" -XPOST "$PICKER_ADDR:$port" \
        -d "reload(CLAUDE_PICKER_CACHE='$cache' python3 '$(dirname "$SELF")/claude-sessions.py' {q})" >/dev/null
    fi
    seen=$now
    sleep 2
  done
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
  watch-claude) watch_claude "${2:?port}" "${3:?fzf pid}" ;;
  *) echo "usage: ${0##*/} claude|hermes|chatgpt" >&2; exit 2 ;;
esac
