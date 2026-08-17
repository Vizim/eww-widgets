#!/bin/bash
# Compact uptime for the profile card, e.g. "4 h 51 min" or "2 d 4 h".
set -u
secs=$(cut -d. -f1 /proc/uptime)
d=$(( secs / 86400 ))
h=$(( secs % 86400 / 3600 ))
m=$(( secs % 3600 / 60 ))

if   [ "$d" -gt 0 ]; then printf '%d d %d h\n'    "$d" "$h"
elif [ "$h" -gt 0 ]; then printf '%d h %d min\n'  "$h" "$m"
else                      printf '%d min\n'       "$m"
fi
