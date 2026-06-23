import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    default property alias contentData: content.data

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + SettingsMaterialPreset.groupPadding * 2

    radius: SettingsMaterialPreset.groupRadius
    color: SettingsMaterialPreset.groupColor
    border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
        : Appearance.zzzEverywhere ? 0 : 0
    border.color: SettingsMaterialPreset.groupBorderColor

    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.width {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    // ZZZ left category accent bar (inset to follow the rounded corners).
    Rectangle {
        visible: Appearance.zzzEverywhere
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            topMargin: root.radius
            bottomMargin: root.radius
            leftMargin: root.border.width
        }
        width: Math.max(3, Appearance.zzz.borderThick + 1)
        color: Appearance.zzz.accent
    }

    ColumnLayout {
        id: content
        anchors {
            fill: parent
            margins: SettingsMaterialPreset.groupPadding
        }
        anchors.leftMargin: SettingsMaterialPreset.groupPadding + (Appearance.zzzEverywhere ? Appearance.zzz.borderThick + 4 : 0)
        spacing: SettingsMaterialPreset.groupSpacing
    }
}
