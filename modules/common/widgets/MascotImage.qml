import QtQuick
import Quickshell
import qs.modules.common

/**
 * The iNiR mascot, rendered per branding rules (crisp pixel-art scaling).
 * Set `pose` to a catalog name from assets/images/mascot/PROMPTS.md,
 * e.g. "notifications-clear", "about-confident", "goodbye-wave".
 * Visibility is gated by the global mascot.enable switch; keep the
 * surface's original icon/placeholder as the switched-off fallback.
 */
Image {
    id: root

    property string pose
    // Placement group for the per-surface toggles in Settings › Mascot.
    // Empty = only gated by the master switch.
    property string surface: ""
    readonly property bool active: (Config.options?.mascot?.enable ?? false) && surfaceEnabled
    readonly property bool surfaceEnabled: {
        if (surface.length === 0) return true
        const s = Config.options?.mascot?.surfaces
        if (!s) return true
        const v = s[surface]
        return v === undefined ? true : v
    }
    // Per-surface pose override (Settings › Mascot › Surface poses):
    // users pick their own image for each placement group
    readonly property string effectivePose: {
        if (surface.length > 0) {
            const o = Config.options?.mascot?.surfacePoses
            const v = o ? (o[surface] ?? "") : ""
            if (v.length > 0) return v
        }
        return pose
    }

    visible: active
    source: (active && effectivePose.length > 0)
        ? Quickshell.shellPath(`assets/images/mascot/inir-mascot-${effectivePose}.png`)
        : ""
    sourceSize.width: 256
    sourceSize.height: 256
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: false
    mipmap: false
}
