pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

// Organic visual face for Cookie Shapes mode. Geometry and input stay owned
// by the host; this component only paints behind its content.
Item {
    id: root

    property color color: Appearance.colors.colLayer1
    property string role: "plate" // plate | card | control | badge
    property bool selected: false
    // Drawn as a ring on the same silhouette, so a focused control reads as an
    // outline instead of a filled plate — which is the only thing that works on
    // hosts whose own fill is transparent (the dock, bar icon buttons).
    property color strokeColor: "transparent"
    property real strokeWidth: 0

    readonly property real aspect: width / Math.max(height, 1)
    readonly property real maxOrganicAspect: role === "control" ? 2.2 : 1.65
    readonly property bool organic: aspect <= maxOrganicAspect
        && aspect >= 1 / maxOrganicAspect

    // Transient pointer states never change topology. Morphing communicates
    // persistent state only; hover/press feedback belongs to color/scale/ripple.
    readonly property string shape: role === "control"
        ? (selected ? "cookie6" : "pill")
        : role === "badge" ? (selected ? "cookie12" : "cookie9")
        : role === "card" ? "cookie9"
        : "cookie12"
    Rectangle {
        anchors.fill: parent
        visible: !root.organic
        color: root.color
        radius: root.role === "control" ? height / 2 : Appearance.rounding.normal
        border.width: root.strokeWidth
        border.color: root.strokeColor
    }

    Loader {
        anchors.fill: parent
        active: root.organic
        sourceComponent: CookiePlate {
            shape: root.shape
            color: root.color
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
        }
    }
}
