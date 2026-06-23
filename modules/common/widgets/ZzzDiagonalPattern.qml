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

            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }
    }
}
