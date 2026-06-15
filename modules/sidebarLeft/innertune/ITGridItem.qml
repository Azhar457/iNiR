import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarLeft.innertune

// Literal translation of Items.kt GridItem — shelf card.
// Column(pad 12, width = GridThumbnailHeight*ratio): thumbnail (128dp, aspectRatio),
// 6dp spacer, title (bodyLarge Bold, 2 lines), subtitle (bodyMedium secondary, 2 lines).
Item {
    id: root
    property string title: ""
    property string subtitle: ""
    property string thumbnailUrl: ""
    property real thumbnailRatio: 1.0
    property bool circle: false
    property bool isActive: false
    property bool isPlaying: false

    readonly property int thumbHeight: ITDimens.gridThumbnailHeight
    readonly property int thumbWidth: Math.round(thumbHeight * thumbnailRatio)

    implicitWidth: thumbWidth + 24            // 12dp padding each side
    implicitHeight: col.implicitHeight + 24

    signal clicked()
    signal longPressed()

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 0

        ITThumbnail {
            Layout.preferredWidth: root.thumbWidth
            Layout.preferredHeight: root.thumbHeight
            Layout.alignment: Qt.AlignHCenter
            thumbnailUrl: root.thumbnailUrl
            isActive: root.isActive
            isPlaying: root.isPlaying
            circle: root.circle
        }

        Item { Layout.preferredHeight: 6 }

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Bold
            color: Appearance.m3colors.m3onSurface
            maximumLineCount: 2
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            horizontalAlignment: root.circle ? Text.AlignHCenter : Text.AlignLeft
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.subtitle !== ""
            text: root.subtitle
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.m3colors.m3secondary
            maximumLineCount: 2
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            horizontalAlignment: root.circle ? Text.AlignHCenter : Text.AlignLeft
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressAndHold: root.longPressed()
    }
}
