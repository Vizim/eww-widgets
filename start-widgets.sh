#!/bin/bash
# Login entry point (see ~/.config/systemd/user/eww-widgets.service).
#
# This only delegates to the cluster launcher so there is exactly one place that
# knows the window list. Running it twice is safe: cluster.sh tears down any
# existing daemon before starting, so a second set of windows cannot appear.
set -u

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"

CLUSTER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/center-cluster/cluster.sh"

# Give the COSMIC session time to bring up the compositor and its layer shell.
sleep 5

exec "$CLUSTER" restart
