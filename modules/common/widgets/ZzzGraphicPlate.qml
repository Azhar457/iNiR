pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common

// Clean ZZZ plate: a generated surface with a single left accent bar (category
// marker). Heavy ornaments (hatching, ghost type, edge rail) are OPT-IN and
// off by default — the bold ZZZ statement lives at panel level, cards stay clean.
// Inner content is masked to the rounded silhouette so accents follow the corners.
Rectangle {
    id: root

    property string ghostText: ""
    property bool showAccentBar: true       // left category bar — the clean signature
    property bool showTape: false            // opt-in poster edge rail
    property bool showDiagonalPattern: false // opt-in hatching
    property bool showTechFrame: false // cards stay clean; the tech frame is a panel-level statement
    property string frameLabel: ""
    property string frameIndex: ""
    property int accentBarThickness: Math.max(3, Appearance.zzz.borderThick + 1)
    property color plateColor: Appearance.zzz.paper
    property color strokeColor: Appearance.zzz.hairlineStrong
    property color ghostColor: Appearance.zzz.ghostInk
    property color accentColor: Appearance.zzz.accent
    readonly property bool active: Appearance.zzzEverywhere

    visible: active
    color: "transparent" // real fill is painted by the masked inner layer
    radius: Appearance.zzz.panelRadius
    border.width: Appearance.zzz.borderThick
    border.color: strokeColor

    // Inner content masked to the rounded silhouette (plain `clip` is rectangular).
    Item {
        id: inner
        anchors.fill: parent
        layer.enabled: root.active
        layer.smooth: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: inner.width
                height: inner.height
                radius: root.radius
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.plateColor
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        // Left category accent bar — the single clean ZZZ marker.
        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: root.showAccentBar ? root.accentBarThickness : 0
            color: root.accentColor
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        // Small poster registration tab: gives clean cards a ZZZ/sticker cue
        // without reintroducing noisy labels over their content.
        Rectangle {
            visible: root.showAccentBar
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Appearance.zzz.borderThick
            anchors.rightMargin: Appearance.zzz.borderThick
            width: Math.max(10, Appearance.zzz.cutCorner)
            height: Appearance.zzz.borderThick * 2
            color: Appearance.zzz.secondary
        }

        // ── Opt-in ornaments (off by default) ──
        ZzzDiagonalPattern {
            anchors.fill: parent
            visible: root.active && root.showDiagonalPattern
            stripeSpacing: 18
            stripeThickness: 1
            stripeColor: root.ghostColor
        }

        ZzzTechFrame {
            visible: root.showTechFrame
            label: root.frameLabel
            index: root.frameIndex
            margin: Math.max(8, Appearance.zzz.borderThick * 4)
            gridSpacing: 64
            accentColor: root.accentColor
            lineColor: Appearance.zzz.technicalGrid
            showGrid: false
            showTicks: false
        }

        Text {
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: -Math.round(width * 0.06)
                bottomMargin: -Math.round(height * 0.22)
            }
            visible: root.ghostText.length > 0
            text: root.ghostText
            color: root.ghostColor
            font.family: Appearance.font.family.title
            font.pixelSize: Math.max(34, Math.round(root.height * 0.62))
            font.weight: Font.Black
            font.italic: true
            renderType: Text.NativeRendering
        }

        ZzzSurfaceAccent {
            showTape: root.showTape
            showSticker: false
            tapeHeight: Appearance.zzz.borderThick * 3
        }

        // TRA-style clipped-corner cue. The plate remains rectangular for layout
        // stability, while the drawn diagonal makes the ZZZ surface read as a
        // technical cut panel. Tied to the tech frame so clean cards have no
        // floating diagonal in their corner.
        Rectangle {
            visible: root.showTechFrame
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Appearance.zzz.borderThick
            anchors.bottomMargin: Math.round(Appearance.zzz.cutCorner / 2)
            width: Appearance.zzz.cutCorner + 6
            height: Appearance.zzz.borderThick
            rotation: -45
            color: root.accentColor
        }
    }
}
