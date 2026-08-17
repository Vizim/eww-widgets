#!/bin/bash
# MPRIS media readout/control for the cluster's player pane.
# Works with any MPRIS player; PLAYER_PREFERENCE picks the order.
set -u

CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/eww-center-cluster"
BLANK="$CFG/images/icons/ui/no-art.png"
PREF="${PLAYER_PREFERENCE:-spotify,firefox,%any}"

mkdir -p "$CACHE"

pc() { playerctl --player="$PREF" "$@" 2>/dev/null; }

meta() { pc metadata --format "$1"; }

case "${1:-}" in
  song)
    t=$(meta '{{title}}'); echo "${t:-Nothing playing}" ;;

  artist)
    a=$(meta '{{artist}}'); echo "${a:-}" ;;

  status)
    # Which transport glyph the play/pause button should show.
    # GTK CSS url() needs a file:// URI here: a bare absolute path in an inline
    # :style is resolved against the config dir and silently fails to load.
    case "$(pc status)" in
      Playing) echo "file://$CFG/images/icons/music/pause.png" ;;
      *)       echo "file://$CFG/images/icons/music/play.png" ;;
    esac ;;

  art)
    url=$(meta '{{mpris:artUrl}}')
    if [ -z "$url" ]; then echo "file://$BLANK"; exit 0; fi
    case "$url" in
      file://*) echo "$url"; exit 0 ;;
    esac
    # Cache remote artwork by URL hash so we fetch each cover exactly once.
    key=$(printf '%s' "$url" | sha1sum | cut -c1-40)
    out="$CACHE/$key.jpg"
    if [ ! -s "$out" ]; then
      curl -fsSL --max-time 6 -o "$out.part" "$url" && mv "$out.part" "$out" \
        || { rm -f "$out.part"; echo "file://$BLANK"; exit 0; }
    fi
    echo "file://$out" ;;

  prev)   pc previous ;;
  next)   pc next ;;
  toggle) pc play-pause ;;

  *) echo "usage: ${0##*/} song|artist|status|art|prev|next|toggle" >&2; exit 2 ;;
esac
