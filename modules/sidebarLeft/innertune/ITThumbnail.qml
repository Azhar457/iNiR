import QtQuick
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarLeft.innertune

// Literal translation of Items.kt ItemThumbnail + PlayingIndicatorBox.
// Rounded network thumbnail; when active, a black scrim fades in with either an
// animated 3-bar equalizer (playing) or a play glyph (paused).
Item {
    id: root
    property string thumbnailUrl: ""
    property int albumIndex: -1          // -1 = show image; >=0 = show track number
    property bool isActive: false
    property bool isPlaying: false
    property int cornerRadius: ITDimens.thumbnailCornerRadius
    property bool circle: false

    readonly property int effRadius: circle ? Math.round(Math.min(width, height) / 2) : cornerRadius

    // Track-number variant (used inside album track lists).
    StyledText {
        anchors.centerIn: parent
        visible: root.albumIndex >= 0 && !root.isActive
        text: root.albumIndex >= 0 ? (root.albumIndex + 1).toString() : ""
        color: Appearance.m3colors.m3onSurface
        font.pixelSize: Appearance.font.pixelSize.small
    }

    StyledImage {
        id: img
        anchors.fill: parent
        visible: root.albumIndex < 0
        source: root.albumIndex < 0 ? root.thumbnailUrl : ""
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: img.width
                height: img.height
                radius: root.effRadius
            }
        }
    }

    // Scrim + indicator overlay (fades in over 500ms when active — InnerTune tween(500)).
    Rectangle {
        id: scrim
        anchors.fill: parent
        radius: root.effRadius
        color: root.albumIndex >= 0 ? "transparent" : Qt.rgba(0, 0, 0, ITDimens.activeBoxAlpha)
        opacity: root.isActive ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }

        // Animated equalizer bars (playing). InnerTune: 3 bars, 4dp wide, 6dp gap, 24dp tall.
        Row {
            anchors.centerIn: parent
            height: 24
            spacing: 6
            visible: root.isActive && root.isPlaying
            Repeater {
                id: barsRepeater
                model: 3
                Rectangle {
                    width: 4
                    radius: ITDimens.thumbnailCornerRadius
                    color: root.albumIndex >= 0 ? Appearance.m3colors.m3onSurface : "white"
                    anchors.bottom: parent.bottom
                    property real level: 0.1
                    height: 24 * level
                    Behavior on height {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 200; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        // Play glyph (active but paused).
        StyledText {
            anchors.centerIn: parent
            visible: root.isActive && !root.isPlaying
            text: "play_arrow"
            font.family: Appearance.font.family.iconMaterial
            font.pixelSize: 24
            color: root.albumIndex >= 0 ? Appearance.m3colors.m3onSurface : "white"
        }
    }

    // Drives the random bar heights (InnerTune retargets every ~50ms; 150ms is gentler
    // on the GPU for a sidebar list). Raw timer — gating on animationsEnabled would freeze it.
    Timer {
        running: root.isActive && root.isPlaying && root.visible
        interval: 150
        repeat: true
        onTriggered: {
            for (let i = 0; i < barsRepeater.count; i++) {
                const bar = barsRepeater.itemAt(i);
                if (bar) bar.level = Math.random() * 0.9 + 0.1;
            }
        }
    }
}
