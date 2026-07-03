import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.sidebarLeft.animeSchedule
import qs.modules.sidebarLeft.innertune
import qs.modules.sidebarLeft.news
// DISABLED: webapps — requires quickshell-webengine rebuild, re-enable when ready
// import qs.modules.sidebarLeft.plugins
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

Item {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 10
    property int screenWidth: 1920
    property int screenHeight: 1080
    property var panelScreen: null
    property bool panelVisible: false

    property bool aiChatEnabled: (Config.options?.policies?.ai ?? 0) !== 0
    property bool translatorEnabled: (Config.options?.sidebar?.translator?.enable ?? false)
    property bool animeEnabled: (Config.options?.policies?.weeb ?? 0) !== 0
    property bool animeCloset: (Config.options?.policies?.weeb ?? 0) === 2
    property bool animeScheduleEnabled: Config.options?.sidebar?.animeSchedule?.enable ?? false
    property bool wallhavenEnabled: Config.options?.sidebar?.wallhaven?.enable !== false
    property bool newsEnabled: Config.options?.sidebar?.news?.enable ?? true
    property bool widgetsEnabled: Config.options?.sidebar?.widgets?.enable ?? true
    property bool toolsEnabled: Config.options?.sidebar?.tools?.enable ?? false
    property bool softwareEnabled: Config.options?.sidebar?.software?.enable ?? false
    property bool ytMusicEnabled: Config.options?.sidebar?.ytmusic?.enable ?? false
    // DISABLED: webapps — requires quickshell-webengine rebuild
    property bool pluginsEnabled: false // Config.options?.sidebar?.plugins?.enable ?? false

    // ─── WebApp state — DISABLED (requires quickshell-webengine) ─────
    property string _activeWebAppId: ""
    property bool pluginViewActive: false // _activeWebAppId !== ""

    // Persistent cache: pluginId → WebAppView instance
    property var _webViewCache: ({})
    property int _webViewCount: 0  // for reactivity

    // DISABLED: webapps — all functions below are stubs until quickshell-webengine is available
    property var _profileCache: ({})

    function _getOrCreateProfile(id: string): QtObject { return null }

    // ─── WebApp management functions (DISABLED) ──────────────────────

    function openWebApp(id: string, url: string, name: string, icon: string, userscriptSources): void {}
    function closeWebApp(): void {}
    function removeWebApp(id: string): void {}
    function _freezeAllWebApps(): void {}
    function _resumeActiveWebApp(): void {}

    // ─── Restore last active plugin (DISABLED) ──────────────────────
    property bool _restoredLastPlugin: false
    function _tryRestoreLastPlugin(): void {}
    function _doRestoreLastPlugin(): void {}

    // Tab button list - simple static order
    property var tabButtonList: {
        const result = []
        if (root.widgetsEnabled) result.push({ icon: "widgets", name: Translation.tr("Widgets") })
        if (root.aiChatEnabled) result.push({ icon: "neurology", name: Translation.tr("Intelligence") })
        if (root.translatorEnabled) result.push({ icon: "translate", name: Translation.tr("Translator") })
        if (root.animeEnabled && !root.animeCloset) result.push({ icon: "bookmark_heart", name: Translation.tr("Anime") })
        if (root.animeScheduleEnabled) result.push({ icon: "calendar_month", name: Translation.tr("Schedule") })
        if (root.wallhavenEnabled) result.push({ icon: "collections", name: Translation.tr("Wallhaven") })
        if (root.newsEnabled) result.push({ icon: "newspaper", name: Translation.tr("News") })
        if (root.ytMusicEnabled) result.push({ icon: "library_music", name: Translation.tr("YT Music") })
        if (root.toolsEnabled) result.push({ icon: "build", name: Translation.tr("Tools") })
        if (root.softwareEnabled) result.push({ icon: "store", name: Translation.tr("Software") })
        // DISABLED: webapps — requires quickshell-webengine rebuild
        // if (root.pluginsEnabled) result.push({ icon: "extension", name: Translation.tr("Web Apps") })
        return result
    }

    // Find the index of the plugins tab
    readonly property int _pluginsTabIndex: {
        for (let i = 0; i < tabButtonList.length; i++) {
            if (tabButtonList[i].icon === "extension") return i
        }
        return -1
    }

    function focusActiveItem() {
        swipeView.currentItem?.forceActiveFocus()
    }

    implicitHeight: sidebarLeftBackground.implicitHeight
    implicitWidth: sidebarLeftBackground.implicitWidth

    StyledRectangularShadow {
        target: sidebarLeftBackground
        visible: !Appearance.gameModeMinimal
    }
    Rectangle {
        id: sidebarLeftBackground

        anchors.fill: parent
        implicitHeight: parent.height - Appearance.sizes.hyprlandGapsOut * 2
        implicitWidth: sidebarWidth - Appearance.sizes.hyprlandGapsOut * 2
        property bool cardStyle: Config.options?.sidebar?.cardStyle ?? false
        readonly property bool angelEverywhere: Appearance.angelEverywhere
        readonly property bool auroraEverywhere: Appearance.auroraEverywhere
        readonly property bool gameModeMinimal: Appearance.gameModeMinimal
        readonly property string wallpaperUrl: {
            const _dep1 = WallpaperListener.multiMonitorEnabled
            const _dep2 = WallpaperListener.effectivePerMonitor
            const _dep3 = Wallpapers.effectiveWallpaperUrl
            return WallpaperListener.wallpaperUrlForScreen(root.panelScreen)
        }
        readonly property bool useWallpaperBackdrop: root.panelVisible
            && auroraEverywhere
            && !gameModeMinimal
            && wallpaperUrl.length > 0

        ColorQuantizer {
            id: sidebarLeftWallpaperQuantizer
            source: (Appearance.auroraEverywhere || Appearance.angelEverywhere) ? sidebarLeftBackground.wallpaperUrl : ""
            depth: 0
            rescaleSize: 10
        }

        readonly property color wallpaperDominantColor: (sidebarLeftWallpaperQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
        readonly property QtObject blendedColors: AdaptedMaterialScheme {
            color: ColorUtils.mix(sidebarLeftBackground.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.colors.colSecondaryContainer
        }

        color: gameModeMinimal ? "transparent"
             : Appearance.zzzEverywhere ? Appearance.zzz.chrome
             : auroraEverywhere ? ColorUtils.applyAlpha((blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
             : (cardStyle ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0)
        border.width: gameModeMinimal ? 0 : Appearance.zzzEverywhere ? 1 : (angelEverywhere ? Appearance.angel.panelBorderWidth : 1)
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairline
            : angelEverywhere ? Appearance.angel.colPanelBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.colors.colLayer0Border
        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
            : angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
            : cardStyle ? Appearance.rounding.normal : (Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1)

        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        clip: true

        // Mask to the rounded panel shape in ZZZ so NO child (backdrop grid,
        // corner ticks, cards) can re-square the corners — surfaces must never break.
        layer.enabled: useWallpaperBackdrop || (Appearance.zzzEverywhere && !gameModeMinimal)
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: sidebarLeftBackground.width
                height: sidebarLeftBackground.height
                radius: sidebarLeftBackground.radius
            }
        }

        Image {
            id: sidebarLeftBlurredWallpaper
            x: -Appearance.sizes.hyprlandGapsOut
            y: -Appearance.sizes.hyprlandGapsOut
            width: root.screenWidth
            height: root.screenHeight
            visible: sidebarLeftBackground.useWallpaperBackdrop
            source: sidebarLeftBackground.useWallpaperBackdrop ? sidebarLeftBackground.wallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screenWidth
            sourceSize.height: root.screenHeight
            asynchronous: true

            // OPTIMIZATION: Release FBO when sidebar is hidden (saves ~16 MiB VRAM)
            layer.enabled: Appearance.effectsEnabled && sidebarLeftBackground.useWallpaperBackdrop && root.panelVisible
            layer.effect: MultiEffect {
                source: sidebarLeftBlurredWallpaper
                anchors.fill: source
                saturation: sidebarLeftBackground.angelEverywhere
                    ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled
                    ? (sidebarLeftBackground.angelEverywhere ? Appearance.angel.blurIntensity : 1)
                    : 0
            }

            Rectangle {
                anchors.fill: parent
                color: sidebarLeftBackground.angelEverywhere
                    ? ColorUtils.transparentize((sidebarLeftBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity * Appearance.angel.panelTransparentize)
                    : ColorUtils.transparentize((sidebarLeftBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        // Angel inset glow — top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: sidebarLeftBackground.angelEverywhere
            color: Appearance.angel.colInsetGlow
            z: 10
        }

        // Angel partial border — elegant half-borders
        AngelPartialBorder {
            targetRadius: sidebarLeftBackground.radius
            z: 10
        }

        ZzzPanelBackdrop {
            anchors.fill: parent
            label: "INTELLIGENCE"
            index: "L"
            ghostText: "LEFT"
            accentColor: Appearance.zzz.chromeStroke
            showTicks: false
            showBurst: false
            showGrid: true
            horizontalBias: 0.18
            verticalBias: 0.04
            ghostWidthFactor: 0.86
            ghostStrength: 0.7
            z: 0
        }

        // ZZZ content wash: a subtle stepped tile plate lifts the content area
        // off the bare chrome so cards/text read cleanly while the structural
        // hairlines stay. Kept low-alpha so chrome + ghost marks still breathe.
        Rectangle {
            anchors.fill: parent
            visible: Appearance.zzzEverywhere
            color: ColorUtils.applyAlpha(Appearance.zzz.tile, 0.55)
            z: 0
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: sidebarPadding
            anchors.topMargin: Appearance.angelEverywhere ? sidebarPadding + 4
                : Appearance.inirEverywhere ? sidebarPadding + 6 : sidebarPadding
            spacing: Appearance.angelEverywhere ? sidebarPadding + 2
                : Appearance.inirEverywhere ? sidebarPadding + 4 : sidebarPadding

            // Tab bar — hidden when webapp is fullscreen in sidebar
            Toolbar {
                id: toolbarContainer
                Layout.alignment: Qt.AlignHCenter
                enableShadow: false
                transparent: Appearance.zzzEverywhere || Appearance.auroraEverywhere || Appearance.inirEverywhere
                visible: !root.pluginViewActive
                ToolbarTabBar {
                    id: tabBar
                    Layout.alignment: Qt.AlignHCenter
                    maxWidth: Math.max(0, root.width - (root.sidebarPadding * 2) - 16)
                    tabButtonList: root.tabButtonList
                    // Don't bind to swipeView - let tabBar be the source of truth
                    onCurrentIndexChanged: swipeView.currentIndex = currentIndex
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.zzzEverywhere ? Appearance.zzz.cardRadius
                    : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                    : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                color: Appearance.zzzEverywhere ? "transparent"
                    : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.auroraEverywhere ? "transparent"
                     : Appearance.colors.colLayer1
                border.width: Appearance.zzzEverywhere ? 0
                    : Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                    : Appearance.inirEverywhere ? 1 : 0
                border.color: Appearance.zzzEverywhere ? "transparent"
                    : Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
                // Organic morph on style/shape switch (organic-transitions)
                Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

                // SwipeView with normal tab content
                SwipeView {
                    id: swipeView
                    anchors.fill: parent
                    spacing: 10
                    visible: !root.pluginViewActive
                    // Sync back to tabBar when swiping
                    onCurrentIndexChanged: {
                        tabBar.setCurrentIndex(currentIndex)
                        const currentTab = root.tabButtonList[currentIndex]
                        if (currentTab?.icon === "neurology") {
                            Ai.ensureInitialized()
                        }
                    }
                    interactive: !(currentItem?.item?.editMode ?? false) && !(currentItem?.item?.dragPending ?? false)

                    clip: true
                    layer.enabled: !Appearance.gameModeMinimal
                    layer.effect: GE.OpacityMask {
                        maskSource: Rectangle {
                            width: swipeView.width
                            height: swipeView.height
                            radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                            Behavior on radius {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                    }

                    Repeater {
                        model: root.tabButtonList
                        delegate: Loader {
                            required property var modelData
                            required property int index
                            active: SwipeView.isCurrentItem || SwipeView.isNextItem || SwipeView.isPreviousItem
                            sourceComponent: {
                                switch (modelData.icon) {
                                    case "widgets": return widgetsComp
                                    case "neurology": return aiChatComp
                                    case "translate": return translatorComp
                                    case "bookmark_heart": return animeComp
                                    case "calendar_month": return animeScheduleComp
                                    case "collections": return wallhavenComp
                                    case "newspaper": return newsComp
                                    case "library_music": return ytMusicComp
                                    case "build": return toolsComp
                                    case "store": return softwareComp
                                    // DISABLED: webapps
                                    // case "extension": return pluginsComp
                                    default: return null
                                }
                            }
                        }
                    }
                }

                // ── WebApp overlay ───────────────────────────────────
                // WebAppViews live HERE, above the SwipeView.
                // Visibility controlled by: active webapp + sidebar open state.
                Item {
                    id: webAppOverlay
                    anchors.fill: parent
                    visible: root.pluginViewActive && GlobalStates.sidebarLeftOpen
                    z: 5
                }
            }
        }

        Component { id: widgetsComp; WidgetsView {} }
        Component { id: aiChatComp; AiChat {} }
        Component { id: translatorComp; Translator {} }
        Component { id: animeComp; Anime {} }
        Component { id: animeScheduleComp; AnimeScheduleView {} }
        Component { id: wallhavenComp; WallhavenView {} }
        Component { id: newsComp; NewsView {} }
        Component { id: ytMusicComp; InnerTuneView {} }
        Component { id: toolsComp; ToolsView {} }
        Component { id: softwareComp; SoftwareView {} }
        // DISABLED: webapps — requires quickshell-webengine rebuild
        // Component {
        //     id: pluginsComp
        //     PluginsTab {
        //         activePluginId: root._activeWebAppId
        //         onPluginRequested: (id, url, name, icon, userscriptSources) => root.openWebApp(id, url, name, icon, userscriptSources)
        //         onPluginCloseRequested: root.closeWebApp()
        //         onPluginRemoved: (id) => root.removeWebApp(id)
        //     }
        // }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                // If webapp is open, close it first (go back to list)
                if (root.pluginViewActive) {
                    root.closeWebApp()
                    event.accepted = true
                    return
                }
                GlobalStates.sidebarLeftOpen = false
            }
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    swipeView.incrementCurrentIndex()
                    event.accepted = true
                }
                else if (event.key === Qt.Key_PageUp) {
                    swipeView.decrementCurrentIndex()
                    event.accepted = true
                }
                else if (event.key === Qt.Key_O) {
                    GlobalStates.sidebarLeftExpanded = !GlobalStates.sidebarLeftExpanded
                    event.accepted = true
                }
                else if (event.key === Qt.Key_P) {
                    GlobalStates.sidebarLeftOpen = false
                    GlobalStates.sidebarLeftExpanded = false
                    GlobalStates.aiChatDetached = true
                    event.accepted = true
                }
            }
        }
    }

    // ── Restore last active plugin (DISABLED — webapps) ────────────
    // Connections {
    //     target: Config
    //     function onReadyChanged() {
    //         if (Config.ready && root.pluginsEnabled) {
    //             root._tryRestoreLastPlugin()
    //         }
    //     }
    // }

    // Component.onCompleted: {
    //     if (Config.ready && root.pluginsEnabled) {
    //         root._tryRestoreLastPlugin()
    //     }
    // }
}
