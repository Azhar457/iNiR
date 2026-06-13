import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Shared card surface for dashboard widgets. Optional icon+title header;
 * children land in the inner column. Style-dispatched like the controlPanel
 * section cards.
 */
Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    default property alias content: inner.data

    // Appearance knobs (Settings › Dashboard › Appearance)
    readonly property bool compact: (Config.options?.dashboard?.appearance?.density ?? "comfortable") === "compact"
    readonly property real cardOpacity: Math.max(0.3, Math.min(1, Config.options?.dashboard?.appearance?.cardOpacity ?? 1))
    readonly property bool showTitle: Config.options?.dashboard?.appearance?.showCardTitles ?? true
    readonly property real pad: compact ? 8 : 12

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : inirEverywhere ? Appearance.inir.colText
        : auroraEverywhere ? Appearance.m3colors.m3onSurface
        : Appearance.colors.colOnLayer1
    readonly property color colSubtext: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : inirEverywhere ? Appearance.inir.colPrimary
        : auroraEverywhere ? Appearance.m3colors.m3primary
        : Appearance.colors.colPrimary

    Layout.fillWidth: true
    implicitHeight: contentColumn.implicitHeight + root.pad * 2

    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: {
        const base = Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : inirEverywhere ? Appearance.inir.colLayer1
            : auroraEverywhere ? Appearance.aurora.colSubSurface
            : Appearance.colors.colLayer1
        return root.cardOpacity >= 1 ? base : ColorUtils.applyAlpha(base, root.cardOpacity * base.a)
    }
    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    border.width: Appearance.angelEverywhere ? 0 : (inirEverywhere ? 1 : 0)
    border.color: Appearance.angelEverywhere ? "transparent"
        : inirEverywhere ? Appearance.inir.colBorder : "transparent"

    AngelPartialBorder { targetRadius: root.radius; coverage: 0.45 }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.compact ? 6 : 8

        RowLayout {
            visible: root.title.length > 0 && root.showTitle
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                visible: root.icon.length > 0
                text: root.icon
                iconSize: Appearance.font.pixelSize.larger
                color: root.colAccent
            }
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            id: inner
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
        }
    }
}
