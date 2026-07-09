pragma ComponentBehavior: Bound

import qs
import QtQuick
import QtQuick.Layouts
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

    implicitWidth: Math.round((root._readConfigKey("contentWidth") ?? 200) * scaleFactor)
    implicitHeight: implicitWidth
    resizableAxes: ({ uniform: "contentWidth" })
    resizeMinWidth: 96
    resizeMinHeight: 96

    readonly property string pose: root._readConfigKey("pose") ?? "reading"
    // Any user-supplied image/GIF replaces the catalog pose entirely
    readonly property string customPath: root._readConfigKey("customPath") ?? ""

    // ── Perching: sit on top of another widget instead of a free-floating spot ──
    readonly property string anchorWidget: root._readConfigKey("anchorWidget") ?? ""
    readonly property string _anchorConfigPath: root.anchorWidget.length > 0 ? ("background.widgets." + root.anchorWidget) : ""
    // Other enabled widgets she could perch on (built-ins + other mascot instances, excluding herself)
    readonly property var _anchorCandidates: {
        Config.revision
        const keys = ["clock", "weather", "mediaControls", "visualizer", "systemMonitor",
            "battery", "notes", "calendarUpcoming", "uptime", "newsTicker"]
        const list = []
        for (const k of keys) {
            if (k === root.configEntryName) continue
            if (Boolean(Config.getNestedValue("background.widgets." + k + ".enable", false)))
                list.push(k)
        }
        const extra = Config.getNestedValue("background.widgets.mascotInstances", {}) ?? {}
        for (const id of Object.keys(extra)) {
            const key = "mascotInstances." + id
            if (key === root.configEntryName) continue
            if (Boolean(Config.getNestedValue("background.widgets." + key + ".enable", false)))
                list.push(key)
        }
        return list
    }
    function _cycleAnchor(dir: int): void {
        const options = [""].concat(root._anchorCandidates)
        const cur = options.indexOf(root.anchorWidget)
        const next = options[((cur === -1 ? 0 : cur) + dir + options.length) % options.length]
        Config.setNestedValue(root._configPath + ".anchorWidget", next)
    }
    // Perches at the anchor's top edge, slightly overlapping it so she reads
    // as standing/sitting on it rather than floating above. Re-runs on every
    // config change (cheap: two reads + a no-op guard) so she follows the
    // anchor if the user drags it, and self-heals if the anchor is removed.
    // Re-entrancy guard: Config.setNestedValues() emits the GLOBAL
    // configChanged signal synchronously, which re-enters this function via
    // the Connections below BEFORE this call frame returns. Without this
    // flag that's unbounded synchronous recursion (hit live: stack overflow
    // across the whole shell, every Config consumer, not just this widget).
    property bool _syncingAnchor: false
    function _syncToAnchor(): void {
        if (root._syncingAnchor) return
        if (root._anchorConfigPath.length === 0) return
        const ax = Number(Config.getNestedValue(root._anchorConfigPath + ".x", NaN))
        const ay = Number(Config.getNestedValue(root._anchorConfigPath + ".y", NaN))
        if (!Number.isFinite(ax) || !Number.isFinite(ay)) return
        // Perch above the anchor; if that would push her off the top of the
        // screen (anchor sits near the top edge), sit below it instead.
        const above = ay - root.height * 0.82
        const nx = Math.round(root._clampX(ax))
        const ny = Math.round(root._clampY(above >= 0 ? above : ay + root.height * 0.18))
        if (Math.round(root.x) === nx && Math.round(root.y) === ny) return
        root._syncingAnchor = true
        const updates = {}
        updates[root._configPath + ".x"] = nx
        updates[root._configPath + ".y"] = ny
        updates[root._configPath + ".placementStrategy"] = "free"
        Config.setNestedValues(updates)
        // "free" mode's live x/y aren't driven by a reactive Binding (see
        // AbstractBackgroundWidget's _autoPosition gate) — force the resync
        // the same way a drag-release does, or she won't visually move.
        root.syncFreePositionFromConfig()
        root._syncingAnchor = false
    }
    Connections {
        target: Config
        function onConfigChanged() { root._syncToAnchor() }
    }
    // Deferred: the FadeLoader's `shown` binding tracks Config.revision, so a
    // synchronous Config write during instantiation re-enters that binding
    // mid-evaluation (logged as a binding loop on `shown`).
    Component.onCompleted: Qt.callLater(root._syncToAnchor)

    // Quick controls: cycle/shuffle the catalog pose right from the desktop.
    // Picking from the catalog clears a custom image on purpose.
    readonly property var _poseList: {
        const m = root._manifest
        const set = new Set()
        Object.keys(m.linesByPose ?? {}).forEach(p => set.add(p))
        ;(m.idlePicks ?? []).forEach(p => set.add(p[0]))
        Object.values(m.reactions ?? {}).forEach(r => (r.poses ?? []).forEach(p => set.add(p)))
        ;(m.animatedPoses ?? []).forEach(p => set.add(p))
        return Array.from(set).sort()
    }
    function _setPose(next: string): void {
        const updates = {}
        updates[root._configPath + ".pose"] = next
        updates[root._configPath + ".customPath"] = ""
        Config.setNestedValues(updates)
    }
    function _cyclePose(dir: int): void {
        const list = root._poseList
        if (list.length === 0) return
        const cur = list.indexOf(root.pose)
        root._setPose(list[((cur === -1 ? 0 : cur) + dir + list.length) % list.length])
    }
    function _shufflePose(): void {
        const list = root._poseList
        if (list.length === 0) return
        root._setPose(list[Math.floor(Math.random() * list.length)])
    }

    editPopoverContent: Component {
        Column {
            spacing: 6
            GridLayout {
                columns: 3
                columnSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "chevron_left"
                    onClicked: root._cyclePose(-1)
                }
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "casino"
                    buttonText: Translation.tr("Shuffle")
                    onClicked: root._shufflePose()
                }
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "chevron_right"
                    onClicked: root._cyclePose(1)
                }
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 180
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.customPath.length > 0 ? Translation.tr("Custom image") : root.pose
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            GridLayout {
                columns: 3
                columnSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                visible: root._anchorCandidates.length > 0
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "chevron_left"
                    onClicked: root._cycleAnchor(-1)
                }
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "chair"
                    buttonText: Translation.tr("Sit on")
                    onClicked: root._cycleAnchor(1)
                }
                SelectionGroupButton {
                    leftmost: true; rightmost: true
                    buttonIcon: "chevron_right"
                    onClicked: root._cycleAnchor(1)
                }
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 180
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: root._anchorCandidates.length > 0
                text: root.anchorWidget.length > 0
                    ? (Translation.tr("Perched on") + " " + root.anchorWidget.split(".").pop())
                    : Translation.tr("Free-floating")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }

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
