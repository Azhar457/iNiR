pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

PanelSurface {
    id: root

    required property string outputName
    readonly property var orbitOptions: Config.options?.orbit ?? {}
    readonly property int itemLimit: Math.max(2, Math.min(8, orbitOptions.trailItems ?? 5))
    readonly property var stashedIds: MinimizedWindows.getMinimizedForOutput(root.outputName)
    readonly property var trailWindows: {
        const workspaceIds = new Set((NiriService.allWorkspaces ?? [])
            .filter(workspace => workspace.output === root.outputName)
            .map(workspace => workspace.id))
        const byId = {}
        for (const window of NiriService.windows ?? [])
            byId[window.id] = window
        const result = []
        for (const id of NiriService.mruWindowIds ?? []) {
            const window = byId[id]
            if (!window || !workspaceIds.has(window.workspace_id) || MinimizedWindows.isMinimized(id))
                continue
            result.push(window)
            if (result.length >= root.itemLimit)
                break
        }
        return result
    }

    implicitWidth: Math.min(980, trailRow.implicitWidth + 20)
    implicitHeight: 46
    island: true
    elevation: 2
    outlined: false

    RowLayout {
        id: trailRow
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6

        MaterialSymbol {
            visible: root.orbitOptions.showTrail ?? true
            text: "history"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }

        Repeater {
            model: (root.orbitOptions.showTrail ?? true) ? root.trailWindows : []

            RippleButton {
                required property var modelData
                Layout.preferredWidth: Math.min(190, Math.max(92, chipContent.implicitWidth + 18))
                Layout.fillHeight: true
                buttonRadius: Appearance.rounding.full
                colBackground: modelData.is_focused
                    ? Appearance.colors.colSecondaryContainer
                    : Appearance.colors.colLayer2
                onClicked: {
                    NiriService.focusWindow(modelData.id)
                    if (root.orbitOptions.closeOnSelect ?? true)
                        GlobalStates.closeOverview()
                }

                contentItem: RowLayout {
                    id: chipContent
                    spacing: 6

                    Image {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        source: AppSearch.getIconSource(modelData.app_id || "")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.title || modelData.app_id || Translation.tr("Window")
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }
        }

        RippleButtonWithIcon {
            visible: (root.orbitOptions.showStash ?? true) && root.stashedIds.length > 0
            Layout.fillHeight: true
            materialIcon: "inventory_2"
            mainText: root.stashedIds.length.toString()
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colLayer2
            onClicked: MinimizedWindows.restoreLatestForOutput(root.outputName,
                (root.orbitOptions.stashRestoreMode ?? "original") !== "current")
            StyledToolTip { text: Translation.tr("Restore latest stashed window") }
        }
    }
}
