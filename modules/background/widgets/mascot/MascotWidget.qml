pragma ComponentBehavior: Bound

import qs
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.background.widgets

/**
 * Desktop mascot widget: a pose from the catalog living on the wallpaper
 * layer, pose picked visually in Settings › Widgets › Mascot. Tapping her
 * pokes the live companion. Registered per the folder contract: import +
 * _builtinWidgets entry + FadeLoader + knownWidgets in Background.qml,
 * schema in Config.qml, defaults/config.json, DesktopWidgetsConfig section,
 * WidgetManagerPanel _supportsAppearance whitelist.
 */
AbstractBackgroundWidget {
    id: root

    configEntryName: "mascot"
    defaultConfig: ({
        placementStrategy: "free", contentWidth: 200,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: false, showBorder: false, backgroundOpacity: 0.16,
        borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1, useBlur: false,
        pose: "reading", x: 120, y: 320
    })

    implicitWidth: Math.round(Config.getNestedValue("background.widgets.mascot.contentWidth", 200) * scaleFactor)
    implicitHeight: implicitWidth
    resizableAxes: ({ uniform: "contentWidth" })
    resizeMinWidth: 96
    resizeMinHeight: 96

    readonly property string pose: Config.getNestedValue("background.widgets.mascot.pose", "reading")

    // GIF poses need AnimatedImage playback; the manifest says which ones
    property var _animatedPoses: []
    FileView {
        path: Quickshell.shellPath("assets/images/mascot/manifest.json")
        onLoadedChanged: {
            if (!loaded) return
            try {
                root._animatedPoses = JSON.parse(text()).animatedPoses ?? []
            } catch (e) {
                console.warn("[MascotWidget] manifest load failed:", e)
            }
        }
    }

    // Card chrome is off by default — she's a cutout living on the desktop.
    // Users can turn the card back on from the widget manager / settings.
    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        surfaceAccent: root.widgetAccent3
        surfaceUseBlur: root.useBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
    }

    AnimatedImage {
        id: sprite
        anchors.fill: parent
        anchors.margins: Math.round(6 * root.scaleFactor)
        source: Quickshell.shellPath(`assets/images/mascot/inir-mascot-${root.pose}.${root._animatedPoses.includes(root.pose) ? "gif" : "png"}`)
        playing: root.powerActive
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: false
        mipmap: false

        // Fallback when the mascot switch is off or the pose asset is gone
        visible: (Config.options?.mascot?.enable ?? false) && status !== Image.Error
    }
    MaterialSymbol {
        anchors.centerIn: parent
        visible: !sprite.visible
        text: "pets"
        iconSize: Math.round(42 * root.scaleFactor)
        color: root.widgetSurfaceInk
    }

    // Tapping her on the desktop summons the live companion
    TapHandler {
        enabled: !GlobalStates.widgetEditMode && sprite.visible
        onTapped: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "poke"])
    }
}
