pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.common

// ZZZ signature surface: a rectangle whose corner is CHAMFERED in the real
// geometry (a true 45° cut), not a sticker drawn on top. This is the distinctive
// ZZZ plate silhouette — fillable, strokeable, antialiased — and the building
// block for ZZZ cards, buttons and console keys.
//
// Content goes in the default slot and sits on top of the plate. The plate paints
// the fill + optional technical stroke following the chamfered outline exactly.
Item {
    id: root

    property color fillColor: Appearance.zzz.paper
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    // Chamfer size; clamped so it never exceeds half the smallest side.
    property real chamfer: Appearance.zzz.cutCorner
    readonly property real _ch: Math.max(0, Math.min(chamfer, width / 2, height / 2))
    // Rounded-corner radius. When > 0 (e.g. ZZZ round mode), the plate renders
    // as a native rounded Rectangle instead of the chamfered Shape — this is
    // what makes the round anime read apply to every ZzzPlate-based surface,
    // which previously stayed square because the Shape's PathLine geometry
    // ignored radius entirely.
    property real radius: Appearance.zzz.round ? Appearance.zzz.panelRadius : 0
    readonly property bool _rounded: radius > 0
    // Which corners are cut. The ZZZ default is a single bottom-right cut — the
    // restrained "manufactured panel" read. Opt into more for stronger statements.
    // (Chamfer flags only apply in SQUARE mode; rounded mode paints all corners.)
    property bool chamferTopLeft: false
    property bool chamferTopRight: false
    property bool chamferBottomLeft: false
    property bool chamferBottomRight: true

    default property alias content: contentHolder.data

    // ── Rounded renderer (round mode) ── native Rectangle, respects radius.
    Rectangle {
        anchors.fill: parent
        visible: root._rounded
        radius: root.radius
        color: root.fillColor
        border.color: root.strokeColor
        border.width: root.strokeWidth
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animationCurves.zzzOvershoot } }
    }

    // ── Chamfered renderer (square mode) ── true 45° cut geometry.
    Shape {
        anchors.fill: parent
        visible: !root._rounded
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            fillColor: root._rounded ? "transparent" : root.fillColor
            strokeColor: root._rounded ? "transparent" : root.strokeColor
            strokeWidth: root._rounded ? 0 : root.strokeWidth
            joinStyle: ShapePath.MiterJoin

            startX: root.chamferTopLeft ? root._ch : 0
            startY: 0

            PathLine { x: root.width - (root.chamferTopRight ? root._ch : 0); y: 0 }
            PathLine { x: root.width; y: root.chamferTopRight ? root._ch : 0 }
            PathLine { x: root.width; y: root.height - (root.chamferBottomRight ? root._ch : 0) }
            PathLine { x: root.width - (root.chamferBottomRight ? root._ch : 0); y: root.height }
            PathLine { x: root.chamferBottomLeft ? root._ch : 0; y: root.height }
            PathLine { x: 0; y: root.height - (root.chamferBottomLeft ? root._ch : 0) }
            PathLine { x: 0; y: root.chamferTopLeft ? root._ch : 0 }
            PathLine { x: root.chamferTopLeft ? root._ch : 0; y: 0 }
        }
    }

    Behavior on fillColor {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    // The chamfer can morph (e.g. grow on hover) for a mechanical ZZZ feedback.
    Behavior on chamfer {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animationCurves.zzzOvershoot }
    }
    Behavior on strokeColor {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    Item {
        id: contentHolder
        anchors.fill: parent
    }
}
