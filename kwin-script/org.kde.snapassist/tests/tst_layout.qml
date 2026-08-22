import QtQuick
import QtTest
import "../contents/ui/layout.js" as Layout

TestCase {
    name: "layoutTiles"

    function rectsOverlap(a, b) {
        // Strict: touching edges at zero slack is not overlap.
        return a.x < b.x + b.w && b.x < a.x + a.w &&
               a.y < b.y + b.h && b.y < a.y + a.h;
    }

    function assertNoOverlaps(slots) {
        for (var i = 0; i < slots.length; ++i) {
            for (var j = i + 1; j < slots.length; ++j) {
                verify(!rectsOverlap(slots[i], slots[j]),
                       "slot " + i + " overlaps slot " + j);
            }
        }
    }

    function assertInBounds(slots, fieldW, fieldH) {
        for (var i = 0; i < slots.length; ++i) {
            var s = slots[i];
            verify(s.x >= 0 && s.y >= 0 && s.x + s.w <= fieldW + 0.001 && s.y + s.h <= fieldH + 0.001,
                   "slot " + i + " out of bounds: " + JSON.stringify(s));
        }
    }

    function test_zeroTiles_returnsEmptyArray() {
        var slots = Layout.layoutTiles(800, 600, 0);
        compare(slots.length, 0);
    }

    function test_singleTile_capsAtMaxWidthAndStaysInField() {
        var slots = Layout.layoutTiles(800, 600, 1);
        compare(slots.length, 1);
        compare(slots[0].w, 320);
        compare(slots[0].h, 320 * 0.72);
        assertInBounds(slots, 800, 600);
    }

    function test_countFitsOneRow_noOverlapAndInBounds() {
        for (var attempt = 0; attempt < 300; ++attempt) {
            var slots = Layout.layoutTiles(1000, 500, 3);
            compare(slots.length, 3);
            assertInBounds(slots, 1000, 500);
            assertNoOverlaps(slots);
        }
    }

    function test_countNeedsTwoRows_noOverlapAndInBounds() {
        for (var attempt = 0; attempt < 300; ++attempt) {
            var slots = Layout.layoutTiles(1000, 700, 5);
            compare(slots.length, 5);
            assertInBounds(slots, 1000, 700);
            assertNoOverlaps(slots);
        }
    }

    function test_manyTiles_stressNoOverlap() {
        for (var attempt = 0; attempt < 300; ++attempt) {
            var slots = Layout.layoutTiles(1200, 900, 10);
            compare(slots.length, 10);
            assertInBounds(slots, 1200, 900);
            assertNoOverlaps(slots);
        }
    }

    function test_tightFieldBothAxes_deterministicEdgeToEdgeNoJitter() {
        var slots = Layout.layoutTiles(300, 144, 6);

        compare(slots.length, 6);
        compare(slots[0].w, 100);
        compare(slots[0].h, 72);
        compare(slots[0].x, 0); compare(slots[0].y, 0);
        compare(slots[1].x, 100); compare(slots[1].y, 0);
        compare(slots[2].x, 200); compare(slots[2].y, 0);
        compare(slots[3].x, 0); compare(slots[3].y, 72);
        compare(slots[4].x, 100); compare(slots[4].y, 72);
        compare(slots[5].x, 200); compare(slots[5].y, 72);
        assertNoOverlaps(slots);
    }

    function test_wideShortField_regressionForCellHeightFieldHBug() {
        var slots = Layout.layoutTiles(960, 300, 6);

        compare(slots.length, 6);
        verify(slots[0].h * 2 <= 300 + 0.001);
        assertInBounds(slots, 960, 300);
        assertNoOverlaps(slots);
    }

    function test_fieldSmallerThanSingleTile_doesNotCrash() {
        var slots = Layout.layoutTiles(50, 30, 1);

        compare(slots.length, 1);
        verify(slots[0].w >= 0);
        verify(slots[0].h >= 0);
        verify(!isNaN(slots[0].x));
        verify(!isNaN(slots[0].y));
    }

    function test_originCentered_whenFieldHasSlack() {
        var fieldW = 2000, fieldH = 1500;
        var slots = Layout.layoutTiles(fieldW, fieldH, 3);

        var minX = Math.min(slots[0].x, slots[1].x, slots[2].x);
        var maxX = Math.max(slots[0].x + slots[0].w, slots[1].x + slots[1].w, slots[2].x + slots[2].w);
        var minY = Math.min(slots[0].y, slots[1].y, slots[2].y);
        var maxY = Math.max(slots[0].y + slots[0].h, slots[1].y + slots[1].h, slots[2].y + slots[2].h);

        verify(minX > 0, "tiles touch the left edge of a spacious field");
        verify(maxX < fieldW, "tiles touch the right edge of a spacious field");
        verify(minY > 0, "tiles touch the top edge of a spacious field");
        verify(maxY < fieldH, "tiles touch the bottom edge of a spacious field");
    }
}
