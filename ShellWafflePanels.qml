import qs.modules.bootGreeting
import qs.modules.cheatsheet
import qs.modules.lock
import qs.modules.mascot
import qs.modules.onScreenKeyboard
import qs.modules.recordingOsd
import qs.modules.tilingOverlay
import qs.modules.overview
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.wallpaperSelector
import qs.modules.wallpaperLauncher
import qs.modules.ii.overlay
import qs.modules.workspaceStrip
import "modules/clipboard" as ClipboardModule

import qs.modules.waffle.actionCenter
import qs.modules.waffle.altSwitcher as WaffleAltSwitcherModule
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.bar as WaffleBarModule
import qs.modules.waffle.clipboard as WaffleClipboardModule
import qs.modules.waffle.notificationCenter
import qs.modules.waffle.onScreenDisplay as WaffleOSDModule
import qs.modules.waffle.startMenu
import qs.modules.waffle.widgets
import qs.modules.waffle.backdrop as WaffleBackdropModule
import qs.modules.waffle.notificationPopup as WaffleNotificationPopupModule
import qs.modules.waffle.taskview as WaffleTaskViewModule

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services
import qs.services.deferred
import "."

Item {
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
        // Start spare-frame incubation only after the immediate shell has
        // produced its entry frame. Activation remains in the deferred phase.
        loading: Config.ready && GlobalStates.shellEntryReady
            && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
        // Activate async when deferred phase is ready (doesn't block UI)
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    component OnDemandPanelLoader: LazyLoader {
        id: onDemandLoader
        required property string identifier
        required property bool open
        property bool retainAfterUse: false
        property bool used: false
        property int closeGraceMs: 250
        property bool resident: open
        property Timer closeGrace: Timer {
            interval: onDemandLoader.closeGraceMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open
        }
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
        onOpenChanged: {
            if (open) {
                used = true
                closeGrace.stop()
                resident = true
            } else if (!(retainAfterUse && used)) {
                closeGrace.restart()
            }
        }
        loading: enabledPanel && resident
        activeAsync: enabledPanel && GlobalStates.deferredPanelsReady && resident
    }

    // === Immediate panels (first frame + early event capture) ===
    PanelLoader { identifier: "wBar"; component: WaffleBarModule.WaffleBar {} }
    PanelLoader { identifier: "wBackground"; component: WaffleBackgroundModule.WaffleBackground {} }
    PanelLoader { identifier: "wBackdrop"; extraCondition: Config.options?.waffles?.background?.backdrop?.enable ?? true; component: WaffleBackdropModule.WaffleBackdrop {} }
    PanelLoader { identifier: "wNotificationPopup"; component: WaffleNotificationPopupModule.WaffleNotificationPopup {} }
    PanelLoader { identifier: "wOnScreenDisplay"; component: WaffleOSDModule.WaffleOSD {} }

    // === Deferred panels (user-triggered or non-critical at boot) ===
    OnDemandPanelLoader { identifier: "wStartMenu"; open: GlobalStates.searchOpen; retainAfterUse: true; component: WaffleStartMenu {} }
    OnDemandPanelLoader { identifier: "wActionCenter"; open: GlobalStates.waffleActionCenterOpen; retainAfterUse: true; component: WaffleActionCenter {} }
    OnDemandPanelLoader { identifier: "wNotificationCenter"; open: GlobalStates.waffleNotificationCenterOpen; component: WaffleNotificationCenter {} }
    OnDemandPanelLoader { identifier: "wWidgets"; open: GlobalStates.waffleWidgetsOpen && (Config.options?.waffles?.modules?.widgets ?? true); component: WaffleWidgets {} }
    DeferredPanelLoader { identifier: "wLock"; component: Lock {} }
    DeferredPanelLoader { identifier: "wPolkit"; component: Polkit {} }
    OnDemandPanelLoader { identifier: "wSessionScreen"; open: GlobalStates.sessionOpen; component: SessionScreen {} }
    OnDemandPanelLoader { identifier: "wTaskView"; open: GlobalStates.waffleTaskViewOpen; component: WaffleTaskViewModule.WaffleTaskView {} }

    // Shared modules that work with waffle (all deferred — user-triggered)
    DeferredPanelLoader { identifier: "iiBootGreeting"; component: BootGreeting {} }
    OnDemandPanelLoader { identifier: "iiCheatsheet"; open: GlobalStates.cheatsheetOpen; component: Cheatsheet {} }
    OnDemandPanelLoader { identifier: "iiOnScreenKeyboard"; open: GlobalStates.oskOpen; component: OnScreenKeyboard {} }
    OnDemandPanelLoader { identifier: "iiOverlay"; open: GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets; component: Overlay {} }
    OnDemandPanelLoader { identifier: "iiOverview"; open: GlobalStates.overviewOpen; retainAfterUse: true; closeGraceMs: 300; component: Overview {} }
    RegionSelectorRouter {}
    // RegionSelector owns its own lazy content. Keep this root resident so a
    // first cold IPC call cannot race two nested on-demand loaders.
    DeferredPanelLoader { identifier: "iiRegionSelector"; component: RegionSelector {} }
    DeferredPanelLoader { identifier: "iiScreenCorners"; component: ScreenCorners {} }
    WallpaperSelectorRouter {}
    OnDemandPanelLoader { identifier: "iiWallpaperSelector"; open: GlobalStates.wallpaperSelectorOpen; retainAfterUse: true; closeGraceMs: 250; component: WallpaperSelector {} }
    OnDemandPanelLoader { identifier: "iiWallpaperLauncher"; open: GlobalStates.wallpaperLauncherOpen; retainAfterUse: true; closeGraceMs: 250; component: WallpaperLauncher {} }
    OnDemandPanelLoader { identifier: "iiCoverflowSelector"; open: GlobalStates.coverflowSelectorOpen; retainAfterUse: true; closeGraceMs: 300; component: WallpaperCoverflow {} }
    DeferredPanelLoader { identifier: "iiClipboard"; extraCondition: Config.options?.panelFamily !== "waffle"; component: ClipboardModule.ClipboardPanel {} }
    OnDemandPanelLoader { identifier: "iiRecordingOsd"; open: RecorderStatus.isRecording; closeGraceMs: 250; component: RecordingOsd {} }
    TilingOverlayRouter {}
    OnDemandPanelLoader {
        identifier: "iiTilingOverlay"
        open: GlobalStates.tilingOverlayPickerOpen || GlobalStates.tilingOverlayOsdOpen
        closeGraceMs: 250
        component: TilingOverlay {}
    }
    DeferredPanelLoader { identifier: "iiWorkspaceStrip"; component: WorkspaceStrip {} }
    DeferredPanelLoader { identifier: "iiMascotCompanion"; extraCondition: Config.options?.mascot?.enable ?? false; component: MascotCompanion {} }

    // Waffle Clipboard - handles IPC when panelFamily === "waffle"
    LazyLoader {
        loading: Config.ready && GlobalStates.shellEntryReady
            && Config.options?.panelFamily === "waffle"
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady && Config.options?.panelFamily === "waffle"
        component: WaffleClipboardModule.WaffleClipboard {}
    }

    IpcHandler {
        target: "search"
        function toggle(): void { GlobalStates.searchOpen = !GlobalStates.searchOpen }
        function close(): void { GlobalStates.searchOpen = false }
        function open(): void { GlobalStates.searchOpen = true }
    }
    IpcHandler {
        target: "wactionCenter"
        function toggle(): void { GlobalStates.waffleActionCenterOpen = !GlobalStates.waffleActionCenterOpen }
    }
    IpcHandler {
        target: "wnotificationCenter"
        function toggle(): void { GlobalStates.waffleNotificationCenterOpen = !GlobalStates.waffleNotificationCenterOpen }
    }
    IpcHandler {
        target: "wwidgets"
        function toggle(): void { GlobalStates.waffleWidgetsOpen = !GlobalStates.waffleWidgetsOpen }
        function close(): void { GlobalStates.waffleWidgetsOpen = false }
        function open(): void { GlobalStates.waffleWidgetsOpen = true }
    }
    IpcHandler {
        target: "taskview"
        function toggle(): void { GlobalStates.waffleTaskViewOpen = !GlobalStates.waffleTaskViewOpen }
        function close(): void { GlobalStates.waffleTaskViewOpen = false }
        function open(): void { GlobalStates.waffleTaskViewOpen = true }
    }
    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { GlobalStates.cheatsheetOpen = !GlobalStates.cheatsheetOpen }
        function close(): void { GlobalStates.cheatsheetOpen = false }
        function open(): void { GlobalStates.cheatsheetOpen = true }
    }
    IpcHandler {
        target: "osk"
        function toggle(): void { GlobalStates.oskOpen = !GlobalStates.oskOpen }
        function close(): void { GlobalStates.oskOpen = false }
        function open(): void { GlobalStates.oskOpen = true }
    }
    IpcHandler {
        target: "overlay"
        function toggle(): void { GlobalStates.overlayOpen = !GlobalStates.overlayOpen }
    }
    IpcHandler {
        target: "session"
        function toggle(): void { GlobalStates.sessionOpen = !GlobalStates.sessionOpen }
        function close(): void { GlobalStates.sessionOpen = false }
        function open(): void { GlobalStates.sessionOpen = true }
    }
    IpcHandler {
        target: "overview"
        function toggle(): void { GlobalStates.searchOpen = !GlobalStates.searchOpen }
        function close(): void { GlobalStates.searchOpen = false }
        function open(): void { GlobalStates.searchOpen = true }
        function toggleReleaseInterrupt(): void { GlobalStates.superReleaseMightTrigger = false }
        function clipboardToggle(): void {
            LauncherSearch.ensurePrefix(Config.options?.search?.prefix?.clipboard ?? ";")
            GlobalStates.searchOpen = true
        }
        function actionOpen(): void {
            LauncherSearch.ensurePrefix(Config.options?.search?.prefix?.action ?? "/")
            GlobalStates.searchOpen = true
        }
    }

    // Waffle AltSwitcher - handles IPC when panelFamily === "waffle"
    LazyLoader {
        loading: Config.ready && GlobalStates.shellEntryReady
            && Config.options?.panelFamily === "waffle"
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady && Config.options?.panelFamily === "waffle"
        component: WaffleAltSwitcherModule.WaffleAltSwitcher {}
    }

    // Dedicated editor overlay, created after Waffle panels so its HUD remains
    // above the taskbar and other persistent surfaces.
    WaffleBackgroundModule.WaffleShellEditHud {}
}
