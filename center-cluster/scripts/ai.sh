#!/bin/bash
# Launchers for the AI row on the profile card.
#
#   ai.sh claude    pick a recent Claude Code session, or start a new one
#   ai.sh hermes    same, for Hermes
#   ai.sh chatgpt   open ChatGPT in Firefox
#
# TERMINAL NOTE: the two pickers have to run a command inside a terminal, and
# Warp cannot do that. Its CLI exposes only cloud/agent subcommands (no exec
# flag), and its warp:// scheme has no run-command action - both were checked
# against the installed build. So the pickers open in $AI_TERMINAL, default
# kitty. Anything that only needs "a terminal" (the profile tile) still uses
# Warp. Set AI_TERMINAL to any terminal whose -e flag runs a command.
set -u

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
TERMINAL="${AI_TERMINAL:-kitty}"
export PATH="$HOME/.local/bin:$PATH"   # claude and hermes both live here

spawn() { setsid -f "$@" >/dev/null 2>&1 & }

# Claude Code stores one jsonl per session under ~/.claude/projects/<mangled>/,
# and scopes `claude --resume` to the current directory. To list every project's
# sessions in one place we read the files directly; each carries the real `cwd`,
# which avoids having to un-mangle the directory name (a lossy transform - it
# cannot tell a dash in a folder name from a path separator).
pick_claude() {
  local rows sel sid cwd
  rows=$(python3 - <<'PY'
import glob, json, os, time
out = []
for f in glob.glob(os.path.expanduser('~/.claude/projects/*/*.jsonl')):
    cwd = summary = None
    try:
        with open(f, encoding='utf-8', errors='ignore') as fh:
            for line in fh:
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                cwd = cwd or d.get('cwd')
                if summary is None and d.get('type') == 'user':
                    c = (d.get('message') or {}).get('content')
                    if isinstance(c, str):
                        summary = c
                    elif isinstance(c, list):
                        for p in c:
                            if isinstance(p, dict) and p.get('type') == 'text':
                                summary = p.get('text'); break
                if cwd and summary:
                    break
    except Exception:
        continue
    if not cwd:
        continue
    s = ' '.join((summary or '').split())[:60]
    out.append((os.path.getmtime(f), os.path.basename(f)[:-6], cwd, s))
out.sort(reverse=True)
for t, sid, cwd, s in out[:40]:
    when = time.strftime('%m-%d %H:%M', time.localtime(t))
    print(f"{sid}\t{cwd}\t{when}  {os.path.basename(cwd):<18.18}  {s}")
PY
)
  sel=$(printf '__NEW__\t%s\t+ start a new session\n%s\n' "$HOME" "$rows" \
        | fzf --delimiter='\t' --with-nth=3.. --reverse --height=100% \
              --prompt='claude > ' --header='Enter opens, Esc cancels')
  [ -z "$sel" ] && exit 0
  sid=$(cut -f1 <<<"$sel")
  cwd=$(cut -f2 <<<"$sel")
  cd "$cwd" 2>/dev/null || cd "$HOME" || exit 1
  if [ "$sid" = "__NEW__" ]; then exec claude; else exec claude --resume "$sid"; fi
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
