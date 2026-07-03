import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "weather"
    defaultConfig: ({
        placementStrategy: "leastBusy", preset: "default", style: "pill", shape: "pill",
        size: 200, tempSize: 80, iconSize: 80,
        showTemp: true, showIcon: true, showCondition: false,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.16, borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1,
        x: 100, y: 100
    })

    readonly property string weatherStyle: Config.getNestedValue("background.widgets.weather.style", "pill")
    readonly property string weatherShape: Config.getNestedValue("background.widgets.weather.shape", "pill")
    readonly property int shapeSize: Math.round((Config.getNestedValue("background.widgets.weather.size", 200)) * scaleFactor)
    readonly property int tempFontSize: Math.round((Config.getNestedValue("background.widgets.weather.tempSize", 80)) * scaleFactor)
    readonly property int weatherIconSize: Math.round((Config.getNestedValue("background.widgets.weather.iconSize", 80)) * scaleFactor)
    readonly property bool showTemp: Config.getNestedValue("background.widgets.weather.showTemp", true)
    readonly property bool showIcon: Config.getNestedValue("background.widgets.weather.showIcon", true)
    readonly property bool showCondition: Config.getNestedValue("background.widgets.weather.showCondition", false)
    readonly property int visibleContentCount: Number(showTemp) + Number(showIcon) + Number(showCondition)
    readonly property int weatherPadding: Math.round((Config.getNestedValue("background.widgets.weather.padding", 20)) * scaleFactor)
    readonly property int tempFontWeight: Config.getNestedValue("background.widgets.weather.tempFontWeight", 500)
    readonly property real conditionOpacity: Config.getNestedValue("background.widgets.weather.conditionOpacity", 0.7)

    implicitHeight: shapeSize
    implicitWidth: shapeSize
    resizableAxes: ({ uniform: "size" })
    resizeMinWidth: 80
    resizeMinHeight: 80
    // Analyze the region in BOTH modes: card needs colText for its overlay, pill needs
    // it so ensureVisible() and the region-aware halo can make the shape read on any
    // wallpaper instead of dissolving into a same-tone background.
    needsColText: true

    // ── Shape name → enum mapping ──
    readonly property var _shapeMap: ({
        "pill": MaterialShape.Shape.Pill, "circle": MaterialShape.Shape.Circle,
        "oval": MaterialShape.Shape.Oval, "diamond": MaterialShape.Shape.Diamond,
        "heart": MaterialShape.Shape.Heart, "flower": MaterialShape.Shape.Flower,
        "cookie4": MaterialShape.Shape.Cookie4Sided, "sunny": MaterialShape.Shape.Sunny,
        "clover": MaterialShape.Shape.Clover4Leaf, "softBurst": MaterialShape.Shape.SoftBurst,
        "gem": MaterialShape.Shape.Gem, "puffy": MaterialShape.Shape.Puffy
    })
    readonly property var pillShapeEnum: _shapeMap[weatherShape] ?? MaterialShape.Shape.Pill

    // ── Accent colors ── primary from the shared desktop-widget identity.
    readonly property color accentPrimary: root.widgetAccent
    readonly property color accentPrimaryContainer: Appearance.zzzEverywhere ? Appearance.zzz.sticker
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colPrimaryContainer
    readonly property color accentOnPrimaryContainer: Appearance.zzzEverywhere ? Appearance.zzz.onSticker
        : Appearance.colors.colOnPrimaryContainer
    readonly property color shapeFill: root.accentPrimaryContainer
    readonly property color shapeInk: ColorUtils.ensureReadable(root.accentOnPrimaryContainer, root.shapeFill, 4.5)
    readonly property color cardInk: ColorUtils.ensureReadable(root.colText, Appearance.colors.colLayer1, 4.5)

    // ── Style tokens ──
    readonly property real cardRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    // Shape options for popover
    readonly property var _shapeOptions: [
        { label: "Pill", value: "pill" }, { label: "Circle", value: "circle" },
        { label: "Oval", value: "oval" }, { label: "Diamond", value: "diamond" },
        { label: "Heart", value: "heart" }, { label: "Flower", value: "flower" },
        { label: "Cookie", value: "cookie4" }, { label: "Sunny", value: "sunny" },
        { label: "Clover", value: "clover" }, { label: "Burst", value: "softBurst" },
        { label: "Gem", value: "gem" }, { label: "Puffy", value: "puffy" }
    ]

    editPopoverContent: Component {
        Column {
            spacing: 6
            // Style mode
            GridLayout {
                columns: 2
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: "Shape", icon: "category", value: "pill" },
                        { label: "Card", icon: "crop_landscape", value: "card" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.weatherStyle === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.weather.style", modelData.value)
                    }
                }
            }
            // Shape picker (visible only in pill/shape mode)
            GridLayout {
                visible: root.weatherStyle === "pill"
                columns: 4
                columnSpacing: 3
                rowSpacing: 3
                Repeater {
                    model: root._shapeOptions
                    Rectangle {
                        required property var modelData
                        property alias hovered: shapeMouseArea.containsMouse
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Appearance.rounding.small
                        color: root.weatherShape === modelData.value
                            ? ColorUtils.applyAlpha(root.accentPrimary, 0.18)
                            : "transparent"
                        border.width: root.weatherShape === modelData.value ? 1.5 : 0
                        border.color: root.accentPrimary

                        MaterialShape {
                            anchors.centerIn: parent
                            implicitSize: 22
                            shape: root._shapeMap[modelData.value] ?? MaterialShape.Shape.Pill
                            color: root.weatherShape === modelData.value
                                ? root.accentPrimary : root.accentOnPrimaryContainer
                        }
                        MouseArea {
                            id: shapeMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: Config.setNestedValue("background.widgets.weather.shape", modelData.value)
                        }
                        StyledToolTip { text: Translation.tr(modelData.label) }
                    }
                }
            }
            // Content toggles
            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: "Temp", icon: "thermostat", key: "showTemp", active: root.showTemp },
                        { label: "Icon", icon: "cloud", key: "showIcon", active: root.showIcon },
                        { label: "Text", icon: "text_fields", key: "showCondition", active: root.showCondition }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: Translation.tr(modelData.label)
                        toggled: modelData.active
                        onClicked: {
                            if (modelData.active && root.visibleContentCount <= 1) return
                            Config.setNestedValue("background.widgets.weather." + modelData.key, !modelData.active)
                        }
                    }
                }
            }
        }
    }

    // Dim factor (0..1)
    property real dimFactor: {
        const v = Config.getNestedValue("background.widgets.weather.dim", 0);
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    // Derived colors per style mode. Dim toward region luminance opposite, not black.
    readonly property color _dimTarget: ColorUtils.contrastColor(root._regionBg)
    readonly property color weatherIconColor: weatherStyle === "pill"
        ? root.shapeInk : ColorUtils.mix(root.widgetAccent, root._dimTarget, dimFactor * 0.35)
    readonly property color weatherConditionColor: weatherStyle === "pill"
        ? ColorUtils.applyAlpha(root.shapeInk, root.conditionOpacity)
        : ColorUtils.applyAlpha(ColorUtils.mix(root.cardInk, root._dimTarget, dimFactor * 0.5), root.conditionOpacity)

    // ── Pill/shape mode ──
    // Soft contact shadow detaches the pill from the wallpaper (shell shadow
    // vocabulary, same edge as every surface). The fill itself goes through
    // ensureVisible so the generated colour stays readable on any wallpaper.
    StyledDropShadow {
        target: pillBackground
        visible: pillBackground.visible && !Appearance.zzzEverywhere
    }

    // zzz: ShapeCanvas (MaterialShape's base) has no stroke/border property, so
    // the pill previously rendered as a flat colour blob with none of zzz's
    // hairline-outline language — the one desktop widget with no zzz edge
    // treatment at all. Fake a hairline stroke with a second, slightly larger
    // shape behind the fill in the hairline colour.
    MaterialShape {
        visible: root.weatherStyle === "pill" && Appearance.zzzEverywhere
        anchors.centerIn: parent
        shape: root.pillShapeEnum
        color: Appearance.zzz.hairlineStrong
        implicitSize: root.shapeSize + Appearance.zzz.borderThick * 2
    }

    MaterialShape {
        visible: root.weatherStyle === "pill" && (Appearance.inirEverywhere || Appearance.angelEverywhere)
        anchors.centerIn: parent
        shape: root.pillShapeEnum
        color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.angel.colCardBorder
        implicitSize: root.shapeSize + 2
    }

    MaterialShape {
        id: pillBackground
        visible: root.weatherStyle === "pill"
        anchors.fill: parent
        shape: root.pillShapeEnum
        color: root.shapeFill
        implicitSize: root.shapeSize
    }

    // ── Card mode ──
    WidgetSurface {
        regionBrightness: root.regionBrightness
        id: cardBackground
        visible: root.weatherStyle === "card"
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: Math.max(root.backgroundOpacity, 0.16)
        surfaceBorderWidth: Math.max(root.borderWidth, 1)
        surfaceBorderOpacity: Math.max(root.borderOpacity, 0.12)
        surfaceColor: root.cardInk
        surfaceAccent: root.widgetAccent
        surfaceUseBlur: root.useBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
    }

    Item {
        anchors.fill: parent
        opacity: 1.0 - root.dimFactor * 0.6

        MaterialSymbol {
            visible: root.visibleContentCount === 0
            anchors.centerIn: parent
            text: "cloud_off"
            iconSize: Math.round(40 * root.scaleFactor)
            color: root.weatherStyle === "pill" ? root.shapeInk : root.widgetInkMuted
        }

        StyledText {
            visible: root.showTemp
            font {
                pixelSize: root.tempFontSize
                family: Appearance.font.family.expressive
                weight: root.tempFontWeight
            }
            color: root.weatherStyle === "pill" ? root.shapeInk : root.cardInk
            text: Weather.data?.temp.substring(0,Weather.data?.temp.length - 1) ?? "--°"
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: root.weatherPadding
                topMargin: Math.round(root.weatherPadding * 1.2)
            }
        }

        MaterialSymbol {
            visible: root.showIcon
            iconSize: root.weatherIconSize
            color: root.weatherIconColor
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: root.weatherPadding
                bottomMargin: Math.round(root.weatherPadding * 1.2)
            }
        }

        StyledText {
            visible: root.showCondition
            font {
                pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                family: Appearance.font.family.main
            }
            color: root.weatherConditionColor
            text: Weather.data?.weatherDescription ?? ""
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Math.round(root.weatherPadding * 0.4)
            }
        }
    }
}
