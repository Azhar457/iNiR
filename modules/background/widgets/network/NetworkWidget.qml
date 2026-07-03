pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "network"
    defaultConfig: ({
        placementStrategy: "free", contentWidth: 280, contentHeight: 96,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: true, showBorder: true, backgroundOpacity: 0.16,
        borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1, useBlur: false,
        x: 80, y: 200
    })

    implicitWidth: Math.round(Config.getNestedValue("background.widgets.network.contentWidth", 280) * scaleFactor)
    implicitHeight: Math.round(Config.getNestedValue("background.widgets.network.contentHeight", 96) * scaleFactor)
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 210
    resizeMinHeight: 76
    needsColText: true

    readonly property color surfaceInk: root.widgetSurfaceInk
    readonly property string connectionName: Network.ethernet
        ? Translation.tr("Ethernet")
        : ((Network.networkName ?? "").length > 0 ? Network.networkName : Translation.tr("Not connected"))
    readonly property string connectionState: Network.ethernet
        ? Translation.tr("Wired connection")
        : Network.wifiStatus === "connected"
            ? Translation.tr("%1% signal").arg(Network.networkStrength)
            : Translation.tr("Wi-Fi %1").arg(Network.wifiStatus)

    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: Math.max(root.backgroundOpacity, 0.16)
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.surfaceInk
        surfaceAccent: root.widgetAccent
        surfaceUseBlur: root.useBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(12 * root.scaleFactor)

        Rectangle {
            Layout.preferredWidth: Math.round(52 * root.scaleFactor)
            Layout.preferredHeight: Layout.preferredWidth
            radius: root.widgetCardRadius
            color: ColorUtils.applyAlpha(root.widgetAccent, 0.18)

            MaterialSymbol {
                anchors.centerIn: parent
                text: Network.materialSymbol
                iconSize: Math.round(30 * root.scaleFactor)
                color: root.widgetAccent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(4 * root.scaleFactor)

            StyledText {
                Layout.fillWidth: true
                text: root.connectionName
                color: root.surfaceInk
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.weight: Font.DemiBold
                font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
            }
            StyledText {
                Layout.fillWidth: true
                text: root.connectionState
                color: ColorUtils.applyAlpha(root.surfaceInk, 0.68)
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
            }
            Rectangle {
                visible: !Network.ethernet && Network.wifiStatus === "connected"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(3, Math.round(4 * root.scaleFactor))
                radius: height / 2
                color: ColorUtils.applyAlpha(root.widgetAccent, 0.16)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Network.networkStrength / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.widgetAccent
                    Behavior on width {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type }
                    }
                }
            }
        }
    }
}
