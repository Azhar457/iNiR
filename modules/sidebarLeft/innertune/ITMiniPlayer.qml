import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.sidebarLeft.innertune

// Literal translation of MiniPlayer.kt — 64dp bar with a 3dp bottom progress line,
// thumbnail + title/artist, play/pause and skip-next. Bound to YtMusic.
Item {
    id: root
    implicitHeight: ITDimens.miniPlayerHeight

    signal expandRequested()

    readonly property real progress: YtMusic.currentDuration > 0
        ? Math.max(0, Math.min(1, YtMusic.currentPosition / YtMusic.currentDuration)) : 0

    Rectangle {
        anchors.fill: parent
        color: Appearance.m3colors.m3surfaceContainer
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: 6
        spacing: 0

        // Media info (thumbnail + title/artist), clickable to expand.
        MouseArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandRequested()

            RowLayout {
                anchors.fill: parent
                spacing: 0
                Item {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    ITThumbnail {
                        anchors.centerIn: parent
                        width: ITDimens.listThumbnailSize
                        height: ITDimens.listThumbnailSize
                        thumbnailUrl: YtMusic.currentThumbnail
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    spacing: 0
                    ITMarqueeText {
                        Layout.fillWidth: true
                        text: YtMusic.currentTitle
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.m3colors.m3onSurface
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: YtMusic.currentArtist
                        font.pixelSize: ITDimens.subtitleTextSize
                        color: Appearance.m3colors.m3secondary
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Play / pause.
        RippleButton {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            buttonRadius: Appearance.rounding.full
            colBackground: YtMusic.isPlaying ? Appearance.m3colors.m3secondaryContainer : "transparent"
            releaseAction: () => YtMusic.togglePlaying()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: YtMusic.isPlaying ? "pause" : "play_arrow"
                iconSize: Appearance.font.pixelSize.huge
                color: YtMusic.isPlaying ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurface
            }
        }

        // Skip next.
        RippleButton {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            buttonRadius: Appearance.rounding.full
            colBackground: "transparent"
            enabled: YtMusic.canGoNext
            releaseAction: () => YtMusic.playNext()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_next"
                iconSize: Appearance.font.pixelSize.huge
                color: enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline
            }
        }
    }

    // 3dp progress line at the bottom (InnerTune LinearProgressIndicator).
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 3
        color: Appearance.m3colors.m3secondaryContainer
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.progress
            color: Appearance.m3colors.m3primary
            Behavior on width {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
            }
        }
    }
}
