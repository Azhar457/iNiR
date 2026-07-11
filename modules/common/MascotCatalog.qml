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
    property var collectionPoses: []
    property var chibiPoses: []
    property var editorialPoses: []
    property var collectionSpecial: ({})
    property var fullBodyPoses: []
    property var contextualOcclusionPoses: []
    property var fullBodyReplacements: ({})
    property var surfaceDefaults: ({})
    property bool ready: false
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

    function isCompatible(pose) {
        return root.fullBodyPoses.indexOf(pose) !== -1
            || root.contextualOcclusionPoses.indexOf(pose) !== -1
    }

    function collectionCategory(pose) {
        const special = root.collectionSpecial[pose]
        if (special?.category) return special.category
        if (root.fullBodyPoses.indexOf(pose) !== -1) return "fullbody"
        if (root.contextualOcclusionPoses.indexOf(pose) !== -1) return "contextual"
        if (root.chibiPoses.indexOf(pose) !== -1) return "chibi"
        if (root.editorialPoses.indexOf(pose) !== -1) return "editorial"
        if (root.isAnimated(pose)) return "animated"
        return "portrait"
    }

    function collectionRole(pose) {
        return root.collectionSpecial[pose]?.role ?? root.collectionCategory(pose)
    }

    function resolvePose(requested, surface, fallbackSurface) {
        if (root.isCompatible(requested)) return requested
        const replacement = root.fullBodyReplacements[requested] ?? ""
        if (root.isCompatible(replacement)) return replacement
        const surfacePose = root.surfaceDefaults[surface]
            ?? root.surfaceDefaults[fallbackSurface]
            ?? "presence-idle-loop"
        return root.isCompatible(surfacePose) ? surfacePose : "presence-idle-loop"
    }

    FileView {
        path: Quickshell.shellPath("assets/images/mascot/manifest.json")
        watchChanges: true
        onLoadedChanged: {
            if (!loaded) return
            try {
                const m = JSON.parse(text())
                root.animatedPoses = m.animatedPoses ?? []
                root.collectionPoses = m.collectionPoses ?? []
                root.chibiPoses = m.chibiPoses ?? []
                root.editorialPoses = m.editorialPoses ?? []
                root.collectionSpecial = m.collectionSpecial ?? {}
                root.fullBodyPoses = m.fullBodyPoses ?? []
                root.contextualOcclusionPoses = m.contextualOcclusionPoses ?? []
                root.fullBodyReplacements = m.fullBodyReplacements ?? {}
                root.surfaceDefaults = m.surfaceDefaults ?? {}
                root.frameScale = m.frameScale ?? {}
                root.ready = true
            } catch (e) {
                root.ready = false
                console.warn("[MascotCatalog] manifest load failed:", e)
            }
        }
    }
}
