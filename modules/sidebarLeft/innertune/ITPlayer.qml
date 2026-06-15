import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects as GE
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.deferred
import qs.modules.sidebarLeft.innertune

// Literal translation of Player.kt (portrait BottomSheetPlayer) — blurred art background,
// large thumbnail, title/artists, seek slider with time labels, and the control row
// [favorite | prev | play/pause(72dp, animated roundness) | next | repeat]. Bound to YtMusic.
Item {
    id: root

    readonly property int hp: ITDimens.playerHorizontalPadding   // 32
    readonly property bool liked: {
        const v = YtMusic.currentVideoId;
        return v !== "" && (YtMusic.likedSongs ?? []).some(s => s.videoId === v);
    }
    readonly property real playPauseRoundness: YtMusic.isPlaying ? 24 : 36
    property bool showLyrics: false
    property bool showQueue: false
    // Drag-to-dismiss state (consumed by the parent's y binding).
    property bool dragging: false
    property real dragY: 0

    signal collapseRequested()

    // Load synced lyrics (LrcLib) whenever the player is showing a new track.
    function _loadLyrics() {
        if (visible && YtMusic.currentVideoId)
            InnerTube.loadLyrics(YtMusic.currentVideoId, YtMusic.currentTitle, YtMusic.currentArtist, YtMusic.currentDuration);
    }
    onVisibleChanged: if (visible) _loadLyrics()
    Connections {
        target: YtMusic
        function onCurrentVideoIdChanged() { root._loadLyrics(); }
    }

    // --- Blurred album-art background + scrim (InnerTune player backdrop) ---
    StyledImage {
        id: bgArt
        anchors.fill: parent
        source: YtMusic.currentThumbnail
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    GE.FastBlur {
        anchors.fill: parent
        source: bgArt
        radius: 96
        cached: true
    }
    Rectangle {
        anchors.fill: parent
        color: Appearance.m3colors.m3background
        opacity: 0.82
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.bottomMargin: 16
        spacing: 0

        // Top bar: collapse chevron. Doubles as the drag handle to swipe the player down.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8

            DragHandler {
                target: null
                xAxis.enabled: false
                yAxis.enabled: true
                onActiveChanged: {
                    if (active) {
                        root.dragging = true;
                    } else {
                        if (root.dragY > root.height * 0.25) root.collapseRequested();
                        root.dragging = false;
                        root.dragY = 0;
                    }
                }
                onTranslationChanged: if (active) root.dragY = Math.max(0, translation.y)
            }

            RippleButton {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                releaseAction: () => root.collapseRequested()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "expand_more"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.m3colors.m3onSurface
                }
            }
            Item { Layout.fillWidth: true }
            // Lyrics toggle.
            RippleButton {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                buttonRadius: Appearance.rounding.full
                colBackground: root.showLyrics ? Appearance.m3colors.m3secondaryContainer : "transparent"
                releaseAction: () => { root.showLyrics = !root.showLyrics; if (root.showLyrics) root.showQueue = false; }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "lyrics"
                    iconSize: Appearance.font.pixelSize.huge
                    fill: root.showLyrics ? 1 : 0
                    color: Appearance.m3colors.m3onSurface
                }
            }
            // Queue toggle.
            RippleButton {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                buttonRadius: Appearance.rounding.full
                colBackground: root.showQueue ? Appearance.m3colors.m3secondaryContainer : "transparent"
                releaseAction: () => { root.showQueue = !root.showQueue; if (root.showQueue) root.showLyrics = false; }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "queue_music"
                    iconSize: Appearance.font.pixelSize.huge
                    fill: root.showQueue ? 1 : 0
                    color: Appearance.m3colors.m3onSurface
                }
            }
        }

        // Center: album art OR synced lyrics (tap art to flip).
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Large album art (square, centered).
            Item {
                anchors.centerIn: parent
                visible: !root.showLyrics && !root.showQueue
                width: Math.min(parent.width - root.hp * 2, parent.height * 0.9)
                height: width
                ITThumbnail {
                    anchors.fill: parent
                    thumbnailUrl: YtMusic.currentThumbnail
                    cornerRadius: Appearance.rounding.normal
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showLyrics = true
                }
            }

            // Synced lyrics.
            ITLyrics {
                anchors.fill: parent
                visible: root.showLyrics
                lyrics: InnerTube.lyrics
            }

            // Up-next queue.
            ITQueue {
                anchors.fill: parent
                visible: root.showQueue
            }
        }

        // Title (marquee on overflow).
        ITMarqueeText {
            Layout.fillWidth: true
            Layout.leftMargin: root.hp
            Layout.rightMargin: root.hp
            text: YtMusic.currentTitle
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.title
            font.weight: Font.Bold
            color: Appearance.m3colors.m3onSurface
        }
        Item { Layout.preferredHeight: 6 }
        // Artists.
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: root.hp
            Layout.rightMargin: root.hp
            text: YtMusic.currentArtist
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.m3colors.m3secondary
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        Item { Layout.preferredHeight: 12 }

        // Seek slider.
        StyledSlider {
            id: seekSlider
            Layout.fillWidth: true
            Layout.leftMargin: root.hp
            Layout.rightMargin: root.hp
            from: 0
            to: YtMusic.currentDuration > 0 ? YtMusic.currentDuration : 1
            stopIndicatorValues: []
            value: _dragging ? value : YtMusic.currentPosition
            property bool _dragging: false
            onPressedChanged: {
                if (pressed) _dragging = true;
                else { YtMusic.seek(value); _dragging = false; }
            }
        }
        Item { Layout.preferredHeight: 4 }
        // Time labels.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.hp + 4
            Layout.rightMargin: root.hp + 4
            StyledText {
                text: root._fmt(seekSlider._dragging ? seekSlider.value : YtMusic.currentPosition)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.m3colors.m3onSurfaceVariant
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: root._fmt(YtMusic.currentDuration)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.m3colors.m3onSurfaceVariant
            }
        }

        Item { Layout.preferredHeight: 12 }

        // Control row.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.hp
            Layout.rightMargin: root.hp
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            // Favorite.
            ITIconButton {
                Layout.fillWidth: true
                symbol: root.liked ? "favorite" : "favorite_border"
                color: root.liked ? Appearance.m3colors.m3error : Appearance.m3colors.m3onSurface
                onClicked: root.liked ? YtMusic.unlikeSong(YtMusic.currentVideoId) : YtMusic.likeSong()
            }
            // Previous.
            ITIconButton {
                Layout.fillWidth: true
                symbol: "skip_previous"
                enabled: YtMusic.canGoPrevious
                onClicked: YtMusic.playPrevious()
            }
            Item { Layout.preferredWidth: 8 }
            // Play / pause (72dp, animated roundness).
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                radius: root.playPauseRoundness
                color: Appearance.m3colors.m3secondaryContainer
                Behavior on radius {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration); easing.type: Easing.Linear }
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: YtMusic.isPlaying ? "pause" : "play_arrow"
                    iconSize: 36
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: YtMusic.togglePlaying()
                }
            }
            Item { Layout.preferredWidth: 8 }
            // Next.
            ITIconButton {
                Layout.fillWidth: true
                symbol: "skip_next"
                enabled: YtMusic.canGoNext
                onClicked: YtMusic.playNext()
            }
            // Repeat.
            ITIconButton {
                Layout.fillWidth: true
                symbol: YtMusic.repeatMode === 1 ? "repeat_one" : "repeat"
                opacity: YtMusic.repeatMode === 0 ? 0.5 : 1.0
                onClicked: YtMusic.repeatMode = (YtMusic.repeatMode + 1) % 3
            }
        }
    }

    function _fmt(seconds) {
        if (!seconds || seconds <= 0) return "0:00";
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const sec = s % 60;
        return m + ":" + (sec < 10 ? "0" + sec : "" + sec);
    }
}
