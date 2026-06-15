import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Translation of Player.kt ResizableIconButton — a flat 32dp icon button.
Item {
    id: root
    property string symbol: ""
    property color color: Appearance.m3colors.m3onSurface
    property bool enabled: true
    implicitHeight: 48
    implicitWidth: 48

    signal clicked()

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.symbol
        iconSize: 32
        color: root.enabled ? root.color : Appearance.m3colors.m3outline
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
