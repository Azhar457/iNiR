import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "clock"
    defaultConfig: ({
        placementStrategy: "leastBusy", style: "cookie",
        fontFamily: "Space Grotesk", timeFormat: "system",
        showSeconds: false, showDate: true, dateStyle: "long",
        timeScale: 100, dateScale: 100, showShadow: true, dim: 70,
        "digital.adaptToWallpaper": true,
        "digital.animateChange": true, "digital.fontWeight": 600,
        "digital.spacing": 6, "digital.preset": "default",
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto",
        x: 100, y: 100
    })

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth
    // Digital mode resizes via timeScale, cookie via cookie.size — avoids scaleFactor churn
    resizableAxes: root.clockStyle === "cookie" ? ({ uniform: "cookie.size" }) : ({ uniform: "timeScale" })
    resizeMinWidth: 80
    resizeMinHeight: 40

    editPopoverContent: Component {
        Column {
            spacing: 6
            GridLayout {
                columns: 2
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { label: "Digital", icon: "digital_out_of_home", value: "digital" },
                        { label: "Cookie", icon: "circle", value: "cookie" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.clockStyle === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.clock.style", modelData.value)
                    }
                }
            }
            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                visible: root.clockStyle === "digital"
                Repeater {
                    model: [
                        { label: "System", icon: "settings", value: "system" },
                        { label: "24h", icon: "schedule", value: "24h" },
                        { label: "12h", icon: "nest_clock_farsight_analog", value: "12h" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.timeFormat === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.clock.timeFormat", modelData.value)
                    }
                }
            }
        }
    }

    property string clockStyle: Config.getNestedValue("background.widgets.clock.style", "cookie")
    property bool adaptDigitalToWallpaper: Config.getNestedValue("background.widgets.clock.digital.adaptToWallpaper", true)
    property bool forceCenter: (GlobalStates.screenLocked && (Config.options?.lock?.centerClock ?? false))
    property bool wallpaperSafetyTriggered: false
    property bool debugRegionActive: false
    property color debugRegionColor: "transparent"
    property real debugRegionBrightness: -1
    property real debugRegionSpread: 0
    property string cookieDiagnostics: "{}"
    needsColText: root.clockStyle === "digital" && (root.adaptDigitalToWallpaper || root.widgetHasSurface)
    liveColorTracking: root.clockStyle === "digital" && root.adaptDigitalToWallpaper && !root.widgetHasSurface
    visibleWhenLocked: true

    // --- Clock customization config ---
    property string clockFontFamily: Config.getNestedValue("background.widgets.clock.fontFamily", "Space Grotesk")
    property string timeFormat: Config.getNestedValue("background.widgets.clock.timeFormat", "system")
    property bool showSeconds: Config.getNestedValue("background.widgets.clock.showSeconds", false)
    property bool showDate: Config.getNestedValue("background.widgets.clock.showDate", true)
    property string dateStyle: Config.getNestedValue("background.widgets.clock.dateStyle", "long")
    property int timeScale: Config.getNestedValue("background.widgets.clock.timeScale", 100)
    property int dateScale: Config.getNestedValue("background.widgets.clock.dateScale", 100)
    property bool showShadow: Config.getNestedValue("background.widgets.clock.showShadow", true)
    property int digitalFontWeight: Config.getNestedValue("background.widgets.clock.digital.fontWeight", 600)
    property int digitalSpacing: Config.getNestedValue("background.widgets.clock.digital.spacing", 6)

    // ── Accent colors ── from the shared desktop-widget identity (AbstractBackgroundWidget)
    // so the clock reads as the same family as weather/sysmon/etc., wallpaper-generated.
    readonly property color accentPrimary: root.widgetAccent
    readonly property color accentSecondary: root.widgetAccent2
    readonly property color accentTertiary: root.widgetAccent3
    // One semantic palette for both renderers. Global-style dispatch already
    // happens in Appearance; ZZZ must keep its primary-container sticker face,
    // not fall back to the near-black chrome used by rectangular plates.
    readonly property color cookieFace: Appearance.colors.colPrimaryContainer
    readonly property color cookieBaseInk: Appearance.zzzEverywhere
        ? Appearance.zzz.onAccent : Appearance.colors.colOnPrimaryContainer
    function readableClockColor(candidate: color, backdrop: color, minContrast: real): color {
        const source = Qt.color(candidate);
        if (ColorUtils.contrastRatio(source, backdrop) >= minContrast)
            return source;
        for (let step = 1; step <= 20; step++) {
            const distance = step * 0.04;
            const darker = Qt.hsla(source.hslHue, source.hslSaturation,
                Math.max(0, source.hslLightness - distance), source.a);
            const lighter = Qt.hsla(source.hslHue, source.hslSaturation,
                Math.min(1, source.hslLightness + distance), source.a);
            const darkRatio = ColorUtils.contrastRatio(darker, backdrop);
            const lightRatio = ColorUtils.contrastRatio(lighter, backdrop);
            if (darkRatio >= minContrast || lightRatio >= minContrast)
                return darkRatio >= minContrast ? darker : lighter;
        }
        return ColorUtils.contrastColor(backdrop);
    }
    function supportingOnFace(strongInk: color, face: color): color {
        for (let weight = 0.72; weight <= 1.001; weight += 0.04) {
            const candidate = ColorUtils.mix(strongInk, face, weight);
            if (ColorUtils.contrastRatio(candidate, face) >= 4.5)
                return candidate;
        }
        return strongInk;
    }
    // Hands sit on the cookie FACE — clamp against it, not the wallpaper.
    readonly property color handPrimary: root.readableClockColor(
        ColorUtils.adaptAccent(root.accentPrimary, root.cookieFace), root.cookieFace, 3.0)
    readonly property color handTertiary: root.readableClockColor(
        ColorUtils.adaptAccent(root.accentTertiary, root.cookieFace), root.cookieFace, 3.0)
    // Marks/numbers use the strong on-face ink. Supporting information remains
    // solid (not alpha-composited) so small text keeps an AA contrast floor.
    readonly property color cookieInk: root.readableClockColor(
        root.cookieBaseInk,
        root.cookieFace,
        4.5)
    readonly property color cookieInfo: root.supportingOnFace(root.cookieInk, root.cookieFace)

    // Local clock with seconds precision when needed (and power is active)
    SystemClock {
        id: displayClock
        // Drop to minutes precision when power is reduced to save CPU
        precision: (root.showSeconds || GlobalStates.screenLocked) && root.powerActive
            ? SystemClock.Seconds : SystemClock.Minutes
    }

    // --- Resolved format patterns (reactive) ---
    property string _timePattern: {
        const fmt = root.timeFormat;
        const sec = root.showSeconds;
        if (fmt === "24h") return sec ? "HH:mm:ss" : "HH:mm";
        if (fmt === "12h") return sec ? "hh:mm:ss AP" : "hh:mm AP";
        // "system" — use global config format, smart seconds append
        const base = Config.options?.time?.format ?? "hh:mm";
        if (sec && !base.includes("s")) {
            const apIdx = base.indexOf(" AP");
            if (apIdx >= 0) return base.slice(0, apIdx) + ":ss" + base.slice(apIdx);
            return base + ":ss";
        }
        return base;
    }
    property string _datePattern: {
        const style = root.dateStyle;
        if (style === "weekday") return "dddd";
        if (style === "numeric") return Config.options?.time?.shortDateFormat ?? "dd/MM";
        if (style === "minimal") return "ddd, d MMM";
        // "long" or default
        return Config.options?.time?.dateFormat ?? "dddd, dd/MM";
    }

    property string timeText: Qt.locale().toString(displayClock.date, root._timePattern)
    property string dateText: Qt.locale().toString(displayClock.date, root._datePattern)

    Binding {
        target: root
        property: "x"
        value: (root.screenWidth - root.width) / 2
        when: root.forceCenter
    }
    Binding {
        target: root
        property: "y"
        value: (root.screenHeight - root.height) / 2
        when: root.forceCenter
    }

    property var textHorizontalAlignment: {
        if (root.forceCenter)
            return Text.AlignHCenter;
        if (root.x < root.scaledScreenWidth / 3)
            return Text.AlignLeft;
        if (root.x > root.scaledScreenWidth * 2 / 3)
            return Text.AlignRight;
        return Text.AlignHCenter;
    }

    // ── Style tokens ──
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    // Per-clock dim factor (0..1), independent from wallpaper dim
    property real dimFactor: {
        const v = Config.getNestedValue("background.widgets.clock.dim", 0);
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    // What the digital text actually sits on: the card plate when one renders,
    // the analyzed wallpaper region otherwise (theme surface until the analysis
    // lands, so nothing re-tones on first paint).
    readonly property bool _digitalCard: root.clockStyle === "digital" && root.widgetHasSurface
    readonly property bool _digitalHasBrightness: root.debugRegionActive
        ? root.debugRegionBrightness >= 0 : root._hasBrightness
    readonly property color _digitalRegionColor: root.debugRegionActive
        ? root.debugRegionColor : root.dominantColor
    readonly property real _digitalRegionBrightness: root.debugRegionActive
        ? root.debugRegionBrightness : root.regionBrightness
    readonly property color _digitalRegionBg: {
        const dominant = Qt.color(root._digitalRegionColor);
        if (!root._digitalHasBrightness) return dominant;
        return Qt.hsla(dominant.hslHue, dominant.hslSaturation,
            root._digitalRegionBrightness, 1.0);
    }
    readonly property color _inkBackdrop: root._digitalCard ? root.widgetPlateColor
        : root._digitalHasBrightness ? root._digitalRegionBg
        : Appearance.colors.colLayer0
    readonly property color _digitalBackdrop: root.adaptDigitalToWallpaper
        ? root._inkBackdrop : Appearance.colors.colLayer0
    // Effective text color for clock based on palette + dim.
    // Dim toward the luminance opposite of the ACTUAL backdrop (card plate or
    // wallpaper region — dimming away from the region while sitting on a plate
    // that opposes the region walked text INTO the plate's tone) so the text
    // keeps its hue character while becoming less prominent. That mix also
    // drains chroma, which left the clock reading grey next to the other
    // widgets' accents — restore the base's saturation so dim only costs
    // lightness. No-op for achromatic bases (the colText path).
    function dimmed(base, backdrop) {
        if (dimFactor <= 0) return base;
        const target = ColorUtils.contrastColor(backdrop ?? root._inkBackdrop);
        const faded = Qt.color(ColorUtils.mix(base, target, 1 - dimFactor * 0.22));
        const source = Qt.color(base);
        return Qt.hsla(source.hslHue, source.hslSaturation,
            faded.hslLightness, source.a);
    }

    // Retain most of the Cookie role while borrowing enough hue/chroma from the
    // local wallpaper region for movement to be visible even when two regions
    // share the same brightness. Lightness is kept until the contrast clamp.
    function regionalCookieColor(base: color, cookieWeight: real): color {
        const source = Qt.color(base);
        const region = Qt.color(root._digitalRegionColor);
        if (!region.valid || region.hslSaturation < 0.04)
            return source;
        const localSaturation = Math.max(source.hslSaturation,
            Math.min(0.72, region.hslSaturation * 0.72));
        const localRole = Qt.hsla(region.hslHue, localSaturation,
            source.hslLightness, source.a);
        return ColorUtils.mix(source, localRole, cookieWeight);
    }

    // Digital borrows the Cookie's ink and hand character, never its face fill.
    function digitalColor(base: color, cookieWeight: real, minContrast: real): color {
        const displayed = root.adaptDigitalToWallpaper
            ? root.regionalCookieColor(base, cookieWeight) : base;
        const dimmedColor = root.dimmed(displayed, root._digitalBackdrop);
        return root.readableClockColor(dimmedColor, root._digitalBackdrop, minContrast);
    }
    readonly property color digitalTimeBase: ColorUtils.mix(root.cookieInk, root.handPrimary, 0.84)
    readonly property color digitalStatusBase: ColorUtils.mix(root.cookieInk, root.handPrimary, 0.78)
    readonly property color digitalTimeColor: root.digitalColor(root.digitalTimeBase, 0.78, 4.5)
    readonly property color digitalDateColor: root.digitalColor(root.cookieInfo, 0.84, 4.5)
    readonly property color digitalMetaColor: root.digitalColor(root.cookieInfo, 0.88, 4.5)
    readonly property color digitalStatusColor: root.digitalColor(root.digitalStatusBase, 0.82, 4.5)

    readonly property string debugPaletteReport: JSON.stringify({
        style: root.clockStyle,
        globalStyle: Appearance.globalStyle,
        adaptive: root.adaptDigitalToWallpaper,
        region: {
            injected: root.debugRegionActive,
            dominant: String(root._digitalRegionColor),
            regionBackdrop: String(root._inkBackdrop),
            displayBackdrop: String(root._digitalBackdrop),
            brightness: root._digitalRegionBrightness
        },
        cookie: {
            face: String(root.cookieFace),
            ink: String(root.cookieInk),
            info: String(root.cookieInfo),
            hourHand: String(root.handPrimary),
            minuteHand: String(root.handTertiary),
            inkContrast: ColorUtils.contrastRatio(root.cookieInk, root.cookieFace),
            infoContrast: ColorUtils.contrastRatio(root.cookieInfo, root.cookieFace),
            renderer: root.cookieDiagnostics
        },
        digital: {
            time: String(root.digitalTimeColor),
            date: String(root.digitalDateColor),
            quote: String(root.digitalMetaColor),
            status: String(root.digitalStatusColor),
            timeContrast: ColorUtils.contrastRatio(root.digitalTimeColor, root._digitalBackdrop),
            dateContrast: ColorUtils.contrastRatio(root.digitalDateColor, root._digitalBackdrop),
            quoteContrast: ColorUtils.contrastRatio(root.digitalMetaColor, root._digitalBackdrop),
            statusContrast: ColorUtils.contrastRatio(root.digitalStatusColor, root._digitalBackdrop)
        }
    })

    // Card background (mainly for digital mode)
    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        anchors.margins: -Math.round(8 * root.scaleFactor)
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.colText
        surfaceAccent: root.widgetAccent
        surfaceUseBlur: root.useBlur
        screenX: root.x + Math.round(8 * root.scaleFactor)
        screenY: root.y + Math.round(8 * root.scaleFactor)
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: (root.backgroundOpacity > 0 || root.borderWidth > 0) && root.clockStyle === "digital"
    }

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: Math.round(6 * root.scaleFactor)

        FadeLoader {
            id: cookieClockLoader
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.clockStyle === "cookie"
            sourceComponent: Column {
                CookieClock {
                    anchors.horizontalCenter: parent.horizontalCenter
                    scaleFactor: root.scaleFactor
                    colBackground: root.cookieFace
                    colOnBackground: root.cookieInk
                    colBackgroundInfo: root.cookieInfo
                    colHourHand: root.handPrimary
                    colMinuteHand: root.handTertiary
                    colSecondHand: root.cookieInk
                    onDiagnosticReportChanged: root.cookieDiagnostics = diagnosticReport
                }
                FadeLoader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    shown: (Config.getNestedValue("background.widgets.clock.quote.enable", false))
                        && (Config.getNestedValue("background.widgets.clock.quote.text", "")) !== ""
                    sourceComponent: CookieQuote {}
                }
            }
        }

        FadeLoader {
            id: digitalClockLoader
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.clockStyle === "digital"
            sourceComponent: ColumnLayout {
                id: clockColumn
                spacing: Math.round(root.digitalSpacing * root.scaleFactor)

                ClockText {
                    color: root.digitalTimeColor
                    font.pixelSize: Math.round(90 * Appearance.fontSizeScale * root.timeScale / 100 * root.scaleFactor)
                    text: root.timeText
                }
                ClockText {
                    visible: root.showDate
                    color: root.digitalDateColor
                    Layout.topMargin: Math.round(-5 * root.scaleFactor)
                    font.pixelSize: Math.round(20 * root.dateScale / 100 * root.scaleFactor)
                    text: root.dateText
                }
                StyledText {
                    // Somehow gets fucked up if made a ClockText???
                    visible: (Config.getNestedValue("background.widgets.clock.quote.enable", false))
                        && (Config.getNestedValue("background.widgets.clock.quote.text", "")).length > 0
                    Layout.fillWidth: true
                    horizontalAlignment: root.textHorizontalAlignment
                    font {
                        pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                        weight: 350
                    }
                    color: root.digitalMetaColor
                    style: root.showShadow ? Text.Raised : Text.Normal
                    styleColor: root.colHalo
                    text: Config.getNestedValue("background.widgets.clock.quote.text", "")
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.standardDecel
                        }
                    }
                }
            }
        }
        Item {
            id: statusText
            anchors.horizontalCenter: parent.horizontalCenter
            implicitHeight: statusTextBg.implicitHeight
            implicitWidth: statusTextBg.implicitWidth
            StyledRectangularShadow {
                target: statusTextBg
                visible: statusTextBg.visible && root.clockStyle === "cookie"
                opacity: statusTextBg.opacity
            }
            Rectangle {
                id: statusTextBg
                anchors.centerIn: parent
                clip: true
                opacity: (safetyStatusText.shown || lockStatusText.shown) ? 1 : 0
                visible: opacity > 0
                implicitHeight: statusTextRow.implicitHeight + 5 * 2
                implicitWidth: statusTextRow.implicitWidth + 5 * 2
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(root.cookieFace, root.clockStyle === "cookie" ? 0 : 1)

                Behavior on implicitWidth {
                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                }
                Behavior on implicitHeight {
                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                }
                Behavior on opacity {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                RowLayout {
                    id: statusTextRow
                    anchors.centerIn: parent
                    spacing: 14
                    Item {
                        Layout.fillWidth: root.textHorizontalAlignment !== Text.AlignLeft
                        implicitWidth: 1
                    }
                    ClockStatusText {
                        id: safetyStatusText
                        shown: root.wallpaperSafetyTriggered
                        statusIcon: "hide_image"
                        statusText: Translation.tr("Wallpaper safety enforced")
                    }
                    ClockStatusText {
                        id: lockStatusText
                        shown: GlobalStates.screenLocked && (Config.options?.lock?.showLockedText ?? false)
                        statusIcon: "lock"
                        statusText: Translation.tr("Locked")
                    }
                    Item {
                        Layout.fillWidth: root.textHorizontalAlignment !== Text.AlignRight
                        implicitWidth: 1
                    }
                }
            }
        }
    }

    component ClockText: StyledText {
        Layout.fillWidth: true
        horizontalAlignment: root.textHorizontalAlignment
        font {
            family: root.clockFontFamily
            pixelSize: 20
            weight: root.digitalFontWeight
        }
        color: root.digitalTimeColor
        style: root.showShadow ? Text.Raised : Text.Normal
        styleColor: root.colHalo
        animateChange: Config.getNestedValue("background.widgets.clock.digital.animateChange", false)
        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
        }
    }
    component ClockStatusText: Row {
        id: statusTextRow
        property alias statusIcon: statusIconWidget.text
        property alias statusText: statusTextWidget.text
        property bool shown: true
        // Cookie status sits on the same face plate; digital status sits directly
        // on the wallpaper and therefore uses its own adapted supporting role.
        property color textColor: root.clockStyle === "cookie"
            ? root.cookieInk : root.digitalStatusColor
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        spacing: 4
        MaterialSymbol {
            id: statusIconWidget
            anchors.verticalCenter: statusTextRow.verticalCenter
            iconSize: Appearance.font.pixelSize.huge
            color: statusTextRow.textColor
            style: root.showShadow ? Text.Raised : Text.Normal
            styleColor: root.colHalo
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.standardDecel
                }
            }
        }
        ClockText {
            id: statusTextWidget
            color: statusTextRow.textColor
            anchors.verticalCenter: statusTextRow.verticalCenter
            font {
                pixelSize: Appearance.font.pixelSize.large
                weight: Font.Normal
            }
            style: root.showShadow ? Text.Raised : Text.Normal
            styleColor: root.colHalo
        }
    }
}
