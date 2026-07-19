pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property list<var> staticEntries: []
    property list<var> animatedEntries: []
    property bool scanning: false
    property string directory: ""

    signal refreshed()

    function refresh(path: string): void {
        const cleanPath = FileUtils.trimFileProtocol(String(path ?? ""))
        if (!cleanPath || scanProcess.running) return
        root.directory = cleanPath
        root.scanning = true
        scanProcess.exec([
            "find", cleanPath, "-type", "f", "(",
            "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o",
            "-iname", "*.png", "-o", "-iname", "*.webp", "-o",
            "-iname", "*.avif", "-o", "-iname", "*.bmp", "-o",
            "-iname", "*.svg", "-o", "-iname", "*.gif", "-o",
            "-iname", "*.mp4", "-o", "-iname", "*.webm", "-o",
            "-iname", "*.mkv", "-o", "-iname", "*.avi", "-o",
            "-iname", "*.mov", ")", "-print"
        ])
    }

    function consume(rawOutput: string): void {
        const staticItems = []
        const animatedItems = []
        const prefix = root.directory.endsWith("/") ? root.directory : root.directory + "/"
        for (const rawLine of String(rawOutput ?? "").split("\n")) {
            const path = rawLine.trim()
            if (!path) continue
            const lower = path.toLowerCase()
            const isVideo = [".mp4", ".webm", ".mkv", ".avi", ".mov"]
                .some(extension => lower.endsWith(extension))
            const animatedRoot = prefix + "Animated/"
            const entry = {
                path: path,
                name: FileUtils.fileNameForPath(path),
                relativePath: path.startsWith(prefix) ? path.slice(prefix.length) : path,
                kind: isVideo ? "video" : lower.endsWith(".gif") ? "gif" : "static"
            }
            if (isVideo && path.startsWith(animatedRoot))
                animatedItems.push(entry)
            else if (!isVideo)
                staticItems.push(entry)
        }
        const byName = (left, right) => left.relativePath.localeCompare(right.relativePath)
        staticItems.sort(byName)
        animatedItems.sort(byName)
        root.staticEntries = staticItems
        root.animatedEntries = animatedItems
        root.refreshed()
    }

    Process {
        id: scanProcess
        stdout: StdioCollector {
            onStreamFinished: root.consume(text)
        }
        onExited: (exitCode, exitStatus) => {
            root.scanning = false
            if (exitCode !== 0) {
                root.staticEntries = []
                root.animatedEntries = []
                root.refreshed()
            }
        }
    }
}
