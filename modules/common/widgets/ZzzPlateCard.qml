pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE

// General-purpose ZZZ content container. Unlike ZzzGraphicPlate (a styled surface),
// this is a card you wrap content in: it imposes the ZZZ grammar — generated plate,
// thick technical stroke, left category accent bar, clipped corner, and an optional
// poster section header — so consumers stop reusing recolored Material cards.
//
// Usage:
//   ZzzPlateCard { title: "Audio"; symbol: "volume_up"; index: "SND / 02"
//       StyledText { text: "..." } }
Rectangle {
    id: root

    property string title: ""
    property string symbol: ""
    property string index: ""
    property color accentColor: Appearance.zzz.accent
    property bool showAccentBar: true
    property bool showHeader: title.length > 0 || symbol.length > 0
    property real padding: 14
    property real spacing: 12

    default property alias content: contentHolder.data

    readonly property bool active: Appearance.zzzEverywhere

    visible: active
    implicitWidth: layout.implicitWidth + padding * 2 + (showAccentBar ? accentBar.width : 0)
    implicitHeight: layout.implicitHeight + padding * 2
    color: "transparent" // real fill painted by the masked inner layer
    radius: Appearance.zzz.panelRadius
    border.width: Appearance.zzz.borderThick
    border.color: Appearance.zzz.hairlineStrong

    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.width {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    Item {
        id: inner
        anchors.fill: parent
        layer.enabled: root.active
        layer.smooth: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: inner.width
                height: inner.height
                radius: root.radius
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.zzz.paper
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }

        Rectangle {
            id: accentBar
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: root.showAccentBar ? Math.max(3, Appearance.zzz.borderThick + 1) : 0
            color: root.accentColor
        }

        // Clipped-corner technical cue.
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Appearance.zzz.borderThick
            anchors.bottomMargin: Math.round(Appearance.zzz.cutCorner / 2)
            width: Appearance.zzz.cutCorner + 6
            height: Appearance.zzz.borderThick
            rotation: -45
            color: root.accentColor
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: root.padding + (root.showAccentBar ? accentBar.width : 0)
        anchors.rightMargin: root.padding
        anchors.topMargin: root.padding
        anchors.bottomMargin: root.padding
        spacing: root.spacing

        ZzzSectionHeader {
            Layout.fillWidth: true
            visible: root.showHeader
            title: root.title
            symbol: root.symbol
            index: root.index
            accentColor: root.accentColor
        }

        ColumnLayout {
            id: contentHolder
            Layout.fillWidth: true
            spacing: root.spacing
        }
    }
}
