import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell.Services.Notifications

RippleButton {
    id: button
    property string buttonText
    property string urgency

    implicitHeight: 34
    leftPadding: 15
    rightPadding: 15
    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    colBackground: Appearance.zzzEverywhere
        ? (urgency == NotificationUrgency.Critical ? Appearance.zzz.secondary : Appearance.zzz.paperAlt)
        : (urgency == NotificationUrgency.Critical)
        ? Appearance.colors.colSecondaryContainer
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer3
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer4
    colBackgroundHover: Appearance.zzzEverywhere
        ? (urgency == NotificationUrgency.Critical ? ColorUtils.applyAlpha(Appearance.zzz.secondary, 0.88) : ColorUtils.mix(Appearance.zzz.paperAlt, Appearance.zzz.signal, 0.92))
        : (urgency == NotificationUrgency.Critical)
        ? Appearance.colors.colSecondaryContainerHover
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer3Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer4Hover
    colRipple: Appearance.zzzEverywhere
        ? ColorUtils.applyAlpha(urgency == NotificationUrgency.Critical ? Appearance.zzz.secondary : Appearance.zzz.accent, 0.32)
        : (urgency == NotificationUrgency.Critical)
        ? Appearance.colors.colSecondaryContainerActive
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer3Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer4Active

    contentItem: StyledText {
        horizontalAlignment: Text.AlignHCenter
        text: buttonText
        color: Appearance.zzzEverywhere
            ? (urgency == NotificationUrgency.Critical ? Appearance.zzz.onSecondary : Appearance.zzz.ink)
            : (urgency == NotificationUrgency.Critical) ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnSurface
    }
}
