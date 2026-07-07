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
    // Any user-supplied image/GIF replaces the catalog pose entirely
    readonly property string customPath: Config.getNestedValue("background.widgets.mascot.customPath", "")

    // GIF poses need AnimatedImage playback; the manifest says which ones
    // (kept whole: the click ladder reads its pose pools from it too)
    property var _manifest: ({})
    readonly property var _animatedPoses: _manifest.animatedPoses ?? []
    FileView {
        path: Quickshell.shellPath("assets/images/mascot/manifest.json")
        onLoadedChanged: {
            if (!loaded) return
            try {
                root._manifest = JSON.parse(text())
            } catch (e) {
                console.warn("[MascotWidget] manifest load failed:", e)
            }
        }
    }

    // Click ladder: pokes escalate through the same manifest pose tiers as
    // the live companion (annoyed → pats → rage), reverting after a moment.
    // With a custom image the ladder is hers no more — clicks just poke the
    // companion instead.
    property string _reactPose: ""
    property int _clicks: 0
    Timer { id: _reactRevert; interval: 6000; onTriggered: root._reactPose = "" }
    Timer { id: _clickReset; interval: 1600; onTriggered: root._clicks = 0 }
    function _reactToClick(): void {
        root._clicks++
        _clickReset.restart()
        const tiers = root._manifest.clickTiers ?? ({})
        const tier = root._clicks >= 4 ? tiers.tier4 : (root._clicks >= 2 ? tiers.tier2 : tiers.tier1)
        const pool = tier?.poses ?? ["annoyed-poked"]
        root._reactPose = pool[Math.floor(Math.random() * pool.length)]
        _reactRevert.restart()
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
        source: {
            if (root.customPath.length > 0)
                return root.customPath.startsWith("file://") ? root.customPath : "file://" + root.customPath
            const p = root._reactPose.length > 0 ? root._reactPose : root.pose
            return Quickshell.shellPath(`assets/images/mascot/inir-mascot-${p}.${root._animatedPoses.includes(p) ? "gif" : "png"}`)
        }
        playing: root.powerActive
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        // custom images aren't pixel art — smooth them; catalog stays crisp
        smooth: root.customPath.length > 0
        mipmap: false

        // Custom images render regardless of the mascot switch; catalog
        // poses stay gated behind it
        visible: (root.customPath.length > 0 || (Config.options?.mascot?.enable ?? false)) && status !== Image.Error
    }
    MaterialSymbol {
        anchors.centerIn: parent
        visible: !sprite.visible
        text: "pets"
        iconSize: Math.round(42 * root.scaleFactor)
        color: root.widgetSurfaceInk
    }

    // Tapping her reacts locally (pose ladder); custom images poke the
    // live companion instead
    TapHandler {
        enabled: !GlobalStates.widgetEditMode && sprite.visible
        onTapped: {
            if (root.customPath.length > 0) {
                Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "poke"])
            } else {
                root._reactToClick()
            }
        }
    }
}
