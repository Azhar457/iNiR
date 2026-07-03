import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

// Style-aware widget background surface.
// Adapts to the active ii style: blur for aurora/angel, border-only for inir, solid for material.
// Parent widget must set screenX/screenY for correct blur alignment.
Rectangle {
    id: root

    property real screenX: 0
    property real screenY: 0
    property real screenWidth: 1920
    property real screenHeight: 1080

    // Widget customization passthrough
    property real surfaceOpacity: 0.06
    property real surfaceBorderWidth: 1
    property real surfaceBorderOpacity: 0.08
    property color surfaceColor: Appearance.colors.colOnLayer0
    // The widget's accent identity (usually root.widgetAccent) — gives the plate
    // an actual color seat instead of a neutral wallpaper-luminance scrim.
    property color surfaceAccent: Appearance.colors.colPrimary
    property real surfaceRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
    // Allows per-widget blur override. When false, blur is disabled even if the
    // active style (aurora/angel) supports it. Lets users get a flat,
    // non-blurred resources widget while keeping a frosted-glass clock, etc.
    property bool surfaceUseBlur: true

    // Power management: when false, disable expensive blur operations.
    // Parent widgets should bind this to their powerActive property.
    property bool powerActive: WidgetPowerManager.widgetsActive

    readonly property bool _angel: Appearance.angelEverywhere
    readonly property bool _aurora: Appearance.auroraEverywhere && !Appearance.inirEverywhere
    readonly property bool _inir: Appearance.inirEverywhere
    readonly property bool _zzz: Appearance.zzzEverywhere
    readonly property bool _glass: (_aurora || _angel) && Appearance.effectsEnabled && root.surfaceUseBlur
    readonly property string _wallpaperUrl: Wallpapers.effectiveWallpaperUrl

    // Wallpaper region brightness behind the widget (0-1; -1 = unknown).
    // Parent widgets bind their own regionBrightness so the plate opposes the
    // wallpaper: near-black on bright regions, theme container on dark ones.
    property real regionBrightness: -1
    readonly property bool _regionBright: regionBrightness >= 0
        ? regionBrightness > 0.55
        : !Appearance.m3colors.darkmode

    // A widget surface is a Material container, not another wallpaper sample.
    // Keep the generated hue while preserving a predictable surface/on-surface
    // relationship. Accent belongs to active data and icons, not to the whole card.
    readonly property color _plateDark: {
        const p = Qt.color(Appearance.colors.colPrimary);
        return Qt.hsla(p.hslHue, Math.min(0.22, p.hslSaturation), 0.11, 1.0);
    }
    // Always the near-black plate: theme-light fills read as white cards on
    // bright wallpapers (maintainer call — black plate everywhere).
    readonly property color _flatFill: ColorUtils.applyAlpha(_plateDark, Math.min(0.96, 0.72 + surfaceOpacity * 0.24))

    radius: surfaceRadius
    color: _glass ? "transparent"
        : _zzz ? "transparent"
        : _inir ? "transparent"
        : surfaceOpacity > 0 ? _flatFill : "transparent"
    border.width: 0
    border.color: "transparent"
    clip: true

    ZzzPlate {
        anchors.fill: parent
        visible: root._zzz
        // ZZZ separates by FILL contrast, not outlines (maintainer design law:
        // bright edge strokes read as accent borders on every card). But the
        // per-widget showBackground/showBorder toggles still apply —
        // INDEPENDENTLY, so "border only" (transparent fill + hairline) is
        // reachable like material. Before this, ZzzPlate always filled with
        // paper, so toggling Border read as adding a background plate.
        fillColor: root.surfaceOpacity > 0
            ? ColorUtils.applyAlpha(Appearance.zzz.paper, Math.min(1.0, 0.70 + root.surfaceOpacity * 0.30))
            : "transparent"
        // ZZZ hairline is subtle by design (plates separate by FILL, not
        // outlines). Respect the per-widget borderOpacity so the slider works in
        // zzz too, but cap at 0.5 so it never becomes a loud accent border.
        strokeColor: ColorUtils.applyAlpha(Appearance.zzz.onColor, Math.max(0.06, Math.min(0.5, root.surfaceBorderOpacity * 1.4)))
        strokeWidth: root.surfaceBorderWidth > 0 ? Appearance.zzz.hairlineThick : 0
        chamfer: Appearance.zzz.cutCorner
        radius: Appearance.zzz.round ? root.radius : 0
    }

    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.width {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    // Separate border overlay — avoids Qt's interior bleed when border.width > 0 on a transparent Rectangle
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        visible: !root._glass && !root._zzz && root.surfaceBorderWidth > 0 && root.surfaceBorderOpacity > 0
        border.width: root.surfaceBorderWidth
        border.color: root._inir
            ? ColorUtils.applyAlpha(Appearance.inir.colBorder, root.surfaceBorderOpacity * 3)
            : ColorUtils.applyAlpha(
                ColorUtils.ensureReadable(Appearance.colors.colPrimary, root._flatFill, 3),
                Math.max(0.18, root.surfaceBorderOpacity * 2))
    }

    // Removed: the ZZZ accent registration tick. Every fix to keep it inside
    // the rounded/chamfered corner still read as visual clutter across every
    // desktop widget at once — removed outright per explicit request instead
    // of iterating on its geometry again.

    // Blur layer for aurora/angel
    layer.enabled: _glass
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    Image {
        id: blurredWallpaper
        x: -root.screenX
        y: -root.screenY
        width: root.screenWidth
        height: root.screenHeight
        // Don't load/blur when the compositor is already blurring underneath.
        // Each WidgetSurface keeps its own FBO when layer.enabled is true; with
        // many widgets enabled this multiplies fast. See #159.
        visible: root._glass && !Appearance.compositorBlurActive && status === Image.Ready
        source: (root._glass && !Appearance.compositorBlurActive) ? root._wallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        sourceSize.width: root.screenWidth
        sourceSize.height: root.screenHeight

        // OPTIMIZATION: Release FBO when widget is not visible or power is off
        layer.enabled: root._glass && !Appearance.compositorBlurActive && root.visible && root.powerActive
        layer.effect: MultiEffect {
            source: blurredWallpaper
            anchors.fill: source
            saturation: root._angel
                ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                : 0.15
            blurEnabled: true
            blurMax: 64
            blur: root._angel ? Appearance.angel.blurIntensity : 0.8
        }
    }

    // Tinted overlay for aurora/angel
    Rectangle {
        anchors.fill: parent
        visible: root._glass
        color: root._angel
            ? ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
            : ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.aurora.popupTransparentize * 1.2)
    }

    // Inset glow — angel only
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Appearance.angel.insetGlowHeight
        visible: root._angel
        color: Appearance.angel.colInsetGlow
    }

    // Partial border — angel only
    AngelPartialBorder {
        visible: root._angel
        targetRadius: root.radius
    }

    // Inir subtle fill
    Rectangle {
        anchors.fill: parent
        visible: root._inir && root.surfaceOpacity > 0
        radius: root.radius
        color: ColorUtils.applyAlpha(root._plateDark, Math.min(0.96, 0.72 + root.surfaceOpacity * 0.24))
    }
}
