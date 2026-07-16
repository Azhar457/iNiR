import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    readonly property bool instantOpen: Config.options?.sidebar?.instantOpen ?? false
    readonly property string animationType: Config.options?.sidebar?.animationType ?? "slide"
    // Expanded width when a webapp is active
    property bool pluginViewActive: false
    // Track transitions to disable width animation during webapp open/close
    property bool _pluginTransitioning: false
    onPluginViewActiveChanged: {
        root._pluginTransitioning = true
        _pluginTransitionTimer.restart()
    }
    Timer {
        id: _pluginTransitionTimer
        interval: 50
        onTriggered: root._pluginTransitioning = false
    }
    readonly property real effectiveSidebarWidth: (pluginViewActive || GlobalStates.sidebarLeftExpanded)
        ? Appearance.sizes.sidebarWidthExtended
        : sidebarWidth

    // Deferred slide trigger: ensures the Wayland surface is mapped before
    // the Behavior animation starts, so Qt tracks the "from" position correctly.
    property bool _sidebarShown: false
    property bool _presentationRequested: false
    property int _presentationReadyFrames: 0
    readonly property int closeGraceMs: Math.max(34,
        (Appearance.animation?.elementMoveExit?.duration ?? 200) + 34)

    function requestPresentation(warmVisible: bool): void {
        // Reopening while the exit transition is still running should reverse
        // immediately on the same mapped surface. The two-frame readiness gate
        // is only necessary for a cold map.
        if (warmVisible && sidebarContentLoader.height > 0
                && sidebarContentLoader.status === Loader.Ready) {
            root._presentationRequested = false
            root._presentationReadyFrames = 0
            presentationTimer.stop()
            root._sidebarShown = true
            return
        }
        root._presentationRequested = true
        root._presentationReadyFrames = 0
        presentationTimer.restart()
    }

    function tryPresent(): void {
        if (!root._presentationRequested || !GlobalStates.sidebarLeftOpen)
            return
        if (sidebarRoot.height <= 0 || sidebarContentLoader.height <= 0)
            return
        if (!sidebarContentLoader._everMounted)
            sidebarContentLoader._everMounted = true
        if (sidebarContentLoader.status !== Loader.Ready)
            return
        // Keep the fully initialized content in its closed pose for two frames.
        // Otherwise a cold Loader can become Ready and open in the same frame,
        // skipping the visible start of pop/fade/scale animations.
        root._presentationReadyFrames++
        if (root._presentationReadyFrames < 2)
            return
        root._presentationRequested = false
        presentationTimer.stop()
        root._sidebarShown = true
    }

    Timer {
        id: presentationTimer
        interval: 16
        repeat: true
        onTriggered: root.tryPresent()
    }

    PanelWindow {
        id: sidebarRoot

        Component.onCompleted: {
            visible = GlobalStates.sidebarLeftOpen
            root._sidebarShown = false
            if (GlobalStates.sidebarLeftOpen)
                root.requestPresentation(false)
        }

        Connections {
            target: GlobalStates
            function onSidebarLeftOpenChanged() {
                if (GlobalStates.sidebarLeftOpen) {
                    const warmVisible = sidebarRoot.visible
                    _closeTimer.stop()
                    sidebarRoot.visible = true
                    root.requestPresentation(warmVisible)
                } else if (root.instantOpen || !Appearance.animationsEnabled) {
                    root._presentationRequested = false
                    presentationTimer.stop()
                    root._sidebarShown = false
                    GlobalStates.sidebarLeftExpanded = false
                    _closeTimer.stop()
                    sidebarRoot.visible = false
                } else {
                    root._presentationRequested = false
                    presentationTimer.stop()
                    root._sidebarShown = false
                    GlobalStates.sidebarLeftExpanded = false
                    _closeTimer.restart()
                }
            }
        }

        Timer {
            id: _closeTimer
            interval: root.closeGraceMs
            onTriggered: sidebarRoot.visible = false
        }

        function hide() {
            GlobalStates.sidebarLeftOpen = false
        }

        exclusiveZone: 0
        implicitWidth: screen?.width ?? 1920
        WlrLayershell.namespace: "quickshell:sidebarLeft"
        WlrLayershell.layer: WlrLayer.Overlay
        // A single sidebar keeps exclusive keyboard focus. With both open,
        // OnDemand lets the compositor focus whichever side the user clicks.
        WlrLayershell.keyboardFocus: !GlobalStates.sidebarLeftOpen || GlobalStates.sidebarLeftHoldOpen
            ? WlrKeyboardFocus.None
            : GlobalStates.sidebarRightOpen ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.Exclusive
        color: "transparent"

        // While a feature holds the sidebar open (InnerTube login), shrink the input region
        // to just the sidebar content so the fullscreen-transparent backdrop becomes
        // click-through — the external browser stays reachable and a stray click can't close us.
        Region { id: sidebarInputRegion; item: sidebarContentLoader }
        // During exit the visual surface remains mapped for animation, but the
        // fullscreen transparent backdrop must stop blocking the desktop at once.
        mask: (GlobalStates.sidebarLeftHoldOpen || !GlobalStates.sidebarLeftOpen
                || GlobalStates.sidebarRightOpen)
            ? sidebarInputRegion : null

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        CompositorFocusGrab {
            id: grab
            windows: [ sidebarRoot ]
            active: CompositorService.isHyprland && sidebarRoot.visible
                && !GlobalStates.sidebarLeftHoldOpen && !GlobalStates.sidebarRightOpen
            onCleared: () => {
                if (!active && !GlobalStates.sidebarLeftHoldOpen) sidebarRoot.hide()
            }
        }

        MouseArea {
            id: backdropClickArea
            anchors.fill: parent
            enabled: GlobalStates.sidebarLeftOpen && !GlobalStates.sidebarLeftHoldOpen
                && !GlobalStates.sidebarRightOpen
            onClicked: mouse => {
                if (GlobalStates.sidebarLeftHoldOpen) return
                const localPos = mapToItem(sidebarContentLoader, mouse.x, mouse.y)
                if (localPos.x < 0 || localPos.x > sidebarContentLoader.width
                        || localPos.y < 0 || localPos.y > sidebarContentLoader.height) {
                    sidebarRoot.hide()
                }
            }
        }

        Loader {
            id: sidebarContentLoader
            // Never instantiate the content tree against an unmapped, zero-height
            // surface. Once the first valid mount begins, keep it alive forever.
            property bool _everMounted: false
            active: _everMounted

            // Shell desaturation effect
            layer.enabled: Appearance.shouldDesaturate("sidebars") && sidebarContentLoader.visible
            layer.effect: ShellDesaturationEffect {}

            anchors {
                top: parent.top
                left: parent.left
                bottom: parent.bottom
                margins: Appearance.sizes.hyprlandGapsOut
                rightMargin: Appearance.sizes.elevationMargin
            }
            width: root.effectiveSidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            Behavior on width {
                // Disable animation when webapp toggles — avoids choppy WebEngine re-layout
                enabled: Appearance.animationsEnabled && !root._pluginTransitioning
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(250)
                    easing.type: Easing.OutCubic
                }
            }
            height: parent.height - Appearance.sizes.hyprlandGapsOut * 2
            onHeightChanged: root.tryPresent()
            onStatusChanged: {
                if (height > 0 && status === Loader.Ready)
                    _everMounted = true
                root.tryPresent()
            }

            // Animation properties driven by states/transitions below
            property real animTranslateX: -(root.effectiveSidebarWidth + Appearance.sizes.hyprlandGapsOut)
            property real animOpacity: 1
            property real animScale: 1
            // Clip wrapper for "reveal" animation
            property bool useClip: root.animationType === "reveal"
            property real clipWidth: root.effectiveSidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            // Drop: vertical offset; Swing: horizontal scale from edge
            property real animTranslateY: 0
            property real animScaleX: 1

            property bool animating: false
            transform: [
                Translate { x: sidebarContentLoader.animTranslateX; y: sidebarContentLoader.animTranslateY },
                Scale { xScale: sidebarContentLoader.animScaleX; origin.x: 0; origin.y: sidebarContentLoader.height / 2 }
            ]
            opacity: sidebarContentLoader.animOpacity
            scale: sidebarContentLoader.animScale

            states: [
                State {
                    name: "open"
                    when: root._sidebarShown
                    PropertyChanges {
                        target: sidebarContentLoader
                        animTranslateX: 0
                        animOpacity: 1
                        animScale: 1
                        animTranslateY: 0
                        animScaleX: 1
                        clipWidth: root.effectiveSidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                    }
                },
                State {
                    name: "closed"
                    when: !root._sidebarShown
                    PropertyChanges {
                        target: sidebarContentLoader
                        animTranslateX: root.animationType === "slide" || root.animationType === "reveal"
                            ? -(root.effectiveSidebarWidth + Appearance.sizes.hyprlandGapsOut)
                            : 0
                        animOpacity: (root.animationType === "slide" || root.animationType === "reveal") ? 1 : 0
                        animScale: root.animationType === "elastic" ? 0.88
                            : root.animationType === "pop" ? 0.94 : 1
                        animTranslateY: root.animationType === "drop"
                            ? -(sidebarContentLoader.height + Appearance.sizes.hyprlandGapsOut * 2) : 0
                        animScaleX: root.animationType === "swing" ? 0 : 1
                        clipWidth: root.animationType === "reveal" ? 0
                            : root.effectiveSidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                    }
                }
            ]
            transitions: [
                Transition {
                    to: "open"
                    enabled: Appearance.animationsEnabled && !root._pluginTransitioning && !root.instantOpen
                    ParallelAnimation {
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animTranslateX"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animTranslateY"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animOpacity"
                            duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.7)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.standardDecel ?? [0, 0, 0, 1, 1, 1]
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: sidebarContentLoader; property: "animScale"
                                from: root.animationType === "elastic" ? 0.88
                                    : root.animationType === "pop" ? 0.94 : 1
                                to: root.animationType === "elastic" ? 1.04
                                    : root.animationType === "pop" ? 1.018 : 1
                                duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.62)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                            }
                            NumberAnimation {
                                target: sidebarContentLoader; property: "animScale"
                                to: 1
                                duration: Math.round((Appearance.animation?.elementMoveEnter?.duration ?? 400) * 0.38)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves?.expressiveEffects ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
                            }
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animScaleX"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "clipWidth"
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                    }
                    onRunningChanged: sidebarContentLoader.animating = running
                },
                Transition {
                    to: "closed"
                    enabled: Appearance.animationsEnabled && !root._pluginTransitioning && !root.instantOpen
                    ParallelAnimation {
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animTranslateX"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animTranslateY"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animOpacity"
                            duration: Math.round((Appearance.animation?.elementMoveExit?.duration ?? 200) * 0.7)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.standardAccel ?? [0.3, 0, 1, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animScale"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "animScaleX"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                        NumberAnimation {
                            target: sidebarContentLoader; property: "clipWidth"
                            duration: Appearance.animation?.elementMoveExit?.duration ?? 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1]
                        }
                    }
                    onRunningChanged: sidebarContentLoader.animating = running
                }
            ]

            focus: GlobalStates.sidebarLeftOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    sidebarRoot.hide();
                }
            }

            sourceComponent: Item {
                id: leftContentHost
                anchors.fill: parent

                // Reveal clips a fixed-width tree instead of resizing it. Text,
                // cards and WebEngine placeholders keep their final geometry.
                Item {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: sidebarContentLoader.useClip
                        ? sidebarContentLoader.clipWidth : parent.width
                    clip: sidebarContentLoader.useClip

                    SidebarLeftContent {
                        width: leftContentHost.width
                        height: leftContentHost.height
                        screenWidth: sidebarRoot.screen?.width ?? 1920
                        screenHeight: sidebarRoot.screen?.height ?? 1080
                        panelScreen: sidebarRoot.screen ?? null
                        panelVisible: sidebarRoot.visible
                        onPluginViewActiveChanged: root.pluginViewActive = pluginViewActive
                    }
                }
            }
        }
    }

    // Detached AI chat window — same process, shares Ai service + theming
    Loader {
        active: GlobalStates.aiChatDetached
        sourceComponent: FloatingWindow {
            id: aiChatWindow
            visible: true
            title: "iNiR AI Chat"
            implicitWidth: 520
            implicitHeight: 780
            minimumSize: Qt.size(380, 400)
            color: Appearance.colors.colLayer0

            onVisibleChanged: {
                if (!visible) GlobalStates.aiChatDetached = false
            }

            AiChat {
                anchors.fill: parent
                anchors.margins: 8
            }
        }
    }

}
