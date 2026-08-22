# Snap Assist for KDE Plasma (Wayland)

A Windows-11-style "Snap Assist" for KDE Plasma 6 / KWin on Wayland: when you
snap a window to a screen half or corner (drag-to-edge or `Meta+Arrow`), a
popup offers your other open windows as thumbnails so you can click (or
arrow-key + Enter) one to fill the remaining free space.

Built from scratch for current Plasma (developed against Plasma 6.7.4 / KWin
6.7.4), grounded in the KWin scripting/effect APIs actually shipped on that
version - not a fork of any existing project.

## How it works

Two independent packages:

- **`kwin-script/org.kde.snapassist`** (required) - a KWin Script
  (`X-Plasma-API: declarativescript`) that detects quick-tiling via
  `Window.quickTileModeChanged`, computes the remaining free rectangle, and
  shows a popup (`PlasmaCore.Dialog`) with `KWin.WindowThumbnail` tiles of
  your other open windows. Picking one sets its `frameGeometry` to fill the
  space.
- **`effect/org.kde.snapassist.placementeffect`** (optional, disabled by
  default) - a small JS-scripted KWin Effect that smoothly animates any
  window's geometry change, modeled on KWin's own shipped `maximize` effect.
  Purely cosmetic; needs no coordination with the script.

A plain JS scripted effect can only animate existing windows, not draw a
custom popup with live thumbnails - which is why the thumbnail picker has to
be the KWin Script (able to host arbitrary QML UI), while the effect stays a
separate, optional add-on purely for animation polish.

## Install

```sh
./install.sh              # installs and enables the script only
./install.sh --with-effect  # also installs the optional placement animation
```

This installs per-user (`~/.local/share/kwin/scripts/...`), no root needed.
Settings are reachable under System Settings > Window Management > KWin
Scripts. If installed with `--with-effect`, the placement animation can be
toggled on/off under System Settings > Desktop Effects (search "Snap Assist
Placement Animation").

To remove: `./uninstall.sh`.

## Configuration

- **Enabled** - master on/off switch.
- **Also show for quarter-tiled (corner) windows** - if disabled, Snap
  Assist only triggers for half-tiles (left/right), not corner quarter-tiles.
- **Trigger delay** - debounce between the snap finishing and the popup
  appearing.

The popup stays open until you click outside it or press Escape - it does
not auto-dismiss.

## Development / testing safely

Don't reload or replace KWin on your live session while iterating - use the
nested test compositor instead:

```sh
./dev-nested-kwin.sh
```

This starts a disposable, windowed KWin Wayland instance in its own D-Bus
session; if it crashes, only that test window is affected. Install/test the
script inside it with `WAYLAND_DISPLAY=snapassist-dev ./install.sh`.

For faster iteration once the basics work, reload just the script via D-Bus
instead of a full compositor restart:

```sh
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript org.kde.snapassist
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadDeclarativeScript \
    "$HOME/.local/share/kwin/scripts/org.kde.snapassist/contents/ui/main.qml" org.kde.snapassist
```

Note: use `loadDeclarativeScript`, not `loadScript` - the latter parses the
file as plain JavaScript and fails on the leading `import` statements this
QML-based package needs.

**Do not use System Settings > Window Management > KWin Scripts (the
checkbox/Apply button) to reload after editing code.** It goes through
`reconfigure()`, which reuses a stale in-memory compiled copy of the script
for the lifetime of the running KWin process - confirmed live even with the
on-disk QML cache (`~/.cache/kwin/qmlcache`) fully cleared. Once a session
has loaded a buggy version this way, only an explicit
`unloadScript`/`loadDeclarativeScript` cycle (what `install.sh` and the
snippet above do) gets the fresh code running again; toggling the KCM
checkbox will not. Use `./install.sh` (or the snippet above) exclusively
while iterating in a live session.

Live debug console (inspect `quickTileMode` values while manually snapping
windows, and see `console.log` output):

```sh
qdbus org.kde.KWin /KWin org.kde.KWin.showDebugConsole
```

## Related projects

[kde-snap-assist](https://github.com/emvaized/kde-snap-assist) by emvaized
covers the same idea for KDE Plasma. This project is an independent
implementation, built from scratch against the Plasma 6.7.4 / KWin 6.7.4
scripting APIs.

## License

GPL-2.0-or-later, see [LICENSE](LICENSE).
