pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import org.kde.kirigami as Kirigami
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root
    focus: true

    required property var targetWindow
    signal confirm()
    signal cancel()

    readonly property string appId: String(targetWindow?.app_id ?? "")
    readonly property string appTitle: String(targetWindow?.title ?? "")
    readonly property string appDisplayName: appTitle || appId || Translation.tr("Unknown")
    readonly property color dangerForeground: ColorUtils.ensureReadable(
        Looks.colors.fg, Looks.colors.danger, 4.5)
    readonly property color dangerSurface: ColorUtils.applyAlpha(Looks.colors.danger, 0.14)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.cancel()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.confirm()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.4)
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            animation: NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    MascotImage {
        anchors.bottom: dialog.top
        anchors.bottomMargin: -12
        anchors.right: dialog.right
        anchors.rightMargin: Looks.dp(18)
        width: Looks.dp(92)
        height: Looks.dp(92)
        pose: "warning-concerned"
        surface: "dialogs"
    }

    WPane {
        id: dialog
        anchors.centerIn: parent
        radius: Looks.cookieEverywhere ? Looks.radius.xLarge : Looks.radius.large
        implicitWidth: Looks.dp(392)
        borderColor: Looks.glassActive ? Looks.colors.tooltipBorder : Looks.colors.bg2Border

        scale: 0.96
        opacity: 0
        Component.onCompleted: {
            scale = 1
            opacity = 1
        }
        Behavior on scale {
            animation: NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
        }
        Behavior on opacity {
            animation: NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
            }
        }

        contentItem: ColumnLayout {
            spacing: 0

            Item {
                Layout.fillWidth: true
                implicitHeight: contentColumn.implicitHeight + Looks.dp(40)

                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    anchors.margins: Looks.dp(20)
                    spacing: Looks.dp(12)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Looks.dp(12)

                        Rectangle {
                            Layout.preferredWidth: Looks.dp(54)
                            Layout.preferredHeight: Looks.dp(54)
                            Layout.alignment: Qt.AlignTop
                            radius: Looks.cookieEverywhere ? height / 2 : Looks.radius.large
                            color: Looks.colors.bg1
                            border.width: 1
                            border.color: Looks.colors.bg2Border

                            Kirigami.Icon {
                                anchors.fill: parent
                                anchors.margins: Looks.dp(9)
                                source: root.appId
                                fallback: "application-x-executable"
                                roundToIconSize: false
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: -Looks.dp(3)
                                anchors.bottomMargin: -Looks.dp(3)
                                width: Looks.dp(20)
                                height: Looks.dp(20)
                                radius: height / 2
                                color: Looks.colors.danger
                                border.width: 2
                                border.color: Looks.colors.bg1

                                FluentIcon {
                                    anchors.centerIn: parent
                                    icon: "dismiss"
                                    implicitSize: Looks.dp(11)
                                    color: root.dangerForeground
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Looks.dp(3)

                            WText {
                                Layout.fillWidth: true
                                text: Translation.tr("Close this window?")
                                font.pixelSize: Looks.font.pixelSize.xlarger
                                font.weight: Looks.font.weight.strongest
                                color: Looks.colors.fg
                                wrapMode: Text.WordWrap
                            }

                            WText {
                                Layout.fillWidth: true
                                text: root.appDisplayName
                                font.pixelSize: Looks.font.pixelSize.normal
                                font.weight: Looks.font.weight.strong
                                color: Looks.colors.fg
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                            }

                            WText {
                                Layout.fillWidth: true
                                visible: root.appId.length > 0 && root.appId !== root.appDisplayName
                                text: root.appId
                                font.pixelSize: Looks.font.pixelSize.small
                                color: Looks.colors.subfg
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: warningText.implicitHeight + Looks.dp(20)
                        radius: Looks.cookieEverywhere ? Looks.radius.xLarge : Looks.radius.medium
                        color: root.dangerSurface
                        border.width: 1
                        border.color: ColorUtils.applyAlpha(Looks.colors.danger, 0.42)

                        RowLayout {
                            id: warningRow
                            anchors.fill: parent
                            anchors.margins: Looks.dp(10)
                            spacing: Looks.dp(10)

                            FluentIcon {
                                icon: "info-filled"
                                implicitSize: Looks.dp(16)
                                color: Looks.colors.danger
                                Layout.alignment: Qt.AlignTop
                            }

                            WText {
                                id: warningText
                                Layout.fillWidth: true
                                text: Translation.tr("Confirm before closing windows")
                                font.pixelSize: Looks.font.pixelSize.small
                                color: Looks.colors.fg
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Looks.colors.bg0Border
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: actionRow.implicitHeight + Looks.dp(28)

                RowLayout {
                    id: actionRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Looks.dp(16)
                    spacing: Looks.dp(8)

                    WBorderedButton {
                        implicitWidth: Looks.dp(104)
                        implicitHeight: Looks.dp(34)
                        horizontalPadding: Looks.dp(14)
                        verticalPadding: Looks.dp(5)
                        text: Translation.tr("Cancel")
                        icon.name: "dismiss"
                        forceShowIcon: true
                        cookieMorphing: Looks.cookieEverywhere
                        onClicked: root.cancel()
                    }

                    WButton {
                        implicitWidth: Looks.dp(104)
                        implicitHeight: Looks.dp(34)
                        horizontalPadding: Looks.dp(14)
                        verticalPadding: Looks.dp(5)
                        text: Translation.tr("Close")
                        icon.name: "delete"
                        forceShowIcon: true
                        cookieMorphing: Looks.cookieEverywhere
                        colBackground: Looks.colors.danger
                        colBackgroundHover: Looks.colors.dangerActive
                        colBackgroundActive: Looks.colors.dangerActive
                        colForeground: root.dangerForeground
                        onClicked: root.confirm()
                    }
                }
            }
        }
    }
}
