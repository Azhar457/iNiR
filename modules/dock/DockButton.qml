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
    // Square by construction, so the face stays organic. The dock paints no
    // resting background, which leaves the hover state as the cookie face —
    // and the pill/macOS styles hide `background` outright, so they are unaffected.
    cookieMorphing: true
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

    // Single zzz tile for every dock button. Subclasses tune it through these
    // properties instead of stacking a second ZzzPlate on top — two plates over
    // the same rect draw two strokes with different corner geometry, which read
    // as a doubled border on hover.
    // Dock tiles are small: controlRadius in round mode (a clean rounded chip),
    // NOT the big panelRadius (ZzzPlate's default) which over-rounds into a blob.
    property bool zzzPlateVisible: Appearance.zzzEverywhere
    property real zzzPlateRadius: Appearance.zzz.round ? Appearance.zzz.controlRadius : 0
    property real zzzPlateChamfer: Appearance.zzz.cutCorner * (root.buttonHovered ? 0.85 : 0.45)
    property color zzzPlateFill: root.buttonHovered ? ColorUtils.applyAlpha(Appearance.zzz.paper, 0.14) : "transparent"
    property color zzzPlateStroke: root.buttonHovered ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.55) : "transparent"

    ZzzPlate {
        anchors.fill: parent
        visible: root.zzzPlateVisible
        radius: root.zzzPlateRadius
        chamfer: root.zzzPlateChamfer
        fillColor: root.zzzPlateFill
        strokeColor: root.zzzPlateStroke
        strokeWidth: Appearance.zzz.borderThick
        z: -1
    }
}
