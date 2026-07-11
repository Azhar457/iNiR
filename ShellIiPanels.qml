import qs.modules.background
import qs.modules.bar
import qs.modules.bootGreeting
import qs.modules.cheatsheet
import qs.modules.controlPanel
import qs.modules.dashboard
import qs.modules.dock
import qs.modules.lock
import qs.modules.mascot
import qs.modules.mediaControls
import qs.modules.notificationPopup
import qs.modules.onScreenDisplay
import qs.modules.pill
import qs.modules.onScreenKeyboard
import qs.modules.recordingOsd
import qs.modules.overview
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.sidebarLeft
import qs.modules.sidebarRight
import qs.modules.tilingOverlay
import qs.modules.verticalBar
import qs.modules.wallpaperSelector
import qs.modules.ii.overlay
import qs.modules.shellUpdate
import qs.modules.workspaceStrip
import "modules/clipboard" as ClipboardModule

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "."

Item {
    id: panelsRoot

    // Immediate panels — visible at first frame or must catch early events
    // Uses `active` which loads synchronously (required for first-frame visibility)
    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // Deferred panels — loaded asynchronously after first frame to reduce boot contention
    // Uses `loading` to pre-load in spare frame time, then `activeAsync` to activate without blocking
    component DeferredPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        // Pre-load async when Config is ready (in spare frame time)
        loading: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
        // Activate async when deferred phase is ready (doesn't block UI)
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // === Immediate panels (first frame + early event capture) ===
    // bar.appearanceStyle picks the horizontal bar's look. classic/islands/scenic/
    // frame are variants of Bar.qml itself; "pill" swaps in a different bar
    // entirely, so it is resolved here rather than inside Bar.qml.
    readonly property bool barVertical: Config.options?.bar?.vertical ?? false
    readonly property bool barPill: (Config.options?.bar?.appearanceStyle ?? "classic") === "pill"

    PanelLoader { identifier: "iiBar"; extraCondition: !panelsRoot.barVertical && !panelsRoot.barPill; component: Bar {} }
    PanelLoader { identifier: "iiBar"; extraCondition: !panelsRoot.barVertical && panelsRoot.barPill; component: PillBar {} }
    PanelLoader { identifier: "iiVerticalBar"; extraCondition: panelsRoot.barVertical; component: VerticalBar {} }
    PanelLoader { identifier: "iiBackground"; component: Background {} }
    PanelLoader { identifier: "iiBackdrop"; extraCondition: Config.options?.background?.backdrop?.enable ?? false; component: Backdrop {} }
    PanelLoader { identifier: "iiDock"; extraCondition: Config.options?.dock?.enable ?? true; component: Dock {} }
    // The pill bar hosts its own toast and OSD faces, so the standalone popup and
    // OSD panels would double every notification and every volume flash. Turning
    // the pill's faces off (bar.pill.toasts / bar.pill.osd) hands each duty back
    // to the standalone panel instead of silencing it.
    PanelLoader { identifier: "iiNotificationPopup"; extraCondition: !panelsRoot.barPill || !(Config.options?.bar?.pill?.toasts ?? true); component: NotificationPopup {} }
    PanelLoader { identifier: "iiOnScreenDisplay"; extraCondition: !panelsRoot.barPill || !(Config.options?.bar?.pill?.osd ?? true); component: OnScreenDisplay {} }

    // === Deferred panels (user-triggered or non-critical at boot) ===
    DeferredPanelLoader { identifier: "iiBootGreeting"; component: BootGreeting {} }
    DeferredPanelLoader { identifier: "iiCheatsheet"; component: Cheatsheet {} }
    DeferredPanelLoader { identifier: "iiControlPanel"; component: ControlPanel {} }
    DeferredPanelLoader { identifier: "iiDashboard"; extraCondition: Config.options?.dashboard?.enable ?? true; component: Dashboard {} }
    DeferredPanelLoader { identifier: "iiLock"; component: Lock {} }
    DeferredPanelLoader { identifier: "iiMediaControls"; component: MediaControls {} }
    DeferredPanelLoader { identifier: "iiOnScreenKeyboard"; component: OnScreenKeyboard {} }
    DeferredPanelLoader { identifier: "iiOverlay"; component: Overlay {} }
    DeferredPanelLoader { identifier: "iiOverview"; component: Overview {} }
    DeferredPanelLoader { identifier: "iiPolkit"; component: Polkit {} }
    DeferredPanelLoader { identifier: "iiRegionSelector"; component: RegionSelector {} }
    DeferredPanelLoader { identifier: "iiScreenCorners"; component: ScreenCorners {} }
    DeferredPanelLoader { identifier: "iiSessionScreen"; component: SessionScreen {} }
    DeferredPanelLoader { identifier: "iiSidebarLeft"; component: SidebarLeft {} }
    DeferredPanelLoader { identifier: "iiSidebarRight"; component: SidebarRight {} }
    DeferredPanelLoader { identifier: "iiTilingOverlay"; component: TilingOverlay {} }
    DeferredPanelLoader { identifier: "iiWallpaperSelector"; component: WallpaperSelector {} }
    DeferredPanelLoader { identifier: "iiCoverflowSelector"; component: WallpaperCoverflow {} }
    DeferredPanelLoader { identifier: "iiClipboard"; component: ClipboardModule.ClipboardPanel {} }
    DeferredPanelLoader { identifier: "iiShellUpdate"; component: ShellUpdateOverlay {} }
    DeferredPanelLoader { identifier: "iiRecordingOsd"; component: RecordingOsd {} }
    DeferredPanelLoader { identifier: "iiWorkspaceStrip"; component: WorkspaceStrip {} }
    DeferredPanelLoader { identifier: "iiMascotCompanion"; extraCondition: Config.options?.mascot?.enable ?? false; component: MascotCompanion {} }

    LazyLoader {
        active: Config.ready && (Config.options?.background?.effects?.ripple?.enable ?? false)
        component: Variants {
            model: Quickshell.screens

            PanelWindow {
                id: rippleWindow
                required property ShellScreen modelData
                screen: modelData
                focusable: false
                color: "transparent"
                visible: ripple.playing

                WlrLayershell.namespace: "quickshell:charging-ripple"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                mask: Region {}
                implicitWidth: modelData.width
                implicitHeight: modelData.height

                FluidRipple {
                    id: ripple
                    anchors.fill: parent
                    color: Appearance.colors.colPrimary
                    duration: Config.options?.background?.effects?.ripple?.rippleDuration ?? 3000

                    Component.onCompleted: {
                        if (Config.options?.background?.effects?.ripple?.reload ?? true) {
                            spawn();
                        }
                    }

                    Connections {
                        target: Battery
                        function onIsPluggedInChanged() {
                            if (Config.options?.background?.effects?.ripple?.charging ?? true) {
                                ripple.spawn();
                            }
                        }
                    }

                    Connections {
                        target: NiriService
                        function onInOverviewChanged() {
                            if (NiriService.inOverview && (Config.options?.background?.effects?.ripple?.overview ?? true)) {
                                if (rippleWindow.modelData.name === NiriService.currentOutput) {
                                    ripple.spawn(0, 0);
                                }
                            }
                        }
                    }

                    Connections {
                        target: GlobalStates
                        function onScreenLockedChanged() {
                            if (GlobalStates.screenLocked && (Config.options?.background?.effects?.ripple?.lock ?? true)) {
                                ripple.spawn();
                            }
                        }

                        function onSessionOpenChanged() {
                            if (GlobalStates.sessionOpen && (Config.options?.background?.effects?.ripple?.session ?? true)) {
                                ripple.spawn();
                            }
                        }

                        function onRequestRipple(x: real, y: real, screenName: string) {
                            if (rippleWindow.modelData.name === screenName) {
                                ripple.spawn(x, y);
                            }
                        }
                    }
                }
            }
        }
    }
}
