#!/usr/bin/env bash
# Removes the Snap Assist KWin script and companion effect for the current user.
set -euo pipefail

kpackagetool6 --type KWin/Script --remove org.kde.snapassist || true
kpackagetool6 --type KWin/Effect --remove org.kde.snapassist.placementeffect || true

qdbus org.kde.KWin /KWin org.kde.KWin.reconfigure

echo "Uninstalled."
