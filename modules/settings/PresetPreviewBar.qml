import QtQuick
import qs.modules.common
import qs.modules.common.functions

// Mini bar preview rendered straight from a layout preset's own data, so it
// always mirrors what applying the preset produces. Reads the five layout
// zones (left / centerLeft / center / centerRight / right) and the surface
// `appearanceStyle` out of the preset's `values` bundle — no hand-authored
// mockup to drift out of sync. Edges hug the screen sides; centerLeft/center/
// centerRight form one cluster around the screen centre, matching BarContent.
Item {
    id: root

    // The preset's `values` map: { "bar.appearanceStyle": ..., "bar.layout.left": [...], ... }
    property var values: ({})
    // Pip colour for the module placeholders (caller tints by active state).
    property color accent: Appearance.colors.colSecondaryContainer

    implicitHeight: 30

    readonly property string style: values?.["bar.appearanceStyle"] ?? "classic"
    readonly property var leftIds:        values?.["bar.layout.left"]        ?? []
    readonly property var centerLeftIds:  values?.["bar.layout.centerLeft"]  ?? []
    readonly property var centerIds:      values?.["bar.layout.center"]      ?? []
    readonly property var centerRightIds: values?.["bar.layout.centerRight"] ?? []
    readonly property var rightIds:       values?.["bar.layout.right"]       ?? []

    readonly property bool isIslands: style === "islands"
    readonly property bool isScenic: style === "scenic"
    readonly property bool isFrame: style === "frame"

    // ── Surface ────────────────────────────────────────────────────────────
    // The "screen" track every preset shares — a recessed strip the bar sits in.
    Rectangle {
        id: track
        anchors.fill: parent
        radius: Appearance.rounding.verysmall
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        clip: true

        // Classic: one solid full-width bar surface inside the track.
        Rectangle {
            visible: root.style === "classic"
            anchors.fill: parent
            anchors.margins: 3
            radius: Appearance.rounding.verysmall - 2
            color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.25)
        }
        // Frame: an outlined floating surface, transparent inside.
        Rectangle {
            visible: root.isFrame
            anchors.fill: parent
            anchors.margins: 3
            radius: Appearance.rounding.verysmall - 2
            color: "transparent"
            border.width: 1
            border.color: ColorUtils.transparentize(root.accent, 0.35)
        }
        // Scenic: a vertical scrim fading into the (wallpaper) track.
        Rectangle {
            visible: root.isScenic
            anchors.fill: parent
            anchors.margins: 1
            radius: track.radius - 1
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.45) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    // ── Module clusters ──────────────────────────────────────────────────────
    // A module placeholder. In islands it carries its own capsule; otherwise the
    // pips sit bare on the shared surface, exactly like the real bar.
    component Pip: Rectangle {
        implicitWidth: 12
        implicitHeight: 7
        radius: height / 2
        color: root.accent
    }
    // A cluster of pips for one logical group, optionally wrapped as an island
    // capsule when the style floats each section.
    component Cluster: Rectangle {
        id: cluster
        property var ids: []
        visible: ids.length > 0
        implicitWidth: clusterRow.implicitWidth + (root.isIslands ? 8 : 0)
        implicitHeight: root.isIslands ? 13 : 7
        radius: height / 2
        color: root.isIslands ? ColorUtils.transparentize(Appearance.colors.colLayer1, 0.2) : "transparent"
        Row {
            id: clusterRow
            anchors.centerIn: parent
            spacing: 3
            Repeater {
                model: cluster.ids
                delegate: Pip {}
            }
        }
    }

    // Left edge — hugs the left side.
    Cluster {
        id: leftCluster
        ids: root.leftIds
        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
    }
    // Right edge — hugs the right side.
    Cluster {
        id: rightCluster
        ids: root.rightIds
        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
    }
    // Centre cluster — centerLeft + center + centerRight grouped around the
    // screen centre, the same pivot the real bar uses.
    Row {
        anchors.centerIn: parent
        spacing: root.isIslands ? 4 : 6
        Cluster { ids: root.centerLeftIds }
        Cluster { ids: root.centerIds }
        Cluster { ids: root.centerRightIds }
    }
}
