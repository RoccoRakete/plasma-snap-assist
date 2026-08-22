.pragma library

function freeZoneForOccupiedRect(occupied, area, showForQuarterTiles) {
    var halfW = Math.round(area.width / 2);
    var halfH = Math.round(area.height / 2);
    // `area` may come from a panel-inclusive source (e.g. a KWin.FullScreenArea
    // fallback) while `occupied` (window.tile.absoluteGeometry) is always
    // panel-exclusive. A size-relative tolerance absorbs that mismatch when
    // recognizing a half/quarter tile - half vs quarter differ by hundreds of
    // pixels, so this stays well short of any real ambiguity.
    var tol = Math.max(4, Math.round(Math.min(area.width, area.height) * 0.05));

    var fullWidth = Math.abs(occupied.width - area.width) <= tol;
    var fullHeight = Math.abs(occupied.height - area.height) <= tol;
    var halfWidthMatch = Math.abs(occupied.width - halfW) <= tol;
    var halfHeightMatch = Math.abs(occupied.height - halfH) <= tol;

    var atLeft = Math.abs(occupied.x - area.x) <= tol;
    var atRight = Math.abs((occupied.x + occupied.width) - (area.x + area.width)) <= tol;
    var atTop = Math.abs(occupied.y - area.y) <= tol;
    var atBottom = Math.abs((occupied.y + occupied.height) - (area.y + area.height)) <= tol;

    if (fullWidth && fullHeight) {
        return null; // fullscreen/maximized - no gap to fill
    }

    if (fullHeight && halfWidthMatch) {
        // half-tile (left or right), full height. Build the zone from
        // occupied's own (confirmed panel-exclusive) height rather than
        // area's, in case area is the panel-inclusive fallback.
        var oppositeWidth = area.width - occupied.width;
        if (atLeft) return Qt.rect(occupied.x + occupied.width, occupied.y, oppositeWidth, occupied.height);
        if (atRight) return Qt.rect(area.x, occupied.y, oppositeWidth, occupied.height);
        return null;
    }

    if (fullWidth && halfHeightMatch) {
        return null; // top/bottom half-tile - no side gap, matches Windows' behavior
    }

    if (!showForQuarterTiles) {
        return null;
    }

    if (halfWidthMatch && halfHeightMatch) {
        // Quarter tile -> offer the diagonally opposite quadrant, sized and
        // positioned entirely from occupied's own (confirmed panel-exclusive)
        // geometry rather than area's. A symmetric quarter split means the
        // opposite quadrant is exactly occupied's own size, so area's
        // width/height/x/y are never needed here - unlike the half-tile
        // branch above, this previously used area.width/area.height for the
        // opposite quadrant's size, which extended the returned zone into
        // panel/taskbar territory whenever the KWin.FullScreenArea
        // (panel-inclusive) fallback was in effect - confirmed live via a
        // popup overlapping the taskbar.
        var oppW = occupied.width;
        var oppH = occupied.height;
        if (atLeft && atTop) return Qt.rect(occupied.x + occupied.width, occupied.y + occupied.height, oppW, oppH);
        if (atLeft && atBottom) return Qt.rect(occupied.x + occupied.width, occupied.y - oppH, oppW, oppH);
        if (atRight && atTop) return Qt.rect(occupied.x - oppW, occupied.y + occupied.height, oppW, oppH);
        if (atRight && atBottom) return Qt.rect(occupied.x - oppW, occupied.y - oppH, oppW, oppH);
    }

    return null;
}
