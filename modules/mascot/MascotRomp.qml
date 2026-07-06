pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * Chaos-mode romp: she runs across the desktop and physically messes with
 * it. Separate window from the peek companion so none of the peek
 * invariants (hide/teardown timers, click ladder) are ever touched.
 *
 * The window ignores exclusive zones so its coordinates line up 1:1 with
 * the Background layer where desktop widgets live; widget geometry comes
 * from the MascotChaos registry and impulses go back out over its signals.
 *
 * Plans: "bonk" (mallet a widget, it goes flying), "toss" (hurl a widget
 * to a new spot — persists only when chaos.allowRearrange), "quake"
 * (ground slam: the bar bounces and every widget wobbles). Fully
 * click-through; aborts instantly on suppression.
 */
PanelWindow {
    id: romp

    required property var rompScreen
    signal finished()

    screen: rompScreen
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    WlrLayershell.namespace: "quickshell:mascotRomp"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}

    readonly property bool suppressed: GameMode.active || GameMode.hasAnyFullscreenWindow
        || GlobalStates.screenLocked || GlobalStates.sessionOpen
    onSuppressedChanged: if (suppressed) romp._abort()

    readonly property int spriteSize: Config.options?.mascot?.companion?.size ?? 150
    readonly property real groundY: height - spriteSize
    readonly property real runSpeed: 0.5 // px per ms

    property var _manifest: ({})
    readonly property var _chaosCfg: _manifest.chaos ?? ({})
    FileView {
        id: manifestFile
        path: Quickshell.shellPath("assets/images/mascot/manifest.json")
        onLoadedChanged: {
            if (!manifestFile.loaded) return
            try {
                romp._manifest = JSON.parse(manifestFile.text())
            } catch (e) {
                console.warn("[MascotRomp] manifest load failed:", e)
            }
            romp._begin()
        }
    }

    // ── Plan ────────────────────────────────────────────────────────────
    property string planType: ""
    property string planTargetKey: ""
    property real planActX: 0
    property real planVX: 0
    property real planVY: 0
    property bool planPersist: false

    function _pickLine(pools): string {
        const pool = pools ?? []
        return pool.length ? Translation.tr(pool[Math.floor(Math.random() * pool.length)]) : ""
    }

    function _makePlan(): bool {
        const targets = MascotChaos.targets().filter(t => t.y + t.h < romp.height && t.w < romp.width * 0.7)
        const rearrange = MascotChaos.allowRearrange
        const options = ["quake"]
        if (targets.length > 0) { options.push("bonk"); options.push("bonk") }
        if (targets.length > 0 && rearrange) options.push("toss")
        romp.planType = options[Math.floor(Math.random() * options.length)]

        if (romp.planType === "quake") {
            romp.planActX = romp.width * (0.30 + Math.random() * 0.40)
            return true
        }
        const t = targets[Math.floor(Math.random() * targets.length)]
        romp.planTargetKey = t.key
        romp.planActX = Math.max(0, Math.min(t.x + t.w / 2 - romp.spriteSize / 2, romp.width - romp.spriteSize))
        if (romp.planType === "bonk") {
            const dir = romp._enterFromLeft ? 1 : -1
            romp.planVX = dir * (140 + Math.random() * 160)
            romp.planVY = 30
            romp.planPersist = rearrange
        } else { // toss
            const nx = 40 + Math.random() * Math.max(80, romp.width - t.w - 80)
            const ny = 40 + Math.random() * Math.max(80, romp.height - t.h - 200)
            romp.planVX = nx - t.x
            romp.planVY = ny - t.y
            romp.planPersist = true
        }
        return true
    }

    // ── Sprite state machine ────────────────────────────────────────────
    property string phase: "idle" // enter | act | aftermath | leave
    property bool _enterFromLeft: Math.random() < 0.5
    property real spriteX: 0
    property string pose: _chaosCfg.run ?? "heroic-run"
    property string line: ""
    readonly property bool running: phase === "enter" || phase === "leave"
    readonly property bool movingRight: runTween.to > spriteX

    NumberAnimation {
        id: runTween
        target: romp
        property: "spriteX"
        onStopped: romp._phaseDone()
    }
    Timer { id: phaseTimer; onTriggered: romp._phaseDone() }

    function _begin(): void {
        if (romp.suppressed || !MascotChaos.enabled) { romp._abort(); return }
        if (!romp._makePlan()) { romp._abort(); return }
        // decide entry side: nearest edge to the action point
        romp._enterFromLeft = romp.planActX < romp.width / 2
        romp.spriteX = romp._enterFromLeft ? -romp.spriteSize : romp.width + romp.spriteSize
        // bonk flings in the run direction — recompute now that the side is known
        if (romp.planType === "bonk")
            romp.planVX = (romp._enterFromLeft ? 1 : -1) * (140 + Math.random() * 160)
        romp.pose = romp._chaosCfg.run ?? "heroic-run"
        romp.line = ""
        romp.phase = "enter"
        console.log(`[MascotRomp] ${romp.planType} → ${romp.planTargetKey || "panel"}`)
        runTween.to = romp.planActX
        runTween.duration = Math.max(450, Math.abs(runTween.to - romp.spriteX) / romp.runSpeed)
        runTween.restart()
    }

    function _phaseDone(): void {
        if (romp.phase === "enter") {
            const act = romp._chaosCfg[romp.planType] ?? ({})
            romp.pose = act.pose ?? "chibi-mallet"
            romp.line = romp._pickLine(act.lines)
            romp.phase = "act"
            phaseTimer.interval = 620
            phaseTimer.restart()
        } else if (romp.phase === "act") {
            // the hit lands
            if (romp.planType === "quake") {
                MascotChaos.panelShake()
                for (const t of MascotChaos.targets())
                    MascotChaos.impact(t.key, (Math.random() - 0.5) * 90, 0, false)
            } else {
                MascotChaos.impact(romp.planTargetKey, romp.planVX, romp.planVY, romp.planPersist)
            }
            const act = romp._chaosCfg[romp.planType] ?? ({})
            romp.pose = act.after ?? "chibi-pointing-laugh"
            romp.phase = "aftermath"
            phaseTimer.interval = 1500
            phaseTimer.restart()
        } else if (romp.phase === "aftermath") {
            romp.pose = romp._chaosCfg.run ?? "heroic-run"
            romp.line = ""
            romp.phase = "leave"
            // keep going in the same direction, out the far side
            runTween.to = romp._enterFromLeft ? romp.width + romp.spriteSize : -romp.spriteSize
            runTween.duration = Math.max(450, Math.abs(runTween.to - romp.spriteX) / romp.runSpeed)
            runTween.restart()
        } else if (romp.phase === "leave") {
            romp.finished()
        }
    }

    function _abort(): void {
        runTween.stop()
        phaseTimer.stop()
        romp.finished()
    }

    // ── Visuals ─────────────────────────────────────────────────────────
    Item {
        id: sprite
        width: romp.spriteSize
        height: romp.spriteSize
        x: romp.spriteX
        y: romp.groundY + bob
        property real bob: 0

        // run-cycle bob: little hops while she's moving
        SequentialAnimation {
            running: romp.running && Appearance.animationsEnabled
            loops: Animation.Infinite
            alwaysRunToEnd: false
            NumberAnimation { target: sprite; property: "bob"; to: -10; duration: 140; easing.type: Easing.OutQuad }
            NumberAnimation { target: sprite; property: "bob"; to: 0; duration: 140; easing.type: Easing.InQuad }
        }
        onYChanged: if (!romp.running && bob !== 0) bob = 0

        AnimatedImage {
            anchors.fill: parent
            source: Quickshell.shellPath(`assets/images/mascot/inir-mascot-${romp.pose}.${(romp._manifest.animatedPoses ?? []).includes(romp.pose) ? "gif" : "png"}`)
            playing: true
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: false
            mipmap: false
            // heroic-run art faces left; mirror when she's headed right
            mirror: romp.running && romp.movingRight
        }
    }

    // Speech bubble, same tooltip token dispatch as the companion
    Rectangle {
        readonly property int pad: 10
        visible: opacity > 0
        opacity: romp.line.length > 0 && romp.phase !== "leave" ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        implicitWidth: rompBubbleText.width + pad * 2
        implicitHeight: rompBubbleText.implicitHeight + pad * 2
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
             : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
             : Appearance.rounding.verysmall
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassTooltip
             : Appearance.inirEverywhere ? Appearance.inir.colLayer2
             : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipSurface
             : Appearance.colors.colLayer3
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
        border.color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder
                    : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : Appearance.colors.colLayer3Hover
        x: Math.max(12, Math.min(sprite.x + sprite.width / 2 - width / 2, romp.width - width - 12))
        y: sprite.y - height - 8

        StyledText {
            id: rompBubbleText
            anchors.centerIn: parent
            text: romp.line
            width: Math.min(implicitWidth, 240)
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.angelEverywhere ? Appearance.angel.colText
                 : Appearance.inirEverywhere ? Appearance.inir.colText
                 : Appearance.colors.colOnLayer3
        }
    }
}
