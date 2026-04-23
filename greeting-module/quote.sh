#!/usr/bin/env bash
# =============================================================================
# Fetches a fresh quote every poll; falls back to cache on network failure.
# Output format:  "Quote text" — Author
# =============================================================================

CACHE_FILE="$HOME/.cache/eww-quote.txt"

quote=""
author=""

raw=$(curl -sf --max-time 5 "https://zenquotes.io/api/random" 2>/dev/null)
quote=$(echo "$raw" | grep -oP '"q":"\K[^"]+')
author=$(echo "$raw" | grep -oP '"a":"\K[^"]+')

if [[ -n "$quote" && -n "$author" ]]; then
  printf '"%s" — %s' "$quote" "$author" > "$CACHE_FILE"
elif [[ -f "$CACHE_FILE" ]]; then
  cat "$CACHE_FILE"
  exit 0
else
  fallbacks=(
    '"The only true wisdom is in knowing you know nothing." — Socrates'
    '"In the middle of difficulty lies opportunity." — Albert Einstein'
    '"The universe is under no obligation to make sense to you." — Neil deGrasse Tyson'
    '"Those who cannot remember the past are condemned to repeat it." — George Santayana'
    '"Science is not only compatible with spirituality; it is a profound source of spirituality." — Carl Sagan'
    '"The measure of a man is what he does with power." — Plato'
  )
  echo "${fallbacks[RANDOM % ${#fallbacks[@]}]}"
  exit 0
fi

cat "$CACHE_FILE"
