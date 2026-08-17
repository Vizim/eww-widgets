#!/bin/bash
# Launchers for the center-cluster app row, resolved against this machine.
# All five apps single-instance themselves, so re-running focuses the open window.
set -u

launch() { setsid -f "$@" >/dev/null 2>&1 & }

case "${1:-}" in
  --files)    launch cosmic-files "$HOME" ;;                          # COSMIC file manager
  --vscode)   launch code ;;                                  # deb, /usr/bin/code
  --discord)  launch flatpak run com.discordapp.Discord ;;    # flatpak
  --warp)     launch warp-terminal ;;                         # deb, /usr/bin/warp-terminal
  --firefox)  launch firefox ;;                               # deb, /usr/bin/firefox
  --obsidian) launch flatpak run md.obsidian.Obsidian ;;      # flatpak
  --terminal) launch warp-terminal ;;                         # terminal tile on the profile card
  --url)      launch firefox "${2:-about:blank}" ;;
  *)
    echo "usage: ${0##*/} --files|--vscode|--discord|--warp|--firefox|--obsidian|--terminal|--url URL" >&2
    exit 2 ;;
esac
