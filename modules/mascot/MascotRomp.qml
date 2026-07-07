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
    // Click-through except her sprite; chase mode captures the whole screen
    // so every click becomes a spot for her to pounce on
    mask: Region { item: romp.phase === "chase" ? chaseCatchArea : sprite }

    // Which behavior this window starts in ("romp" | "chase")
    property string startMode: "romp"

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
    // A plan is a list of stops; each stop is a place to run to and a thing
    // to do there. Rampage chains several, trip has a stop that hits nothing.
    property string planType: ""
    property var planStops: []
    property int planIndex: 0

    function _pickLine(pools): string {
        const pool = pools ?? []
        return pool.length ? Translation.tr(pool[Math.floor(Math.random() * pool.length)]) : ""
    }

    // Chaos poses can be a single name or a pool; pools rotate with memory
    property var _recentActPoses: []
    function _pickActPose(p, fallback): string {
        if (!p) return fallback
        if (typeof p === "string") return p
        const fresh = p.filter(x => !romp._recentActPoses.includes(x))
        const src = fresh.length ? fresh : p
        const pick = src[Math.floor(Math.random() * src.length)]
        romp._recentActPoses.push(pick)
        while (romp._recentActPoses.length > 3) romp._recentActPoses.shift()
        return pick
    }

    function _actXFor(t): real {
        return Math.max(0, Math.min(t.x + t.w / 2 - romp.spriteSize / 2, romp.width - romp.spriteSize))
    }

    function _makePlan(): bool {
        const targets = MascotChaos.targets().filter(t => t.y + t.h < romp.height && t.w < romp.width * 0.7)
        const rearrange = MascotChaos.allowRearrange
        const stops = []

        // Comedy fail: sometimes she just eats the floor and leaves
        if (Math.random() < 0.12) {
            romp.planType = "trip"
            stops.push({ kind: "trip", actX: romp.width * (0.30 + Math.random() * 0.40) })
            romp.planStops = stops
            return true
        }

        const options = ["quake", "punt"]
        if (targets.length > 0) {
            options.push("bonk", "bonk", "wreck")
            if (targets.length >= 2) options.push("rampage", "rampage")
            if (rearrange) options.push("toss")
        }
        romp.planType = options[Math.floor(Math.random() * options.length)]

        const shuffled = targets.slice().sort(() => Math.random() - 0.5)
        const hitMode = pref => pref === "wreck" ? "wreck" : (rearrange ? "persist" : "bounce")

        if (romp.planType === "quake") {
            stops.push({ kind: "quake", actX: romp.width * (0.30 + Math.random() * 0.40) })
        } else if (romp.planType === "punt") {
            // she kicks the bar/dock directly — the panels take it personally
            stops.push({ kind: "punt", actX: romp.width * (0.15 + Math.random() * 0.70) })
        } else if (romp.planType === "rampage") {
            // tear through up to 3 widgets, escalating
            const n = Math.min(3, shuffled.length)
            for (let i = 0; i < n; i++) {
                const t = shuffled[i]
                stops.push({
                    kind: "hit", key: t.key, x: t.x, w: t.w, actX: romp._actXFor(t),
                    vx: (Math.random() < 0.5 ? -1 : 1) * (160 + Math.random() * 200), vy: 30,
                    mode: i === n - 1 ? "wreck" : hitMode("")
                })
            }
        } else if (romp.planType === "toss") {
            const t = shuffled[0]
            const nx = 40 + Math.random() * Math.max(80, romp.width - t.w - 80)
            const ny = 40 + Math.random() * Math.max(80, romp.height - t.h - 200)
            stops.push({ kind: "hit", key: t.key, x: t.x, w: t.w, actX: romp._actXFor(t), vx: nx - t.x, vy: ny - t.y, mode: "persist" })
        } else {
            // bonk or wreck: single target, direction filled in at _begin
            const t = shuffled[0]
            stops.push({
                kind: "hit", key: t.key, x: t.x, w: t.w, actX: romp._actXFor(t),
                vx: 140 + Math.random() * 160, vy: 30,
                mode: romp.planType === "wreck" ? "wreck" : hitMode(""),
                dodge: romp.planType === "bonk" && Math.random() < 0.25
            })
        }
        romp.planStops = stops
        return stops.length > 0
    }

    // Domino: if the flung widget's landing spot overlaps another target,
    // that one takes a delayed secondary hit
    property var _dominoHit: null
    Timer {
        id: dominoTimer
        interval: 480
        onTriggered: {
            if (!romp._dominoHit) return
            MascotChaos.impact(romp._dominoHit.key, romp._dominoHit.vx, 0, "bounce")
            romp._dominoHit = null
        }
    }
    function _checkDomino(stop): void {
        if (stop.mode === "wreck") return
        const lx = stop.x + stop.vx
        for (const t of MascotChaos.targets()) {
            if (t.key === stop.key) continue
            if (lx < t.x + t.w && lx + stop.w > t.x && Math.abs(t.y - 0) < romp.height) {
                romp._dominoHit = { key: t.key, vx: stop.vx * 0.5 }
                dominoTimer.restart()
                return
            }
        }
    }

    // Calling card after a proper wrecking (real notification, 40% chance)
    function _maybeCallingCard(): void {
        if (Math.random() > 0.4) return
        const lines = romp._chaosCfg.notify ?? ["Nothing happened. Don't check your widgets."]
        const body = Translation.tr(lines[Math.floor(Math.random() * lines.length)])
        Quickshell.execDetached(["notify-send", "-a", "Kira", "-i",
            Quickshell.shellPath("assets/images/mascot/inir-mascot-peace-wink.png").toString().replace("file://", ""),
            Translation.tr("Kira was here"), body])
    }

    // ── Sprite state machine ────────────────────────────────────────────
    property string phase: "idle" // enter | act | aftermath | leave
    property bool _enterFromLeft: Math.random() < 0.5
    property real spriteX: 0
    // Run style picked once per outing (usually the run cycle, sometimes tiptoes)
    property string _runPose: "heroic-run"
    property string pose: _runPose
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
        romp._runPose = romp._pickActPose(romp._chaosCfg.run, "heroic-run")
        if (romp.startMode === "chase") {
            // run in to center stage first, then the game is on
            romp._enterFromLeft = Math.random() < 0.5
            romp.spriteX = romp._enterFromLeft ? -romp.spriteSize : romp.width + romp.spriteSize
            romp.pose = romp._runPose
            romp.phase = "enter"
            romp.planStops = [{ kind: "chase", actX: romp.width * 0.45 }]
            romp.planIndex = 0
            romp.planType = "chase"
            console.log("[MascotRomp] chase mode")
            romp._runTo(romp.width * 0.45)
            return
        }
        if (!romp._makePlan()) { romp._abort(); return }
        romp.planIndex = 0
        const first = romp.planStops[0]
        // enter from the edge nearest to the first stop
        romp._enterFromLeft = first.actX < romp.width / 2
        romp.spriteX = romp._enterFromLeft ? -romp.spriteSize : romp.width + romp.spriteSize
        // single hits fling in her run direction so she "kicks through"
        if ((romp.planType === "bonk" || romp.planType === "wreck") && first.kind === "hit")
            first.vx = (romp._enterFromLeft ? 1 : -1) * Math.abs(first.vx)
        romp.pose = romp._runPose
        romp.line = ""
        romp.phase = "enter"
        console.log(`[MascotRomp] ${romp.planType} (${romp.planStops.length} stop${romp.planStops.length > 1 ? "s" : ""})`)
        romp._runTo(first.actX)
    }

    function _runTo(x: real): void {
        runTween.to = x
        runTween.duration = Math.max(450, Math.abs(x - romp.spriteX) / romp.runSpeed)
        runTween.restart()
    }

    property bool _dodged: false
    function _phaseDone(): void {
        if (romp.phase === "chase") { romp._chaseTimeout(); return }
        const stop = romp.planStops[romp.planIndex]
        if (romp.phase === "enter" && stop.kind === "chase") {
            romp._startChase()
            return
        }
        if (romp.phase === "enter") {
            const cfgKey = stop.kind === "hit" ? romp._hitCfgKey(stop) : stop.kind
            const act = romp._chaosCfg[cfgKey] ?? ({})
            romp.pose = romp._pickActPose(act.pose, stop.kind === "trip" ? "dead-crash" : "chibi-mallet")
            romp.line = romp._pickLine(act.lines)
            romp.phase = "act"
            phaseTimer.interval = stop.kind === "trip" ? 2000 : 620
            phaseTimer.restart()
        } else if (romp.phase === "act") {
            if (stop.kind === "trip") {
                // she just lies there; then gets up, pretends it didn't happen
                romp.pose = "annoyed-poked"
                romp.line = romp._pickLine(romp._chaosCfg.trip?.after_lines ?? ["You saw NOTHING."])
                romp.phase = "aftermath"
                phaseTimer.interval = 1200
                phaseTimer.restart()
                return
            }
            if (stop.kind === "hit" && stop.dodge && !romp._dodged) {
                // the widget saw it coming — quick sidestep, she whiffs
                romp._dodged = true
                MascotChaos.impact(stop.key, (Math.random() < 0.5 ? -1 : 1) * 70, 0, "bounce")
                romp.pose = romp._pickActPose(romp._chaosCfg.dodge_pose, "chibi-rage")
                romp.line = romp._pickLine(romp._chaosCfg.dodge ?? ["Oh, it DODGED. Cute."])
                romp.phase = "act"
                phaseTimer.interval = 900
                phaseTimer.restart()
                return
            }
            // the hit lands
            if (stop.kind === "quake") {
                MascotChaos.panelShake(1)
                for (const t of MascotChaos.targets())
                    MascotChaos.impact(t.key, (Math.random() - 0.5) * 90, 0, "bounce")
            } else if (stop.kind === "punt") {
                MascotChaos.panelShake(2.4)
            } else {
                MascotChaos.impact(stop.key, stop.vx, stop.vy, stop.mode)
                romp._checkDomino(stop)
            }
            romp.planIndex++
            if (romp.planIndex < romp.planStops.length) {
                // rampage: on to the next victim
                romp.pose = romp._runPose
                romp.line = ""
                romp.phase = "enter"
                romp._runTo(romp.planStops[romp.planIndex].actX)
                return
            }
            const cfgKey = stop.kind === "hit" ? romp._hitCfgKey(stop) : stop.kind
            const act = romp._chaosCfg[cfgKey] ?? ({})
            romp.pose = romp._pickActPose(act.after, "chibi-pointing-laugh")
            romp.phase = "aftermath"
            phaseTimer.interval = 1500
            phaseTimer.restart()
            if (stop.mode === "wreck" || romp.planType === "rampage")
                romp._maybeCallingCard()
        } else if (romp.phase === "aftermath") {
            romp.pose = romp._runPose
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

    function _hitCfgKey(stop): string {
        if (stop.kind === "quake") return "quake"
        if (romp.planType === "toss") return "toss"
        return stop.mode === "wreck" ? "wreck" : "bonk"
    }

    function _abort(): void {
        runTween.stop()
        chaseXTween.stop()
        chaseYTween.stop()
        phaseTimer.stop()
        romp.finished()
    }

    // ── Chase mode: she hunts your mouse clicks ─────────────────────────
    // Every click is a spot to pounce on; click HER to catch her and win.
    property int _chaseClicks: 0
    property real spriteY: -1 // -1 = glued to the ground
    NumberAnimation { id: chaseXTween; target: romp; property: "spriteX"; duration: 320; easing.type: Easing.OutQuad }
    NumberAnimation {
        id: chaseYTween
        target: romp
        property: "spriteY"
        duration: 320
        easing.type: Easing.OutQuad
        onStopped: if (romp.phase === "chase") romp.pose = romp._chaosCfg.chase?.wait ?? "crouch-ready"
    }

    function _startChase(): void {
        runTween.stop()
        romp._chaseClicks = 0
        romp.phase = "chase"
        romp.pose = romp._pickActPose(romp._chaosCfg.chase?.invite, "follow-me")
        romp.line = romp._pickLine(romp._chaosCfg.chase?.lines ?? ["Catch me if you can."])
        if (romp.spriteY < 0) romp.spriteY = romp.groundY
        phaseTimer.interval = 25000
        phaseTimer.restart()
    }

    function _chasePounce(cx: real, cy: real): void {
        romp._chaseClicks++
        if (romp._chaseClicks > 14) { romp._endChase("bored"); return }
        romp.pose = romp._chaosCfg.chase?.pounce ?? "pounce-point"
        romp.line = ""
        chaseXTween.stop(); chaseYTween.stop()
        chaseXTween.to = Math.max(0, Math.min(cx - romp.spriteSize / 2, romp.width - romp.spriteSize))
        chaseYTween.to = Math.max(0, Math.min(cy - romp.spriteSize / 2, romp.height - romp.spriteSize))
        chaseXTween.restart(); chaseYTween.restart()
    }

    function _chaseTimeout(): void { romp._endChase("timeout") }

    function _endChase(how: string): void {
        phaseTimer.stop()
        chaseXTween.stop(); chaseYTween.stop()
        const c = romp._chaosCfg.chase ?? ({})
        if (how === "caught") {
            romp.pose = "purr-content"
            romp.line = romp._pickLine(c.caught ?? ["Okay. You win. This once."])
        } else if (how === "bored") {
            romp.pose = "facepalm"
            romp.line = romp._pickLine(c.bored ?? ["I have things to wreck. Bye."])
        } else {
            romp.pose = "shrug-annoyed"
            romp.line = romp._pickLine(c.timeout ?? ["Too slow. Noted."])
        }
        // settle to the ground, brag a moment, then leave
        romp.spriteY = -1
        romp.phase = "aftermath"
        phaseTimer.interval = 1800
        phaseTimer.restart()
    }

    // ── Visuals ─────────────────────────────────────────────────────────
    // Chase mode: the whole screen becomes her playground and every click
    // a pounce target; clicking her ends the game (you caught her)
    Item {
        id: chaseCatchArea
        anchors.fill: parent
        visible: romp.phase === "chase"
        MouseArea {
            anchors.fill: parent
            enabled: romp.phase === "chase"
            onClicked: mouse => {
                const inSprite = mouse.x >= sprite.x && mouse.x <= sprite.x + sprite.width
                    && mouse.y >= sprite.y && mouse.y <= sprite.y + sprite.height
                if (inSprite) romp._endChase("caught")
                else romp._chasePounce(mouse.x, mouse.y)
            }
        }
    }

    Item {
        id: sprite
        width: romp.spriteSize
        height: romp.spriteSize
        x: romp.spriteX
        y: (romp.spriteY >= 0 ? romp.spriteY : romp.groundY) + bob
        property real bob: 0

        // Poked mid-romp: she startles — and might turn it into a game
        TapHandler {
            enabled: romp.phase === "act" || romp.phase === "aftermath"
            onTapped: {
                if (Math.random() < 0.45) {
                    romp._startChase()
                } else {
                    romp.pose = "annoyed-poked"
                    romp.line = romp._pickLine(romp._chaosCfg.startle ?? ["HEY. Working here."])
                }
            }
        }

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
            // run art faces left unless listed in manifest facesRight;
            // mirror whenever art facing and travel direction disagree
            mirror: romp.running && (romp.movingRight !== (romp._manifest.facesRight ?? []).includes(romp.pose))
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
