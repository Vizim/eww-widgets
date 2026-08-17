#!/bin/bash
# Build the three purple marks for the AI row on the profile card.
#
# These are vendor trademarks, so images/icons/ai/ is gitignored and this script
# is how you regenerate it after a fresh clone:
#
#   ./scripts/sync-ai-icons.sh
#   AI_TINT='#c4b5fd' ./scripts/sync-ai-icons.sh    # different purple
#
# Sources: Claude's app icon (fetched once and cached), the Hermes desktop app
# icon from a local Hermes install, and OpenAI's mark from the icon theme.
set -eu

CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$CFG/images/icons/ai/_src"
mkdir -p "$SRC" "$CFG/images/icons/ai"

CLAUDE_URL="${CLAUDE_ICON_URL:-https://claude.ai/images/claude_app_icon.png}"
if [ ! -s "$SRC/claude.png" ]; then
  echo "fetching Claude mark..."
  curl -fsSL --max-time 25 -A "Mozilla/5.0" "$CLAUDE_URL" -o "$SRC/claude.png" \
    || echo "  could not fetch (offline?) - Claude icon will be skipped" >&2
fi

CFG="$CFG" SRC="$SRC" TINT="${AI_TINT:-#a78bfa}" python3 - <<'PY'
import gi, io, os, sys
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf
from PIL import Image

CFG, SRC = os.environ['CFG'], os.environ['SRC']
t = os.environ['TINT'].lstrip('#')
TINT = tuple(int(t[i:i+2], 16) for i in (0, 2, 4))
COLLOID = os.path.expanduser('~/.local/share/icons/Colloid/apps/scalable')
HERMES = os.path.expanduser('~/.hermes/hermes-agent/apps/desktop/assets/icon.png')

# Every mark is reduced to the glyph alone - no app-icon plate behind it.
#   'dark'  glyph is darker than its plate     -> keep the dark pixels
#   'white' white glyph on a coloured plate    -> keep by min-channel, since a
#           saturated plate can be as bright as white and defeat a luma test
#   'cut'   coloured glyph on a pale plate     -> threshold the plate away
JOBS = [
    ('claude',  f'{SRC}/claude.png',      'cut'),    # sunburst on cream
    ('hermes',  HERMES,                   'dark'),   # ink drawing on a white plate
    ('chatgpt', f'{COLLOID}/openai.svg',  'white'),  # white knot on a green plate
]

for name, path, mode in JOBS:
    if not os.path.exists(path):
        print(f'  {name:8s} SKIPPED (missing {path})', file=sys.stderr)
        continue
    pb = GdkPixbuf.Pixbuf.new_from_file_at_size(path, 256, 256)
    im = Image.open(io.BytesIO(pb.save_to_bufferv('png', [], [])[1])).convert('RGBA')
    src_a = im.split()[3]
    flat = Image.new('RGBA', im.size, (255, 255, 255, 255))
    flat.alpha_composite(im)
    g = flat.convert('L')
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    op, gp, ap = out.load(), g.load(), src_a.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            lum = gp[x, y]
            if mode == 'dark':
                a = int(ap[x, y] * ((255 - lum) / 255))
            elif mode == 'white':
                r, g, b, _ = im.getpixel((x, y))
                a = max(0, min(255, int((min(r, g, b) - 120) * 255 / 80)))
            else:                                  # cut
                a = max(0, min(255, int((186 - lum) * 255 / 46)))
            if a > 8:
                op[x, y] = (*TINT, a)
    dest = os.path.join(CFG, 'images/icons/ai', f'{name}.png')
    out.save(dest)
    print(f'  {name:8s} {mode:5s} <- {path}')
PY
