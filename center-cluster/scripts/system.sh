#!/bin/bash
# Volume and microphone readout/control via pactl (PipeWire-pulse on Pop!_OS).
set -u

level() { # <get-subcommand> <device>
  local v
  v=$(pactl "$1" "$2" 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%')
  echo "${v:-0}"
}

muted() { pactl "$1" "$2" 2>/dev/null | grep -q yes; }

case "${1:-}" in
  volume)
    muted get-sink-mute @DEFAULT_SINK@ && echo 0 || level get-sink-volume @DEFAULT_SINK@ ;;
  mic)
    muted get-source-mute @DEFAULT_SOURCE@ && echo 0 || level get-source-volume @DEFAULT_SOURCE@ ;;
  set-volume)
    pactl set-sink-mute   @DEFAULT_SINK@   0
    pactl set-sink-volume @DEFAULT_SINK@   "${2:-0}%" ;;
  set-mic)
    pactl set-source-mute   @DEFAULT_SOURCE@ 0
    pactl set-source-volume @DEFAULT_SOURCE@ "${2:-0}%" ;;
  *) echo "usage: ${0##*/} volume|mic|set-volume N|set-mic N" >&2; exit 2 ;;
esac
