pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root
    settingsPageIndex: 17
    settingsPageName: Translation.tr("Autostart")

    // ── Helpers ──────────────────────────────────────────────────────────

    function isDesktopEnabled(desktopId: string): bool {
        const entries = Config.options?.autostart?.entries ?? []
        for (let i = 0; i < entries.length; ++i) {
            if (entries[i].type === "desktop" && entries[i].desktopId === desktopId && entries[i].enabled)
                return true
        }
        return false
    }

    function setDesktopEnabled(desktopId: string, enabled: bool): void {
        let entries = [...(Config.options?.autostart?.entries ?? [])]
        let idx = -1
        for (let i = 0; i < entries.length; ++i) {
            if (entries[i].type === "desktop" && entries[i].desktopId === desktopId) {
                idx = i
                break
            }
        }
        if (enabled && idx === -1) {
            entries.push({ type: "desktop", desktopId: desktopId, enabled: true })
        } else if (enabled && idx !== -1) {
            entries[idx].enabled = true
        } else if (!enabled && idx !== -1) {
            entries[idx].enabled = false
        }
        Config.setNestedValue("autostart.entries", entries)
    }

    function addCommand(command: string): void {
        const cmd = command.trim()
        if (cmd.length === 0)
            return
        let entries = [...(Config.options?.autostart?.entries ?? [])]
        entries.push({ type: "command", command: cmd, enabled: true })
        Config.setNestedValue("autostart.entries", entries)
        commandInput.text = ""
    }

    function removeEntry(index: int): void {
        let entries = [...(Config.options?.autostart?.entries ?? [])]
        if (index >= 0 && index < entries.length) {
            entries.splice(index, 1)
            Config.setNestedValue("autostart.entries", entries)
        }
    }

    function setEntryEnabled(index: int, enabled: bool): void {
        let entries = [...(Config.options?.autostart?.entries ?? [])]
        if (index >= 0 && index < entries.length) {
            entries[index].enabled = enabled
            Config.setNestedValue("autostart.entries", entries)
        }
    }

    function getCommandEntries(): var {
        const entries = Config.options?.autostart?.entries ?? []
        const cmds = []
        for (let i = 0; i < entries.length; ++i) {
            if (entries[i].type === "command")
                cmds.push({ entry: entries[i], originalIndex: i })
        }
        return cmds
    }

    // Sorted + filtered app list: enabled first, then alphabetical, filtered by search
    function getFilteredApps(): var {
        const search = appSearchField.text.toLowerCase().trim()
        const apps = AppSearch.list ?? []
        const result = []
        for (let i = 0; i < apps.length; ++i) {
            const app = apps[i]
            const name = (app.name || "").toLowerCase()
            const generic = (app.genericName || "").toLowerCase()
            if (search && !name.includes(search) && !generic.includes(search))
                continue
            result.push(app)
        }
        result.sort((a, b) => {
            const aEnabled = root.isDesktopEnabled(a.id)
            const bEnabled = root.isDesktopEnabled(b.id)
            if (aEnabled !== bEnabled)
                return aEnabled ? -1 : 1
            return (a.name || "").localeCompare(b.name || "")
        })
        return result
    }

    // ── Layout ───────────────────────────────────────────────────────────

    SettingsCardSection {
        expanded: true
        icon: "rocket_launch"
        title: Translation.tr("General")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "rocket_launch"
                text: Translation.tr("Start apps on launch")
                checked: Config.options?.autostart?.enable ?? false
                onCheckedChanged: Config.setNestedValue("autostart.enable", checked)
                StyledToolTip {
                    text: Translation.tr("When enabled, selected apps and commands launch automatically when iNiR starts.")
                }
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "apps"
        title: Translation.tr("Applications")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: appSearchField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search applications...")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurface
                placeholderTextColor: Appearance.colors.colSubtext
                background: Rectangle {
                    color: Appearance.colors.colLayer1
                    radius: Appearance.rounding.small
                    border.width: appSearchField.activeFocus ? 2 : 1
                    border.color: appSearchField.activeFocus
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colLayer0Border
                }
            }

            ListView {
                id: appListView
                Layout.fillWidth: true
                implicitHeight: Math.min(400, appListView.contentHeight)
                clip: true
                model: root.getFilteredApps()

                delegate: RowLayout {
                    id: appDelegate
                    required property var modelData
                    required property int index
                    width: appListView.width
                    spacing: 10

                    Item {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            anchors.fill: parent
                            source: AppSearch.getIconSource(appDelegate.modelData.icon, appDelegate.modelData.name)
                            sourceSize.width: 56
                            sourceSize.height: 56
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }

                        MaterialSymbol {
                            anchors.fill: parent
                            text: "apps"
                            iconSize: 22
                            color: Appearance.colors.colOnSurface
                            visible: !(AppSearch.getIconSource(appDelegate.modelData.icon, appDelegate.modelData.name).length > 0)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: appDelegate.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            text: appDelegate.modelData.comment ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            visible: (text ?? "").length > 0
                        }
                    }

                    StyledSwitch {
                        checked: root.isDesktopEnabled(appDelegate.modelData.id)
                        onCheckedChanged: root.setDesktopEnabled(appDelegate.modelData.id, checked)
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "terminal"
        title: Translation.tr("Custom Commands")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialTextField {
                    id: commandInput
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("e.g. telegram-desktop --start-minimized")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurface
                    placeholderTextColor: Appearance.colors.colSubtext
                    background: Rectangle {
                        color: Appearance.colors.colLayer1
                        radius: Appearance.rounding.small
                        border.width: commandInput.activeFocus ? 2 : 1
                        border.color: commandInput.activeFocus
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colLayer0Border
                    }
                    onAccepted: root.addCommand(commandInput.text)
                }

                RippleButton {
                    buttonText: Translation.tr("Add")
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.small
                    onClicked: root.addCommand(commandInput.text)
                }
            }

            ListView {
                id: commandListView
                Layout.fillWidth: true
                implicitHeight: Math.min(200, commandListView.contentHeight)
                clip: true
                model: root.getCommandEntries()

                delegate: RowLayout {
                    id: cmdDelegate
                    required property var modelData
                    required property int index
                    width: commandListView.width
                    spacing: 10

                    MaterialSymbol {
                        text: "terminal"
                        iconSize: 22
                        color: Appearance.colors.colOnSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: cmdDelegate.modelData.entry.command
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnSurface
                        elide: Text.ElideRight
                    }

                    StyledSwitch {
                        checked: cmdDelegate.modelData.entry.enabled
                        onCheckedChanged: root.setEntryEnabled(cmdDelegate.modelData.originalIndex, checked)
                    }

                    RippleButton {
                        buttonText: Translation.tr("Remove")
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.small
                        onClicked: root.removeEntry(cmdDelegate.modelData.originalIndex)
                    }
                }
            }
        }
    }
}
