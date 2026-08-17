#!/bin/bash
# Thin wrapper over the greeting-module scripts so the cluster reuses them
# instead of duplicating the phrase pools.
#
# Two things are normalised here:
#  - output is folded to a fixed column count. eww's :limit-width truncates the
#    string with an ellipsis rather than setting a wrap width, so the line
#    breaks have to come from the text itself. The widths are chosen to fit the
#    profile card without widening its window (see the note in eww.yuck).
#  - the quote API returns em dashes and curly quotes; those become ASCII.
set -u

MOD="${GREETING_MODULE:-$HOME/Desktop/eww-widgets/greeting-module}"

ascii() {
  sed -e 's/\xe2\x80\x94/-/g'   \
      -e 's/\xe2\x80\x93/-/g'   \
      -e "s/\xe2\x80\x98/'/g"   \
      -e "s/\xe2\x80\x99/'/g"   \
      -e 's/\xe2\x80\x9c/"/g'   \
      -e 's/\xe2\x80\x9d/"/g'   \
      -e 's/\xe2\x80\xa6/.../g'
}

# Fold to COLS, then force exactly LINES lines (truncating or padding with blank
# lines). The constant line count matters: on a translucent panel a label that
# shrinks leaves its old glyphs behind, because the region it gave up is never
# repainted. Fixing the height means nothing is ever vacated.
block() { # <cols> <lines>
  ascii | fold -s -w "$1" | sed 's/[[:space:]]*$//' \
    | awk -v n="$2" '{ if (NR <= n) print } END { for (i = NR + 1; i <= n; i++) print "" }'
}

case "${1:-}" in
  greeting)
    [ -f "$MOD/greeting.sh" ] || { printf '\n'; exit 0; }
    bash "$MOD/greeting.sh" | block "${GREETING_COLS:-22}" "${GREETING_LINES:-2}" ;;
  quote)
    [ -f "$MOD/quote.sh" ] || { printf '\n\n\n\n'; exit 0; }
    bash "$MOD/quote.sh" | block "${QUOTE_COLS:-28}" "${QUOTE_LINES:-4}" ;;
  *)
    echo "usage: ${0##*/} greeting|quote" >&2; exit 2 ;;
esac
