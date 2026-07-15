pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.pill

// Edge-hover workspace navigator with window thumbnails and a now-playing
// media flyout.
//
// Hidden until the configured edge is hovered (zero visible pixels, input
// limited to the trigger zone). A single window-level hover region drives the
// open/close lifecycle so moving between cards and into a flyout never makes it
// flicker; it closes on its own once the pointer leaves the panel. A vertical,
// scrollable rail of thumbnails sits flush against the edge; the active or
// hovered entry is highlighted and spawns a detached flyout toward the interior.
Scope {
    id: root

    property bool ipcOpen: false
    signal closeRequested()

    function refreshCachedPreviews(): void {
        if (!(Config.options?.workspaceStrip?.showPreviews ?? true) || !CompositorService.isNiri)
            return
        WindowPreviewService.initialize()
        WindowPreviewService.captureForTaskView()
    }

    IpcHandler {
        target: "workspaceStrip"

        function open(): string {
            root.ipcOpen = true
            root.refreshCachedPreviews()
            return "open"
        }
        function close(): string {
            root.ipcOpen = false
            root.closeRequested()
            return "closed"
        }
        function toggle(): string {
            root.ipcOpen = !root.ipcOpen
            if (root.ipcOpen) root.refreshCachedPreviews()
            else root.closeRequested()
            return root.ipcOpen ? "open" : "closed"
        }
        function status(): string {
            return root.ipcOpen ? "open" : "auto"
        }
    }

    Variants {
        model: Quickshell.screens

        Loader {
            id: stripLoader
            required property var modelData
            active: true

            // The layershell anchor can't be flipped on a live window: swapping
            // left/right left the strip stuck on the old edge until it was toggled
            // off and on. Recreate it instead, the same way the dock handles moves.
            property string sideKey: Config.options?.workspaceStrip?.side ?? "right"
            onSideKeyChanged: {
                active = false
                stripReloadTimer.start()
            }

            Timer {
                id: stripReloadTimer
                interval: 50
                onTriggered: stripLoader.active = true
            }

            sourceComponent: PanelWindow {
            id: stripWindow
            property var modelData: stripLoader.modelData

            readonly property string screenName: modelData?.name ?? ""
            readonly property bool isRight: (Config.options?.workspaceStrip?.side ?? "right") === "right"
            readonly property int previewSize: Math.max(64, Config.options?.workspaceStrip?.previewSize ?? 150)
            // panelWidth is clamped below to whatever actually fits rail + flyout
            // for the chosen previewSize (see _minPanelWidth); a too-small value
            // would push the side flyout off the window or onto the rail.
            readonly property int configPanelWidth: Math.max(360, Config.options?.workspaceStrip?.panelWidth ?? 480)
            readonly property int _minFlyoutWidth: 196
            readonly property int _minPanelWidth: railWidth + edgeMargin * 2 + _minFlyoutWidth + 14
            readonly property int panelWidth: Math.max(_minPanelWidth, configPanelWidth)
            readonly property int triggerZone: Math.max(1, Config.options?.workspaceStrip?.triggerWidth ?? 6)
            readonly property int openDelay: Math.max(1, Config.options?.workspaceStrip?.openDelay ?? 110)
            readonly property int closeDelay: Math.max(1, Config.options?.workspaceStrip?.closeDelay ?? 320)
            readonly property bool showAppIcons: Config.options?.workspaceStrip?.showAppIcons ?? true
            readonly property bool showMetadata: Config.options?.workspaceStrip?.showMetadata ?? true
            readonly property bool showPreviews: Config.options?.workspaceStrip?.showPreviews ?? true
            readonly property bool showMediaPlayer: Config.options?.workspaceStrip?.showMediaPlayer ?? true
            // Chrome dialect. The Ricelin island look is opt-in so every global
            // style keeps its own surface design: "auto" follows the bar (island
            // only while the pill bar is active), "island"/"stock" force it.
            readonly property string chromeStyle: Config.options?.workspaceStrip?.style ?? "auto"
            readonly property bool islandChrome: !Appearance.zzzEverywhere
                && (chromeStyle === "island"
                    || (chromeStyle === "auto"
                        && (Config.options?.bar?.appearanceStyle ?? "classic") === "pill"))
            readonly property bool perMonitor: (Config.options?.workspaceStrip?.perMonitor ?? true) && CompositorService.isNiri
            readonly property bool scrollNavigation: Config.options?.workspaceStrip?.scrollNavigation ?? false
            readonly property bool scrollNavigationSwitchWorkspace: Config.options?.workspaceStrip?.scrollNavigationSwitchWorkspace ?? true
            readonly property int scrollNavigationDebounceMs: Math.max(50, Config.options?.workspaceStrip?.scrollNavigationDebounceMs ?? 180)
            readonly property real mouseScrollDeltaThreshold: Config.options?.interactions?.scrolling?.mouseScrollDeltaThreshold ?? 120
            readonly property real mouseScrollFactor: Config.options?.interactions?.scrolling?.mouseScrollFactor ?? 120
            readonly property real touchpadScrollFactor: Config.options?.interactions?.scrolling?.touchpadScrollFactor ?? 450
            // Accumulated scroll delta — supports multi-notch mouse wheels and
            // continuous touchpad scrolls without skittering on micro-movements.
            property real _scrollAccum: 0

            // Landscape card geometry — windows are landscape, so a 16:10 thumbnail
            // shows their real shape instead of a cropped vertical slice. The media
            // card is square (album art) and overrides this ratio itself.
            readonly property real cardRatio: 0.625
            readonly property int cardBaseW: previewSize
            readonly property int cardBaseH: Math.round(previewSize * cardRatio)
            readonly property int cardSelW: Math.round(previewSize * 1.22)
            readonly property int cardSelH: Math.round(cardSelW * cardRatio)
            readonly property int railWidth: cardSelW + 16
            readonly property int edgeMargin: 12
            readonly property int railInset: panelWidth - railWidth - edgeMargin
            readonly property int detailWidth: Math.max(190, railInset - edgeMargin + 14)

            // Now-playing entry at the head of the rail.
            readonly property int mediaKey: -100
            readonly property bool hasPlayer: showMediaPlayer && MprisController.activePlayer !== null
            readonly property bool selIsMedia: _hoveredKey === mediaKey

            readonly property var outputWorkspaces: {
                if (CompositorService.isNiri) {
                    const ws = perMonitor && screenName.length > 0
                        ? (NiriService.allWorkspaces ?? []).filter(w => w.output === screenName)
                        : (NiriService.currentOutputWorkspaces ?? [])
                    return ws.slice().sort((a, b) => (a?.idx ?? 0) - (b?.idx ?? 0))
                }
                if (CompositorService.isHyprland)
                    return (Hyprland.workspaces.values ?? []).slice().sort((a, b) => (a?.id ?? 0) - (b?.id ?? 0))
                return []
            }

            // Niri-only: bucket every window by its workspace id ONCE per window
            // list change, instead of each card filtering the full window list on
            // its own. Cards read their slice from this map by workspace id, which
            // keeps the rail O(windows) on refresh rather than O(workspaces×windows).
            readonly property var windowsByWorkspace: {
                if (!CompositorService.isNiri) return ({})
                const map = ({})
                const wins = NiriService.windows ?? []
                for (let i = 0; i < wins.length; i++) {
                    const w = wins[i]
                    const wid = w?.workspace_id ?? 0
                    if (!map[wid]) map[wid] = []
                    map[wid].push(w)
                }
                return map
            }

            readonly property bool shown: root.ipcOpen || _hoverOpen
            property bool _hoverOpen: false
            property int _hoveredKey: -1
            property Item _selDelegate: null

            function keyFor(ws, index: int): int {
                const id = ws?.id ?? 0
                if (id > 0) return id
                return (CompositorService.isNiri ? (ws?.idx ?? index + 1) : (ws?.id ?? index + 1))
            }

            function dismiss(): void {
                root.ipcOpen = false
                _hoverOpen = false
                _hoveredKey = -1
            }

            function switchWorkspace(ws, index: int): void {
                if (CompositorService.isNiri) {
                    // Address the workspace by its stable id so a card on a
                    // non-focused monitor switches the right workspace; a niri
                    // Index reference resolves against the focused output only.
                    const id = ws?.id ?? 0
                    if (id > 0) NiriService.switchToWorkspaceById(id)
                    else NiriService.switchToWorkspace(ws?.idx ?? index + 1)
                } else if (CompositorService.isHyprland) {
                    Hyprland.dispatch(`workspace ${ws?.id ?? index + 1}`)
                }
                dismiss()
            }

            // Scroll-navigation: move the selection one slot through the rail
            // (media head + workspace cards) without leaving the strip. dir > 0
            // moves toward the end of the rail.
            function stepSelection(dir: int): void {
                const list = outputWorkspaces
                if (list.length === 0) return
                // Build the ordered key list: media slot first (if shown), then ws.
                const keys = []
                if (hasPlayer) keys.push(mediaKey)
                for (let i = 0; i < list.length; i++) keys.push(keyFor(list[i], i))

                // Current index: the hovered key, or the active workspace.
                let cur = keys.indexOf(_hoveredKey)
                if (cur < 0) {
                    const activeIdx = list.findIndex(w => CompositorService.isNiri
                        ? (w?.is_active ?? false) : (w?.active ?? false))
                    cur = (hasPlayer ? 1 : 0) + Math.max(0, activeIdx)
                }
                const next = Math.max(0, Math.min(keys.length - 1, cur + (dir > 0 ? 1 : -1)))
                _hoveredKey = keys[next]
            }

            // Step the selection, scroll it into view, and optionally switch
            // the compositor workspace. Used by both the WheelHandler and the
            // scroll cooldown timer so the logic lives in one place.
            function stepAndSwitch(dir: int): void {
                stepSelection(dir)
                Qt.callLater(railFlick.ensureSelectionVisible)
                if (!scrollNavigationSwitchWorkspace) return
                if (_hoveredKey === mediaKey || _hoveredKey < 0) return
                const newKey = _hoveredKey
                const list = outputWorkspaces
                for (let wi = 0; wi < list.length; wi++) {
                    if (keyFor(list[wi], wi) === newKey) {
                        const ws = list[wi]
                        if (CompositorService.isNiri) {
                            const id = ws?.id ?? 0
                            if (id > 0) NiriService.switchToWorkspaceById(id)
                            else NiriService.switchToWorkspace(ws?.idx ?? (wi + 1))
                        } else if (CompositorService.isHyprland) {
                            Hyprland.dispatch(`workspace ${ws?.id ?? (wi + 1)}`)
                        }
                        break
                    }
                }
            }

            // Focus a specific window (and switch to its workspace), then close.
            function focusWindow(win): void {
                if (win === null) return
                if (CompositorService.isNiri) NiriService.focusWindow(win.id)
                else if (CompositorService.isHyprland)
                    Hyprland.dispatch(`focuswindow address:0x${(win.address ?? "").replace(/^0x/, "")}`)
                dismiss()
            }

            // Close a window in place; the strip stays open so several can be
            // dismissed in a row.
            function closeWindow(win): void {
                if (win === null) return
                if (CompositorService.isNiri) NiriService.closeWindow(win.id)
                else if (CompositorService.isHyprland)
                    Hyprland.dispatch(`closewindow address:0x${(win.address ?? "").replace(/^0x/, "")}`)
            }

            // Move a window to another workspace without stealing focus, so the
            // strip can be used to reorganize windows without leaving the current
            // view. The flyout refreshes from live service state.
            function moveWindowToWorkspace(win, ws, index: int): void {
                if (win === null || ws === null) return
                if (CompositorService.isNiri) {
                    // Target the destination by id so the window lands on the
                    // right monitor's workspace even when it isn't focused.
                    const id = ws?.id ?? 0
                    if (id > 0) NiriService.moveWindowToWorkspaceById(win.id, id, false)
                    else NiriService.moveWindowToWorkspace(win.id, ws?.idx ?? index + 1, false)
                } else if (CompositorService.isHyprland) {
                    const id = ws?.id ?? index + 1
                    Hyprland.dispatch(`movetoworkspacesilent ${id},address:0x${(win.address ?? "").replace(/^0x/, "")}`)
                }
            }

            // Send a window to a fresh workspace at the end of THIS strip's
            // output. Niri always keeps one empty trailing workspace per output,
            // so the last entry of the (output-scoped) rail is that empty slot;
            // target it by id so the window stays on this monitor and niri spawns
            // the next empty workspace behind it. An Index reference would resolve
            // against the focused output and could land on the wrong monitor.
            function moveWindowToNewWorkspace(win): void {
                if (win === null) return
                if (CompositorService.isNiri) {
                    const list = outputWorkspaces
                    const last = list.length > 0 ? list[list.length - 1] : null
                    const lastId = last?.id ?? 0
                    if (lastId > 0) NiriService.moveWindowToWorkspaceById(win.id, lastId, false)
                    else NiriService.moveWindowToWorkspace(win.id, (last?.idx ?? 0) + 1, false)
                } else if (CompositorService.isHyprland) {
                    Hyprland.dispatch(`movetoworkspacesilent empty,address:0x${(win.address ?? "").replace(/^0x/, "")}`)
                }
            }

            screen: modelData
            implicitWidth: panelWidth
            implicitHeight: modelData.height
            visible: !GameMode.shouldHidePanels
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:workspaceStrip"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                right: isRight
                left: !isRight
            }

            // The sliding container IS the input mask AND the hover detector, all
            // one object. This is the key anti-flicker contract (mirrors the Dock):
            // when the mask, the thing that slides, and the thing that senses the
            // pointer are the same item, the input region can never desync from the
            // animated geometry mid-slide. The previous design animated three
            // separate objects (a HoverHandler, a mask Item, and content.x) and the
            // mask read the content's geometry a frame late, which dropped hover
            // mid-animation and oscillated open/closed under heavier styles.
            mask: Region { item: GameMode.shouldHidePanels ? emptyMask : stripContent }

            Item { id: emptyMask; width: 0; height: 0 }

            Connections {
                target: root
                function onCloseRequested(): void {
                    stripWindow._hoverOpen = false
                    stripWindow._hoveredKey = -1
                }
            }

            // Reset the selection to the active workspace each time it opens.
            // Clear _selDelegate so the flyout doesn't reference a stale delegate.
            onShownChanged: if (!shown) {
                _hoveredKey = -1
                _selDelegate = null
                _scrollAccum = 0
            }

            Timer {
                id: openTimer
                interval: stripWindow.openDelay
                onTriggered: {
                    if (!stripContent.containsMouse) return
                    stripWindow._hoverOpen = true
                    root.refreshCachedPreviews()
                }
            }
            Timer {
                id: closeTimer
                interval: stripWindow.closeDelay
                onTriggered: {
                    if (!stripContent.containsMouse && !root.ipcOpen
                            && !windowDragProxy.dragging)
                        stripWindow._hoverOpen = false
                }
            }
            // Cooldown timer: spaces steps so the visual can catch up. While
            // running, deltas still accumulate; when it fires and enough has
            // accumulated for another step, it fires that step immediately.
            Timer {
                id: scrollDebounceTimer
                interval: stripWindow.scrollNavigationDebounceMs
                repeat: false
                onTriggered: {
                    if (Math.abs(stripWindow._scrollAccum) >= stripWindow.mouseScrollDeltaThreshold) {
                        const sign = stripWindow._scrollAccum > 0 ? 1 : -1
                        stripWindow._scrollAccum -= sign * stripWindow.mouseScrollDeltaThreshold
                        stripWindow.stepAndSwitch(sign > 0 ? -1 : 1)
                        scrollDebounceTimer.restart()
                    } else {
                        stripWindow._scrollAccum = 0
                    }
                }
            }

            // Hidden: pushed off-screen by an animated edge margin, leaving only a
            // thin trigger sliver. Shown: margin animates to 0. Because the mask
            // tracks THIS item directly, the sliver→panel transition stays
            // continuous under the pointer.
            MouseArea {
                id: stripContent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                width: stripWindow.panelWidth
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: stripWindow.isRight ? parent.right : undefined
                anchors.left: stripWindow.isRight ? undefined : parent.left

                readonly property real hideOffset: stripWindow.shown
                    ? 0 : (stripWindow.panelWidth - stripWindow.triggerZone)
                anchors.rightMargin: stripWindow.isRight ? -hideOffset : 0
                anchors.leftMargin: stripWindow.isRight ? 0 : -hideOffset

                // The slide MUST be monotonic. Because this item is also the hover
                // detector and input mask, any overshoot past the target (the ZZZ
                // elementMoveEnter curve overshoots to 1.56) momentarily pushes the
                // panel back out of the pointer, dropping hover and oscillating the
                // strip open/closed. zzz keeps its snap; everything else rides the
                // Ricelin liquid-morph curve — front-loaded with a long settle,
                // and strictly non-overshoot, so the anti-flicker contract holds.
                readonly property int _slideDuration: Appearance.zzzEverywhere
                    ? Appearance.animation.elementMoveEnter.duration
                    : PillMotion.glide
                readonly property var _slideCurve: Appearance.zzzEverywhere
                    ? Appearance.animationCurves.zzzSnap
                    : PillMotion.morphCurve

                Behavior on anchors.rightMargin {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: stripContent._slideDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: stripContent._slideCurve
                    }
                }
                Behavior on anchors.leftMargin {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: stripContent._slideDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: stripContent._slideCurve
                    }
                }

                onContainsMouseChanged: {
                    if (containsMouse) {
                        closeTimer.stop()
                        if (!stripWindow.shown) openTimer.restart()
                    } else {
                        openTimer.stop()
                        if (stripWindow.shown && !root.ipcOpen && !windowDragProxy.dragging)
                            closeTimer.restart()
                    }
                }

                // Click-to-dismiss on empty space (lowest layer; cards, flyout and
                // their controls sit above this and handle their own clicks).
                MouseArea {
                    anchors.fill: parent
                    enabled: stripWindow.shown
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: stripWindow.dismiss()
                }

                // ── Workspace detail flyout (follows the selected card) ──
                WorkspaceStripDetail {
                    id: detailFlyout

                    readonly property Item sel: stripWindow._selDelegate
                    // Anchor to the slot's resting center, not its animated height.
                    // The card grows over elementResize (~300ms) on selection; if the
                    // flyout tracked the live height it would chase a moving target
                    // and feel laggy. selCenterY uses the slot's own center (y +
                    // height/2) but the slot height is the resting size, so the
                    // flyout lands immediately and only its own short slide animates.
                    readonly property real selCenterY: sel
                        ? railFlick.y + sel.y + sel.height / 2 - railFlick.contentY
                        : stripContent.height / 2

                    visible: stripWindow.shown && stripWindow.showMetadata
                        && sel !== null && !stripWindow.selIsMedia
                    islandChrome: stripWindow.islandChrome

                    // Live screen position for the glass/backdrop crop — tracks the
                    // flyout as it follows the selection and as the panel slides.
                    readonly property point _screenPos: {
                        void x; void y; void stripContent.x;
                        return mapToItem(null, 0, 0)
                    }
                    backdropScreenX: (stripWindow.isRight
                        ? (stripWindow.modelData?.width ?? stripWindow.width) - stripWindow.width
                        : 0) + _screenPos.x
                    backdropScreenY: _screenPos.y
                    backdropScreenWidth: stripWindow.modelData?.width ?? 1920
                    backdropScreenHeight: stripWindow.modelData?.height ?? 1080
                    showAppIcons: stripWindow.showAppIcons
                    showPreviews: stripWindow.showPreviews
                    dragProxy: windowDragProxy
                    wsName: sel?.cardWsName ?? ""
                    wsIndex: sel?.cardWsIndex ?? 0
                    focusedTitle: sel?.cardFocusedTitle ?? ""
                    focusedAppId: sel?.cardFocusedAppId ?? ""
                    wsWindows: sel?.cardWsWindows ?? []
                    isActiveWs: sel?.cardIsActiveWs ?? false

                    onWindowActivated: win => stripWindow.focusWindow(win)
                    onWindowCloseRequested: win => stripWindow.closeWindow(win)

                    width: stripWindow.detailWidth
                    x: stripWindow.isRight
                        ? stripWindow.railInset + 14 - width
                        : stripWindow.railWidth + stripWindow.edgeMargin - 14
                    y: Math.max(8, Math.min(stripContent.height - height - 8, selCenterY - height / 2))
                    opacity: visible ? 1 : 0
                    // Morph, don't pop: the flyout settles in from the rail side.
                    scale: visible ? 1 : 0.96
                    transformOrigin: stripWindow.isRight ? Item.Right : Item.Left

                    // Snappy follow: short, non-elastic slide so the flyout tracks
                    // the hovered card almost immediately instead of lagging behind.
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }
                    Behavior on scale {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: PillMotion.morph
                            easing.type: PillMotion.easeMorph
                            easing.bezierCurve: PillMotion.morphCurve
                        }
                    }
                }

                // ── Now-playing media flyout (follows the media card) ──
                WorkspaceStripMedia {
                    id: mediaFlyout

                    readonly property Item sel: stripWindow._selDelegate
                    readonly property real selCenterY: sel
                        ? railFlick.y + sel.y + sel.height / 2 - railFlick.contentY
                        : stripContent.height / 2

                    visible: stripWindow.shown && stripWindow.selIsMedia && stripWindow.hasPlayer
                    islandChrome: stripWindow.islandChrome

                    readonly property point _screenPos: {
                        void x; void y; void stripContent.x;
                        return mapToItem(null, 0, 0)
                    }
                    backdropScreenX: (stripWindow.isRight
                        ? (stripWindow.modelData?.width ?? stripWindow.width) - stripWindow.width
                        : 0) + _screenPos.x
                    backdropScreenY: _screenPos.y
                    backdropScreenWidth: stripWindow.modelData?.width ?? 1920
                    backdropScreenHeight: stripWindow.modelData?.height ?? 1080

                    width: stripWindow.detailWidth
                    x: stripWindow.isRight
                        ? stripWindow.railInset + 14 - width
                        : stripWindow.railWidth + stripWindow.edgeMargin - 14
                    y: Math.max(8, Math.min(stripContent.height - height - 8, selCenterY - height / 2))
                    opacity: visible ? 1 : 0
                    scale: visible ? 1 : 0.96
                    transformOrigin: stripWindow.isRight ? Item.Right : Item.Left

                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }
                    Behavior on scale {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: PillMotion.morph
                            easing.type: PillMotion.easeMorph
                            easing.bezierCurve: PillMotion.morphCurve
                        }
                    }
                }

                // ── Vertical, scrollable thumbnail rail (flush against the edge) ──
                Flickable {
                    id: railFlick
                    width: stripWindow.railWidth
                    height: Math.min(railColumn.implicitHeight, stripContent.height - 24)
                    anchors.verticalCenter: parent.verticalCenter
                    x: stripWindow.isRight ? stripWindow.railInset : stripWindow.edgeMargin
                    contentHeight: railColumn.implicitHeight
                    contentWidth: width
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: true
                    clip: false

                    // Accumulated scroll destination so wheel deltas stack while
                    // the contentY animation is running (mirrors StyledFlickable).
                    property real scrollTargetY: 0

                    onContentYChanged: {
                        if (!scrollAnim.running)
                            scrollTargetY = contentY
                    }

                    Behavior on contentY {
                        NumberAnimation {
                            id: scrollAnim
                            duration: Appearance.animation.scroll.duration
                            easing.type: Appearance.animation.scroll.type
                            easing.bezierCurve: Appearance.animation.scroll.bezierCurve
                        }
                    }

                    ScrollBar.vertical: StyledScrollBar {
                        policy: railFlick.contentHeight > railFlick.height
                            ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }

                    // Keep the selected slot visible after scroll-nav moves it.
                    function ensureSelectionVisible(): void {
                        const sel = stripWindow._selDelegate
                        if (!sel) return
                        const itemTop = sel.y
                        const itemBottom = sel.y + sel.height
                        if (itemTop < railFlick.contentY)
                            railFlick.contentY = Math.max(0, itemTop - 8)
                        else if (itemBottom > railFlick.contentY + railFlick.height)
                            railFlick.contentY = Math.min(
                                Math.max(0, railFlick.contentHeight - railFlick.height),
                                itemBottom - railFlick.height + 8)
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            // Scroll-navigation: step the selection through the rail
                            // instead of free-scrolling the thumbnail column.
                            if (stripWindow.scrollNavigation) {
                                // Accumulate until a full notch is reached, then
                                // step exactly one workspace. Mouse wheels send
                                // ±120 per notch (= 1 step immediately). Touchpad
                                // deltas (~10-15 per event) accumulate to 120 in
                                // ~8-10 events, so one swipe yields 1-2 steps
                                // instead of racing through all workspaces.
                                // A short cooldown spaces steps so the visual can
                                // catch up — this is the Windows-like feel.
                                stripWindow._scrollAccum += event.angleDelta.y
                                const threshold = stripWindow.mouseScrollDeltaThreshold
                                if (Math.abs(stripWindow._scrollAccum) < threshold) return
                                if (scrollDebounceTimer.running) return
                                // Consume exactly one threshold worth, carry rest.
                                const sign = stripWindow._scrollAccum > 0 ? 1 : -1
                                stripWindow._scrollAccum -= sign * threshold
                                scrollDebounceTimer.restart()
                                stripWindow.stepAndSwitch(sign > 0 ? -1 : 1)
                                return
                            }
                            // Free-scroll: scale by scroll factor, differentiate
                            // mouse vs touchpad (mirrors StyledFlickable.qml).
                            const threshold = stripWindow.mouseScrollDeltaThreshold
                            const delta = event.angleDelta.y / threshold
                            const scrollFactor = Math.abs(event.angleDelta.y) >= threshold
                                ? stripWindow.mouseScrollFactor
                                : stripWindow.touchpadScrollFactor
                            const maxY = Math.max(0, railFlick.contentHeight - railFlick.height)
                            const base = scrollAnim.running ? railFlick.scrollTargetY : railFlick.contentY
                            const targetY = Math.max(0, Math.min(base - delta * scrollFactor, maxY))
                            railFlick.scrollTargetY = targetY
                            railFlick.contentY = targetY
                            event.accepted = true
                        }
                    }

                    Column {
                        id: railColumn
                        width: parent.width
                        spacing: 8

                        // Now-playing media card.
                        Item {
                            id: mediaSlot
                            visible: stripWindow.hasPlayer
                            width: stripWindow.railWidth
                            // Constant slot height: selection growth never reflows
                            // the rail — a moving list under the pointer is what made
                            // hover selection jump between slots. The card overflows
                            // its slot instead (z-stacked, clip off).
                            height: visible ? stripWindow.cardBaseW : 0
                            z: isSelected ? 10 : 1

                            readonly property bool isSelected: stripWindow.selIsMedia

                            Behavior on height {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation {
                                    duration: PillMotion.fast
                                    easing.type: PillMotion.easeStandard
                                }
                            }

                            onIsSelectedChanged: if (isSelected) stripWindow._selDelegate = mediaSlot

                            WorkspaceStripMediaCard {
                                selected: mediaSlot.isSelected
                                shown: stripWindow.shown
                                isRight: stripWindow.isRight
                                islandChrome: stripWindow.islandChrome
                                width: mediaSlot.isSelected ? stripWindow.cardSelW : stripWindow.cardBaseW
                                height: width
                                anchors.verticalCenter: parent.verticalCenter
                                x: stripWindow.isRight ? stripWindow.railWidth - width : 0

                                Behavior on width {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation {
                                        duration: PillMotion.fast
                                        easing.type: PillMotion.easeStandard
                                    }
                                }

                                onActivated: stripWindow._hoveredKey = stripWindow.mediaKey
                            }

                            // Full-row hover, same reasoning as the workspace slots.
                            HoverHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onHoveredChanged: if (hovered) stripWindow._hoveredKey = stripWindow.mediaKey
                            }
                        }

                        Repeater {
                            model: stripWindow.outputWorkspaces

                            Item {
                                id: slot
                                required property var modelData
                                required property int index

                                readonly property int wsKey: stripWindow.keyFor(modelData, index)
                                readonly property bool isActive: CompositorService.isNiri
                                    ? (modelData?.is_active ?? false)
                                    : (modelData?.active ?? false)
                                readonly property bool isSelected: stripWindow.selIsMedia
                                    ? false
                                    : (stripWindow._hoveredKey >= 0
                                        ? stripWindow._hoveredKey === wsKey
                                        : isActive)

                                // Data surfaced to the shared flyout when selected.
                                property var cardWorkspace: modelData
                                property int cardIndex: index
                                property alias cardWsName: wsCard.wsName
                                property alias cardWsIndex: wsCard.wsIndex
                                property alias cardFocusedTitle: wsCard.focusedTitle
                                property alias cardFocusedAppId: wsCard.focusedAppId
                                property alias cardWsWindows: wsCard.wsWindows
                                property alias cardIsActiveWs: wsCard.isActiveWs

                                width: stripWindow.railWidth
                                // Constant slot height — see mediaSlot note: growth
                                // must never reflow the rail under the pointer.
                                height: stripWindow.cardBaseH
                                z: isSelected ? 10 : 1

                                onIsSelectedChanged: if (isSelected) stripWindow._selDelegate = slot
                                Component.onCompleted: if (isSelected) stripWindow._selDelegate = slot
                                Component.onDestruction: if (stripWindow._selDelegate === slot) stripWindow._selDelegate = null

                                WorkspaceStripCard {
                                    id: wsCard
                                    workspace: slot.modelData
                                    selected: slot.isSelected
                                    shown: stripWindow.shown
                                    isRight: stripWindow.isRight
                                    islandChrome: stripWindow.islandChrome
                                    showPreviews: stripWindow.showPreviews
                                    showAppIcons: stripWindow.showAppIcons
                                    injectedWindows: CompositorService.isNiri
                                        ? (stripWindow.windowsByWorkspace[slot.modelData?.id ?? 0] ?? [])
                                        : null

                                    width: slot.isSelected ? stripWindow.cardSelW : stripWindow.cardBaseW
                                    height: slot.isSelected ? stripWindow.cardSelH : stripWindow.cardBaseH
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: stripWindow.isRight ? stripWindow.railWidth - width : 0

                                    Behavior on width {
                                        enabled: Appearance.animationsEnabled
                                        NumberAnimation {
                                            duration: PillMotion.fast
                                            easing.type: PillMotion.easeStandard
                                        }
                                    }
                                    Behavior on height {
                                        enabled: Appearance.animationsEnabled
                                        NumberAnimation {
                                            duration: PillMotion.fast
                                            easing.type: PillMotion.easeStandard
                                        }
                                    }

                                    onActivated: stripWindow.switchWorkspace(slot.modelData, slot.index)

                                    // Drop target: dropping a dragged window here
                                    // moves it onto this workspace.
                                    dropTargeted: cardDrop.containsDrag
                                    DropArea {
                                        id: cardDrop
                                        anchors.fill: parent
                                        keys: [windowDragProxy.dragKey]
                                        onDropped: drop => {
                                            stripWindow.moveWindowToWorkspace(
                                                windowDragProxy.win, slot.modelData, slot.index)
                                            drop.accept()
                                        }
                                    }
                                }

                                // Selection follows hover and PERSISTS on hover-out
                                // so the side flyout (and its controls) stay reachable.
                                // On the SLOT (full rail width), not the card: the
                                // unselected card is narrower than the rail row, and
                                // hover dead-zones next to small cards made vertical
                                // travel feel imprecise.
                                HoverHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onHoveredChanged: if (hovered) stripWindow._hoveredKey = slot.wsKey
                                }
                            }
                        }

                        // ── "New workspace" drop zone — only while dragging a
                        // window. Drop here to spin the window off to a fresh
                        // workspace at the end of the list (a power move you can't
                        // do anywhere else this quickly).
                        Item {
                            id: newWsSlot
                            visible: windowDragProxy.dragging
                            width: stripWindow.railWidth
                            height: visible ? stripWindow.cardBaseH : 0

                            Behavior on height {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation {
                                    duration: Appearance.animation.elementResize.duration
                                    easing.type: Appearance.animation.elementResize.type
                                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                                }
                            }

                            Item {
                                id: newWsZone
                                width: stripWindow.cardBaseW
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                x: stripWindow.isRight ? stripWindow.railWidth - width : 0

                                readonly property bool _zzz: Appearance.zzzEverywhere
                                readonly property bool _hot: newWsDrop.containsDrag
                                readonly property color _accent: _zzz
                                    ? Appearance.zzz.accent : Appearance.colors.colPrimary

                                // Non-zzz plate; the Ricelin frame treatment is
                                // island-chrome only, stock keeps its accent ring.
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !newWsZone._zzz
                                    radius: Appearance.rounding.normal
                                    color: newWsZone._hot
                                        ? (stripWindow.islandChrome
                                            ? Qt.alpha(PillTheme.verm, 0.2)
                                            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.78))
                                        : (stripWindow.islandChrome ? PillTheme.frameBg : "transparent")
                                    border.width: newWsZone._hot ? 2 : (stripWindow.islandChrome ? 1 : 1.5)
                                    border.color: newWsZone._hot
                                        ? (stripWindow.islandChrome ? PillTheme.vermLit : Appearance.colors.colPrimary)
                                        : (stripWindow.islandChrome
                                            ? PillTheme.border
                                            : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.2))
                                    Behavior on color {
                                        enabled: Appearance.animationsEnabled
                                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                    }
                                    Behavior on border.color {
                                        enabled: Appearance.animationsEnabled
                                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                    }
                                }

                                // zzz: chamfered console plate matching the rail cards.
                                ZzzPlate {
                                    anchors.fill: parent
                                    visible: newWsZone._zzz
                                    fillColor: newWsZone._hot
                                        ? ColorUtils.transparentize(Appearance.zzz.accent, 0.8)
                                        : "transparent"
                                    strokeColor: newWsZone._hot
                                        ? Appearance.zzz.accent : Appearance.zzz.hairlineStrong
                                    strokeWidth: newWsZone._hot
                                        ? Appearance.zzz.hairlineThick * 1.5 : Appearance.zzz.hairline
                                    chamfer: Appearance.zzz.cutCorner * 0.5
                                    chamferBottomRight: stripWindow.isRight && !Appearance.zzz.round
                                    chamferBottomLeft: !stripWindow.isRight && !Appearance.zzz.round
                                }

                                // Kanji 新 (new) in island chrome, plus icon otherwise.
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: (stripWindow.islandChrome && PillTheme.showGlyphs) ? "jp:新" : "add"
                                    iconSize: 24
                                    color: newWsZone._hot
                                        ? newWsZone._accent : Appearance.colors.colSubtext
                                }

                                DropArea {
                                    id: newWsDrop
                                    anchors.fill: parent
                                    keys: [windowDragProxy.dragKey]
                                    onDropped: drop => {
                                        stripWindow.moveWindowToNewWorkspace(windowDragProxy.win)
                                        drop.accept()
                                    }
                                }
                            }
                        }
                    }
                }

                // Shared floating drag ghost (above the rail + flyouts) that the
                // detail flyout's window rows drive to move windows between
                // workspaces. Rail cards' DropAreas accept its payload.
                WorkspaceStripDragProxy {
                    id: windowDragProxy
                }
            }
            }
        }
    }
}
