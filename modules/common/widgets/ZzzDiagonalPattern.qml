pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

// Generated-color diagonal hatching for ZZZ surfaces.
// Inactive styles create zero delegates.
Item {
    id: root

    anchors.fill: parent
    clip: true

    property int stripeSpacing: 22
    property int stripeThickness: Math.max(1, Appearance.zzz.borderThick)
    property color stripeColor: Appearance.zzz.diagonalStripe
    readonly property bool active: Appearance.zzzEverywhere && Appearance.zzz.useDiagonals
    readonly property int stripeCount: active
        ? Math.ceil((width + height * 2) / Math.max(1, stripeSpacing)) + 2
        : 0

    visible: opacity > 0
    opacity: active ? 1 : 0

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Repeater {
        model: root.stripeCount

        Rectangle {
            required property int index

            width: root.stripeThickness
            height: Math.max(root.width, root.height) * 2
            x: index * root.stripeSpacing - root.height
            y: -root.height / 2
            rotation: -24
            color: root.stripeColor

            // NOTE: no per-stripe `Behavior on color`. The hatch color only
            // changes on a style switch or wallpaper regen — both of which
            // also drive the parent `Behavior on opacity` (the whole pattern
            // fades out before a new color lands, then fades back in), so the
            // snap is invisible. Per-delegate ColorAnimation × ~42 stripes ×
            // up to 136 cards on a busy settings page = thousands of always-
            // resident animation evaluators; this is the single biggest idle-
            // CPU cost under ZZZ. Keep exactly one Behavior (parent opacity).
        }
    }
}
