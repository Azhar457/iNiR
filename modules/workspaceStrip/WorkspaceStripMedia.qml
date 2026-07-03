pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects as GE
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// "Now playing" media flyout — the music-player analog of the reference.
// Shown when the media thumbnail is selected; reuses MprisController so it
// drives whatever player the rest of the shell tracks.
PanelSurface {
    id: media

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool _zzz: Appearance.zzzEverywhere
    readonly property real _progress: (player?.length ?? 0) > 0
        ? Math.max(0, Math.min(1, (player?.position ?? 0) / player.length)) : 0

    elevation: 2
    cardStyle: true
    implicitHeight: column.implicitHeight + 32

    // Keep position fresh while playing (MPRIS doesn't push position ticks).
    Timer {
        running: media.visible && (media.player?.isPlaying ?? false) && !seek.pressed
        interval: 1000
        repeat: true
        onTriggered: media.player?.positionChanged()
    }

    // Swallow clicks on the flyout body so interacting with it never bubbles to
    // the strip's dismiss handler. Controls sit above this and keep working.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: -1
    }

    Column {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 16
        }
        spacing: 12

        // Header: album art + track identity.
        Row {
            width: parent.width
            spacing: 12

            Item {
                width: 60
                height: 60
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: artBg
                    anchors.fill: parent
                    radius: media._zzz ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                }
                Image {
                    id: art
                    anchors.fill: parent
                    // Cached, resolved square art (handles YT Music too) instead of
                    // the raw MPRIS url, decoded at ×2 so it stays crisp.
                    source: MediaArtwork.displaySource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
                    sourceSize.width: Math.round(width * 2)
                    sourceSize.height: Math.round(height * 2)
                    visible: status === Image.Ready && source.toString().length > 0
                    layer.enabled: true
                    layer.effect: GE.OpacityMask {
                        maskSource: Rectangle {
                            width: art.width
                            height: art.height
                            radius: artBg.radius
                        }
                    }
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: 26
                    color: Appearance.colors.colOnLayer2
                    visible: !art.visible
                    opacity: 0.7
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 72
                spacing: 1

                StyledText {
                    width: parent.width
                    text: Translation.tr("Now playing").toUpperCase()
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    color: media._zzz ? Appearance.zzz.accent : Appearance.colors.colPrimary
                }
                StyledText {
                    width: parent.width
                    text: StringUtils.cleanMusicTitle(media.player?.trackTitle ?? "") || Translation.tr("Unknown track")
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: media._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer1
                }
                StyledText {
                    width: parent.width
                    text: media.player?.trackArtist ?? ""
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // Seek bar + times.
        Column {
            width: parent.width
            spacing: 3

            StyledSlider {
                id: seek
                width: parent.width
                enabled: media.player?.canSeek ?? false
                value: media._progress
                onMoved: if (media.player)
                    media.player.position = value * (media.player.length ?? 0)
            }

            Item {
                width: parent.width
                height: elapsed.implicitHeight
                StyledText {
                    id: elapsed
                    anchors.left: parent.left
                    text: StringUtils.friendlyTimeForSeconds(media.player?.position ?? 0)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    anchors.right: parent.right
                    text: StringUtils.friendlyTimeForSeconds(media.player?.length ?? 0)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // Transport controls.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            Repeater {
                model: [
                    { icon: "skip_previous", primary: false },
                    { icon: "__playpause", primary: true },
                    { icon: "skip_next", primary: false }
                ]

                RippleButton {
                    required property var modelData
                    readonly property bool isPlay: modelData.icon === "__playpause"
                    readonly property real size: isPlay ? 46 : 38
                    implicitWidth: size
                    implicitHeight: size
                    buttonRadius: isPlay
                        ? ((media.player?.isPlaying ?? false) ? Appearance.rounding.normal : size / 2)
                        : size / 2
                    enabled: isPlay ? (media.player !== null)
                        : (modelData.icon === "skip_next"
                            ? MprisController.canGoNextForPlayer(media.player)
                            : MprisController.canGoPreviousForPlayer(media.player))
                    colBackground: isPlay
                        ? (media._zzz ? Appearance.zzz.accent : Appearance.colors.colPrimary)
                        : (media._zzz ? Appearance.zzz.bg3 : Appearance.colors.colLayer2)
                    colBackgroundHover: isPlay
                        ? (media._zzz ? Appearance.zzz.accent : Appearance.colors.colPrimaryHover)
                        : (media._zzz ? Appearance.zzz.bg4 : Appearance.colors.colLayer2Hover)
                    downAction: () => {
                        if (modelData.icon === "__playpause") media.player?.togglePlaying()
                        else if (modelData.icon === "skip_next") MprisController.nextForPlayer(media.player)
                        else MprisController.previousForPlayer(media.player)
                    }

                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        fill: 1
                        iconSize: parent.isPlay ? Appearance.font.pixelSize.huge : Appearance.font.pixelSize.larger
                        text: parent.isPlay
                            ? ((media.player?.isPlaying ?? false) ? "pause" : "play_arrow")
                            : modelData.icon
                        color: parent.isPlay
                            ? (media._zzz ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimary)
                            : (media._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer2)
                    }
                }
            }
        }
    }
}
