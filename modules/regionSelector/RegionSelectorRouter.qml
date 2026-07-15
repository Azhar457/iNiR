pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

Scope {
    id: root

    function open(action, mode): void {
        GlobalStates.regionSelectorAction = action
        GlobalStates.regionSelectorMode = mode
        GlobalStates.regionSelectorOpen = true
    }
    function screenshot(): void { open(RegionSelection.SnipAction.Copy, RegionSelection.SelectionMode.RectCorners) }
    function search(): void {
        open(RegionSelection.SnipAction.Search,
            (Config.options?.search?.imageSearch?.useCircleSelection ?? false)
                ? RegionSelection.SelectionMode.Circle : RegionSelection.SelectionMode.RectCorners)
    }
    function ocr(): void { open(RegionSelection.SnipAction.CharRecognition, RegionSelection.SelectionMode.RectCorners) }
    function record(): void { open(RegionSelection.SnipAction.Record, RegionSelection.SelectionMode.RectCorners) }
    function recordWithSound(): void { open(RegionSelection.SnipAction.RecordWithSound, RegionSelection.SelectionMode.RectCorners) }
    function menu(): void { screenshot() }

    IpcHandler {
        target: "region"
        function screenshot(): void { root.screenshot() }
        function search(): void { root.search() }
        function googleLens(): void { root.search() }
        function ocr(): void { root.ocr() }
        function record(): void { root.record() }
        function recordWithSound(): void { root.recordWithSound() }
        function menu(): void { root.menu() }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut { name: "regionScreenshot"; description: "Takes a screenshot of the selected region"; onPressed: root.screenshot() }
            GlobalShortcut { name: "regionSearch"; description: "Searches the selected region"; onPressed: root.search() }
            GlobalShortcut { name: "regionOcr"; description: "Recognizes text in the selected region"; onPressed: root.ocr() }
            GlobalShortcut { name: "regionRecord"; description: "Records the selected region"; onPressed: root.record() }
            GlobalShortcut { name: "regionRecordWithSound"; description: "Records the selected region with sound"; onPressed: root.recordWithSound() }
            GlobalShortcut { name: "regionMenu"; description: "Opens the unified snip menu"; onPressed: root.menu() }
        }
    }
}
