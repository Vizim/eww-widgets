#!/bin/bash
# Retint the cluster from the current COSMIC wallpaper.
#
# Reads the active wallpaper out of the COSMIC background config, finds its
# dominant hue, and rewrites the AUTO-PALETTE block in eww.scss with a palette
# built around that hue. Saturation and lightness are pinned to the values
# sampled from the reference dashboard, so only the hue travels: the cluster
# picks up the wallpaper's colour family without drifting off the reference look.
#
#   ./scripts/theme-from-wallpaper.sh                    # use the COSMIC wallpaper
#   ./scripts/theme-from-wallpaper.sh path/to.jpg        # use a specific image
#   HUE=280 ./scripts/theme-from-wallpaper.sh            # force a hue, skip sampling
#   THEME_MODE=light ./scripts/theme-from-wallpaper.sh   # light panels (reference look)
#
# THEME_MODE picks whether the panels are a dark tint (default) or the
# reference's light one. Run scripts/sync-icons.sh with the same THEME_MODE
# afterwards so the transport glyphs are tinted for the right background.
#
# Everything outside the AUTO-PALETTE markers (alpha, radius, font, sizes) is
# hand-editable and is never touched by this script.
set -eu

CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCSS="$CFG/eww.scss"

wallpaper() {
  [ $# -gt 0 ] && { echo "$1"; return; }
  local conf="$HOME/.config/cosmic/com.system76.CosmicBackground/v1/all"
  [ -f "$conf" ] && sed -n 's/.*source:[[:space:]]*Path("\([^"]*\)").*/\1/p' "$conf" | head -1
}

WALL="$(wallpaper "$@")"

SCSS="$SCSS" WALL="${WALL:-}" HUE="${HUE:-}" MODE="${THEME_MODE:-dark}" python3 - <<'PY'
import colorsys, os, re, sys
from collections import Counter

SCSS = os.environ['SCSS']
WALL = os.environ['WALL']
FORCED = os.environ.get('HUE') or ''
MODE   = os.environ.get('MODE', 'dark')

def hexc(h, s, l):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360.0, l, s)
    return '#%02x%02x%02x' % (round(r * 255), round(g * 255), round(b * 255))

def dominant_hue(path):
    from PIL import Image
    im = Image.open(path).convert('RGB')
    im.thumbnail((160, 160))
    # Weight each pixel's hue by how colourful and mid-toned it is, so a big
    # flat dark area cannot outvote the image's actual colour.
    buckets = Counter()
    for r, g, b in im.getdata():
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        if s < 0.15 or l < 0.12 or l > 0.92:
            continue
        buckets[round(h * 360 / 10) * 10] += s * (1 - abs(l - 0.5) * 1.2)
    if not buckets:
        return None
    return buckets.most_common(1)[0][0]

if FORCED:
    hue, src = float(FORCED), f'forced HUE={FORCED}'
elif WALL and os.path.exists(WALL):
    h = dominant_hue(WALL)
    if h is None:
        hue, src = 262.0, f'{os.path.basename(WALL)} (no usable colour, kept reference hue)'
    else:
        hue, src = float(h), os.path.basename(WALL)
else:
    hue, src = 262.0, 'no wallpaper found, kept reference hue'

# Accent hue offsets and S/L come straight from the reference dashboard, whose
# panel sits at hue 262. Each offset is that colour's hue distance from the
# panel, so a new base hue rotates the palette as one piece.
#   panel   #9484ac hsl(262, 20%, 60%)   +0
#   uptime  #c04364 hsl(344, 50%, 51%)   +82
#   song    #8fbcbb hsl(178, 22%, 65%)   +276
#   artist  #ebcb8b hsl( 40, 71%, 73%)   +138
#   weather #e8dcc8 hsl( 36, 47%, 85%)   +134
ACCENTS = [
    ('$accent-uptime',  hexc(hue + 82,  0.50, 0.51)),
    ('$accent-song',    hexc(hue + 276, 0.22, 0.65)),
    ('$accent-artist',  hexc(hue + 138, 0.71, 0.73)),
    ('$accent-weather', hexc(hue + 134, 0.47, 0.85)),
]

# The surface set flips with THEME_MODE. Text and the panel swap ends of the
# lightness range; the transport disc always contrasts against the panel, and
# sync-icons.sh tints the play/pause glyph to sit on that disc.
if MODE == 'light':
    SURFACES = [
        ('$panel',         hexc(hue,     0.20, 0.60)),
        ('$ink',           hexc(hue,     0.18, 0.09)),
        ('$ink-soft',      hexc(hue,     0.14, 0.24)),
        ('$ring-inner',    hexc(hue + 2, 0.32, 0.74)),
        ('$ring-track',    hexc(hue,     0.06, 0.90)),
        ('$pill',          hexc(hue + 40, 0.20, 0.88)),
        ('$transport-bg',  hexc(hue,     0.10, 0.08)),
    ]
else:
    SURFACES = [
        ('$panel',         hexc(hue,      0.24, 0.11)),
        ('$ink',           hexc(hue,      0.20, 0.93)),
        ('$ink-soft',      hexc(hue,      0.16, 0.68)),
        ('$ring-inner',    hexc(hue + 2,  0.26, 0.26)),
        ('$ring-track',    hexc(hue,      0.12, 0.32)),
        ('$pill',          hexc(hue + 40, 0.16, 0.22)),
        ('$transport-bg',  hexc(hue,      0.18, 0.92)),
    ]

P = SURFACES + ACCENTS

block = ['  // AUTO-PALETTE START - written by scripts/theme-from-wallpaper.sh',
         f'  // source: {src}',
         f'  // base hue: {hue:.0f}   mode: {MODE}']
width = max(len(n) for n, _ in P)
block += [f'  {n:<{width}}: {v};' for n, v in P]
block.append('  // AUTO-PALETTE END')
new = '\n'.join(block)

css = open(SCSS, encoding='utf-8').read()
pat = re.compile(r'^[ \t]*// AUTO-PALETTE START.*?^[ \t]*// AUTO-PALETTE END[ \t]*$',
                 re.S | re.M)
if not pat.search(css):
    sys.exit('AUTO-PALETTE markers not found in eww.scss')
open(SCSS, 'w', encoding='utf-8').write(pat.sub(new, css))

print(f'source   : {src}')
print(f'base hue : {hue:.0f}')
print(f'mode     : {MODE}')
for n, v in P:
    print(f'  {n:<{width}} {v}')
PY

echo
echo "Rewrote the AUTO-PALETTE block in eww.scss. Apply it with:"
echo "  $CFG/cluster.sh reload"
