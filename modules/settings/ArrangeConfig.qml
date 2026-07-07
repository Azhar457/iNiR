pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Arrange settings: reorder nav groups, rename them, add new ones, and move
 * pages between groups. The arrangement persists as a JSON string in
 * settingsUi.categories ("" = defaults; property var inside JsonObject
 * crashes the VME, hence the string). SettingsPageRegistry sanitizes on
 * read, so a broken value can never hide a page — anything missing lands
 * in a trailing "More" group. Built per the inir-settings-ui method:
 * data-driven Repeaters over the effective arrangement, every mutation
 * writes the whole snapshot back through Config.setNestedValue.
 */
ContentPage {
    id: root
    settingsPageIndex: 20
    settingsPageName: Translation.tr("Arrange")

    function _snapshot(): var {
        return SettingsPageRegistry.categories.map(c => ({ label: c.label, pages: c.pages.slice() }))
    }
    function _save(cats): void {
        Config.setNestedValue("settingsUi.categories", JSON.stringify(cats))
    }
    function moveCategory(i: int, delta: int): void {
        const c = _snapshot()
        const j = i + delta
        if (j < 0 || j >= c.length) return
        const t = c[i]; c[i] = c[j]; c[j] = t
        _save(c)
    }
    function renameCategory(i: int, label: string): void {
        const c = _snapshot()
        if (!c[i] || label.trim().length === 0) return
        c[i].label = label.trim()
        _save(c)
    }
    function removeCategory(i: int): void {
        const c = _snapshot()
        if (!c[i] || c[i].pages.length > 0) return
        c.splice(i, 1)
        _save(c)
    }
    function addCategory(): void {
        const c = _snapshot()
        c.push({ label: Translation.tr("New group"), pages: [] })
        _save(c)
    }
    function movePage(ci: int, pi: int, delta: int): void {
        const c = _snapshot()
        const pages = c[ci]?.pages
        if (!pages) return
        const j = pi + delta
        if (j < 0 || j >= pages.length) return
        const t = pages[pi]; pages[pi] = pages[j]; pages[j] = t
        _save(c)
    }
    function movePageTo(ci: int, pi: int, targetCi: int): void {
        const c = _snapshot()
        if (!c[ci] || !c[targetCi] || ci === targetCi) return
        const page = c[ci].pages.splice(pi, 1)[0]
        c[targetCi].pages.push(page)
        _save(c)
    }

    SettingsCardSection {
        expanded: true
        icon: "swap_vert"
        title: Translation.tr("Arrange settings")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Reorder groups and pages, rename groups, or move pages wherever you like. The search always finds everything, no matter the arrangement.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }

            Flow {
                Layout.fillWidth: true
                spacing: 5
                RippleButtonWithIcon {
                    materialIcon: "add"
                    mainText: Translation.tr("Add group")
                    onClicked: root.addCategory()
                }
                RippleButtonWithIcon {
                    materialIcon: "restart_alt"
                    mainText: Translation.tr("Reset arrangement")
                    onClicked: Config.setNestedValue("settingsUi.categories", "")
                }
            }
        }

        Repeater {
            model: SettingsPageRegistry.categories.length
            delegate: SettingsGroup {
                id: catGroup
                required property int index
                readonly property var cat: SettingsPageRegistry.categories[catGroup.index] ?? ({ label: "", pages: [] })

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialTextField {
                        Layout.fillWidth: true
                        text: catGroup.cat.label
                        onEditingFinished: if (text !== catGroup.cat.label) root.renameCategory(catGroup.index, text)
                    }
                    RippleButtonWithIcon {
                        materialIcon: "arrow_upward"
                        onClicked: root.moveCategory(catGroup.index, -1)
                    }
                    RippleButtonWithIcon {
                        materialIcon: "arrow_downward"
                        onClicked: root.moveCategory(catGroup.index, 1)
                    }
                    RippleButtonWithIcon {
                        materialIcon: "delete"
                        visible: catGroup.cat.pages.length === 0
                        onClicked: root.removeCategory(catGroup.index)
                    }
                }

                Repeater {
                    model: catGroup.cat.pages.length
                    delegate: RowLayout {
                        id: pageRow
                        required property int index
                        readonly property int pageIdx: catGroup.cat.pages[pageRow.index] ?? 0
                        readonly property var page: SettingsPageRegistry.pages[pageRow.pageIdx] ?? ({ name: "?", icon: "help" })
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        spacing: 6

                        MaterialSymbol {
                            text: pageRow.page.icon ?? "settings"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: pageRow.page.name ?? "?"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                        RippleButtonWithIcon {
                            materialIcon: "arrow_upward"
                            onClicked: root.movePage(catGroup.index, pageRow.index, -1)
                        }
                        RippleButtonWithIcon {
                            materialIcon: "arrow_downward"
                            onClicked: root.movePage(catGroup.index, pageRow.index, 1)
                        }
                        StyledComboBox {
                            Layout.preferredWidth: 150
                            model: SettingsPageRegistry.categories.map((c, i) => ({ displayName: c.label, value: i }))
                            textRole: "displayName"
                            currentIndex: catGroup.index
                            onActivated: idx => {
                                if (idx !== catGroup.index)
                                    root.movePageTo(catGroup.index, pageRow.index, idx)
                            }
                        }
                    }
                }
            }
        }
    }
}
