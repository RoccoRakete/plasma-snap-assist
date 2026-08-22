/*
    Snap Assist for KDE Plasma / KWin (Wayland)

    Detects when a window has been quick-tiled to a screen half or corner
    (via drag-to-edge or Meta+Arrow) and offers the other open windows as
    thumbnails to fill the remaining free area - similar to Windows' Snap
    Assist.
*/
import QtQuick
import org.kde.kwin
import "geometry.js" as Geometry

Item {
    id: root

    property bool cfgEnabled: true
    property bool cfgShowForQuarterTiles: true
    property int cfgTriggerDelayMs: 150

    property var overlay: null
    property var pendingWindow: null
    property var managedWindows: []
    property var activeConnections: []

    function loadConfig() {
        root.cfgEnabled = KWin.readConfig("Enabled", true) === true || KWin.readConfig("Enabled", true) === "true";
        root.cfgShowForQuarterTiles = KWin.readConfig("ShowForQuarterTiles", true) === true || KWin.readConfig("ShowForQuarterTiles", true) === "true";
        root.cfgTriggerDelayMs = parseInt(KWin.readConfig("TriggerDelayMs", 150), 10);
    }

    // --- window bookkeeping -------------------------------------------------

    function manage(window) {
        if (!window || root.managedWindows.indexOf(window) !== -1) {
            return;
        }
        root.managedWindows.push(window);

        var tileHandler = function () {
            root.onQuickTileModeChanged(window);
        };
        window.quickTileModeChanged.connect(tileHandler);
        root.activeConnections.push({ window: window, signalName: "quickTileModeChanged", handler: tileHandler });
    }

    function onWindowAdded(window) {
        root.manage(window);
    }

    // Window objects outlive script reloads (they belong to KWin, not to this
    // script instance), and Workspace itself is a permanent singleton - plain
    // .connect() closures on either are NOT automatically disconnected when
    // this Item is destroyed on unload. Confirmed live via "Cannot call/read
    // ... of null" errors from zombie closures of earlier (already-unloaded)
    // script instances still firing on real signals, including
    // Workspace.windowAdded (a global signal, not per-window - easy to miss).
    // Must explicitly disconnect everything this instance connected.
    Component.onDestruction: {
        for (var i = 0; i < root.activeConnections.length; ++i) {
            var c = root.activeConnections[i];
            try {
                c.window[c.signalName].disconnect(c.handler);
            } catch (e) {
                // window may already be gone - nothing to clean up then
            }
        }
        try {
            Workspace.windowAdded.disconnect(root.onWindowAdded);
        } catch (e) {
            // ignore
        }
    }

    // Temporary diagnostic: console.log visibility via journalctl has proven
    // unreliable mid-session, so surface key checkpoints as desktop
    // notifications instead (independent delivery path).
    function notify(message) {
        try {
            callDBus("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                "org.freedesktop.Notifications", "Notify",
                "snapassist", 0, "", "Snap Assist Debug", message, [], {}, 5000);
        } catch (e) {
            // ignore - this is a best-effort diagnostic
        }
    }

    function onQuickTileModeChanged(window) {
        root.notify("quickTileModeChanged fired, cfgEnabled=" + root.cfgEnabled);
        if (!root.cfgEnabled || !window) {
            return;
        }
        root.pendingWindow = window;
        triggerTimer.restart();
    }

    Timer {
        id: triggerTimer
        interval: root.cfgTriggerDelayMs
        repeat: false
        onTriggered: root.trigger(root.pendingWindow)
    }

    // --- zone geometry -------------------------------------------------------

    // Window.quickTileMode is not readable from scripts (confirmed live: reads
    // back as undefined, even though the quickTileModeChanged signal itself
    // fires fine - the getter apparently isn't exposed as a scriptable
    // property on this KWin version). Window.tile IS accessible (confirmed
    // live via the KWin Debug Console: shows e.g. "Left (0,0 960x1158)") and
    // exposes the tile's actual absoluteGeometry, so free-zone detection is
    // done purely from geometry instead of the QuickTileFlag bitmask.
    //
    // v1 simplification: for a quarter-tile we offer the single diagonally
    // opposite quadrant (always a genuinely free rectangle). Offering the two
    // remaining half-strips as additional simultaneous suggestions is a
    // natural v1.1 enhancement once the core interaction is proven.
    function freeZoneForOccupiedRect(occupied, area) {
        return Geometry.freeZoneForOccupiedRect(occupied, area, root.cfgShowForQuarterTiles);
    }

    // --- candidate windows -----------------------------------------------------

    // Desktop/output objects are primarily compared with === below, same
    // pattern KWin's own declarative WindowHeap.qml uses for screen
    // comparison (confirmed via its source: `item.screen === targetScreen`).
    // String() is tried as an additive fallback (never removes a match ===
    // would have found) in case declarative property reads hand back
    // non-identical wrappers for what's conceptually the same desktop/output
    // - live testing showed candidateWindows() producing zero candidates
    // even with two windows both reporting output "eDP-1" and the same
    // desktop in the Debug Console, with no other explanation found, so
    // this is a live-reasoned suspicion, not purely hypothetical - the same
    // class of issue already confirmed for Workspace.MaximizeArea's
    // availability above.
    function desktopsInclude(desktops, desktop) {
        for (var i = 0; i < desktops.length; ++i) {
            if (desktops[i] === desktop || String(desktops[i]) === String(desktop)) {
                return true;
            }
        }
        return false;
    }

    function candidateWindows(excludeWindow, output, desktop) {
        var list = [];
        var all = Workspace.windows;
        for (var i = 0; i < all.length; ++i) {
            var w = all[i];
            if (!w || w === excludeWindow) continue;
            if (w.minimized || w.skipTaskbar) continue;
            if (w.output !== output && String(w.output) !== String(output)) continue;
            if (!w.onAllDesktops && desktop && !root.desktopsInclude(w.desktops, desktop)) continue;
            list.push(w);
        }
        return list;
    }

    // --- trigger / overlay --------------------------------------------------

    function trigger(window) {
        console.log("snapassist: trigger() called, window=" + window);
        if (!window) {
            return;
        }
        var tile;
        try {
            tile = window.tile;
        } catch (e) {
            return; // window was closed in the meantime
        }
        console.log("snapassist: trigger() tile=" + tile);
        if (!tile) {
            return;
        }
        var occupied = tile.absoluteGeometry;
        console.log("snapassist: occupied=" + JSON.stringify(occupied));
        if (!occupied) {
            return;
        }

        // KWin.PlacementArea is not a valid enum member on this KWin version
        // (confirmed live: read back as undefined). KWin.FullScreenArea (used
        // by the shipped desktopchangeosd script) returns the full physical
        // screen INCLUDING space reserved for panels, while window.tile's
        // absoluteGeometry (occupied, above) already excludes panels - this
        // mismatch made a normal half-tile fail every full/half-height match
        // in freeZoneForOccupiedRect (confirmed live: occupied height 1158 vs
        // FullScreenArea height ~1200 on a screen with a panel). KWin's own
        // outline.qml (the snap-preview effect, computing the identical
        // "where does a tiled/maximized window sit" question) uses
        // Workspace.MaximizeArea instead, which is panel-aware. That effect
        // runs in a different scripting context than this declarative script
        // though (per this repo's own confirmed plain-JS-vs-declarative API
        // gotcha), so MaximizeArea's availability here isn't confirmed live -
        // fall back to FullScreenArea if it's missing. Either way,
        // freeZoneForOccupiedRect uses a size-relative tolerance (see
        // geometry.js) generous enough to absorb a panel-height mismatch.
        var desktop = (window.desktops && window.desktops.length > 0) ? window.desktops[0] : null;
        var areaType = (typeof Workspace.MaximizeArea !== "undefined") ? Workspace.MaximizeArea : KWin.FullScreenArea;
        var area = Workspace.clientArea(areaType, window.output, desktop);
        var zone = root.freeZoneForOccupiedRect(occupied, area);
        if (!zone || zone.width < 80 || zone.height < 80) {
            return;
        }

        var candidates = root.candidateWindows(window, window.output, desktop);
        if (candidates.length === 0) {
            return;
        }

        root.showOverlay(zone, candidates);
    }

    function showOverlay(zone, candidates) {
        if (!root.overlay) {
            var component = Qt.createComponent("SnapAssistOverlay.qml");
            if (component.status !== Component.Ready) {
                console.warn("snapassist: failed to load SnapAssistOverlay.qml:", component.errorString());
                return;
            }
            root.overlay = component.createObject(root, {});
        }
        root.overlay.showFor(zone, candidates);
    }

    Component.onCompleted: {
        root.notify("script (re)loaded");
        root.loadConfig();
        var all = Workspace.windows;
        root.notify("managing " + all.length + " existing windows");
        for (var i = 0; i < all.length; ++i) {
            root.manage(all[i]);
        }
        Workspace.windowAdded.connect(root.onWindowAdded);
    }
}
