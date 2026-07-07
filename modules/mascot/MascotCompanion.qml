import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * Playful mascot companion: she occasionally peeks from a screen edge and
 * reacts to shell events (music, battery, updates, network). Strictly
 * non-invasive: input only on her sprite, never over fullscreen windows or
 * game mode, never while locked or on the session screen, rate-limited.
 * IPC target "mascot": poke() / appear(pose, edge) / hide().
 */
Scope {
    id: root

    readonly property bool companionEnabled: (Config.options?.mascot?.enable ?? false)
        && (Config.options?.mascot?.companion?.enable ?? true)
    readonly property int intervalMinutes: Config.options?.mascot?.companion?.intervalMinutes ?? 25
    readonly property int spriteSize: Config.options?.mascot?.companion?.size ?? 150
    readonly property string placement: Config.options?.mascot?.companion?.placement ?? "peek"
    readonly property int visibleSeconds: Config.options?.mascot?.companion?.visibleSeconds ?? 8
    readonly property int slideMs: Config.options?.mascot?.companion?.slideMs ?? 400

    // Only peek from edges the user allows; fall back to any edge if all are off
    function _edgeAllowed(e) {
        const cfg = Config.options?.mascot?.companion?.edges
        if (!cfg) return true
        const v = cfg[e]
        return v === undefined ? true : v
    }
    function _fixEdge(e) {
        if (_edgeAllowed(e)) return e
        for (const alt of ["left", "right", "top", "bottom"])
            if (_edgeAllowed(alt)) return alt
        return e
    }
    readonly property bool suppressed: GameMode.active || GameMode.hasAnyFullscreenWindow
        || GlobalStates.screenLocked || GlobalStates.sessionOpen

    // Where the user's main panel actually lives — contextual reactions and
    // panel-flavored peeks come from this edge instead of a hardcoded "top"
    readonly property string panelEdge: (Config.options?.panelFamily ?? "ii") === "waffle" ? "bottom"
        : (Config.options?.bar?.bottom ?? false) ? "bottom"
        : (Config.options?.bar?.vertical ?? false) ? "left"
        : "top"

    // Which screen she lives on: the configured primary, or the one with
    // the focused workspace (multi-monitor setups)
    readonly property var companionScreen: {
        if ((Config.options?.mascot?.companion?.monitor ?? "primary") === "focused") {
            const out = NiriService.currentOutput ?? ""
            if (out.length > 0) {
                const s = Quickshell.screens.find(scr => scr.name === out)
                if (s) return s
            }
        }
        return GlobalStates.primaryScreen
    }

    property string pose: "edge-peek"
    property string edge: "right" // "left" | "right" | "top"
    property bool showing: false
    property string line: ""
    property double _lastShownAt: 0
    property int _clickCount: 0
    property string _contextualSource: ""
    property var _manifest: ({ idlePicks: [], linesByPose: ({}), idleLines: [], animatedPoses: [], linesByPoseSource: ({}), moodLines: ({}), smartLines: ({}) })

    property string _lastGameName: ""
    property string _focusApp: ""
    property double _focusSince: Date.now()

    // What she says, by pose. Rendered as a QML bubble — translated,
    // theme-aware, never baked into the image.
    readonly property var _linesByPose: _manifest.linesByPose && Object.keys(_manifest.linesByPose).length
        ? _manifest.linesByPose
        : ({
            "music-vibe": [Translation.tr("Decent taste. Barely."), Translation.tr("Volume up. Trust me.")],
            "battery-low": [Translation.tr("Feed the battery. Now.")],
            "update-ready": [Translation.tr("Update's ready. I read the changelog so you don't have to.")],
            "cable-defeat": [Translation.tr("The internet left. It's not me.")],
            "sleep-dnd": [Translation.tr("Shh. Do-not-disturb includes me. Rude.")],
            "late-night": [Translation.tr("Sleep is a feature, you know.")],
            "morning-coffee": [Translation.tr("Coffee first. Talk later.")],
            "tea-break": [Translation.tr("Tea. Don't rush me.")],
            "gaming-focus": [Translation.tr("GG. Who won?"), Translation.tr("Back already? Rematch?")],
            "workspace-juggle": [Translation.tr("Pick one already."), Translation.tr("They're all the same workspace to me.")]
        })
    readonly property var _linesByPoseSource: _manifest.linesByPoseSource ?? ({})
    readonly property var _moodLines: _manifest.moodLines ?? ({})
    readonly property var _idleLines: _manifest.idleLines?.length
        ? _manifest.idleLines
        : [
            Translation.tr("Just checking."),
            Translation.tr("Still no crashes? Impressive."),
            Translation.tr("Your config… bold choices."),
            Translation.tr("Hydrate."),
            Translation.tr("Super+/ shows the keybinds. Just saying."),
            Translation.tr("I saw that typo.")
        ]

    // Click ladder pose/line pools — manifest-driven, translated at pick time
    readonly property var _clickTier1Poses: _manifest.clickTiers?.tier1?.poses ?? ["annoyed-poked", "shy-flustered", "error-annoyed"]
    readonly property var _clickTier1Lines: _manifest.clickTiers?.tier1?.lines ?? ["Do I look clickable to you?", "...What.", "Wow. Rude."]
    readonly property var _clickTier2Poses: _manifest.clickTiers?.tier2?.poses ?? ["purr-content", "heart-eyes-pat", "shy-flustered", "chibi-love"]
    readonly property var _clickTier2Lines: _manifest.clickTiers?.tier2?.lines ?? ["...okay. Pats are acceptable.", "Don't make it weird.", "...Hmph."]
    readonly property var _clickTier4Poses: _manifest.clickTiers?.tier4?.poses ?? ["chibi-rage", "laughing-roast", "facepalm", "chibi-cry"]
    readonly property var _clickTier4Lines: _manifest.clickTiers?.tier4?.lines ?? ["THAT'S IT. I'm out.", "Banned. Forever.", "CONSEQUENCES."]

    // Stare-notice reactions — manifest-driven, anti-repeat via _recentLines
    readonly property var _stareReactions: _manifest.stareReactions?.length
        ? _manifest.stareReactions
        : [
            { pose: "shy-flustered", line: "...What." },
            { pose: "fisheye-inspect", line: "Take a picture. It lasts longer." },
            { pose: "annoyed-poked", line: "Creeping is still creeping." }
        ]

    // Anti-repetition memory: she never repeats a recent line or pose,
    // which is most of what "she feels scripted" was.
    property var _recentLines: []
    property var _recentPoses: []
    function _remember(list, item, cap) {
        list.push(item)
        while (list.length > cap) list.shift()
    }
    function _pickFrom(pool) {
        if (!pool || !pool.length) return ""
        const fresh = pool.filter(l => !_recentLines.includes(l))
        const src = fresh.length ? fresh : pool
        const pick = src[Math.floor(Math.random() * src.length)]
        _remember(_recentLines, pick, 12)
        return pick
    }
    function _pickPose(pool) {
        if (!pool || !pool.length) return ""
        const fresh = pool.filter(p => !_recentPoses.includes(p))
        const src = fresh.length ? fresh : pool
        const pick = src[Math.floor(Math.random() * src.length)]
        _remember(_recentPoses, pick, 10)
        return pick
    }

    function _lineFor(poseName) {
        // Contextual mode: try source-specific lines first
        if (root._contextualSource.length > 0
            && (Config.options?.mascot?.companion?.contextualPlacement ?? false)) {
            const sourcePool = _linesByPoseSource[poseName]
            if (sourcePool && sourcePool.length) return Translation.tr(_pickFrom(sourcePool))
        }
        const pool = _linesByPose[poseName]
        if (pool && pool.length) return Translation.tr(_pickFrom(pool))
        // Idle peeks only talk sometimes; silence is also personality
        if (Math.random() < 0.55) {
            // 50/50: blend in mood lines if personality is enabled and has the current mood
            const moodEnabled = Config.options?.mascot?.personality?.enabled ?? true
            const mood = moodEnabled ? (MascotMood.currentMood ?? "neutral") : null
            const moodPool = mood ? (root._moodLines[mood] ?? []) : []
            const custom = Config.options?.mascot?.companion?.customLines ?? []
            const baseLines = _idleLines.concat(custom.filter(l => (l ?? "").length > 0))
            const useMood = moodPool.length > 0 && Math.random() < 0.5
            const all = useMood ? moodPool : baseLines
            return all.length ? Translation.tr(_pickFrom(all)) : ""
        }
        return ""
    }

    // Pretty-print an app identifier: strip reverse-dns (only if no spaces,
    // i.e. looks like an app_id, not a title), capitalize, truncate 40
    function _prettyAppName(s) {
        if (!s || s.length === 0) return ""
        let name = s
        if (!s.includes(" ")) {
            const dotIdx = s.lastIndexOf(".")
            name = dotIdx >= 0 ? s.substring(dotIdx + 1) : s
        }
        name = name.charAt(0).toUpperCase() + name.slice(1)
        return name.length > 40 ? name.substring(0, 37) + "..." : name
    }

    // Poses that exist as animated GIF loops instead of static PNGs
    readonly property var animatedPoses: _manifest.animatedPoses?.length
        ? _manifest.animatedPoses
        : ["tail-sway", "ear-twitch", "sleepy-nod", "wave-loop", "idle-blink", "idle-breathe"]

    readonly property var _idlePicks: _manifest.idlePicks?.length
        ? _manifest.idlePicks
        : [
            ["edge-peek", "left"], ["right-edge-peek", "right"], ["top-peek", "top"],
            ["upside-down-peek", "top"], ["hanging-claws", "top"],
            ["fisheye-inspect", "right"], ["box-hideout", "left"]
        ]

    // Idle pick = the whole catalog + a few time/mood-flavored duplicates.
    // Flavor biases the odds gently; it never drowns out catalog variety,
    // and recent poses are filtered out so she rotates instead of looping.
    function _timeFlavoredPick() {
        const hour = (new Date()).getHours()
        const moodEnabled = Config.options?.mascot?.personality?.enabled ?? true
        const mood = moodEnabled ? (MascotMood.currentMood ?? "neutral") : "neutral"
        let bag = _idlePicks.slice()
        const add = (pose, edge, n) => { for (let i = 0; i < n; i++) bag.push([pose, edge]) }
        if (mood === "sleepy") { add("sleepy-nod", "left", 3); add("chibi-sleepy", "left", 2) }
        if (mood === "hyper") { add("chibi-bounce", "right", 2); add("chibi-happy", "right", 1); add("energy-drink", "right", 2); add("skater-trick", "right", 1) }
        if (hour >= 1 && hour < 6) { add("late-night", "right", 4); add("sleepy-nod", "left", 2) }
        if (hour >= 6 && hour < 11) add("morning-coffee", "left", 4)
        add(Math.random() < 0.5 ? "mate-break" : "tea-break", "right", 2)
        add("tail-sway", "right", 2); add("ear-twitch", "left", 1); add("idle-breathe", "right", 2)
        const fresh = bag.filter(p => !_recentPoses.includes(p[0]))
        const src = fresh.length ? fresh : bag
        return src[Math.floor(Math.random() * src.length)]
    }

    function show(poseName: string, edgeName: string): bool {
        if (!companionEnabled || suppressed || showing) {
            console.log(`[MascotCompanion] peek denied (enabled=${companionEnabled} suppressed=${suppressed} showing=${showing})`)
            return false
        }
        edgeName = _fixEdge(edgeName)
        // Pose-edge coherence: edge-anchored art never appears from a wrong
        // edge, no matter what settings overrides or IPC calls request.
        const aff = _manifest.poseAffinity?.[poseName]
        if (aff && aff.length && !aff.includes(edgeName))
            edgeName = aff.find(e => _edgeAllowed(e)) ?? aff[0]

        // Edge switch mid-teardown: kill old window so slide-in originates from the new edge
        if (companionLoader.active && !showing && edgeName !== edge) {
            teardownTimer.stop()
        }

        console.log(`[MascotCompanion] peek: ${poseName} from ${edgeName}`)
        pose = poseName
        edge = edgeName
        line = _lineFor(poseName)
        _clickCount = 0
        _lastShownAt = Date.now()
        showing = true
        hideTimer.restart()
        return true
    }

    // Context brain: idle peeks that comment on what's actually happening
    // instead of pure random. Each candidate names a manifest contextLines
    // pool; %1 in a line is filled with the candidate's arg.
    property string _lastContext: ""
    function _smartCandidates() {
        const out = []
        const now = new Date()
        const day = now.getDay()
        const hour = now.getHours()
        if (_eventEnabled("music") && _looksLikeMusic()) {
            const t = MprisController.activePlayer?.trackTitle ?? ""
            out.push({ key: "media-playing", pose: "music-vibe", edge: "right", arg: t.length > 40 ? t.substring(0, 37) + "..." : t })
        }
        const notifCount = Notifications.list?.length ?? 0
        if (notifCount >= 10)
            out.push({ key: "notif-pileup", pose: "detective-glass", edge: "right", arg: notifCount })
        const upDays = parseInt((DateTime.uptime.match(/(\d+)\s*d/) ?? [])[1] ?? "0")
        if (upDays >= 2)
            out.push({ key: "uptime-days", pose: "tired-dev", edge: "left", arg: upDays })
        if (day === 1 && hour >= 6 && hour < 12)
            out.push({ key: "monday", pose: "morning-coffee", edge: "left" })
        if (day === 5 && hour >= 20)
            out.push({ key: "friday-night", pose: "popcorn-watch", edge: "right" })
        if ((day === 0 || day === 6) && hour >= 12 && hour < 20)
            out.push({ key: "weekend", pose: "reading", edge: "right" })
        if (Battery.isPluggedIn && Battery.percentage >= 0.97)
            out.push({ key: "battery-full", pose: "peace-wink", edge: "left" })
        if (root._focusApp.length > 0 && Date.now() - root._focusSince > 45 * 60 * 1000)
            out.push({ key: "app-marathon", pose: "typing-loop", edge: "right", arg: root._prettyAppName(root._focusApp) })
        // Wet weather outside → umbrella commentary (wttr WWO rain/sleet/thunder codes)
        if (Weather.enabled) {
            const wet = ["176", "179", "182", "185", "200", "263", "266", "281", "284", "293", "296", "299", "302", "305", "308", "311", "314", "317", "320", "353", "356", "359", "386", "389", "392", "395"]
            if (wet.includes(String(Weather.data?.wCode ?? "113")))
                out.push({ key: "weather-wet", pose: "weather-umbrella", edge: "top", arg: Weather.data?.description ?? "" })
        }
        // Music "playing" into a muted sink deserves a call-out
        if (_eventEnabled("music") && MprisController.isPlaying && (Audio.sink?.audio?.muted ?? false))
            out.push({ key: "muted-media", pose: "facepalm", edge: "right" })
        const winCount = NiriService.windows?.length ?? 0
        if (winCount >= 12)
            out.push({ key: "window-pileup", pose: Math.random() < 0.5 ? "marshaller-windows" : "heavy-lift", edge: "top", arg: winCount })
        // Never the same commentary twice in a row
        return out.filter(c => c.key !== root._lastContext)
    }

    function _showWithLine(poseName, edgeName, lineText) {
        if (!show(poseName, edgeName)) return false
        line = lineText
        return true
    }

    function poke(): bool {
        // Chaos mode: once in a while the idle visit is a full desktop romp
        if (chaosEnabled && !rompActive
            && Date.now() - _lastRompAt > 30 * 60 * 1000
            && Math.random() < 0.12) {
            return startRomp(Math.random() < 0.2 ? "chase" : "romp")
        }
        const ctxs = _smartCandidates()
        const ctxLines = _manifest.contextLines ?? ({})
        if (ctxs.length && Math.random() < 0.6) {
            const c = ctxs[Math.floor(Math.random() * ctxs.length)]
            const pool = ctxLines[c.key] ?? []
            if (pool.length) {
                let text = Translation.tr(_pickFrom(pool))
                if (c.arg !== undefined) text = text.arg(c.arg)
                if (_showWithLine(c.pose, c.edge, text)) {
                    root._lastContext = c.key
                    _remember(_recentPoses, c.pose, 10)
                    return true
                }
                return false
            }
        }
        // Fall back to the flavored candidate bag (already avoids recent poses)
        const pick = _timeFlavoredPick()
        _remember(_recentPoses, pick[0], 10)
        return show(pick[0], pick[1])
    }

    // Event reactions share one cooldown so she never spams
    function _showReaction(poseName, edgeName, sourceWidget) {
        if (Date.now() - _lastShownAt < 120 * 1000) {
            console.log(`[MascotCompanion] reaction '${poseName}' swallowed by cooldown`)
            return false
        }
        const contextualOn = Config.options?.mascot?.companion?.contextualPlacement ?? false
        if (contextualOn && sourceWidget.length > 0) {
            root._contextualSource = sourceWidget
            show(poseName, root.panelEdge)
        } else {
            root._contextualSource = ""
            show(poseName, edgeName)
        }
        return true
    }
    // Every event reaction is user-configurable: on/off per event, and an
    // optional fixed pose override (settings) replacing the manifest pool.
    function _eventEnabled(key) {
        const e = Config.options?.mascot?.companion?.events
        const v = e ? e[key] : undefined
        return v === undefined ? true : v
    }
    function _eventPose(key, pool) {
        const p = Config.options?.mascot?.companion?.eventPoses
        const v = p ? (p[key] ?? "") : ""
        return v.length > 0 ? v : _pickPose(pool ?? [])
    }

    // Event reactions are pose POOLS (manifest "reactions") so the same
    // trigger never parades the same image; the line follows the picked pose.
    readonly property var _reactionMap: _manifest.reactions ?? ({})
    function reactEvent(key) {
        if (!_eventEnabled(key)) return
        const fallback = ({
            "battery": { poses: ["battery-low"], edge: "left", source: "battery" },
            "update": { poses: ["update-ready"], edge: "top", source: "update" },
            "network": { poses: ["cable-defeat"], edge: "left", source: "network" },
            "dnd": { poses: ["sleep-dnd"], edge: "right", source: "dnd" },
            "notification": { poses: ["detective-glass"], edge: "right", source: "" },
            "wallpaper": { poses: ["theme-artist"], edge: "right", source: "" },
            "screenshot": { poses: ["camera-boop"], edge: "right", source: "" },
            "gaming": { poses: ["gaming-focus"], edge: "right", source: "" },
            "workspace": { poses: ["workspace-juggle"], edge: "top", source: "" },
            "unlock": { poses: ["waving-hi"], edge: "right", source: "" }
        })
        const r = _reactionMap[key] ?? fallback[key]
        if (!r) return
        _showReaction(_eventPose(key, r.poses), r.edge ?? "right", r.source ?? "")
    }
    function _reactWithLine(poseName, edgeName, sourceWidget, lineText) {
        if (_showReaction(poseName, edgeName, sourceWidget))
            root.line = lineText
    }

    function hide() {
        hideTimer.stop()
        showing = false
    }

    Timer {
        id: idleTimer
        running: root.companionEnabled && !root.showing && !root.suppressed
        repeat: true
        interval: Math.max(3, root.intervalMinutes) * 60000 * (0.75 + Math.random() * 0.5)
        onTriggered: {
            interval = Math.max(3, root.intervalMinutes) * 60000 * (0.75 + Math.random() * 0.5)
            root.poke()
        }
    }

    Timer {
        id: hideTimer
        interval: Math.max(3, root.visibleSeconds) * 1000
        onTriggered: {
            if (companionLoader.item?.hovered ?? false) { restart(); return }
            const cameFrom = root.edge
            root.showing = false
            // Rare prank: she immediately re-peeks from the opposite edge, watching
            if (Math.random() < 0.08 && !root.suppressed) {
                root._prankEdge = cameFrom === "left" ? "right" : "left"
                prankTimer.restart()
            }
        }
    }

    property string _prankEdge: "right"
    Timer {
        id: prankTimer
        interval: 1400
        onTriggered: root.show(root._pickPose(root._manifest.prankPoses ?? ["fisheye-inspect"]), root._prankEdge)
    }

    // If a fullscreen window / game / lock appears mid-peek, vanish instantly
    onSuppressedChanged: if (suppressed) hide()

    Connections {
        target: MprisController
        function onIsPlayingChanged() {
            if (MprisController.isPlaying) musicSustainTimer.restart()
            else musicSustainTimer.stop()
        }
    }

    // A real song has an artist; browser videos playing through MPRIS
    // usually don't. Requiring one (default) keeps her music commentary
    // to actual music — configurable for people who want everything.
    readonly property bool _musicRequireArtist: Config.options?.mascot?.companion?.musicRequireArtist ?? true
    function _looksLikeMusic() {
        if (!MprisController.isPlaying) return false
        const artist = MprisController.activePlayer?.trackArtist ?? ""
        return !_musicRequireArtist || artist.length > 0
    }

    Timer {
        id: musicSustainTimer
        interval: 7000
        onTriggered: {
            if (!root._eventEnabled("music") || !root._looksLikeMusic()) return
            const title = MprisController.activePlayer?.trackTitle ?? ""
            if (title.length === 0) return
            const artist = MprisController.activePlayer?.trackArtist ?? ""
            const mpose = root._eventPose("music", root._reactionMap.music?.poses ?? ["music-vibe"])
            const pool = root._manifest.smartLines?.["music-track"] ?? []
            if (pool.length === 0) { root._showReaction(mpose, "right", "media"); return }
            const usePool = artist.length > 0 ? pool : pool.filter(l => !l.includes("%2"))
            if (usePool.length === 0) { root._showReaction(mpose, "right", "media"); return }
            const truncatedTitle = title.length > 40 ? title.substring(0, 37) + "..." : title
            let text = Translation.tr(root._pickFrom(usePool))
            text = artist.length > 0 ? text.arg(truncatedTitle).arg(artist) : text.arg(truncatedTitle)
            root._reactWithLine(mpose, "right", "media", text)
        }
    }

    Connections {
        target: Battery
        function onIsLowAndNotChargingChanged() {
            if (Battery.isLowAndNotCharging) root.reactEvent("battery")
        }
    }

    Connections {
        target: ShellUpdates
        function onHasUpdateChanged() {
            if (ShellUpdates.hasUpdate) root.reactEvent("update")
        }
    }

    Connections {
        target: Network
        function onWifiStatusChanged() {
            if (Network.wifiStatus === "disconnected") root.reactEvent("network")
        }
    }

    Connections {
        target: Notifications
        function onSilentChanged() {
            if (Notifications.silent) root.reactEvent("dnd")
        }
        // Nosy: sometimes she comes to read your notifications. Chance-gated
        // on top of the shared 120s cooldown so it stays a treat, not a pest.
        function onNotify(notification) {
            if (Notifications.silent) return
            if (Math.random() > 0.3) return
            root.reactEvent("notification")
        }
    }

    // A wallpaper change re-themes the whole shell — she notices. The grace
    // window swallows the initial config-load "change" at startup.
    property double _bootAt: Date.now()
    Connections {
        target: Wallpapers
        function onEffectiveWallpaperPathChanged() {
            if (Date.now() - root._bootAt < 30 * 1000) return
            root.reactEvent("wallpaper")
        }
    }

    // She notices screenshots: after the region selector closes she may show
    // up asking to be in the picture. Chance-gated + shared 120s cooldown, and
    // delayed so she never appears while the capture is still happening.
    property bool _regionWasOpen: false
    Connections {
        target: GlobalStates
        function onRegionSelectorOpenChanged() {
            if (GlobalStates.regionSelectorOpen) { root._regionWasOpen = true; return }
            if (root._regionWasOpen) {
                root._regionWasOpen = false
                if (Math.random() < 0.5) screenshotTimer.restart()
            }
        }
        // Welcome-back after unlocking — she kept the place safe, obviously.
        // Boot grace swallows the initial lock-state settle at startup.
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) return
            if (Date.now() - root._bootAt < 30 * 1000) return
            if (Math.random() < 0.35) unlockTimer.restart()
        }
    }
    Timer { id: unlockTimer; interval: 2200; onTriggered: root.reactEvent("unlock") }
    Timer { id: screenshotTimer; interval: 1800; onTriggered: root.reactEvent("screenshot") }

    // "GG" after a gaming session ends — only if game mode was active for ≥8s
    // (filters out brief fullscreen video, IDE toggle, etc.)
    property bool _wasGaming: false
    Timer {
        id: gameModeSustainTimer
        interval: 8000
        onTriggered: {
            root._wasGaming = true
            const w = NiriService.activeWindow
            root._lastGameName = root._prettyAppName(w?.title ?? w?.app_id ?? "")
        }
    }
    Connections {
        target: GameMode
        function onActiveChanged() {
            if (GameMode.active) {
                gameModeSustainTimer.restart()
            } else {
                gameModeSustainTimer.stop()
                if (root._wasGaming) {
                    root._wasGaming = false
                    ggTimer.restart()
                }
            }
        }
    }
    Timer { id: ggTimer; interval: 3500; onTriggered: {
        if (!root._eventEnabled("gaming")) return
        if (root._lastGameName.length > 0) {
            const pool = root._manifest.smartLines?.["game-over"] ?? []
            if (pool.length > 0) {
                const pose = root._eventPose("gaming", root._reactionMap.gaming?.poses ?? ["gaming-focus"])
                root._reactWithLine(pose, "right", "", Translation.tr(root._pickFrom(pool)).arg(root._lastGameName))
                return
            }
        }
        root.reactEvent("gaming")
    }}

    // Track focused app for marathon detection
    Connections {
        target: NiriService
        function onActiveWindowChanged() {
            const app = NiriService.activeWindow?.app_id ?? ""
            if (app !== root._focusApp) {
                root._focusApp = app
                root._focusSince = Date.now()
            }
        }
    }

    // Frantic workspace switching earns commentary
    property int _wsHops: 0
    Connections {
        target: NiriService
        function onFocusedWorkspaceIndexChanged() {
            root._wsHops++
            wsHopsWindow.restart()
            if (root._wsHops >= 6) {
                root._wsHops = 0
                root.reactEvent("workspace")
            }
        }
    }
    Timer { id: wsHopsWindow; interval: 4000; onTriggered: root._wsHops = 0 }

    // ── Chaos mode: she runs across the desktop and messes with it ──────
    property bool rompActive: false
    property string rompMode: "romp"
    property double _lastRompAt: 0
    readonly property bool chaosEnabled: companionEnabled && MascotChaos.enabled
    function startRomp(mode: string): bool {
        if (!chaosEnabled || suppressed || rompActive) {
            console.log(`[MascotCompanion] romp denied (chaos=${chaosEnabled} suppressed=${suppressed} active=${rompActive})`)
            return false
        }
        _lastRompAt = Date.now()
        rompMode = mode
        rompActive = true
        return true
    }
    Loader {
        id: rompLoader
        active: root.rompActive
        sourceComponent: MascotRomp {
            rompScreen: root.companionScreen
            startMode: root.rompMode
            onFinished: root.rompActive = false
        }
    }

    IpcHandler {
        target: "mascot"

        function poke(): void { root.poke() }
        // Chaos mode: run across the desktop and mess with widgets/panels
        function romp(): void { root.startRomp("romp") }
        // Chase game: she hunts your mouse clicks — click her to catch her
        function chase(): void { root.startRomp("chase") }
        // Undo the chaos: every displaced widget returns home
        function tidy(): void {
            MascotChaos.tidy()
            const t = root._manifest.chaos?.tidy ?? ({})
            if (root.show(t.pose ?? "checklist-steps", "right"))
                root.line = Translation.tr(root._pickFrom(t.lines ?? ["You saw nothing."]))
        }
        // Named "appear" because "show" collides with the `qs ipc show` subcommand
        function appear(pose: string, edge: string): void { root.show(pose, edge) }
        function appearContextual(pose: string, sourceWidget: string): void {
            // Testable entry: skip reactTo cooldown (it's an explicit IPC call)
            root._contextualSource = sourceWidget
            root.show(pose, root.panelEdge)
        }
        // Easter eggs need a fixed line instead of the random _lineFor pick
        function appearWithLine(pose: string, edge: string, line: string): void {
            if (root.show(pose, edge)) root.line = line
        }
        function hide(): void { root.hide() }
    }

    // Load pose data / dialogue from manifest.json at runtime
    FileView {
        id: manifestFile
        path: Quickshell.shellPath("assets/images/mascot/manifest.json")
        onLoadedChanged: {
            if (!manifestFile.loaded) return
            try {
                root._manifest = JSON.parse(manifestFile.text())
            } catch (e) {
                console.warn("[MascotCompanion] manifest load failed:", e)
            }
        }
    }

    Loader {
        id: companionLoader
        active: root.showing || teardownTimer.running

        Timer {
            id: teardownTimer
            // Keep the window alive for the slide-out animation (configurable)
            interval: Math.max(450, root.slideMs + 50)
        }

        onActiveChanged: if (!active) root._clickCount = 0

        sourceComponent: PanelWindow {
            id: companionWindow

            readonly property bool hovered: mascotHover.hovered

            screen: root.companionScreen
            visible: true
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:mascotCompanion"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            mask: Region { item: mascotItem }

            // Random-but-stable placement along the chosen edge for this peek
            // When contextual mode is active, use a widget-aligned x fraction
            readonly property real edgeFraction: {
                if (root._contextualSource.length > 0) {
                    const map = ({ "battery": 0.85, "media": 0.30, "update": 0.92, "network": 0.80, "dnd": 0.78 })
                    return map[root._contextualSource] ?? (0.22 + Math.random() * 0.5)
                }
                return 0.22 + Math.random() * 0.5
            }

            Item {
                id: mascotItem

                readonly property bool fromTop: root.edge === "top"
                readonly property bool fromBottom: root.edge === "bottom"
                readonly property bool fromLeft: root.edge === "left"
                readonly property bool vertical: fromTop || fromBottom
                readonly property int size: root.spriteSize
                // How far she retreats off-screen when hidden
                readonly property int hideOffset: size + 24

                // Panel-sitter: the window respects layer-shell exclusive zones, so its
                // bounds already track bar/dock/taskbar in both families at runtime.
                // Panel-sitter just hugs the window edge; peek mode uses a small offset.
                readonly property bool panelSitterMode: root.placement === "panel-sitter"
                readonly property int _peekOffset: Math.round(size * 0.07)
                readonly property int _topPeekOffset: Math.round(size * 0.05)

                // Starts false so she slides in from off-screen on creation
                property bool onStage: false
                readonly property bool peekedOut: root.showing && onStage

                Component.onCompleted: Qt.callLater(() => onStage = true)

                width: size
                height: size
                // Side peeks are anchored to the bottom of the screen so cutout
                // sprites never show a floating cut edge; top/bottom peeks pick
                // a random horizontal spot per appearance.
                // Panel-sitter: window bounds already track panels via exclusive zones,
                // so the sprite just hugs the window edge (or uses a peek offset).
                x: vertical ? companionWindow.width * companionWindow.edgeFraction
                   : fromLeft ? (peekedOut
                      ? (panelSitterMode ? 0 : -_peekOffset)
                      : -hideOffset)
                   : (peekedOut
                      ? (panelSitterMode ? companionWindow.width - width : companionWindow.width - width + _peekOffset)
                      : companionWindow.width + hideOffset)
                y: fromTop ? (peekedOut
                   ? (panelSitterMode ? 0 : -_topPeekOffset)
                   : -hideOffset)
                   : fromBottom ? (peekedOut
                      ? (panelSitterMode ? companionWindow.height - height : companionWindow.height - height + _peekOffset)
                      : companionWindow.height + hideOffset)
                   : (panelSitterMode
                      ? companionWindow.height - height
                      : companionWindow.height - height + _peekOffset)

                Behavior on x {
                    enabled: Appearance.animationsEnabled && !mascotItem.vertical
                    NumberAnimation { duration: Math.max(100, root.slideMs); easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1] }
                }
                Behavior on y {
                    enabled: Appearance.animationsEnabled && mascotItem.vertical
                    NumberAnimation { duration: Math.max(100, root.slideMs); easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1] }
                }

                AnimatedImage {
                    id: companionSprite
                    anchors.fill: parent
                    source: Quickshell.shellPath(`assets/images/mascot/inir-mascot-${root.pose}.${root.animatedPoses.includes(root.pose) ? "gif" : "png"}`)
                    playing: root.showing
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: false
                    mipmap: false
                    // Only poses drawn hugging the left canvas edge flip on the
                    // right edge; everything else (badge text, asymmetric props)
                    // must render as drawn — mirroring reverses the iNiR badge.
                    mirror: root.edge === "right" && (root._manifest.mirrorOnRight ?? ["edge-peek"]).includes(root.pose)
                }

                HoverHandler { id: mascotHover }

                // Stare at her long enough and she notices
                Timer {
                    id: stareTimer
                    interval: 4000
                    running: mascotHover.hovered && root.showing && root.pose !== "shy-flustered"
                    onTriggered: {
                        const fresh = root._stareReactions.filter(r => !root._recentLines.includes(r.line))
                        const src = fresh.length ? fresh : root._stareReactions
                        const pick = src[Math.floor(Math.random() * src.length)]
                        root._remember(root._recentLines, pick.line, 12)
                        root._remember(root._recentPoses, pick.pose, 10)
                        root.pose = pick.pose
                        root.line = Translation.tr(pick.line)
                    }
                }

                TapHandler {
                    onTapped: {
                        root._clickCount++
                        clickResetTimer.restart()
                        if (root._clickCount >= 4) {
                            // Enough. She rage-quits.
                            root.pose = root._pickPose(root._clickTier4Poses)
                            root.line = Translation.tr(root._pickFrom(root._clickTier4Lines))
                            offendedTimer.restart()
                        } else if (root._clickCount >= 2) {
                            // Fine, pats are accepted. Dignity optional.
                            root.pose = root._pickPose(root._clickTier2Poses)
                            root.line = Translation.tr(root._pickFrom(root._clickTier2Lines))
                            hideTimer.restart()
                        } else {
                            // First poke: tolerated, barely
                            root.pose = root._pickPose(root._clickTier1Poses)
                            root.line = Translation.tr(root._pickFrom(root._clickTier1Lines))
                            hideTimer.restart()
                        }
                    }
                }

                Timer { id: clickResetTimer; interval: 1500; onTriggered: root._clickCount = 0 }
                Timer { id: offendedTimer; interval: 900; onTriggered: root.hide() }
            }

            // Speech bubble — QML layer beside her, input-transparent
            Rectangle {
                id: bubble

                readonly property int pad: 10

                visible: opacity > 0
                opacity: root.showing && root.line.length > 0 ? 1 : 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                implicitWidth: bubbleText.width + pad * 2
                implicitHeight: bubbleText.implicitHeight + pad * 2
                // Same style dispatch as StyledToolTipContent so the bubble
                // reads as a native shell tooltip in every global style
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

                x: mascotItem.vertical
                    ? Math.max(12, Math.min(mascotItem.x + mascotItem.width / 2 - width / 2, companionWindow.width - width - 12))
                    : mascotItem.fromLeft ? mascotItem.x + mascotItem.width + 6
                    : mascotItem.x - width - 6
                y: mascotItem.fromTop ? mascotItem.y + mascotItem.height + 6
                    : mascotItem.fromBottom ? mascotItem.y - height - 6
                    : mascotItem.y + mascotItem.height * 0.25 - height / 2

                StyledText {
                    id: bubbleText
                    anchors.centerIn: parent
                    text: root.line
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
    }

    onShowingChanged: if (!showing) teardownTimer.restart()
}
