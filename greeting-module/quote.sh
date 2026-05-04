#!/usr/bin/env bash
# Fetches a fresh quote each poll; falls back to time-appropriate cache on failure.
# Output format:  "Quote text" — Author

CACHE_FILE="$HOME/.cache/eww-quote.txt"
HOUR=$(( 10#$(date +%H) ))

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

# Time-bucketed fallbacks
early_morning=(
  '"The secret of getting ahead is getting started." — Mark Twain'
  '"Either you run the day or the day runs you." — Jim Rohn'
  '"Lose an hour in the morning, and you will spend all day looking for it." — Richard Whately'
  '"Morning is an important time of day because how you spend your morning can often tell you what kind of day you are going to have." — Lemony Snicket'
  '"The early morning has gold in its mouth." — Benjamin Franklin'
)

morning=(
  '"Today is your opportunity to build the tomorrow you want." — Ken Poirot'
  '"Believe you can and you are halfway there." — Theodore Roosevelt'
  '"The only way to do great work is to love what you do." — Steve Jobs'
  '"Do something today that your future self will thank you for." — Sean Patrick Flanery'
  '"It always seems impossible until it is done." — Nelson Mandela'
  '"Start where you are. Use what you have. Do what you can." — Arthur Ashe'
  '"Great things never come from comfort zones." — Unknown'
)

afternoon=(
  '"Focus on being productive instead of busy." — Tim Ferriss'
  '"You dont have to be great to start, but you have to start to be great." — Zig Ziglar'
  '"Energy and persistence conquer all things." — Benjamin Franklin'
  '"The secret of your future is hidden in your daily routine." — Mike Murdock'
  '"Success is the sum of small efforts, repeated day in and day out." — Robert Collier'
  '"An investment in knowledge pays the best interest." — Benjamin Franklin'
  '"The harder you work, the luckier you get." — Gary Player'
)

evening=(
  '"The measure of a life is the measure of love and respect so it is." — Stevie Wonder'
  '"In the end, it is not the years in your life that count, it is the life in your years." — Abraham Lincoln'
  '"What we think, we become." — Buddha'
  '"The unexamined life is not worth living." — Socrates'
  '"Reflect upon your present blessings, of which every man has plenty." — Charles Dickens'
  '"Turn your wounds into wisdom." — Oprah Winfrey'
  '"We are what we repeatedly do. Excellence then is not an act, but a habit." — Aristotle'
)

night=(
  '"Rest when you are weary. Refresh and renew yourself, your body, your mind, your spirit." — Ralph Marston'
  '"Sleep is the best meditation." — Dalai Lama'
  '"A good laugh and a long sleep are the two best cures for anything." — Irish Proverb'
  '"Tomorrow is a new day with no mistakes in it yet." — L.M. Montgomery'
  '"The night is the hardest time to be alive and 4am knows all my secrets." — Poppy Z. Brite'
  '"End each day with a thought of gratitude." — Unknown'
  '"Let your dreams be your wings." — Unknown'
)

if   (( HOUR >= 0  && HOUR <= 5  )); then pool=("${early_morning[@]}")
elif (( HOUR >= 6  && HOUR <= 11 )); then pool=("${morning[@]}")
elif (( HOUR >= 12 && HOUR <= 16 )); then pool=("${afternoon[@]}")
elif (( HOUR >= 17 && HOUR <= 20 )); then pool=("${evening[@]}")
else                                      pool=("${night[@]}")
fi

echo "${pool[RANDOM % ${#pool[@]}]}"
