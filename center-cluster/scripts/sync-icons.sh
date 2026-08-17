#!/bin/bash
# Regenerate the cluster's app icons from the icon theme that is currently
# applied, resolving each app the same way the dock does: read Icon= from the
# app's desktop entry, then look that name up in the theme (with the theme's own
# inheritance and fallback). Rasterises through librsvg/gdk-pixbuf, the same
# renderer GTK uses, so vector icons stay crisp. Re-run after changing themes.
#
#   ./scripts/sync-icons.sh              # theme from gsettings
#   ICON_THEME=Papirus ./scripts/sync-icons.sh
set -eu

CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME="${ICON_THEME:-$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'\"")}"

CFG="$CFG" THEME="${THEME:-Adwaita}" SIZE="${ICON_SIZE:-256}" MODE="${THEME_MODE:-dark}" python3 - <<'PY'
import configparser, os, re, sys
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import Gtk, GdkPixbuf

CFG   = os.environ['CFG']
THEME = os.environ['THEME']
SIZE  = int(os.environ['SIZE'])
MODE  = os.environ.get('MODE', 'dark')

# tile -> (desktop entry basename, output path relative to CFG, icon-name override)
# The override forces a specific theme icon name instead of the entry's Icon=.
# Use it where the app ships its own branded icon but the theme has a styled
# equivalent we would rather have.
TILES = [
    ('files',    'com.system76.CosmicFiles', 'images/icons/apps/files.png',    'system-file-manager'),
    ('vscode',   'code',                     'images/icons/apps/vscode.png',   None),
    ('discord',  'com.discordapp.Discord',   'images/icons/apps/discord.png',  None),
    ('warp',     'dev.warp.Warp',            'images/icons/apps/warp.png',     None),
    ('firefox',  'firefox',                  'images/icons/apps/firefox.png',  None),
    ('obsidian', 'md.obsidian.Obsidian',     'images/icons/apps/obsidian.png', None),
]

# Monochrome icons pulled from the same theme and tinted. Keep these colours in
# step with the matching $p-* / $accent-* values in eww.scss.
SYMBOLIC = [
    ('shutdown', 'system-shutdown-symbolic',     '#ff7a5c', 'images/icons/system/shutdown.png'),
    ('suspend',  'weather-clear-night-symbolic', '#ffd166', 'images/icons/system/suspend.png'),
    ('logout',   'logout-symbolic',              '#4fc3e8', 'images/icons/system/logout.png'),
    ('reboot',   'view-refresh-symbolic',        '#7fd18a', 'images/icons/system/reboot.png'),
    ('volume',   'audio-volume-high-symbolic',      '#5c64ff', 'images/icons/ui/volume.png'),
    ('mic',      'audio-input-microphone-symbolic', '#85da6c', 'images/icons/ui/mic.png'),
    ('uptime',   'alarm-symbolic',                  '#c04364', 'images/icons/ui/uptime.png'),
]

# Transport glyphs flip with the theme mode: prev/next sit directly on the panel,
# play/pause sit on the $transport-bg disc, which is the panel's opposite.
_ON_PANEL = '#e9e6ef' if MODE != 'light' else '#151515'
_ON_DISC  = '#151515' if MODE != 'light' else '#ffffff'
SYMBOLIC += [
    ('prev',  'media-skip-backward-symbolic',  _ON_PANEL, 'images/icons/music/prev.png'),
    ('next',  'media-skip-forward-symbolic',   _ON_PANEL, 'images/icons/music/next.png'),
    ('play',  'media-playback-start-symbolic', _ON_DISC,  'images/icons/music/play.png'),
    ('pause', 'media-playback-pause-symbolic', _ON_DISC,  'images/icons/music/pause.png'),
]

# Weather glyphs, keyed by the basename scripts/weather.sh derives from the
# WMO code. Tinted to $accent-weather.
WEATHER_TINT = '#ebdbc7' if MODE == 'light' else '#e9dcc9'
WEATHER = [
    'clear', 'clear-night', 'few-clouds', 'overcast',
    'fog', 'showers', 'showers-scattered', 'snow', 'storm',
]

# Brand logos for the website tiles, taken from the theme where it has them.
# recolour: any strongly saturated pixel is flattened to this colour, leaving the
# white/near-white glyph alone. Colloid's whatsapp icon is a green rounded square
# with a white handset, and the green has to match the tile it sits on, so the
# square disappears into the tile. Keep in step with $c-whatsapp in eww.scss.
WEBSITES = [
    ('whatsapp', 'whatsapp-tray', 'images/icons/websites/whatsapp.png', None, '#ffffff'),
]

APP_DIRS = [
    '/usr/share/applications',
    os.path.expanduser('~/.local/share/applications'),
    '/var/lib/flatpak/exports/share/applications',
    os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
]

theme = Gtk.IconTheme.new()
theme.set_custom_theme(THEME)

# Some names the cluster needs (monochrome brand glyphs) are not in every theme,
# so fall back through these before giving up.
FALLBACK_THEMES = ['Papirus', 'Adwaita', 'hicolor']
_fallbacks = []
for _t in FALLBACK_THEMES:
    _th = Gtk.IconTheme.new()
    _th.set_custom_theme(_t)
    _fallbacks.append((_t, _th))


def icon_name(entry):
    """The Icon= value from the app's desktop entry, or the entry name itself."""
    for d in APP_DIRS:
        p = os.path.join(d, entry + '.desktop')
        if os.path.exists(p):
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            cp.read(p, encoding='utf-8')
            return cp.get('Desktop Entry', 'Icon', fallback=entry) or entry
    return entry


def resolve(name):
    if os.path.isabs(name) and os.path.exists(name):
        return name
    for th in [theme] + [t for _, t in _fallbacks]:
        for flags in (Gtk.IconLookupFlags.FORCE_SVG, 0):
            info = th.lookup_icon(name, SIZE, flags)
            if info and info.get_filename():
                return info.get_filename()
    for ext in ('svg', 'png'):
        p = f'/usr/share/pixmaps/{name}.{ext}'
        if os.path.exists(p):
            return p
    return None


def rasterize(src, out, size=SIZE, tint=None):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if tint:
        with open(src, encoding='utf-8') as fh:
            svg = fh.read()
        svg = re.sub(r'fill="#[0-9a-fA-F]{3,8}"', f'fill="{tint}"', svg)
        svg = re.sub(r'fill:\s*#[0-9a-fA-F]{3,8}', f'fill:{tint}', svg)
        if 'fill=' not in svg:                       # relies on currentColor
            svg = svg.replace('<svg ', f'<svg fill="{tint}" ', 1)
        loader = GdkPixbuf.PixbufLoader.new_with_type('svg')
        loader.set_size(size, size)
        loader.write(svg.encode('utf-8'))
        loader.close()
        return loader.get_pixbuf()
    # new_from_file_at_size rasterises SVGs at the target size (crisp, not upscaled)
    return GdkPixbuf.Pixbuf.new_from_file_at_size(src, size, size)


def flatten(path, hexrgb):
    """Repaint saturated pixels a flat colour, leaving white/grey glyphs intact.

    Colloid ships some brand icons as an embedded raster, so tinting the SVG's
    fill attributes does nothing; this works on the rendered pixels instead.
    """
    import colorsys
    from PIL import Image
    tr, tg, tb = (int(hexrgb[i:i + 2], 16) for i in (1, 3, 5))
    im = Image.open(path).convert('RGBA')
    out = []
    for r, g, b, a in im.getdata():
        _, _, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        out.append((tr, tg, tb, a) if s > 0.25 else (r, g, b, a))
    im.putdata(out)
    im.save(path)


print(f'icon theme: {THEME}')
failed = 0

print('  -- app icons (via each app\'s desktop entry) --')
for tile, entry, rel, override in TILES:
    src = resolve(override) if override else None
    if src is None:
        src = resolve(icon_name(entry))
    if not src:
        print(f'  {tile:9s} NO ICON FOUND for {entry} (kept existing)', file=sys.stderr)
        failed += 1
        continue
    pb = rasterize(src, os.path.join(CFG, rel))
    pb.savev(os.path.join(CFG, rel), 'png', [], [])
    origin = THEME if f'/icons/{THEME}/' in src else 'fallback'
    print(f'  {tile:9s} {origin:9s} {pb.get_width()}x{pb.get_height()}  {src}')

print('  -- website logos --')
for tile, name, rel, recolour, tint in WEBSITES:
    src = resolve(name)
    if not src:
        print(f'  {tile:9s} NO ICON FOUND for {name} (kept existing)', file=sys.stderr)
        failed += 1
        continue
    out = os.path.join(CFG, rel)
    pb = rasterize(src, out, tint=tint)
    pb.savev(out, 'png', [], [])
    if recolour:
        flatten(out, recolour)
    origin = THEME if f'/icons/{THEME}/' in src else 'fallback'
    print(f'  {tile:9s} {origin:9s} {tint or recolour or ""}  {src}')

print('  -- symbolic icons (tinted) --')
for tile, name, tint, rel in SYMBOLIC:
    src = resolve(name)
    if not src:
        print(f'  {tile:9s} NO ICON FOUND for {name} (kept existing)', file=sys.stderr)
        failed += 1
        continue
    out = os.path.join(CFG, rel)
    pb = rasterize(src, out, tint=tint)
    pb.savev(out, 'png', [], [])
    origin = THEME if f'/icons/{THEME}/' in src else 'fallback'
    print(f'  {tile:9s} {origin:9s} {tint}  {src}')

print('  -- weather glyphs (tinted) --')
made = []
for base in WEATHER:
    src = resolve(f'weather-{base}-symbolic')
    if not src:
        print(f'  weather-{base}: NOT FOUND', file=sys.stderr)
        failed += 1
        continue
    out = os.path.join(CFG, 'images/icons/weather', f'{base}.png')
    pb = rasterize(src, out, tint=WEATHER_TINT)
    pb.savev(out, 'png', [], [])
    made.append(base)
print(f'  {len(made)} glyphs: {" ".join(made)}')

sys.exit(1 if failed else 0)
PY
