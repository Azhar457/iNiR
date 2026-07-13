pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "japaneseTypography"
    defaultConfig: ({
        enable: false,
        locked: false,
        placementStrategy: "free",
        preset: "exhibition",
        primaryText: "夏の記憶",
        secondaryText: "潮風と、あの子と、終わらない夏",
        sealText: "特別展",
        footerText: "PACIFIC DRIVE-IN",
        dateText: "7.12 — 8.31",
        showSecondary: true,
        showSeal: true,
        showFooter: true,
        fontFamily: "serif",
        primarySize: 72,
        secondarySize: 18,
        columnGap: 14,
        letterSpacing: 2,
        shadowStrength: 35,
        contentWidth: 330,
        contentHeight: 600,
        dim: 10,
        widgetScale: 100,
        widgetOpacity: 100,
        showBackground: false,
        useBlur: false,
        showBorder: false,
        backgroundOpacity: 0,
        borderWidth: 0,
        borderOpacity: 0.12,
        cornerRadius: -1,
        colorMode: "auto",
        x: 56,
        y: 120
    })

    implicitWidth: Math.round(Config.getNestedValue("background.widgets.japaneseTypography.contentWidth", 330) * root.scaleFactor)
    implicitHeight: Math.round(Config.getNestedValue("background.widgets.japaneseTypography.contentHeight", 600) * root.scaleFactor)
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 220
    resizeMinHeight: 320
    resizeMaxWidth: 720
    resizeMaxHeight: 1000
    needsColText: true
    liveColorTracking: true

    readonly property string primaryText: Config.getNestedValue("background.widgets.japaneseTypography.primaryText", "夏の記憶")
    readonly property string secondaryText: Config.getNestedValue("background.widgets.japaneseTypography.secondaryText", "潮風と、あの子と、終わらない夏")
    readonly property string sealText: Config.getNestedValue("background.widgets.japaneseTypography.sealText", "特別展")
    readonly property string footerText: Config.getNestedValue("background.widgets.japaneseTypography.footerText", "PACIFIC DRIVE-IN")
    readonly property string dateText: Config.getNestedValue("background.widgets.japaneseTypography.dateText", "7.12 — 8.31")
    readonly property bool showSecondary: Config.getNestedValue("background.widgets.japaneseTypography.showSecondary", true)
    readonly property bool showSeal: Config.getNestedValue("background.widgets.japaneseTypography.showSeal", true)
    readonly property bool showFooter: Config.getNestedValue("background.widgets.japaneseTypography.showFooter", true)
    readonly property string fontFamily: Config.getNestedValue("background.widgets.japaneseTypography.fontFamily", "serif")
    readonly property real primarySize: Config.getNestedValue("background.widgets.japaneseTypography.primarySize", 72)
    readonly property real secondarySize: Config.getNestedValue("background.widgets.japaneseTypography.secondarySize", 18)
    readonly property real configuredColumnGap: Config.getNestedValue("background.widgets.japaneseTypography.columnGap", 14)
    readonly property real configuredLetterSpacing: Config.getNestedValue("background.widgets.japaneseTypography.letterSpacing", 2)
    readonly property real shadowStrength: Math.max(0, Math.min(100,
        Config.getNestedValue("background.widgets.japaneseTypography.shadowStrength", 35)))

    readonly property real outerPad: Math.round(Math.max(12 * root.scaleFactor, Math.min(root.width, root.height) * 0.035))
    readonly property bool compact: root.width < 270 * root.scaleFactor || root.height < 430 * root.scaleFactor
    readonly property real footerExtent: root.showFooter
        ? Math.round(Math.max(54 * root.scaleFactor, Math.min(92 * root.scaleFactor, root.height * 0.15)))
        : 0
    readonly property real leadPixelSize: Math.max(28 * root.scaleFactor, Math.min(
        root.primarySize * root.scaleFactor,
        Math.max(28 * root.scaleFactor, body.height / 5.2),
        Math.max(28 * root.scaleFactor, body.width * (root.compact ? 0.27 : 0.23))))
    readonly property real notePixelSize: Math.max(11 * root.scaleFactor, Math.min(
        root.secondarySize * root.scaleFactor,
        Math.max(11 * root.scaleFactor, body.height / 16),
        Math.max(11 * root.scaleFactor, body.width * 0.085)))
    readonly property real effectiveColumnGap: Math.max(6 * root.scaleFactor, root.configuredColumnGap * root.scaleFactor)
    readonly property real effectiveLetterSpacing: Math.max(0, root.configuredLetterSpacing * root.scaleFactor)
    readonly property color leadInk: root.widgetInk
    readonly property color noteInk: ColorUtils.applyAlpha(root.widgetInk, 0.76)
    readonly property color detailInk: ColorUtils.applyAlpha(root.widgetInk, 0.66)
    readonly property color accentInk: root.widgetAccentVisible

    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetPlateColor
        surfaceAccent: root.widgetAccent
        surfaceUseBlur: root.useBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
    }

    Item {
        id: editorialComposition
        anchors.fill: parent
        anchors.margins: root.outerPad
        clip: true

        layer.enabled: root.shadowStrength > 0 && !root.widgetHasSurface
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.colHalo
            shadowOpacity: root.shadowStrength / 100
            shadowBlur: 0.62
            shadowHorizontalOffset: 1
            shadowVerticalOffset: 2
        }

        Item {
            id: body
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: footerBlock.visible ? footerBlock.top : parent.bottom
                bottomMargin: footerBlock.visible ? Math.round(12 * root.scaleFactor) : 0
            }
            clip: true

            VerticalJapaneseText {
                id: leadColumn
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }
                width: Math.max(root.leadPixelSize * 1.25, body.width * (root.compact ? 0.58 : 0.48))
                text: root.primaryText
                fontFamily: root.fontFamily
                fontPixelSize: root.leadPixelSize
                fontWeight: Font.Medium
                letterSpacing: root.effectiveLetterSpacing
                columnGap: root.effectiveColumnGap
                maxColumns: root.compact ? 1 : 2
                color: root.leadInk
            }

            VerticalJapaneseText {
                id: editorialNote
                visible: root.showSecondary && body.width >= 210 * root.scaleFactor && body.height >= 240 * root.scaleFactor
                anchors {
                    top: parent.top
                    topMargin: Math.round(root.leadPixelSize * 0.18)
                    bottom: parent.bottom
                    left: leadColumn.right
                    leftMargin: root.effectiveColumnGap
                }
                width: Math.max(root.notePixelSize * 2.2, body.width * 0.23)
                text: root.secondaryText
                fontFamily: root.fontFamily
                fontPixelSize: root.notePixelSize
                fontWeight: Font.Normal
                letterSpacing: Math.max(0, root.effectiveLetterSpacing * 0.5)
                columnGap: Math.max(5 * root.scaleFactor, root.effectiveColumnGap * 0.65)
                maxColumns: root.compact ? 1 : 2
                color: root.noteInk
            }

            Rectangle {
                id: seal
                visible: root.showSeal && body.width >= 220 * root.scaleFactor && body.height >= 260 * root.scaleFactor
                anchors {
                    top: parent.top
                    right: parent.right
                }
                width: Math.max(34 * root.scaleFactor, root.notePixelSize * 2.35)
                height: Math.min(body.height * 0.30,
                    Math.max(74 * root.scaleFactor, Array.from(root.sealText).length * root.notePixelSize * 1.22 + 18 * root.scaleFactor))
                color: "transparent"
                border.width: Math.max(1, Math.round(root.scaleFactor))
                border.color: root.accentInk
                radius: 0

                VerticalJapaneseText {
                    anchors.fill: parent
                    anchors.margins: Math.round(5 * root.scaleFactor)
                    text: root.sealText
                    fontFamily: root.fontFamily
                    fontPixelSize: Math.max(10 * root.scaleFactor, root.notePixelSize * 0.86)
                    fontWeight: Font.DemiBold
                    letterSpacing: 0
                    columnGap: 0
                    maxColumns: 1
                    color: root.accentInk
                }
            }
        }

        Item {
            id: footerBlock
            visible: root.showFooter && root.footerExtent > 0
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: root.footerExtent

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                }
                width: Math.min(parent.width * 0.78, 250 * root.scaleFactor)
                height: Math.max(1, Math.round(root.scaleFactor))
                color: root.accentInk
                opacity: 0.72
            }

            StyledText {
                anchors {
                    left: parent.left
                    top: parent.top
                    topMargin: Math.round(10 * root.scaleFactor)
                    right: parent.right
                }
                text: root.footerText
                color: root.leadInk
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                font {
                    family: Appearance.font.family.main
                    pixelSize: Math.max(10 * root.scaleFactor, Math.min(16 * root.scaleFactor, root.footerExtent * 0.24))
                    weight: Font.DemiBold
                    letterSpacing: Math.max(0, Math.round(root.scaleFactor))
                }
            }

            StyledText {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                text: root.dateText
                color: root.detailInk
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Math.max(10 * root.scaleFactor, Math.min(15 * root.scaleFactor, root.footerExtent * 0.22))
                    weight: Font.Medium
                    letterSpacing: Math.max(0, Math.round(root.scaleFactor * 0.8))
                }
            }
        }
    }
}
