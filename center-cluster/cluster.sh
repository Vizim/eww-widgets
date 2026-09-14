#!/bin/bash
# Start / reload / stop the center cluster.
#   ./cluster.sh start | stop | reload | restart | status | open
# start/stop/restart go through the eww-widgets systemd user unit when it is
# available, so there is only ever one daemon. "open" is the unit's post-start
# hook: wait for the daemon, then open every window.
set -u

CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EWW=$(command -v eww) || { echo "eww not found in PATH" >&2; exit 1; }
UNIT=eww-widgets.service

WINDOWS=(
  profile
  link_github link_youtube link_planner link_whatsapp
  media blockclock apps
  power_off power_suspend power_logout power_reboot
  system resources
)

have_unit() {
  systemctl --user cat "$UNIT" >/dev/null 2>&1
}

wait_ready() {
  for _ in $(seq 1 40); do
    "$EWW" -c "$CFG" ping >/dev/null 2>&1 && return 0
    sleep 0.25
  done
  echo "eww daemon did not come up" >&2
  return 1
}

open_windows() {
  wait_ready || exit 1
  # An eww client can wedge holding its pipe open, so cap it and detach the fds.
  timeout 30 "$EWW" -c "$CFG" open-many "${WINDOWS[@]}" >/dev/null 2>&1 < /dev/null
  echo "cluster started"
}

kill_stray() {
  # Anything not owned by the unit: a hand-started daemon or a wedged client.
  pkill    -f "eww -c $CFG" 2>/dev/null || true
  sleep 0.5
  pkill -9 -f "eww -c $CFG" 2>/dev/null || true
}

start() {
  if have_unit; then
    systemctl --user is-active --quiet "$UNIT" || kill_stray
    systemctl --user start "$UNIT"
    return
  fi
  "$EWW" -c "$CFG" ping >/dev/null 2>&1 || {
    setsid "$EWW" -c "$CFG" daemon >/dev/null 2>&1 < /dev/null &
  }
  open_windows
}

stop() {
  if have_unit; then
    systemctl --user stop "$UNIT"
  else
    timeout 10 "$EWW" -c "$CFG" close-all >/dev/null 2>&1 < /dev/null || true
    timeout 10 "$EWW" -c "$CFG" kill      >/dev/null 2>&1 < /dev/null || true
  fi
  kill_stray
  echo "cluster stopped"
}

case "${1:-start}" in
  start)   start ;;
  stop)    stop ;;
  open)    open_windows ;;
  reload)  timeout 20 "$EWW" -c "$CFG" reload >/dev/null 2>&1 < /dev/null; sleep 0.5; open_windows ;;
  restart) stop; sleep 1; start ;;
  status)  timeout 10 "$EWW" -c "$CFG" active-windows 2>/dev/null < /dev/null || echo "not running" ;;
  *)       echo "usage: ${0##*/} start|stop|reload|restart|status|open" >&2; exit 2 ;;
esac
