pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

// ZZZ style editor — surfaces the ZZZ personality axis: silhouette variant.
// Square = sharp console plates with cut-corner chamfers (classic ZZZ).
// Round = softer anime UI — pill controls, rounded panels, no chamfer.
// Bound to `appearance.zzz.shape`. Geometry flips shell-wide reactively
// (every radius/cutCorner consumer reads Appearance.zzz.* which depends on it).
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 12

    ConfigSelectionArray {
        Layout.fillWidth: true
        currentValue: Config.options?.appearance?.zzz?.shape ?? "square"
        onSelected: (newValue) => {
            Config.setNestedValue("appearance.zzz.shape", newValue)
        }
        options: [
            { displayName: Translation.tr("Square"), icon: "square", value: "square" },
            { displayName: Translation.tr("Round"), icon: "rounded_corner", value: "round" }
        ]
    }

    StyledText {
        Layout.fillWidth: true
        text: Translation.tr("Square stays ZZZ's sharp console silhouette with cut-corner chamfers. Round softens the whole shell into an anime UI: pill controls, rounded panels and no chamfer. Changes apply instantly across every surface.")
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.smaller
        wrapMode: Text.WordWrap
    }
}
