pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Mascot asset catalog: which pose names ship animated (GIF) vs static
 * (PNG), read once from assets/images/mascot/manifest.json so
 * per-instance widgets don't each parse the manifest.
 */
Singleton {
    id: root

    property var animatedPoses: []
    // Per-pose apparent-size correction, derived from the composition tag
    // logged in PROMPTS.md (extreme close-ups read "bigger" than full-body
    // shots at the same box size). Absent = 1.0, no correction.
    property var frameScale: ({})

    function isAnimated(pose) {
        return root.animatedPoses.indexOf(pose) !== -1
    }

    function scaleFor(pose) {
        return root.frameScale[pose] ?? 1.0
    }

    function sourceFor(pose) {
        if (!pose || pose.length === 0)
            return ""
        const ext = root.isAnimated(pose) ? "gif" : "png"
        return Quickshell.shellPath(`assets/images/mascot/inir-mascot-${pose}.${ext}`)
    }

    FileView {
        path: Quickshell.shellPath("assets/images/mascot/manifest.json")
        onLoadedChanged: {
            if (!loaded) return
            try {
                const m = JSON.parse(text())
                root.animatedPoses = m.animatedPoses ?? []
                root.frameScale = m.frameScale ?? {}
            } catch (e) {
                console.warn("[MascotCatalog] manifest load failed:", e)
            }
        }
    }
}
