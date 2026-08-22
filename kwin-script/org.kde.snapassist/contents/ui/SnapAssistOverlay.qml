import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin
import "layout.js" as Layout

// Popup shown in the free screen zone after a window has been snapped,
// offering the other open windows as thumbnails to fill that zone.
//
// Uses PlasmaCore.Dialog with the Qt.Popup flag (rather than a plain
// PlasmaCore.Window, as the shipped desktopchangeosd OSD script uses) because
// Qt.Popup brings the "closes on outside click" behaviour we need - this is
// the same pattern the shipped window-switcher (thumbnail_grid) uses for its
// own thumbnail grid popup.
PlasmaCore.Dialog {
    id: overlayDialog

    location: PlasmaCore.Types.Floating
    flags: Qt.Popup | Qt.X11BypassWindowManagerHint
    // StandardBackground: a KWin declarative script has no API to isolate
    // just the wallpaper texture from whatever else the compositor is
    // currently drawing behind the popup, so this themed/blurred panel is
    // the pragmatic stand-in - it obscures/blurs real windows sitting in
    // the free zone rather than showing them clearly through the popup.
    backgroundHints: PlasmaCore.Dialog.StandardBackground
    visible: false

    property var targetZone: null

    function shuffled(arr) {
        var a = arr.slice();
        for (var i = a.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var tmp = a[i]; a[i] = a[j]; a[j] = tmp;
        }
        return a;
    }

    function showFor(zone, windows) {
        overlayDialog.targetZone = zone;
        // The dialog's actual on-screen window is mainItem (content) PLUS
        // PlasmaCore.Dialog's own frame margins around it (confirmed via
        // PlasmaQuick::Dialog's header: "Margins of the dialog around the
        // mainItem" - the window is not just mainItem's size). Sizing
        // content to the full zone and ignoring this let the frame overflow
        // past the zone's bottom edge into the taskbar - confirmed live.
        // Shrink content by exactly these margins so window (content +
        // margins) matches the zone. Computed here directly from zone
        // rather than read back from content.width/height (which are QML
        // bindings driven by the targetZone assignment just above) - reading
        // a binding's result immediately after changing its source is not
        // guaranteed to already reflect the new value, and a stale/undefined
        // read here previously produced NaN coordinates, which silently
        // failed to map the popup at all (no error, no popup). Must match
        // content's own width/height formula below exactly.
        var dm = overlayDialog.margins;
        var outerW = Math.max(280, zone.width);
        var outerH = Math.max(220, zone.height);
        var w = Math.max(0, outerW - dm.left - dm.right);
        var h = Math.max(0, outerH - dm.top - dm.bottom);
        overlayDialog.x = Math.round(zone.x + (zone.width - outerW) / 2);
        overlayDialog.y = Math.round(zone.y + (zone.height - outerH) / 2);

        // Staggered, randomized layout instead of a rigid grid: shuffle the
        // window order, then scatter tiles outward from the field's center
        // (layout.js guarantees no two tiles ever overlap). Positions are
        // computed once per show, not as live bindings, so the layout stays
        // stable while the popup is open.
        var margin = Kirigami.Units.largeSpacing;
        var fieldW = w - margin * 2;
        var fieldH = h - margin * 2;
        var order = overlayDialog.shuffled(windows);
        var slots = Layout.layoutTiles(fieldW, fieldH, order.length);

        var model = [];
        for (var i = 0; i < order.length; ++i) {
            model.push({
                window: order[i],
                x: slots[i].x,
                y: slots[i].y,
                w: slots[i].w - margin,
                h: slots[i].h - margin
            });
        }
        content.tileModel = model;
        content.currentIndex = 0;

        overlayDialog.visible = true;
        content.forceActiveFocus();
    }

    function dismiss() {
        overlayDialog.visible = false;
        content.tileModel = [];
    }

    function confirm(index) {
        var model = content.tileModel;
        if (!model || index < 0 || index >= model.length || !overlayDialog.targetZone) {
            dismiss();
            return;
        }
        var chosen = model[index].window;
        try {
            chosen.frameGeometry = overlayDialog.targetZone;
            // Placing a window doesn't raise or focus it - confirmed live
            // it can stay behind other windows after being tiled. Workspace
            // (KWin::WorkspaceWrapper, confirmed via libkwin.so symbols and
            // the shipped Present Windows/Overview QML using the identical
            // activeWindow pattern) exposes both; set both rather than rely
            // on activation implicitly raising too.
            Workspace.activeWindow = chosen;
            Workspace.raiseWindow(chosen);
        } catch (e) {
            console.warn("snapassist: failed to place window:", e);
        }
        dismiss();
    }

    mainItem: FocusScope {
        id: content

        readonly property real zoneWidth: overlayDialog.targetZone ? overlayDialog.targetZone.width : 400
        readonly property real zoneHeight: overlayDialog.targetZone ? overlayDialog.targetZone.height : 300

        // content (mainItem) is shrunk by the dialog's own frame margins so
        // that the actual window - content plus those margins - matches the
        // free zone exactly, flush with its edges. Must match the w/h
        // formula in showFor() above exactly.
        width: Math.max(0, Math.max(280, zoneWidth) - overlayDialog.margins.left - overlayDialog.margins.right)
        height: Math.max(0, Math.max(220, zoneHeight) - overlayDialog.margins.top - overlayDialog.margins.bottom)
        focus: true

        property var tileModel: []
        property int currentIndex: 0

        function moveNext() {
            if (content.tileModel.length > 0) {
                content.currentIndex = (content.currentIndex + 1) % content.tileModel.length;
            }
        }

        function movePrev() {
            if (content.tileModel.length > 0) {
                content.currentIndex = (content.currentIndex - 1 + content.tileModel.length) % content.tileModel.length;
            }
        }

        Keys.onLeftPressed: content.movePrev()
        Keys.onUpPressed: content.movePrev()
        Keys.onRightPressed: content.moveNext()
        Keys.onDownPressed: content.moveNext()
        Keys.onReturnPressed: overlayDialog.confirm(content.currentIndex)
        Keys.onEnterPressed: overlayDialog.confirm(content.currentIndex)
        Keys.onEscapePressed: overlayDialog.dismiss()

        // Lightens the panel regardless of the current Plasma theme's own
        // (possibly dark) dialog background color - a fixed light wash on
        // top of the StandardBackground frame rather than something theme
        // color dependent.
        Rectangle {
            anchors.fill: parent
            color: "white"
            opacity: 0.14
        }

        Item {
            id: field
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            clip: true

            Repeater {
                model: content.tileModel

                delegate: SnapAssistTile {
                    x: modelData.x
                    y: modelData.y
                    width: modelData.w
                    height: modelData.h
                    windowObject: modelData.window
                    isCurrent: index === content.currentIndex
                    onActivated: overlayDialog.confirm(index)
                }
            }
        }
    }
}
