# Greeting Module

A centered Eww widget that displays a time-aware personal greeting and a cached quote of the day.

---

## Files

| File | Purpose |
|---|---|
| `eww.yuck` | Widget and window definitions |
| `eww.scss` | Styles for greeting and quote labels |
| `greeting.sh` | Time-bucket greeting logic with non-repeating random selection |
| `quote.sh` | Quote fetcher with 24-hour file cache and offline fallback |
| `eww-quote-cache.service` | Systemd service to pre-warm the quote cache at login |
| `eww-quote-cache.timer` | Systemd timer to refresh the cache once daily |

---

## Configuration

### Changing the name
Open `greeting.sh` and change the single variable at the top:
```bash
NAME="Zain"
```

### Colour / font tweaks
Edit `eww.scss`. The two key classes are:
```scss
.greeting-label { font-size: 52px; ... }
.quote-label    { font-size: 16px; ... }
```

---

## Usage

**Install scripts** (copy to your Eww config or symlink):
```bash
cp greeting.sh quote.sh ~/.config/eww/greeting-module/
chmod +x ~/.config/eww/greeting-module/*.sh
```

**Start the widget:**
```bash
eww -c ~/Desktop/eww-widgets/greeting-module open greeting
```

**Close:**
```bash
eww -c ~/Desktop/eww-widgets/greeting-module close greeting
```

**Test the greeting script manually:**
```bash
bash ~/Desktop/eww-widgets/greeting-module/greeting.sh
```

**Test the quote script manually:**
```bash
bash ~/Desktop/eww-widgets/greeting-module/quote.sh
```

**Force a fresh quote fetch** (delete the cache):
```bash
rm ~/.cache/eww-quote.txt
bash ~/Desktop/eww-widgets/greeting-module/quote.sh
```

---

## Systemd Setup (quote cache pre-warm + daily refresh)

```bash
# Copy units to systemd user directory
cp eww-quote-cache.service eww-quote-cache.timer ~/.config/systemd/user/

# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now eww-quote-cache.timer

# Verify timer
systemctl --user status eww-quote-cache.timer
```

The timer fires 30 seconds after login and then every 24 hours. The service calls `quote.sh` which skips the network request if the cache is already fresh.

---

## How It Works

### Greeting
- `greeting.sh` reads the current hour and picks one of 5 phrase pools (early morning / morning / afternoon / evening / night).
- A phrase is picked at random. If it matches the last shown phrase (stored in `~/.cache/eww-last-greeting.txt`), it re-rolls once.
- Eww polls the script every **1 hour** so the greeting shifts naturally with the time of day.

### Quote
- `quote.sh` checks the age of `~/.cache/eww-quote.txt`.
- If older than 24 hours (or missing), it fetches from **zenquotes.io** (primary) with **quotable.io** as a fallback.
- If both APIs are unreachable and no cache exists, a static fallback quote is used so the widget never shows blank.
- Eww polls every **30 minutes** — the script handles the actual 24 hr gate internally.
