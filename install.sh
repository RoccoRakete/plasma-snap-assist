#!/usr/bin/env bash
# Installs the Snap Assist KWin script (and optionally its companion
# placement-animation effect) for the current user, then asks KWin to
# reload its configuration so the change takes effect.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PKG="$SCRIPT_DIR/kwin-script/org.kde.snapassist"
EFFECT_PKG="$SCRIPT_DIR/effect/org.kde.snapassist.placementeffect"

WITH_EFFECT=0
for arg in "$@"; do
    case "$arg" in
        --with-effect) WITH_EFFECT=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

install_or_upgrade() {
    local type="$1" pkg="$2"
    if kpackagetool6 --type "$type" --install "$pkg" 2>/dev/null; then
        echo "Installed: $pkg"
    else
        kpackagetool6 --type "$type" --upgrade "$pkg"
        echo "Upgraded: $pkg"
    fi
}

install_or_upgrade "KWin/Script" "$SCRIPT_PKG"
kwriteconfig6 --file kwinrc --group Plugins --key org.kde.snapassistEnabled true

if [ "$WITH_EFFECT" -eq 1 ]; then
    install_or_upgrade "KWin/Effect" "$EFFECT_PKG"
    kwriteconfig6 --file kwinrc --group Plugins --key org.kde.snapassist.placementeffectEnabled true
fi

# Deliberately NOT calling `qdbus org.kde.KWin /KWin org.kde.KWin.reconfigure`
# here: confirmed live that it triggers KWin's own internal script reload
# via a path that can serve a stale cached component even after a
# kpackagetool6 upgrade, re-introducing already-fixed bugs. The kwriteconfig6
# write above is enough for the enabled state to stick across future
# restarts; for *this* session, load the fresh code directly and explicitly.
# NOTE: loadDeclarativeScript (not loadScript) is required for this package's
# X-Plasma-API: declarativescript type - loadScript parses the file as plain
# JavaScript and fails on the leading `import` statements.
echo "Reloading script code..."
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript org.kde.snapassist >/dev/null
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadDeclarativeScript \
    "$HOME/.local/share/kwin/scripts/org.kde.snapassist/contents/ui/main.qml" org.kde.snapassist >/dev/null

echo "Done. Enable/tweak settings under System Settings > Window Management > KWin Scripts."
