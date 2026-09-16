pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property string configEntryName
    required property var manifestKeys
    property var readConfigKey: null
    property string outputName: ""

    implicitWidth: _col.implicitWidth
    implicitHeight: _col.implicitHeight

    function _writeVal(key, val) {
        // Write to global config
        Config.setNestedValue("background.widgets." + root.configEntryName + "." + key, val)
        // Also sync output override if output exists
        if (root.outputName && root.outputName.length > 0) {
            DesktopWidgetLayout.setValue(root.outputName, root.configEntryName, key, val)
        }
    }

    Column {
        id: _col
        spacing: 4

        Repeater {
            model: root.manifestKeys

            Item {
                id: keyDelegate
                required property var modelData
                readonly property string cfgKey: modelData.key
                readonly property var spec: modelData.spec
                readonly property string cfgType: spec?.type ?? "bool"
                readonly property string label: spec?.label ?? cfgKey
                readonly property var currentVal: root.readConfigKey ? root.readConfigKey(cfgKey) : spec?.["default"]
                readonly property var optionsList: spec?.options ?? []
                readonly property bool hasOptions: optionsList && optionsList.length > 0

                width: _content.implicitWidth
                height: _content.implicitHeight

                Row {
                    id: _content
                    spacing: 4

                    // 1. Bool: toggle button
                    RippleButton {
                        id: boolButton
                        visible: keyDelegate.cfgType === "bool"
                        width: visible ? Math.max(100, _boolLabel.implicitWidth + 16) : 0; height: 28
                        buttonRadius: Appearance.rounding.small
                        toggled: Boolean(keyDelegate.currentVal)
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        colBackgroundToggled: Appearance.colors.colPrimaryContainer
                        colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
                        colRipple: Appearance.colors.colLayer1Active
                        colRippleToggled: Appearance.colors.colPrimaryContainerActive
                        downAction: () => root._writeVal(keyDelegate.cfgKey, !Boolean(keyDelegate.currentVal))
                        contentItem: StyledText {
                            id: _boolLabel
                            anchors.centerIn: parent
                            text: keyDelegate.label
                            color: boolButton.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    // 2. Options / Enum cycling
                    StyledText {
                        visible: keyDelegate.cfgType !== "bool"
                        anchors.verticalCenter: parent.verticalCenter
                        text: keyDelegate.label
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    RippleButton {
                        visible: keyDelegate.cfgType !== "bool"
                        width: visible ? 24 : 0; height: 24
                        buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.06)
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        downAction: () => {
                            if (keyDelegate.hasOptions) {
                                const curIdx = keyDelegate.optionsList.findIndex(o => (o.value ?? o) === keyDelegate.currentVal);
                                const nextIdx = (curIdx - 1 + keyDelegate.optionsList.length) % keyDelegate.optionsList.length;
                                const nextVal = keyDelegate.optionsList[nextIdx].value ?? keyDelegate.optionsList[nextIdx];
                                root._writeVal(keyDelegate.cfgKey, nextVal);
                            } else {
                                const step = keyDelegate.spec?.step ?? 1;
                                const min = keyDelegate.spec?.min ?? -Infinity;
                                root._writeVal(keyDelegate.cfgKey, Math.max(min, Number(keyDelegate.currentVal ?? 0) - step));
                            }
                        }
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "remove"; iconSize: 14; color: Appearance.colors.colOnLayer2 }
                    }

                    StyledText {
                        visible: keyDelegate.cfgType !== "bool"
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (keyDelegate.hasOptions) {
                                const match = keyDelegate.optionsList.find(o => (o.value ?? o) === keyDelegate.currentVal);
                                return match?.label ?? String(keyDelegate.currentVal ?? "");
                            }
                            return String(keyDelegate.currentVal ?? keyDelegate.spec?.["default"] ?? 0);
                        }
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: keyDelegate.hasOptions ? Appearance.font.family.main : Appearance.font.family.numbers
                    }

                    RippleButton {
                        visible: keyDelegate.cfgType !== "bool"
                        width: visible ? 24 : 0; height: 24
                        buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.06)
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        downAction: () => {
                            if (keyDelegate.hasOptions) {
                                const curIdx = keyDelegate.optionsList.findIndex(o => (o.value ?? o) === keyDelegate.currentVal);
                                const nextIdx = (curIdx + 1) % keyDelegate.optionsList.length;
                                const nextVal = keyDelegate.optionsList[nextIdx].value ?? keyDelegate.optionsList[nextIdx];
                                root._writeVal(keyDelegate.cfgKey, nextVal);
                            } else {
                                const step = keyDelegate.spec?.step ?? 1;
                                const max = keyDelegate.spec?.max ?? Infinity;
                                root._writeVal(keyDelegate.cfgKey, Math.min(max, Number(keyDelegate.currentVal ?? 0) + step));
                            }
                        }
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "add"; iconSize: 14; color: Appearance.colors.colOnLayer2 }
                    }
                }
            }
        }
    }
}
