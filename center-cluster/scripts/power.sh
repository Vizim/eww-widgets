#!/bin/bash
# Session/power actions. Only reached after the tile has been armed by a first
# click, so a single stray click cannot shut the machine down.
set -u

session_id() {
  if [ -n "${XDG_SESSION_ID:-}" ]; then
    echo "$XDG_SESSION_ID"
  else
    loginctl list-sessions --no-legend | awk -v u="$USER" '$3 == u { print $1; exit }'
  fi
}

case "${1:-}" in
  poweroff) systemctl poweroff ;;
  reboot)   systemctl reboot ;;
  suspend)  systemctl suspend ;;
  logout)
    sid=$(session_id)
    [ -n "$sid" ] && loginctl terminate-session "$sid" || loginctl terminate-user "$USER"
    ;;
  *) echo "usage: ${0##*/} poweroff|reboot|suspend|logout" >&2; exit 2 ;;
esac
