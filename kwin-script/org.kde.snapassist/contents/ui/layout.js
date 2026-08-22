.pragma library

// Places tileCount fixed-aspect tiles within a fieldW x fieldH area,
// scattered outward from the field's center with random jitter, and
// guarantees no two returned tiles ever overlap.
//
// Overlap-safety argument: two axis-aligned rectangles only overlap if
// both their x-ranges and y-ranges overlap. baseX below depends only on
// column (never row) and jitterRangeX is the same constant for every
// tile, so the x-only no-overlap guarantee between any two
// different-column tiles holds regardless of row (symmetrically for
// y/row, independent of column). For same-row adjacent tiles, the worst
// case is both jittering the full jitterRangeX toward each other, which
// shrinks the nominal (stepX - cellWidth) gap by 2*jitterRangeX =
// 0.85*slack <= slack, leaving a gap >= 0.15*slack >= 0 - never negative.
// The final clamp to field bounds only ever engages for the two extreme
// tiles in a row/column, and only when jittering away from their sole
// neighbor (baseX is monotonic in column), so it never touches the
// adversarial "toward each other" direction this proof depends on.
function layoutTiles(fieldW, fieldH, tileCount) {
    if (tileCount <= 0) {
        return [];
    }
    fieldW = Math.max(0, fieldW);
    fieldH = Math.max(0, fieldH);

    var columns = Math.max(1, Math.min(tileCount, 3));
    var rows = Math.ceil(tileCount / columns);

    // Bounded by both axes - capping only against fieldW/columns let
    // cellHeight silently exceed fieldH/rows on a wide-but-short field,
    // causing rows to overlap before any jitter was even applied.
    var cellWidth = Math.max(0, Math.min(320, fieldW / columns, (fieldH / rows) / 0.72));
    var cellHeight = cellWidth * 0.72;

    var desiredStepX = cellWidth * 1.5;
    var desiredStepY = cellHeight * 1.6;

    var maxStepX = columns > 1 ? (fieldW - cellWidth) / (columns - 1) : desiredStepX;
    var maxStepY = rows > 1 ? (fieldH - cellHeight) / (rows - 1) : desiredStepY;
    var stepX = columns > 1 ? Math.min(desiredStepX, maxStepX) : 0;
    var stepY = rows > 1 ? Math.min(desiredStepY, maxStepY) : 0;

    // Center the grid's own bounding box within the field - a spacious
    // field leaves a big inset margin all around; a tight field shrinks
    // gracefully toward edge-to-edge rather than overflowing it.
    var gridW = columns > 1 ? (columns - 1) * stepX + cellWidth : cellWidth;
    var gridH = rows > 1 ? (rows - 1) * stepY + cellHeight : cellHeight;
    var originX = (fieldW - gridW) / 2;
    var originY = (fieldH - gridH) / 2;

    // Capped below half the inter-tile gap so two grid-adjacent tiles can
    // never touch even if both jitter maximally toward each other (0.85 is
    // a small safety margin under the theoretical max of half the slack).
    var jitterRangeX = columns > 1
        ? Math.max(0, (stepX - cellWidth) / 2) * 0.85
        : Math.max(0, (fieldW - cellWidth) / 2) * 0.4;
    var jitterRangeY = rows > 1
        ? Math.max(0, (stepY - cellHeight) / 2) * 0.85
        : Math.max(0, (fieldH - cellHeight) / 2) * 0.4;

    var slots = [];
    for (var i = 0; i < tileCount; ++i) {
        var col = i % columns;
        var row = Math.floor(i / columns);
        var baseX = originX + (columns > 1 ? col * stepX : 0);
        var baseY = originY + (rows > 1 ? row * stepY : 0);
        var jitterX = (Math.random() * 2 - 1) * jitterRangeX;
        var jitterY = (Math.random() * 2 - 1) * jitterRangeY;
        var x = Math.max(0, Math.min(baseX + jitterX, fieldW - cellWidth));
        var y = Math.max(0, Math.min(baseY + jitterY, fieldH - cellHeight));
        slots.push({ x: x, y: y, w: cellWidth, h: cellHeight });
    }
    return slots;
}
