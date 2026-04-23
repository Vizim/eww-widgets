#!/bin/bash
export DISPLAY=:0
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"

sleep 3

EWW=$(which eww 2>/dev/null)
if [[ -z "$EWW" ]]; then
  echo "eww not found in PATH" >&2
  exit 1
fi

WIDGETS_DIR="$HOME/Desktop/eww-widgets"

# Kill any stale daemons from a previous session
for mod in clock-module stats-module greeting-module; do
  $EWW -c "$WIDGETS_DIR/$mod" kill 2>/dev/null || true
done
sleep 0.5

# Start daemons
$EWW -c "$WIDGETS_DIR/clock-module"   daemon
$EWW -c "$WIDGETS_DIR/stats-module"   daemon
$EWW -c "$WIDGETS_DIR/greeting-module" daemon

# Wait for each daemon to be ready (up to 10s each)
wait_for_daemon() {
  local cfg="$1"
  local i=0
  until $EWW -c "$cfg" ping &>/dev/null; do
    (( ++i > 20 )) && { echo "eww daemon timeout: $cfg" >&2; return 1; }
    sleep 0.5
  done
}

wait_for_daemon "$WIDGETS_DIR/clock-module"
wait_for_daemon "$WIDGETS_DIR/stats-module"
wait_for_daemon "$WIDGETS_DIR/greeting-module"

# Open windows
$EWW -c "$WIDGETS_DIR/clock-module"    open-many time-hour time-min time-sec date-month date-day
$EWW -c "$WIDGETS_DIR/stats-module"    open stats-widget
$EWW -c "$WIDGETS_DIR/greeting-module" open greeting
