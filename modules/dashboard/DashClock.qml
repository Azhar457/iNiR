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
            font.pixelSize: Appearance.font.pixelSize.title * (root.zzzEverywhere ? 2.3 : 2)
            font.family: Appearance.font.family.numbers
            font.weight: root.zzzEverywhere ? Font.Black : Font.DemiBold
            font.italic: root.zzzEverywhere
            color: root.colAccent
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.zzzEverywhere ? DateTime.date.toUpperCase() : DateTime.date
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: root.zzzEverywhere ? Font.Bold : Font.Normal
            color: root.colSubtext
            elide: Text.ElideRight
        }
    }
}
