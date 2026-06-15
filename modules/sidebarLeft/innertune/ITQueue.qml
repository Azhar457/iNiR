import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.sidebarLeft.innertune

// Translation of Queue.kt — the up-next list. Shows YtMusic.activePlaylist with the current
// track highlighted; tapping a row jumps to it within the active queue.
StyledFlickable {
    id: root
    readonly property var queue: YtMusic.activePlaylist ?? []
    contentHeight: column.implicitHeight
    clip: true

    // Keep the playing track in view when it advances.
    Connections {
        target: YtMusic
        function onCurrentIndexChanged() {
            const y = YtMusic.currentIndex * ITDimens.listItemHeight;
            if (y < root.contentY || y > root.contentY + root.height - ITDimens.listItemHeight)
                root.contentY = Math.max(0, y - root.height / 2);
        }
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: 0

        ITNavigationTitle {
            Layout.fillWidth: true
            title: Translation.tr("Queue")
            label: root.queue.length > 0 ? Translation.tr("%1 songs").arg(root.queue.length) : ""
        }

        Repeater {
            model: root.queue
            delegate: ITSongListItem {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitWidth: column.width
                song: modelData
                isActive: index === YtMusic.currentIndex
                isPlaying: isActive && YtMusic.isPlaying
                onClicked: YtMusic.playFromPlaylist(root.queue, index, YtMusic.activePlaylistSource || "queue")
            }
        }
    }
}
