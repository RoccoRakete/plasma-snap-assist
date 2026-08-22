import QtQuick
import QtTest
import "../contents/ui/geometry.js" as Geometry

TestCase {
    name: "freeZoneForOccupiedRect"

    property var area: ({ x: 0, y: 0, width: 1920, height: 1200 })

    function test_leftHalfTile_returnsRightHalfZone() {
        var occupied = { x: 0, y: 0, width: 960, height: 1200 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, area, true);

        compare(zone.x, 960);
        compare(zone.y, 0);
        compare(zone.width, 960);
        compare(zone.height, 1200);
    }

    function test_rightHalfTile_returnsLeftHalfZone() {
        var occupied = { x: 960, y: 0, width: 960, height: 1200 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, area, true);

        compare(zone.x, 0);
        compare(zone.y, 0);
        compare(zone.width, 960);
        compare(zone.height, 1200);
    }

    function test_topHalfTile_returnsNull() {
        var occupied = { x: 0, y: 0, width: 1920, height: 600 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, area, true);

        compare(zone, null);
    }

    function test_bottomHalfTile_returnsNull() {
        var occupied = { x: 0, y: 600, width: 1920, height: 600 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, area, true);

        compare(zone, null);
    }

    function test_fullscreen_returnsNull() {
        var occupied = { x: 0, y: 0, width: 1920, height: 1200 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, area, true);

        compare(zone, null);
    }

    function test_topLeftQuarterTile_returnsBottomRightQuadrant() {
        var occupied = { x: 0, y: 0, width: 960, height: 600 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, area, true);

        compare(zone.x, 960);
        compare(zone.y, 600);
        compare(zone.width, 960);
        compare(zone.height, 600);
    }

    function test_bottomRightQuarterTile_returnsTopLeftQuadrant() {
        var occupied = { x: 960, y: 600, width: 960, height: 600 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, area, true);

        compare(zone.x, 0);
        compare(zone.y, 0);
        compare(zone.width, 960);
        compare(zone.height, 600);
    }

    function test_quarterTile_withQuarterTilesDisabled_returnsNull() {
        var occupied = { x: 0, y: 0, width: 960, height: 600 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, area, false);

        compare(zone, null);
    }

    function test_panelExcludedArea_leftHalfTile_stillReturnsRightHalfZone() {
        // Regression case for the live bug: occupied comes from
        // window.tile.absoluteGeometry (panel-excluded), area must be
        // computed the same way (Workspace.MaximizeArea, not
        // FullScreenArea) or this half-tile match silently fails.
        var panelExcludedArea = { x: 0, y: 0, width: 1920, height: 1158 };
        var occupied = { x: 0, y: 0, width: 960, height: 1158 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, panelExcludedArea, true);

        compare(zone.x, 960);
        compare(zone.y, 0);
        compare(zone.width, 960);
        compare(zone.height, 1158);
    }

    function test_panelInclusiveAreaFallback_leftHalfTile_returnsPanelExcludedZone() {
        // If Workspace.MaximizeArea isn't available and main.qml falls back
        // to KWin.FullScreenArea, area is panel-INCLUSIVE (1200) while
        // occupied stays panel-exclusive (1158, the real usable height).
        // The zone must still be recognized as a half-tile, and critically
        // must use occupied's real height (1158), not area's (1200) -
        // using area's height would place the suggested window's bottom
        // edge underneath the panel.
        var panelInclusiveArea = { x: 0, y: 0, width: 1920, height: 1200 };
        var occupied = { x: 0, y: 0, width: 960, height: 1158 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, panelInclusiveArea, true);

        compare(zone.x, 960);
        compare(zone.y, 0);
        compare(zone.width, 960);
        compare(zone.height, 1158);
    }

    function test_panelInclusiveAreaFallback_topLeftQuarterTile_returnsPanelExcludedZone() {
        // Same fallback scenario as the half-tile regression above, but for
        // a quarter tile: area is panel-INCLUSIVE (1200) while occupied is
        // panel-exclusive (579, i.e. half of the real usable height 1158).
        // The opposite quadrant must be sized from occupied (579), not from
        // area.height - occupied.height (which would be 1200 - 579 = 621,
        // extending 42px into the panel).
        var panelInclusiveArea = { x: 0, y: 0, width: 1920, height: 1200 };
        var occupied = { x: 0, y: 0, width: 960, height: 579 };

        var zone = Geometry.freeZoneForOccupiedRect(occupied, panelInclusiveArea, true);

        compare(zone.x, 960);
        compare(zone.y, 579);
        compare(zone.width, 960);
        compare(zone.height, 579);
    }
}
