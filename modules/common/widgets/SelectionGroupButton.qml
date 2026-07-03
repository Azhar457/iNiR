import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

GroupButton {
    id: root
    horizontalPadding: 11
    verticalPadding: 6
    bounce: false
    property string buttonIcon
    property string buttonPreviewKind: ""
    property bool leftmost: false
    property bool rightmost: false
    readonly property bool showZzzPreview: Appearance.zzzEverywhere && buttonPreviewKind.length > 0
    leftRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : (toggled || leftmost) ? (height / 2) : Appearance.rounding.unsharpenmore
    rightRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : (toggled || rightmost) ? (height / 2) : Appearance.rounding.unsharpenmore
    Behavior on leftRadius {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }
    Behavior on rightRadius {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }
    // ZZZ: idle segments are NEUTRAL plate, not bright secondary. Under zzz
    // colSecondaryContainer resolves to zzz.secondary (a signal) — using it for
    // the unselected base/hover made every segment glow and the hover glare.
    // Selected state stays the inherited GroupButton sticker (colBackgroundToggled).
    colBackground: Appearance.zzzEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colSecondaryContainer
    colBackgroundHover: Appearance.zzzEverywhere ? Appearance.colors.colLayer1Hover
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colSecondaryContainerHover
    colBackgroundActive: Appearance.zzzEverywhere ? Appearance.colors.colLayer1Active
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSecondaryContainerActive

    component ZzzCornerPreview: Item {
        id: preview
        required property string kind
        implicitWidth: 18
        implicitHeight: 12
        clip: true

        readonly property bool hug: kind === "hug"
        readonly property bool rect: kind === "rect"
        readonly property bool card: kind === "card"
        readonly property bool detached: kind === "float" || kind === "card"
        readonly property color previewFill: root.toggled
            ? ColorUtils.mix(Appearance.zzz.sticker, Appearance.zzz.onSticker, 0.18)
            : (card ? Appearance.zzz.chromeAlt : Appearance.zzz.paperAlt)
        readonly property color previewStroke: root.toggled
            ? ColorUtils.applyAlpha(Appearance.zzz.onSticker, 0.58)
            : Appearance.zzz.hairlineStrong
        readonly property color accentColor: root.toggled
            ? Appearance.zzz.onSticker
            : (card ? Appearance.zzz.secondary : Appearance.zzz.accentSoft)

        ZzzPlate {
            anchors {
                fill: parent
                leftMargin: preview.hug ? -5 : 0
                topMargin: preview.detached ? 1 : 0
                bottomMargin: preview.detached ? 1 : 0
            }
            fillColor: preview.previewFill
            strokeColor: preview.previewStroke
            strokeWidth: 1
            radius: preview.rect ? 0 : (preview.card ? Appearance.zzz.cardRadius : Appearance.zzz.controlRadius)
            chamfer: (!Appearance.zzz.round && !preview.rect) ? Math.max(4, Appearance.zzz.cutCorner * 0.35) : 0
            chamferTopRight: !preview.rect
            chamferBottomRight: false
            chamferBottomLeft: false
        }

        Rectangle {
            visible: preview.card
            x: 2
            y: 1
            width: 8
            height: 1
            radius: height / 2
            color: preview.accentColor
            opacity: 0.92
        }
    }

    contentItem: RowLayout {
        spacing: (root.showZzzPreview || root.buttonIcon?.length > 0) && root.buttonText?.length > 0 ? 4 : 0

        Behavior on spacing {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }

        Item {
            id: iconReveal
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.showZzzPreview ? cornerPreview.implicitWidth : (root.buttonIcon?.length > 0 ? materialSymbol.implicitWidth : 0)
            implicitHeight: root.showZzzPreview ? cornerPreview.implicitHeight : materialSymbol.implicitHeight
            opacity: root.showZzzPreview || root.buttonIcon?.length > 0 ? 1 : 0
            visible: opacity > 0
            clip: true

            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            Loader {
                id: cornerPreview
                anchors.centerIn: parent
                active: root.showZzzPreview
                sourceComponent: ZzzCornerPreview {
                    kind: root.buttonPreviewKind
                }
            }

            MaterialSymbol {
                id: materialSymbol
                anchors.centerIn: parent
                visible: !root.showZzzPreview
                text: root.buttonIcon
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.zzzEverywhere
                    ? (root.toggled ? Appearance.zzz.onSticker : Appearance.zzz.ink)
                    : (root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer)
            }
        }

        Item {
            implicitWidth: root.buttonText?.length > 0 ? textItem.implicitWidth : 0
            implicitHeight: textMetrics.height // Force height to that of regular text
            opacity: root.buttonText?.length > 0 ? 1 : 0
            visible: opacity > 0
            clip: true

            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            TextMetrics {
                id: textMetrics
                font.family: Appearance.font.family.main
                text: "Abc"
            }

            StyledText {
                id: textItem
                anchors.centerIn: parent
                color: Appearance.zzzEverywhere
                    ? (root.toggled ? Appearance.zzz.onSticker : Appearance.zzz.ink)
                    : (root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer)
                text: root.buttonText
            }
        }
    }
}
