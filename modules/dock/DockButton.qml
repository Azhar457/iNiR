import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    property bool vertical: false
    property string dockPosition: "bottom"

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    implicitWidth: vertical ? (implicitHeight - topInset - bottomInset) : (implicitHeight - topInset - bottomInset)
    implicitHeight: 50
    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.normal

    colBackground: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? "transparent" : "transparent"

    colBackgroundHover: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer0Hover
    colRipple: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.22)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer0Active

    background.implicitHeight: 50
    background.implicitWidth: 50

    ZzzPlate {
        anchors.fill: parent
        visible: Appearance.zzzEverywhere
        chamfer: root.buttonHovered ? Appearance.zzz.cutCorner * 0.85 : Appearance.zzz.cutCorner * 0.45
        fillColor: root.buttonHovered ? ColorUtils.applyAlpha(Appearance.zzz.paper, 0.14) : "transparent"
        strokeColor: root.buttonHovered ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.55) : "transparent"
        strokeWidth: Appearance.zzz.borderThick
        z: -1
    }
}
