import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Big clock card: accent time display with the full date underneath.
 */
DashCard {
    id: root

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        spacing: 2

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: DateTime.time
            font.pixelSize: Appearance.font.pixelSize.title * 2
            font.family: Appearance.font.family.numbers
            font.weight: Font.DemiBold
            color: root.colAccent
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: DateTime.date
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.normal
            color: root.colSubtext
            elide: Text.ElideRight
        }
    }
}
