#!/bin/bash
# Set the ARMED variable that drives the power tiles' two-step confirm.
# Pass a tile name to arm it, or "none" to disarm.
set -u
CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EWW=$(command -v eww) || exit 0

val="${1:-none}"
[ "$val" = "none" ] && val=""
exec "$EWW" -c "$CFG" update "ARMED=$val"
