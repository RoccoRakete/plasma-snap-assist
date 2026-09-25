# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Approach
- Read existing files before writing. Don't re-read unless changed.
- Thorough in reasoning, concise in output.
- Skip files over 100KB unless required.
- No sycophantic openers or closing fluff.
- No emojis or em-dashes.
- Do not guess APIs, versions, flags, commit SHAs, or package names. Verify by reading code or docs before asserting.

## Output
- Return code first. Explanation after, only if non-obvious.
- No inline prose. Use comments sparingly - only where logic is unclear.
- No boilerplate unless explicitly requested.

## Code Rules
- Simplest working solution. No over-engineering.
- No abstractions for single-use operations.
- No speculative features or "you might also want..."
- Read the file before modifying it. Never edit blind.
- No docstrings or type annotations on code not being changed.
- No error handling for scenarios that cannot happen.
- Three similar lines is better than a premature abstraction.

## Review Rules
- State the bug. Show the fix. Stop.
- No suggestions beyond the scope of the review.
- No compliments on the code before or after the review.

## Debugging Rules
- Never speculate about a bug without reading the relevant code first.
- State what you found, where, and the fix. One pass.
- If cause is unclear: say so. Do not guess.

## Simple Formatting
- No em dashes, smart quotes, or decorative Unicode symbols.
- Plain hyphens and straight quotes only.
- Natural language characters (accented letters, CJK, etc.) are fine when the content requires them.
- Code output must be copy-paste safe.

## What this is

A KDE Plasma 6 / KWin Wayland "Snap Assist": when a window is quick-tiled to a
screen half or corner, a popup offers other open windows as thumbnails to
fill the remaining free space. Plain QML + JavaScript KWin packages — no
build system, no package manager, no compiled code. There is no separate
`README.md` architecture summary beyond what's below; the repo README covers
install/usage instructions and should be kept in sync with any behavioral
change made here.

## Commands

Apart from the Nix flake (packaging + the `geometry.js`/`layout.js` QML
tests), there is no build/lint tooling. Validation of live behavior is manual:

```sh
./install.sh                # install + enable the KWin script only, then force-reload it
./install.sh --with-effect  # also install the optional placement-animation effect
./uninstall.sh               # remove both packages
nix build                    # package: $out/share/kwin/{scripts,effects}/<Id>
nix flake check              # runs the QML tests in the sandbox

./dev-nested-kwin.sh          # launch a disposable nested KWin Wayland compositor
                               # for safe testing — NEVER reload/replace KWin on the
                               # live session while iterating
```

`qdbus org.kde.KWin /KWin org.kde.KWin.reconfigure` does NOT reliably reload
an already-loaded script's QML source after `kpackagetool6 --upgrade` —
confirmed live it can be actively harmful: calling it re-triggers KWin's own
internal script reload via a path that keeps reusing a stale in-memory
compiled copy of the script for the lifetime of the running KWin process
(confirmed even with `~/.cache/kwin/qmlcache` fully cleared — this is not a
disk-cache issue, `reconfigure()`'s reload path does not recompile from the
changed file at all). This re-introduces an already-fixed bug even after an
explicit unload/loadDeclarativeScript cycle had already applied the fix.
**The System Settings > Window Management > KWin Scripts checkbox/Apply
button goes through this same broken `reconfigure()` path — do not use it to
test code changes.** `install.sh` does NOT call `reconfigure` for the reload
step, only unload+load; do the same manually after editing QML while a
script is already loaded:

```sh
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript org.kde.snapassist
qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadDeclarativeScript \
    "$HOME/.local/share/kwin/scripts/org.kde.snapassist/contents/ui/main.qml" org.kde.snapassist
```

`Scripting` exposes both `loadScript` (plain-JS packages) and
`loadDeclarativeScript` (QML/`declarativescript` packages, what this repo's
script package is) as distinct D-Bus methods. Using `loadScript` on this
package fails with `Unexpected token 'import'` (confirmed live) since it
parses the file as plain JavaScript.

**Even the unload+load cycle above can go stale within one long-running
`kwin_wayland` process**, not just `reconfigure()`: confirmed live across a
whole debugging session that after several `unloadScript`/
`loadDeclarativeScript` cycles at the *same file path*, both the top-level
script file and files it loads internally via `Qt.createComponent()` (e.g.
`SnapAssistOverlay.qml`) can keep serving an old compiled version - an error
message referencing an already-fixed line kept reappearing verbatim after
the file on disk was already corrected and reloaded multiple times. The only
reliable fix found was a full reboot (a fresh `kwin_wayland` process); a
same-path reload after editing is usually fine for the first 1-3 cycles but
should not be trusted past that without independent confirmation (see the
diagnostics-unreliable note below for why "no error in the log" isn't
sufficient confirmation either). If you hit this, don't keep guessing at
more code fixes - reboot and retest with the minimum number of manual
reloads before drawing conclusions.

Live debug console (inspect `quickTileMode` values while manually snapping windows, view `console.log` output):

```sh
qdbus org.kde.KWin /KWin org.kde.KWin.showDebugConsole
```

If `qmllint` is available in the working environment, lint changed `.qml` files with it before considering a change done. Confirmed available via the built `qtdeclarative` Nix store output (not on `$PATH` by default - find it with `find /nix/store -maxdepth 1 -iname "*qtdeclarative-*"` and look for one with a `bin/` containing `qml`, `qmllint`, `qmltestrunner`). `org.kde.kwin` can't be resolved by `qmllint` even with `-I <kwin-package>/lib/qt-6/qml` - `KWin`/`Workspace` are registered purely in C++ at runtime with no discoverable `qmldir`, so warnings about them (and anything downstream, like `Component`/`Timer` failing to resolve in `main.qml`) are expected noise, not real findings; only trust `qmllint` for syntax errors and files that don't import `org.kde.kwin`.

`geometry.js` (`freeZoneForOccupiedRect`, pure - no KWin API calls) has real test coverage at `kwin-script/org.kde.snapassist/tests/tst_geometry.qml`, run via:

```sh
qmltestrunner -input kwin-script/org.kde.snapassist/tests/tst_geometry.qml
```

This is the only part of the script testable outside a live KWin session (~1000x faster than a live round-trip and immune to the logging blackout below) - the rest of `main.qml`/`SnapAssistOverlay.qml` call directly into live `Workspace`/`KWin` APIs and can only be validated live.

## Architecture

Two independent KPackages that don't coordinate with each other directly:

- **`kwin-script/org.kde.snapassist/`** — the required package, a `KWin/Script`
  with `X-Plasma-API: declarativescript` (QML). This is the only viable
  vehicle for the custom thumbnail-picker popup: a plain JS `KWin/Effect`
  (`X-Plasma-API: javascript`) can only animate existing windows via
  `animate()`/`Effect.*` — it cannot render arbitrary QML UI. Entry point is
  `contents/ui/main.qml`.
- **`effect/org.kde.snapassist.placementeffect/`** — optional, disabled by
  default, a `KWin/Effect` (`X-Plasma-API: javascript`) that purely animates
  geometry changes (modeled on KWin's shipped `maximize` effect). It reacts
  to `windowFrameGeometryChanged` generically, so it needs no knowledge of
  the script.

### Detection → overlay flow (`kwin-script/org.kde.snapassist/contents/ui/`)

1. `main.qml` connects to every window's `quickTileModeChanged` signal
   (`manage()`, wired up for existing windows at `Component.onCompleted` and
   for new ones via `Workspace.windowAdded`).
2. On a tile-mode change, a debounce `Timer` (`cfgTriggerDelayMs`) calls
   `trigger(window)`. `Window.quickTileMode` is not readable from scripts
   (confirmed live: reads back `undefined`), so detection is purely
   geometry-based: `window.tile.absoluteGeometry` (panel-exclusive) is
   compared against `Workspace.clientArea(Workspace.MaximizeArea, ...)`
   (falls back to `KWin.FullScreenArea`, panel-inclusive, if `MaximizeArea`
   isn't available in this script context - not independently confirmed) via
   `freeZoneForOccupiedRect()` in `geometry.js`, a pure function (imported as
   `Geometry`, tested standalone - see Commands) that returns the single free
   rectangle: opposite half for a half-tile, opposite quadrant for a
   quarter-tile, `null` for full-width/height snaps. Its tolerance is
   size-relative and the returned zone is built from `occupied`'s own
   dimensions specifically so either area source produces a correct result.
3. `candidateWindows()` filters `Workspace.windows` (a property, not the
   plain-JS `windowList()` method) down to windows on the same
   `output`/desktop, excluding the snapped window itself, minimized, and
   `skipTaskbar` windows. Both the `output` and `desktop` comparisons try
   `===` first, falling back to `String(a) === String(b)` - live testing
   showed `===` alone silently producing zero candidates even for windows
   confirmed (via Debug Console) to share the same output/desktop.
4. `showOverlay()` lazily instantiates `SnapAssistOverlay.qml` and calls its
   `showFor(zone, candidates)`.
5. `SnapAssistOverlay.qml` is a `PlasmaCore.Dialog` (chosen over
   `PlasmaCore.Window` specifically for `Qt.Popup`'s click-outside-to-dismiss
   behavior) positioned to exactly hug the free zone, containing a
   `GridView` of `SnapAssistTile.qml` delegates. Confirming a tile (click,
   Enter, or the tile's own key handler) sets `chosenWindow.frameGeometry =
   targetZone` directly - confirmed live that this direct property
   assignment actually moves the window from this declarative context.
6. `SnapAssistTile.qml` renders a live preview via `WindowThumbnail { wId:
   windowObject.internalId }` - `internalId` confirmed live (KWin Debug
   Console) to be a real, populated UUID property on `Window`.

Config (`Enabled`, `ShowForQuarterTiles`, `OverlayTimeoutMs`,
`TriggerDelayMs`) is KConfigXT (`contents/config/main.xml`) with a QWidgets
form (`contents/ui/config.ui`) — this is the generic mechanism KWin's own
shipped scripts/effects use for their System Settings page, and applies
regardless of whether the script itself is JS or QML.

### Confirmed via live testing

- `Workspace.windowList()` (the plain-JS `workspace` method) does not exist
  on the declarative `Workspace` singleton — use the property
  `Workspace.windows` instead (`DeclarativeScriptWorkspaceWrapper::windows()`
  in `libkwin.so`). The plain-JS and declarative KWin scripting APIs are NOT
  interchangeable 1:1; don't assume a method name from one side works on the
  other without checking `journalctl --user` after a reload.
- `reconfigure()` does not force-reload script QML — see Commands above.
- `quickTileModeChanged` does fire from the declarative side once connected,
  and `trigger()`'s detection/geometry pipeline (`window.tile`,
  `absoluteGeometry`) runs correctly — confirmed via `journalctl` across
  multiple fresh boots.
- The full end-to-end flow is confirmed working live: quick-tiling a window
  shows the popup positioned correctly in the free zone, and clicking a
  suggested window resizes it into that zone via `chosen.frameGeometry =
  overlayDialog.targetZone` (`SnapAssistOverlay.qml`'s `confirm()`) — direct
  `frameGeometry` assignment IS writable from the declarative script context
  for this purpose, confirmed live.
- `candidateWindows()`'s `w.output`/`w.desktops` comparisons needed an
  additive `String(a) === String(b)` fallback alongside `===` — live testing
  showed zero candidates even with two windows both reporting the same
  `output` ("eDP-1") and desktop in the Debug Console, with every other
  explanation (minimized/skipTaskbar/geometry) ruled out first. KWin's own
  declarative `WindowHeap.qml` uses plain `===` for screen comparison, so
  this isn't universal - but relying on it alone silently produced empty
  candidate lists here.
- `kwin_wayland --help`: `-s`/`--socket <socket>` names the socket this
  instance listens on. `--wayland-display <display>` is a different thing -
  which *host* Wayland display to connect to as a client in windowed mode -
  and was wrongly used for the former in an earlier version of
  `dev-nested-kwin.sh`, causing it to collide with the live session's
  `wayland-0` socket instead of creating an isolated one.
- `KWin.FullScreenArea` (via `Workspace.clientArea()`) returns the full
  physical screen INCLUDING space reserved for panels, while
  `window.tile.absoluteGeometry` is always panel-exclusive - comparing the
  two directly with a tight tolerance makes every normal half/quarter-tile
  match silently fail. `Workspace.MaximizeArea` (used by KWin's own shipped
  `outline.qml` snap-preview effect) is panel-aware, but that's an *effect*
  context, not a declarative *script* context, so its availability here
  isn't independently confirmed - `main.qml` now guards with
  `typeof Workspace.MaximizeArea !== "undefined"` and falls back to
  `KWin.FullScreenArea`, with `geometry.js`'s tolerance made size-relative
  and its returned zone built from `occupied`'s own dimensions so either
  source produces a correct result.

### Diagnostics are unreliable mid-session

Both `console.log`/`console.warn` (via `journalctl`) and `notify()`'s
`callDBus()`-based desktop notifications intermittently stop producing any
output at all in a given `kwin_wayland` process - confirmed repeatedly: a
fresh throwaway plain-JS probe script's guaranteed-to-execute top-level
`console.log` produced nothing, in multiple different processes, after as
few as 2-3 `unloadScript`/`loadDeclarativeScript` cycles. This is NOT
specific to this script and is not fixed by restarting `plasmashell`; a
fresh reboot only buys a handful of reliably-logging reload cycles before it
recurs. Root cause unknown. Consequences for future debugging:
- Absence of expected log/notification output is not reliable evidence the
  code didn't run - it may just be this blackout. Don't conclude a code path
  was skipped from silence alone; corroborate with a direct visual check or
  the KWin Debug Console (live C++ introspection, not script-log-dependent)
  where possible.
- Prefer testing pure logic via `qmltestrunner` (see Commands) over live
  `journalctl` roundtrips whenever the logic doesn't need a real KWin
  session - it's ~1000x faster and immune to this issue entirely.
- If you must add live diagnostics, add several redundant checkpoints (not
  just one) so a mid-session blackout starting between them still tells you
  something, and remove them once done rather than leaving them as
  permanent scaffolding.
- The QML component-cache staleness above and this logging blackout are
  probably two symptoms of the same underlying long-running-process
  degradation - `quickTileModeChanged` itself stopped firing (not just going
  unlogged) after enough reload cycles in one debugging session, only
  resolved by a fresh reboot. When live testing repeatedly shows "nothing
  happened" across several different code changes in a row, suspect the
  process's accumulated state before suspecting the latest edit - reboot and
  retest with a single clean reload (or none, relying on KWin's own
  boot-time auto-load) before concluding anything about the code itself.

### Known unverified assumptions

`KWin.PlacementArea`'s enum member name (vs. the confirmed-working
`KWin.FullScreenArea` fallback) and whether `Workspace.MaximizeArea` actually
resolves in the declarative script context (the code no longer depends on
knowing this - see above - but confirming it would let the
`KWin.FullScreenArea` fallback path be deleted) are still unconfirmed. When
touching detection logic, check these against a live Debug Console rather
than assuming.

`dev-nested-kwin.sh`'s socket flag is now confirmed correct (`-s`/`--socket`,
see above), but the script itself remains otherwise unverified end-to-end:
in one live attempt, `org.kde.KWin` never registered on the isolated D-Bus
session bus at all (`qdbus` reported "Service 'org.kde.KWin' does not
exist"), so `install.sh`'s reload step failed inside it. Root cause not
found - possibly needs `--xwayland` or another flag omitted from the current
invocation. Live testing on the real session (with a fresh reboot per the
note above) was used successfully instead; nested testing needs further work
before it can be recommended as reliable.

## Agent skills

### Issue tracker

Issues and specs live as local markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at the repo root (created lazily as terms/decisions resolve). See `docs/agents/domain.md`.
