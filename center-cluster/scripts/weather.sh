#!/bin/bash
# Current conditions from open-meteo (no API key). Response is cached so the
# 4 poll subcommands cost one request per WEATHER_TTL, not one each.
#
#   weather.sh temp | cond | icon
#
# Location and units come from ~/.config/eww-widgets/local.env or the environment:
#   WEATHER_LAT, WEATHER_LON, WEATHER_UNIT (fahrenheit|celsius), WEATHER_TTL
set -u
[ -f "$HOME/.config/eww-widgets/local.env" ] && . "$HOME/.config/eww-widgets/local.env"

LAT="${WEATHER_LAT:-39.7392}"
LON="${WEATHER_LON:--104.9903}"
UNIT="${WEATHER_UNIT:-fahrenheit}"
TTL="${WEATHER_TTL:-900}"

CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/eww-center-cluster"
JSON="$CACHE/weather.json"
ICONS="$CFG/images/icons/weather"

mkdir -p "$CACHE"

fetch() {
  local url="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,weather_code,is_day&temperature_unit=${UNIT}"
  curl -fsS --max-time 8 "$url" -o "$JSON.part" 2>/dev/null && mv "$JSON.part" "$JSON" || rm -f "$JSON.part"
}

# Refresh only when the cache is missing or older than TTL.
if [ ! -s "$JSON" ] || [ "$(( $(date +%s) - $(stat -c %Y "$JSON") ))" -gt "$TTL" ]; then
  fetch
fi
[ -s "$JSON" ] || { echo "--"; exit 0; }

get() { jq -r ".current.$1 // empty" "$JSON" 2>/dev/null; }

code=$(get weather_code)
is_day=$(get is_day)

# WMO weather code -> label + icon basename (see open-meteo docs)
case "${code:-}" in
  0)                 label="Clear";      icon="clear" ;;
  1|2)               label="Partly sun"; icon="few-clouds" ;;
  3)                 label="Overcast";   icon="overcast" ;;
  45|48)             label="Fog";        icon="fog" ;;
  51|53|55|56|57)    label="Drizzle";    icon="showers-scattered" ;;
  61|63|65|66|67)    label="Rain";       icon="showers" ;;
  80|81|82)          label="Showers";    icon="showers" ;;
  71|73|75|77|85|86) label="Snow";       icon="snow" ;;
  95|96|99)          label="Storm";      icon="storm" ;;
  *)                 label="--";         icon="clear" ;;
esac

# Clear skies get a moon after dark.
[ "$icon" = clear ] && [ "${is_day:-1}" = 0 ] && icon="clear-night"

case "${1:-}" in
  temp)
    t=$(get temperature_2m)
    [ -n "$t" ] || { echo "--"; exit 0; }
    printf '%.0f%s\n' "$t" "$([ "$UNIT" = celsius ] && echo C || echo F)" ;;
  cond) echo "$label" ;;
  icon) echo "file://$ICONS/$icon.png" ;;
  *) echo "usage: ${0##*/} temp|cond|icon" >&2; exit 2 ;;
esac
