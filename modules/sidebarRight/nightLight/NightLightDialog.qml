import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: Appearance.rounding.normal
    color: Appearance.m3colors.m3surfaceContainerHigh

    property real dialogWidth: 350

    implicitHeight: nightLightColumn.implicitHeight
    implicitWidth: dialogWidth

    Behavior on implicitHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    Column {
        id: nightLightColumn
        Layout.fillWidth: true
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: 4

        RippleButton {
            id: titleButton
            Layout.fillWidth: true
            buttonRadius: root.radius
            colBackground: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainerHigh)
            colBackgroundHover: Appearance.colors.colLayer1Hover
            colRipple: Appearance.colors.colLayer1Active
            onClicked: {
                Hyprsunset.fetchState()
            }

            contentItem: RowLayout {
                spacing: 10

                StyledText {
                    id: titleText
                    font {
                        family: Appearance.font.family.title
                        pixelSize: Appearance.font.pixelSize.larger
                        weight: Font.Medium
                    }
                    text: Translation.tr("Night Light")
                }

                Item { Layout.fillWidth: true }

                MaterialSymbol {
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.m3colors.m3onSurface
                }
            }
            Layout.leftMargin: 0
            Layout.rightMargin: 0
        }

        Column {
            id: nightLightColumnInner
            Layout.topMargin: -16
            Layout.fillWidth: true
            anchors {
                left: parent.left
                right: parent.right
            }
            spacing: 4

            ConfigSwitch {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                iconSize: Appearance.font.pixelSize.larger
                buttonIcon: "lightbulb"
                text: Translation.tr("Enable now")
                autoToggle: false
                checked: Hyprsunset.active
                onToggledByUser: checked => Hyprsunset.toggle(checked)
            }

            ConfigSwitch {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                iconSize: Appearance.font.pixelSize.larger
                buttonIcon: "night_sight_auto"
                text: Translation.tr("Automatic")
                autoToggle: false
                checked: Config.options?.light?.night?.automatic ?? false
                onToggledByUser: checked => {
                    Config.setNestedValue("light.night.automatic", checked);
                }
            }

            // Schedule settings (only visible when automatic is enabled)
            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                visible: Config.options?.light?.night?.automatic ?? false
                opacity: visible ? 1 : 0
                spacing: 4

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                ConfigTimeInput {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    icon: "wb_twilight"
                    text: Translation.tr("Turn on at")
                    value: Config.options?.light?.night?.from ?? "19:00"
                    onTimeChanged: (newTime) => {
                        Config.setNestedValue("light.night.from", newTime);
                    }
                }

                ConfigTimeInput {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    icon: "wb_sunny"
                    text: Translation.tr("Turn off at")
                    value: Config.options?.light?.night?.to ?? "06:30"
                    onTimeChanged: (newTime) => {
                        Config.setNestedValue("light.night.to", newTime);
                    }
                }
            }

            WindowDialogSlider {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                icon: "thermometer"
                text: Translation.tr("Color temperature")
                value: Config.options?.light?.night?.colorTemperature ?? 6000
                from: 1000
                to: 6000
                stepSize: 100
                stopIndicatorValues: [6000]
                tooltip: Translation.tr("Lower the temperature to reduce blue light exposure. On Niri/wlsunset this affects the current filter temperature when Night Light is active.")
                onValueChanged: {
                    Config.setNestedValue("light.night.colorTemperature", value);
                }
            }
        }
    }
}
