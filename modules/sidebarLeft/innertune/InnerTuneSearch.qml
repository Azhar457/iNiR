import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.sidebarLeft.innertune

// Translation of OnlineSearchResult.kt (songs section) — a vertical list of
// SongListItems. Results come through YtMusic.searchResults (routed via InnerTube).
StyledFlickable {
    id: root
    property var results: []
    contentHeight: column.implicitHeight
    clip: true

    signal playRequested(int index)

    ColumnLayout {
        id: column
        width: root.width
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            visible: YtMusic.searching || root.results.length === 0
            MaterialLoadingIndicator {
                anchors.centerIn: parent
                visible: YtMusic.searching
            }
            StyledText {
                anchors.centerIn: parent
                visible: !YtMusic.searching && root.results.length === 0
                text: Translation.tr("No results")
                color: Appearance.m3colors.m3onSurfaceVariant
            }
        }

        Repeater {
            model: root.results
            delegate: ITSongListItem {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitWidth: column.width
                song: modelData
                liked: modelData.liked ?? false
                isActive: modelData.videoId === YtMusic.currentVideoId
                isPlaying: isActive && YtMusic.isPlaying
                onClicked: root.playRequested(index)
            }
        }
    }
}
