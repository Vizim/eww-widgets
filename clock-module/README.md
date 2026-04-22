# BC-Lock — Eww Block Clock

A Rainmeter BC-lock inspired block clock for [Eww](https://github.com/elkowar/eww).

Each time and date element is a semi-transparent progress bar rendered as its own independent Eww window. The windows can be layered on top of each other to recreate the original composite block effect, or spread across the desktop to show each element individually.

---

## Files

| File | Purpose |
|---|---|
| `eww.yuck` | Widget definitions, poll variables, and window declarations |
| `eww.scss` | Styling — including the two-variable colour palette |

---

## Elements

| Window name | What it tracks | Fill direction |
|---|---|---|
| `time-hour` | Current hour (0–23) | Left → Right |
| `time-min` | Current minute (0–59) | Top → Bottom |
| `time-sec` | Current second (0–59) | Right → Left |
| `date-month` | Month (1–12) | Right → Left |
| `date-day` | Day of the month (1–31) | Bottom → Top |

---

## Usage

**Start all windows:**
```bash
eww -c ~/Desktop/eww-widgets/clock-module open-many \
  time-hour time-min time-sec date-month date-day
```

**Close all windows:**
```bash
eww -c ~/Desktop/eww-widgets/clock-module close-all
```

**Toggle debug labels** (shows HR / MIN / SEC / MON / DAY tags):
```bash
# Show labels
eww -c ~/Desktop/eww-widgets/clock-module update debug=true

# Hide labels
eww -c ~/Desktop/eww-widgets/clock-module update debug=false
```

---

## Customising the Colour Palette

Open `eww.scss` and change the two variables at the very top:

```scss
$color-primary:   #fcf083;   // Main hue  (hour, sec, day)
$color-secondary: #fcf083;   // Accent hue (min, month)
```

That's it — all 5 elements update automatically. Each element keeps a unique opacity so the layered blending effect is preserved regardless of what colour you pick.

**Example palettes:**

| Look | Primary | Secondary |
|---|---|---|
| Teal & Lemon | `#00d2c8` | `#fcf083` |
| All Yellow | `#fcf083` | `#fcf083` |
| Pink & Purple | `#ec4899` | `#a855f7` |
| White glass | `#ffffff` | `#ffffff` |

---

## Repositioning Elements

Each window is positioned individually. To move a specific element, edit the `:geometry` line in its `(defwindow ...)` block in `eww.yuck`:

```yuck
(defwindow time-hour
  :monitor 0
  :geometry (geometry :x "0px" :y "0px" :width "300px" :height "300px" :anchor "center")
  ...)
```

Change `:anchor` to any of: `center`, `top left`, `top right`, `bottom left`, `bottom right`, etc., and adjust `:x` / `:y` to offset from that anchor.

---

## Dependencies

- [Eww](https://github.com/elkowar/eww) (ElKowar's Wacky Widgets)
- `date` (standard GNU coreutils — available on all Linux systems)

No additional packages required.
