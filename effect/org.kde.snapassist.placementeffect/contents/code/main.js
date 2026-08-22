/*
    Snap Assist placement animation.

    Purely cosmetic, optional companion to the org.kde.snapassist KWin
    script: animates any window frame-geometry change with a size+position
    tween, modeled directly on KWin's shipped "maximize" effect. It reacts
    generically to windowFrameGeometryChanged, so it needs no coordination
    with the snapassist script - it animates geometry changes regardless of
    what caused them.
*/

"use strict";

class SnapAssistPlacementEffect {
    constructor() {
        this.duration = animationTime(200);

        effect.configChanged.connect(this.loadConfig.bind(this));
        effect.animationEnded.connect(this.restoreForceBlurState.bind(this));

        effects.windowAdded.connect(this.manage.bind(this));
        for (const window of effects.stackingOrder) {
            this.manage(window);
        }
    }

    loadConfig() {
        this.duration = animationTime(200);
    }

    manage(window) {
        window.windowFrameGeometryChanged.connect(this.onGeometryChanged.bind(this));
    }

    onGeometryChanged(window, oldGeometry) {
        if (!window.visible) {
            return;
        }
        const newGeometry = window.geometry;
        if (newGeometry.width === oldGeometry.width &&
            newGeometry.height === oldGeometry.height &&
            newGeometry.x === oldGeometry.x &&
            newGeometry.y === oldGeometry.y) {
            return;
        }

        if (window.placementAnimation) {
            cancel(window.placementAnimation);
            delete window.placementAnimation;
        }

        window.setData(Effect.WindowForceBlurRole, true);

        window.placementAnimation = animate({
            window: window,
            duration: this.duration,
            animations: [
                {
                    type: Effect.Size,
                    from: { value1: oldGeometry.width, value2: oldGeometry.height },
                    to: { value1: newGeometry.width, value2: newGeometry.height },
                    curve: QEasingCurve.OutCubic
                },
                {
                    type: Effect.Translation,
                    from: {
                        value1: oldGeometry.x - newGeometry.x - (newGeometry.width - oldGeometry.width) / 2,
                        value2: oldGeometry.y - newGeometry.y - (newGeometry.height - oldGeometry.height) / 2
                    },
                    to: { value1: 0, value2: 0 },
                    curve: QEasingCurve.OutCubic
                }
            ]
        });
    }

    restoreForceBlurState(window) {
        window.setData(Effect.WindowForceBlurRole, null);
    }
}

new SnapAssistPlacementEffect();
