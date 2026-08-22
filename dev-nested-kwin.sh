#!/usr/bin/env bash
# Launches a disposable, nested KWin Wayland compositor (in its own D-Bus
# session) for safely testing Snap Assist without touching your real,
# running Plasma session. If it crashes or misbehaves, only this test
# window is affected.
#
# Confirmed live via `kwin_wayland --help`: `-s`/`--socket <socket>` names
# the socket this instance listens on ("If not set 'wayland-0' is used").
# `--wayland-display <display>` is NOT for that - it's "The Wayland Display
# to use in windowed mode", i.e. which *host* compositor to connect to as a
# client. Passing the desired socket name to `--wayland-display` (an earlier
# version of this script did) makes kwin_wayland try to connect to a
# nonexistent host display, then fall back to listening on the default
# "wayland-0" - colliding with the real, already-running session compositor
# ("unable to lock lockfile .../wayland-0.lock, maybe another compositor is
# running").
set -euo pipefail

SOCKET_NAME="${1:-snapassist-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting nested KWin Wayland on socket '$SOCKET_NAME'..."
echo "Once it's up, in another terminal run apps against it with:"
echo "  WAYLAND_DISPLAY=$SOCKET_NAME <app>"
echo "And install/enable the script inside it with:"
echo "  WAYLAND_DISPLAY=$SOCKET_NAME $SCRIPT_DIR/install.sh"
echo

exec dbus-run-session -- kwin_wayland \
    --width 1600 --height 900 \
    --socket "$SOCKET_NAME"
