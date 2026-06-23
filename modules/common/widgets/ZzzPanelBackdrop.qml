pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// Shared panel-level ZZZ statement. Use this behind content on major ii
// surfaces so the strong identity lives at the container level, not repeated
// inside every child card.
Item {
    id: root

    anchors.fill: parent

    property string label: ""
    property string index: ""
    property string ghostText: "Z·Z·Z"
    property color accentColor: Appearance.zzz.accent
    property bool showBurst: true
    property bool burstTriad: false
    property bool showGrid: true
    property bool showTicks: false
    property real ghostWidthFactor: 0.74
    property real ghostStrength: 1.0
    property real horizontalBias: 0.12
    property real verticalBias: 0.04

    readonly property bool active: Appearance.zzzEverywhere
    readonly property real frameMargin: Math.max(
        Appearance.zzz.markerLength + Appearance.zzz.borderThick * 3,
        Appearance.zzz.panelRadius + Appearance.zzz.borderThick
    )
    readonly property real burstSize: Math.max(
        Appearance.zzz.markerLength * 4,
        Math.min(width, height) * 0.24
    )

    visible: opacity > 0
    opacity: active ? 1 : 0
    clip: true

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    // Elegant depth: a faint top sheen lifts the surface and a soft floor
    // grounds it, so the panel reads as a lit console plate instead of a dead
    // flat fill. Pure token-driven, no animation (perf-neutral static layer).
    Rectangle {
        anchors.fill: parent
        visible: root.active
        // Round to the panel radius so this near-full fill never re-squares the
        // host panel's corners (panels clip rectangularly, not by radius).
        radius: Appearance.zzz.panelRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.zzz.onColor, Appearance.zzz.dark ? 0.05 : 0.035) }
            GradientStop { position: 0.30; color: "transparent" }
            GradientStop { position: 0.78; color: "transparent" }
            GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.zzz.bg0, Appearance.zzz.dark ? 0.32 : 0.18) }
        }
    }

    ZzzGhostMark {
        visible: root.active
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: Math.round(root.width * root.horizontalBias)
        anchors.verticalCenterOffset: Math.round(root.height * root.verticalBias)
        width: Math.max(0, Math.min(root.width * root.ghostWidthFactor, root.width - root.frameMargin * 2))
        height: width * 0.42
        strength: root.ghostStrength
        mark: root.ghostText.length > 0 ? root.ghostText : "Z·Z·Z"
    }

    ZzzBurst {
        visible: root.active && root.showBurst
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.frameMargin + Appearance.zzz.cutCorner
        width: root.burstSize
        height: root.burstSize
        barColor: root.accentColor
        triad: root.burstTriad
    }

    ZzzTechFrame {
        anchors.fill: parent
        label: root.label
        index: root.index
        accentColor: root.accentColor
        margin: root.frameMargin
        showGrid: root.showGrid
        showTicks: root.showTicks
    }
}
