import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property int currentIndex: 0
    property int totalCount: 0
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3
    property bool paintMaterialPill: false
    property real padding: (root.isMaterial && !root.paintMaterialPill) ? 0 : 5
    property color bgColor: M3Palette.primaryContainer
    property bool spectrumEnabled: false
    property var spectrumPoints: []
    property real spectrumCeiling: 1000
    property string spectrumType: "bars"
    property real spectrumOpacity: 0.35
    property real spectrumFillRatio: 0.6
    property string spectrumBarsOrigin: "bottom"
    property real spectrumDensity: 12
    property real spectrumGap: 2
    property int spectrumSmoothing: 2
    property string spectrumWaveMode: "fill"
    property real spectrumLineWidth: 2
    property real spectrumEdgeInset: 0
    property real spectrumEdgeSoftness: 0.28
    property string spectrumFrequencyProfile: "flat"
    property real spectrumAccentStrength: 0.7
    property Item spectrumDomain: null

    readonly property real fullRadius: height / 2
    readonly property real midRadius: Config.options.bar.m3.cornerStyle === 2 ? Appearance.rounding.unsharpenmore + 2 : Appearance.rounding.unsharpenmore
    property real startRadius: {
        if (totalCount <= 1) return fullRadius;
        if (currentIndex === 0) return fullRadius;
        return midRadius;
    }
    property real endRadius: {
        if (totalCount <= 1) return fullRadius;
        if (currentIndex === totalCount - 1) return fullRadius;
        return midRadius;
    }

    implicitWidth: vertical && root.isMaterial ? Appearance.sizes.baseVerticalBarWidth - 6 : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight

    default property alias items: gridLayout.children

    readonly property real _spectrumX: {
        const geometryDependency = root.x + root.y + root.width + root.height
            + (root.parent?.x ?? 0) + (root.parent?.width ?? 0)
        if (!root.spectrumDomain || !(root.spectrumDomain.width > 0))
            return 0
        return root.mapToItem(root.spectrumDomain, 0, 0).x
    }

    Rectangle {
        id: background
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        color: !(Config.options?.bar?.m3?.showBackground ?? true)
            ? "transparent"
            : (root.isMaterial && !root.paintMaterialPill)
                ? "transparent"
                : (root.isMaterial && root.paintMaterialPill)
                    ? root.bgColor
                    : (Config.options?.bar.m3.borderless === "transparent"
                        ? "transparent"
                        : Config.options.bar.m3.cornerStyle === 2
                        ? M3Palette.surface
                        : M3Palette.surfaceContainerLow)
        border.width: root.isMaterial && root.paintMaterialPill
            && (Config.options?.bar?.m3?.borderless ?? "pills") === "separated" ? 1 : 0
        border.color: M3Palette.outlineVariant

        topLeftRadius: (root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (Config.options?.bar.m3.borderless === "separated" ? root.fullRadius : root.startRadius)
        bottomLeftRadius: (root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (Config.options?.bar.m3.borderless === "separated" ? root.fullRadius : root.vertical ? root.endRadius : root.startRadius)
        topRightRadius: (root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (Config.options?.bar.m3.borderless === "separated" ? root.fullRadius : root.vertical ? root.startRadius : root.endRadius)
        bottomRightRadius: (root.isMaterial && root.paintMaterialPill) ? root.fullRadius : (Config.options?.bar.m3.borderless === "separated" ? root.fullRadius : root.endRadius)

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        CavaSpectrum {
            anchors.fill: parent
            active: root.spectrumEnabled
                && root.isMaterial
                && root.paintMaterialPill
                && (Config.options?.bar?.m3?.borderless ?? "separated") === "separated"
            points: root.spectrumPoints
            normalizationCeiling: root.spectrumCeiling
            visualizerType: root.spectrumType
            spectrumOpacity: root.spectrumOpacity
            fillRatio: root.spectrumFillRatio
            spectrumColor: M3Palette.primary
            sampleStartRatio: root.spectrumDomain && root.spectrumDomain.width > 0
                ? Math.max(0, Math.min(1, root._spectrumX / root.spectrumDomain.width)) : 0
            sampleEndRatio: root.spectrumDomain && root.spectrumDomain.width > 0
                ? Math.max(sampleStartRatio,
                    Math.min(1, (root._spectrumX + root.width) / root.spectrumDomain.width)) : 1
            barsOrigin: root.spectrumBarsOrigin
            pixelsPerBar: root.spectrumDensity
            barSpacing: root.spectrumGap
            smoothing: root.spectrumSmoothing
            waveMode: root.spectrumWaveMode
            lineWidth: root.spectrumLineWidth
            edgeInset: root.spectrumEdgeInset
            edgeSoftness: root.spectrumEdgeSoftness
            frequencyProfile: root.spectrumFrequencyProfile
            accentStrength: root.spectrumAccentStrength
            topLeftRadius: background.topLeftRadius
            topRightRadius: background.topRightRadius
            bottomLeftRadius: background.bottomLeftRadius
            bottomRightRadius: background.bottomRightRadius
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors.centerIn: parent
        columnSpacing: 0
        rowSpacing: 0
    }
}
