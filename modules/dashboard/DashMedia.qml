import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Media card: cover art, track info and transport controls. Shows a playful
 * placeholder when nothing is playing (the panel keeps its composition).
 */
DashCard {
    id: root

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool hasPlayer: player !== null && (player?.trackTitle ?? "").length > 0
    readonly property bool isPlaying: player?.isPlaying ?? false

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        // Cover art / placeholder shape
        Item {
            implicitWidth: 64
            implicitHeight: 64

            Rectangle {
                id: artMask
                anchors.fill: parent
                radius: Appearance.rounding.small
                visible: false
            }

            Image {
                id: artImage
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 128
                sourceSize.height: 128
                opacity: status === Image.Ready ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                layer.enabled: status === Image.Ready
                layer.effect: GE.OpacityMask { maskSource: artMask }
            }

            MaterialShapeWrappedMaterialSymbol {
                anchors.fill: parent
                text: "music_note"
                shape: MaterialShape.Shape.Cookie4Sided
                padding: 8
                iconSize: 30
                opacity: artImage.status !== Image.Ready ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.hasPlayer ? (root.player?.trackTitle ?? "") : Translation.tr("Nothing playing")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: root.hasPlayer ? (root.player?.trackArtist ?? "") : Translation.tr("No music is currently playing")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.colSubtext
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.topMargin: 4
                spacing: 4

                component MediaButton: RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : root.inirEverywhere ? Appearance.inir.colLayer2Hover
                        : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                        : Appearance.colors.colLayer2Hover
                    property alias iconName: symbol.text
                    property alias iconColor: symbol.color
                    contentItem: MaterialSymbol {
                        id: symbol
                        anchors.centerIn: parent
                        iconSize: 20
                        color: root.colText
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MediaButton {
                    iconName: "skip_previous"
                    enabled: MprisController.canGoPrevious
                    onClicked: MprisController.previous()
                }
                MediaButton {
                    iconName: root.isPlaying ? "pause" : "play_arrow"
                    iconColor: root.colAccent
                    enabled: root.hasPlayer
                    onClicked: MprisController.togglePlaying()
                }
                MediaButton {
                    iconName: "skip_next"
                    enabled: MprisController.canGoNext
                    onClicked: MprisController.next()
                }
            }
        }
    }
}
