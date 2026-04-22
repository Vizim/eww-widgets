#!/usr/bin/env bash
# =============================================================================
# CONFIG — change this to update the name across all greetings
# =============================================================================
NAME="Zain"
# =============================================================================

CACHE_FILE="$HOME/.cache/eww-last-greeting.txt"
HOUR=$(date +%H)

# ── Time-bucket phrase pools ──────────────────────────────────────────────────

early_morning=(
  "Up late, $NAME?"
  "Burning the midnight oil, $NAME"
  "Still going, $NAME?"
  "Late night session, $NAME?"
  "Can't sleep, $NAME?"
  "The world is quiet now, $NAME"
  "Just you and the screen, $NAME"
  "Midnight grind, $NAME"
  "$NAME, it's very late"
  "You're dedicated, $NAME"
  "The night owl strikes again, $NAME"
  "Dark outside, bright screen, $NAME"
  "Another late one, $NAME?"
  "$NAME, go to sleep soon"
  "Pushing through the night, $NAME?"
  "Deep focus hours, $NAME"
  "The quiet hours, $NAME"
  "Stars are out, $NAME"
)

morning=(
  "Good morning, $NAME"
  "Morning, $NAME"
  "Rise and shine, $NAME"
  "Hey, good morning $NAME"
  "A fresh start, $NAME"
  "Today's yours, $NAME"
  "Up and at it, $NAME"
  "Let's get it, $NAME"
  "New day, $NAME"
  "Make it count, $NAME"
  "Morning energy, $NAME"
  "Ready to go, $NAME?"
  "$NAME, the day awaits"
  "Fresh morning, $NAME"
  "Coffee time, $NAME?"
  "Another day, another win, $NAME"
  "Start strong, $NAME"
  "The morning is yours, $NAME"
  "Good to see you, $NAME"
  "$NAME, let's have a great day"
)

afternoon=(
  "Good afternoon, $NAME"
  "Hey, $NAME"
  "Welcome back, $NAME"
  "Afternoon, $NAME"
  "How's the day going, $NAME?"
  "Halfway through, $NAME"
  "Keep it up, $NAME"
  "$NAME, you're doing great"
  "Afternoon grind, $NAME"
  "Still crushing it, $NAME?"
  "The day is still young, $NAME"
  "Locked in, $NAME?"
  "Back at it, $NAME"
  "Productive afternoon, $NAME?"
  "What's next, $NAME?"
  "Deep in the zone, $NAME"
  "$NAME, the afternoon is yours"
  "Making moves, $NAME"
  "Hey there, $NAME"
  "$NAME, keep going"
)

evening=(
  "Good evening, $NAME"
  "Evening, $NAME"
  "Hey there, $NAME"
  "Welcome home, $NAME"
  "Winding down, $NAME?"
  "How was your day, $NAME?"
  "Time to relax, $NAME"
  "Evening vibes, $NAME"
  "You made it, $NAME"
  "The day is done, $NAME"
  "Rest up, $NAME"
  "$NAME, the evening is yours"
  "Take it easy, $NAME"
  "Decompress, $NAME"
  "Nice work today, $NAME"
  "$NAME, you earned this"
  "Chill time, $NAME"
  "Evening check-in, $NAME"
  "Sunset hours, $NAME"
  "Slow down, $NAME"
)

night=(
  "Good night soon, $NAME?"
  "Winding down, $NAME?"
  "Late night, $NAME"
  "Night owl mode, $NAME"
  "Getting late, $NAME"
  "Last stretch of the day, $NAME"
  "$NAME, don't stay up too late"
  "Almost time to rest, $NAME"
  "Night mode, $NAME"
  "The day is almost over, $NAME"
  "Wrapping up, $NAME?"
  "$NAME, tomorrow needs you rested"
  "One more thing then sleep, $NAME?"
  "Night shift, $NAME?"
  "Quiet evening, $NAME"
  "$NAME, the night is peaceful"
  "Dim the lights, $NAME"
  "Signing off soon, $NAME?"
  "Stars are out, $NAME"
  "Rest is productive too, $NAME"
)

# ── Pick the correct pool ─────────────────────────────────────────────────────

if   (( HOUR >= 0  && HOUR <= 5  )); then pool=("${early_morning[@]}")
elif (( HOUR >= 6  && HOUR <= 11 )); then pool=("${morning[@]}")
elif (( HOUR >= 12 && HOUR <= 16 )); then pool=("${afternoon[@]}")
elif (( HOUR >= 17 && HOUR <= 20 )); then pool=("${evening[@]}")
else                                      pool=("${night[@]}")
fi

# ── Pick a random phrase, avoid repeating the last one ───────────────────────

last=""
[[ -f "$CACHE_FILE" ]] && last=$(cat "$CACHE_FILE")

count=${#pool[@]}
phrase="${pool[RANDOM % count]}"

# Re-roll once if we hit the same phrase
if [[ "$phrase" == "$last" && $count -gt 1 ]]; then
  phrase="${pool[RANDOM % count]}"
fi

echo "$phrase" > "$CACHE_FILE"
printf '%s' "$phrase"
