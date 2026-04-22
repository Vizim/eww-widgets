#!/usr/bin/env bash
# =============================================================================
# Fetches a filtered quote and caches it for 24 hours.
# Categories: science, philosophy, politics, history, technology
# Output format:  "Quote text" — Author
# =============================================================================

CACHE_FILE="$HOME/.cache/eww-quote.txt"
MAX_AGE=86400  # 24 hours in seconds

# Pipe-separated tags for quotable.io — add or remove as you like
TAGS="science|philosophy|politics|history|technology"

# ── Check whether the cache is fresh ─────────────────────────────────────────

fetch_needed=true

if [[ -f "$CACHE_FILE" ]]; then
  file_age=$(( $(date +%s) - $(date -r "$CACHE_FILE" +%s) ))
  (( file_age < MAX_AGE )) && fetch_needed=false
fi

# ── Fetch a fresh quote if stale ─────────────────────────────────────────────

if $fetch_needed; then
  # Primary: quotable.io with category filter
  raw=$(curl -sf --max-time 5 \
    "https://api.quotable.io/random?tags=${TAGS}" 2>/dev/null)

  if [[ -n "$raw" ]]; then
    quote=$(echo "$raw" | grep -oP '"content":"\K[^"]+')
    author=$(echo "$raw" | grep -oP '"author":"\K[^"]+')
  fi

  # Fallback: zenquotes (no filtering, but better than nothing)
  if [[ -z "$quote" ]]; then
    raw=$(curl -sf --max-time 5 "https://zenquotes.io/api/random" 2>/dev/null)
    quote=$(echo "$raw" | grep -oP '"q":"\K[^"]+')
    author=$(echo "$raw" | grep -oP '"a":"\K[^"]+')
  fi

  if [[ -n "$quote" && -n "$author" ]]; then
    printf '"%s" — %s' "$quote" "$author" > "$CACHE_FILE"
  elif [[ ! -f "$CACHE_FILE" ]]; then
    # Offline with no cache — curated static fallbacks
    fallbacks=(
      '"The universe is under no obligation to make sense to you." — Neil deGrasse Tyson'
      '"The only true wisdom is in knowing you know nothing." — Socrates'
      '"Science is not only compatible with spirituality; it is a profound source of spirituality." — Carl Sagan'
      '"Those who cannot remember the past are condemned to repeat it." — George Santayana'
      '"The measure of a man is what he does with power." — Plato'
      '"In the middle of difficulty lies opportunity." — Albert Einstein'
    )
    echo "${fallbacks[RANDOM % ${#fallbacks[@]}]}" > "$CACHE_FILE"
  fi
fi

# ── Output ───────────────────────────────────────────────────────────────────

cat "$CACHE_FILE"
