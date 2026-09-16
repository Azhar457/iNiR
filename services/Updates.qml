pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service. Supports Arch (checkupdates) and Fedora (dnf check-update).
 */
Singleton {
    id: root

    property bool available: false
    property string updateCommand: "checkupdates"
    property int count: 0
    
    readonly property bool updateAdvised: available && count > (Config.options?.updates?.adviseUpdateThreshold ?? 75)
    readonly property bool updateStronglyAdvised: available && count > (Config.options?.updates?.stronglyAdviseUpdateThreshold ?? 200)

    function load() {}
    function refresh() {
        if (!available) return;
        print("[Updates] Checking for system updates")
        checkUpdatesProc.running = true;
    }

    Timer {
        interval: (Config.options?.updates?.checkInterval ?? 120) * 60 * 1000
        repeat: true
        running: Config.ready
        onTriggered: {
            print("[Updates] Periodic update check due")
            root.refresh();
        }
    }

    Timer {
        id: availabilityDefer
        interval: 1500
        repeat: false
        onTriggered: checkAvailabilityArchProc.running = true
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) availabilityDefer.start()
        }
    }

    Process {
        id: checkAvailabilityArchProc
        running: false
        command: ["which", "checkupdates"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.updateCommand = "checkupdates";
                root.available = true;
                root.refresh();
            } else {
                checkAvailabilityFedoraProc.running = true;
            }
        }
    }

    Process {
        id: checkAvailabilityFedoraProc
        running: false
        command: ["which", "dnf"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.updateCommand = "dnf";
                root.available = true;
                root.refresh();
            }
        }
    }

    Process {
        id: checkUpdatesProc
        command: root.updateCommand === "dnf" ? ["bash", "-c", "dnf check-update -q | awk '/^[[:alnum:]]/ {print $1}'"] : ["checkupdates"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (text ?? "").trim();
                root.count = t.length > 0 ? t.split("\n").length : 0;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && exitCode !== 100) { // dnf returns 100 if updates are available
                console.error("[Updates] update check failed", exitCode, exitStatus)
            }
        }
    }
}
