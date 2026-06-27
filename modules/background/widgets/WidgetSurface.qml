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

    // Wallpaper-derived hue so the desktop widgets actually carry the generated
    // colour per style instead of a near-neutral text tint. Same derivation as
    // Appearance.wallpaperDominantColor blended toward the primary container.
    readonly property color _wallpaperTint: ColorUtils.mix(Appearance.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.6)
    // Tinted plate fill for the flat (material/cards) branch: blend the neutral
    // surfaceColor toward the wallpaper hue and lift the alpha a little so the
    // colour reads on the desktop. zzz (carbon) and inir (restraint) opt out.
    readonly property color _flatFill: ColorUtils.applyAlpha(ColorUtils.mix(surfaceColor, _wallpaperTint, 0.62), Math.min(0.85, surfaceOpacity * 2.2))

    radius: surfaceRadius
    color: _glass ? "transparent"
        : _zzz ? Appearance.zzz.paper
        : _inir ? "transparent"
        : surfaceOpacity > 0 ? _flatFill : "transparent"
    border.width: _zzz ? Appearance.zzz.borderThick : 0
    border.color: _zzz ? Appearance.zzz.hairline : "transparent"
    clip: true

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
            : ColorUtils.applyAlpha(root.surfaceColor, root.surfaceBorderOpacity)
    }

    // ZZZ accent registration tick on the top-left corner of the widget plate.
    Rectangle {
        anchors { left: parent.left; top: parent.top }
        width: Appearance.zzz.borderThick + 1
        height: Math.min(parent.height * 0.28, 18)
        visible: root._zzz
        color: Appearance.zzz.accent
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

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
        color: ColorUtils.applyAlpha(Appearance.inir.colLayer1, root.surfaceOpacity * 2)
    }
}
