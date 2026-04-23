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

$EWW -c "$WIDGETS_DIR/clock-module" daemon
$EWW -c "$WIDGETS_DIR/stats-module" daemon
$EWW -c "$WIDGETS_DIR/greeting-module" daemon

sleep 2

$EWW -c "$WIDGETS_DIR/clock-module" open-many time-hour time-min time-sec date-month date-day
$EWW -c "$WIDGETS_DIR/stats-module" open stats-widget
$EWW -c "$WIDGETS_DIR/greeting-module" open greeting
