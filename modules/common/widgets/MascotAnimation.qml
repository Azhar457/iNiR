import QtQuick
import Quickshell
import qs.modules.common

/**
 * Animated (GIF) variant of MascotImage for loop poses like "idle-blink" or
 * "wave-loop". Same mascot.enable gating and crisp-rendering contract; only
 * plays while visible. Note: AnimatedImage's sourceSize is read-only, so
 * unlike MascotImage there is no decode-size cap here — keep loop GIFs small.
 */
AnimatedImage {
    id: root

    property string pose
    // Placement group for the per-surface toggles in Settings › Quick › Mascot
    property string surface: ""
    readonly property bool active: (Config.options?.mascot?.enable ?? false) && surfaceEnabled
    readonly property bool surfaceEnabled: {
        if (surface.length === 0) return true
        const s = Config.options?.mascot?.surfaces
        if (!s) return true
        const v = s[surface]
        return v === undefined ? true : v
    }

    visible: active
    playing: active && visible
    source: (active && pose.length > 0)
        ? Quickshell.shellPath(`assets/images/mascot/inir-mascot-${pose}.gif`)
        : ""
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: false
    mipmap: false
}
