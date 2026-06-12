import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 16
    settingsPageName: Translation.tr("Dashboard")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    // Widget catalog: id → display metadata. Columns hold ids; "hidden" means
    // the id is in no column.
    readonly property var widgetCatalog: [
        { id: "welcome", name: Translation.tr("Welcome"), icon: "waving_hand" },
        { id: "clock", name: Translation.tr("Clock"), icon: "schedule" },
        { id: "system", name: Translation.tr("System usage"), icon: "monitoring" },
        { id: "github", name: Translation.tr("GitHub activity"), icon: "deployed_code" },
        { id: "notifications", name: Translation.tr("Notifications"), icon: "notifications" },
        { id: "todo", name: Translation.tr("To Do"), icon: "checklist" },
        { id: "media", name: Translation.tr("Media player"), icon: "music_note" },
        { id: "weather", name: Translation.tr("Weather"), icon: "partly_cloudy_day" },
        { id: "calendar", name: Translation.tr("Calendar"), icon: "calendar_month" },
        { id: "agenda", name: Translation.tr("Agenda"), icon: "event_upcoming" }
    ]
    readonly property var columnIds: ["left", "center", "right"]

    function _col(name) {
        const a = Config.options?.dashboard?.layout?.[name]
        return (a && a.length >= 0) ? a.slice() : []
    }
    function columnOf(id) {
        for (let i = 0; i < root.columnIds.length; i++)
            if (root._col(root.columnIds[i]).indexOf(id) !== -1)
                return root.columnIds[i]
        return "hidden"
    }
    function setColumn(id, col) {
        if (root.columnOf(id) === col) return
        let u = {}
        for (let i = 0; i < root.columnIds.length; i++) {
            const zone = root.columnIds[i]
            const arr = root._col(zone)
            const idx = arr.indexOf(id)
            if (idx !== -1) { arr.splice(idx, 1); u["dashboard.layout." + zone] = arr }
            if (zone === col) { arr.push(id); u["dashboard.layout." + zone] = arr }
        }
        Config.setNestedValues(u)
    }
    function moveWithin(id, dir) {
        const zone = root.columnOf(id)
        if (zone === "hidden") return
        const arr = root._col(zone)
        const idx = arr.indexOf(id)
        const next = idx + dir
        if (idx === -1 || next < 0 || next >= arr.length) return
        arr.splice(idx, 1)
        arr.splice(next, 0, id)
        Config.setNestedValue("dashboard.layout." + zone, arr)
    }

    SettingsCardSection {
        visible: !root.isIiActive
        expanded: true
        icon: "info"
        title: Translation.tr("Not Active")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("The dashboard only applies when using the Material (ii) panel style. Go to Modules → Panel Style to switch.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "space_dashboard"
        title: Translation.tr("General")

        SettingsGroup {
            ConfigSwitch {
                text: Translation.tr("Enable dashboard")
                description: Translation.tr("Centered hub with clock, notifications, media, weather and more")
                checked: Config.options?.dashboard?.enable ?? true
                onCheckedChanged: Config.setNestedValue("dashboard.enable", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Show header")
                description: Translation.tr("Uptime chip and quick action buttons at the top")
                checked: Config.options?.dashboard?.showHeader ?? true
                onCheckedChanged: Config.setNestedValue("dashboard.showHeader", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Show power buttons")
                description: Translation.tr("Lock and session buttons in the header")
                enabled: Config.options?.dashboard?.showHeader ?? true
                checked: Config.options?.dashboard?.showPowerButtons ?? true
                onCheckedChanged: Config.setNestedValue("dashboard.showPowerButtons", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Keep loaded in memory")
                description: Translation.tr("Faster opening at the cost of RAM")
                checked: Config.options?.dashboard?.keepLoaded ?? false
                onCheckedChanged: Config.setNestedValue("dashboard.keepLoaded", checked)
            }
            ConfigSpinBox {
                text: Translation.tr("Panel width (% of screen)")
                value: Math.round((Config.options?.dashboard?.widthRatio ?? 0.62) * 100)
                from: 40
                to: 90
                stepSize: 2
                onValueChanged: Config.setNestedValue("dashboard.widthRatio", value / 100)
            }
        }

        ContentSubsection {
            title: Translation.tr("Welcome subtitle")
            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Custom phrase under the greeting (optional)")
                text: Config.options?.dashboard?.subtitle ?? ""
                onTextChanged: {
                    Qt.callLater(() => {
                        Config.setNestedValue("dashboard.subtitle", text)
                    });
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("GitHub username")
            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Username for the contributions widget (optional)")
                text: Config.options?.dashboard?.github?.username ?? ""
                onTextChanged: {
                    Qt.callLater(() => {
                        Config.setNestedValue("dashboard.github.username", text)
                    });
                }
            }
        }

        SettingsGroup {
            RowLayout {
                spacing: 6
                Layout.fillWidth: true
                MaterialSymbol {
                    text: "keyboard_command_key"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Toggle with a keybinding running: %1").arg("inir ipc call dashboard toggle")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "widgets"
        title: Translation.tr("Widgets")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Place each widget in a column, or hide it. Use the arrows to reorder within a column.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.widgetCatalog
                delegate: RowLayout {
                    id: widgetRow
                    required property var modelData
                    readonly property string widgetColumn: root.columnOf(modelData.id)
                    Layout.fillWidth: true
                    spacing: 10

                    MaterialSymbol {
                        text: widgetRow.modelData.icon
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: widgetRow.modelData.name
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    ConfigSelectionArray {
                        Layout.fillWidth: false
                        currentValue: widgetRow.widgetColumn
                        onSelected: newValue => root.setColumn(widgetRow.modelData.id, newValue)
                        options: [
                            { displayName: Translation.tr("Hidden"), value: "hidden" },
                            { displayName: Translation.tr("Left"), value: "left" },
                            { displayName: Translation.tr("Center"), value: "center" },
                            { displayName: Translation.tr("Right"), value: "right" }
                        ]
                    }
                    RippleButton {
                        implicitWidth: 30
                        implicitHeight: 30
                        buttonRadius: Appearance.rounding.full
                        enabled: widgetRow.widgetColumn !== "hidden"
                        onClicked: root.moveWithin(widgetRow.modelData.id, -1)
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "arrow_upward"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSecondaryContainer
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    RippleButton {
                        implicitWidth: 30
                        implicitHeight: 30
                        buttonRadius: Appearance.rounding.full
                        enabled: widgetRow.widgetColumn !== "hidden"
                        onClicked: root.moveWithin(widgetRow.modelData.id, 1)
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "arrow_downward"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSecondaryContainer
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
