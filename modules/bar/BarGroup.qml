import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property real padding: 8
    readonly property bool cardStyleEverywhere: (Config.options?.dock?.cardStyle ?? false) && (Config.options?.sidebar?.cardStyle ?? false) && (Config.options?.bar?.cornerStyle === 3)
    // Islands bar appearance: each group is its own floating surface
    readonly property bool islandStyle: !vertical && (Config.options?.bar?.appearanceStyle ?? "classic") === "islands"
    readonly property bool zzzPlate: false
    implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight
    // Natural content width regardless of any implicitWidth override, so the bar
    // can size a pill to its content without a binding loop.
    readonly property real contentWidth: gridLayout.implicitWidth + padding * 2
    // True when the group has no visible children (Qt layouts exclude
    // visible:false items, so an all-hidden zone reports ~0 inner width). Lets
    // callers collapse the pill entirely instead of showing a ghost background.
    readonly property bool empty: gridLayout.implicitWidth < 1
    default property alias items: gridLayout.children

    // El fondo de cada grupo de la barra ahora sale del molde compartido
    // (PanelSurface) en vez de dibujarse a mano. Misma pinta que antes, pero
    // controlada desde un solo lugar → cambiar PanelSurface cambia toda la barra.
    PanelSurface {
        id: background
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        island: root.islandStyle
        cardStyle: root.cardStyleEverywhere
        borderless: !root.islandStyle && (Config.options?.bar?.borderless ?? false)
        elevation: root.islandStyle ? 0 : 1
        // En zzz la barra mantiene su contorno unificado; los grupos quedan transparentes.
        zzzChamfer: false
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors {
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
            top: root.vertical ? parent.top : undefined
            bottom: root.vertical ? parent.bottom : undefined
            margins: root.padding
        }
        columnSpacing: 4
        rowSpacing: 12
    }
}
