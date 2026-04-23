#!/usr/bin/env bash
# Fetches a fresh quote each poll; falls back to cache on network failure.
# Output format:  "Quote text" — Author

CACHE_FILE="$HOME/.cache/eww-quote.txt"

raw=$(curl -sf --max-time 5 "https://zenquotes.io/api/random" 2>/dev/null)

if [[ -n "$raw" ]]; then
  quote=$(jq -r '.[0].q' <<< "$raw" 2>/dev/null)
  author=$(jq -r '.[0].a' <<< "$raw" 2>/dev/null)
fi

if [[ -n "$quote" && -n "$author" && "$quote" != "null" ]]; then
  result=$(printf '"%s" — %s' "$quote" "$author")
  echo "$result" > "$CACHE_FILE"
  echo "$result"
  exit 0
fi

if [[ -f "$CACHE_FILE" ]]; then
  cat "$CACHE_FILE"
  exit 0
fi

fallbacks=(
  '"The only true wisdom is in knowing you know nothing." — Socrates'
  '"In the middle of difficulty lies opportunity." — Albert Einstein'
  '"The universe is under no obligation to make sense to you." — Neil deGrasse Tyson'
  '"Those who cannot remember the past are condemned to repeat it." — George Santayana'
  '"Science is not only compatible with spirituality; it is a profound source of spirituality." — Carl Sagan'
  '"The measure of a man is what he does with power." — Plato'
)
echo "${fallbacks[RANDOM % ${#fallbacks[@]}]}"
