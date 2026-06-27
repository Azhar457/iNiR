pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.functions
import qs.services

// Shared ZZZ wallpaper-glass wash. It carries only the blurred wallpaper hue
// and a restrained sheen; the caller still owns the final plate fill/stroke.
Item {
    id: root

    property real maskRadius: 0
    property real chamfer: Appearance.zzz.cutCorner
    property bool chamferTopLeft: false
    property bool chamferTopRight: false
    property bool chamferBottomLeft: false
    property bool chamferBottomRight: false
    property bool glassEnabled: Appearance.zzzEverywhere
        && Appearance.effectsEnabled
        && (Config.options?.appearance?.zzz?.glass ?? true)

    visible: glassEnabled

    layer.enabled: glassEnabled
    layer.effect: GE.OpacityMask {
        maskSource: ZzzPlate {
            width: root.width
            height: root.height
            fillColor: "white"
            radius: root.maskRadius
            chamfer: root.chamfer
            chamferTopLeft: root.chamferTopLeft
            chamferTopRight: root.chamferTopRight
            chamferBottomLeft: root.chamferBottomLeft
            chamferBottomRight: root.chamferBottomRight
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        visible: root.glassEnabled && status === Image.Ready
        opacity: Appearance.zzz.dark ? 0.16 : 0.12
        source: root.glassEnabled ? Wallpapers.effectiveWallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        sourceSize.width: Math.max(1, Math.round(width))
        sourceSize.height: Math.max(1, Math.round(height))

        layer.enabled: root.glassEnabled && root.visible
        layer.effect: MultiEffect {
            source: wallpaper
            anchors.fill: source
            saturation: -0.05
            blurEnabled: true
            blurMax: 64
            blur: 1
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: ColorUtils.applyAlpha(
                    Appearance.zzz.onColor,
                    Appearance.zzz.dark ? 0.045 : 0.03
                )
            }
            GradientStop { position: 0.32; color: "transparent" }
            GradientStop { position: 0.78; color: "transparent" }
            GradientStop {
                position: 1.0
                color: ColorUtils.applyAlpha(
                    Appearance.zzz.bg0,
                    Appearance.zzz.dark ? 0.26 : 0.16
                )
            }
        }
    }
}
