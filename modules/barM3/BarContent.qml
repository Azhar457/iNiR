import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    implicitHeight: Appearance.sizes.barHeight
    width: parent.width
    readonly property real barPadding: 0
    readonly property bool isMaterial: Config.options.bar.m3.cornerStyle === 3
    readonly property real centerPillX: centerPill.x
    readonly property real centerPillWidth: centerPill.width

    readonly property bool trayHasItems: SystemTray.items.values.length > 0

    function filterLayout(layout) {
        if (trayHasItems) return layout
        return layout.filter(name => name !== "sysTray")
    }

    readonly property var effectiveLeftLayout:   filterLayout(Config.options.bar.m3.layouts.leftLayout)
    readonly property var effectiveMiddleLayout: filterLayout(Config.options.bar.m3.layouts.middleLayout)
    readonly property var effectiveRightLayout:  filterLayout(Config.options.bar.m3.layouts.rightLayout)

    function getWidgetUrl(name) {
        if (!name) return "";
        let formattedName = name.charAt(0).toUpperCase() + name.slice(1);
        return Qt.resolvedUrl("./" + formattedName + ".qml");
    }

    function getMirroredForIndex(layout, idx) {
        const prevCount = layout.slice(0, idx).filter(w => w === "visualizer").length
        return prevCount % 2 === 1
    }

    // One cava process for the whole bar. The showcase layout puts a visualizer
    // on each side of the centre, and a per-widget process would have spawned
    // one subprocess per instance for the exact same spectrum.
    readonly property bool wantsVisualizer: root.effectiveLeftLayout.includes("visualizer")
        || root.effectiveMiddleLayout.includes("visualizer")
        || root.effectiveRightLayout.includes("visualizer")
    readonly property bool wantsBackgroundVisualizer: (Config.options?.bar?.visualizer?.enable ?? false)
        && (Config.options?.bar?.m3?.showBackground ?? true)
        && root.visible
    readonly property bool audioPlaying: MprisController.isPlaying || YtMusic.isPlaying
    readonly property real spectrumFillRatio: Math.max(0.1,
        Math.min(1, Config.options?.bar?.visualizer?.height ?? 0.6))
    readonly property real spectrumOpacity: Math.max(0,
        Math.min(1, Config.options?.bar?.visualizer?.opacity ?? 0.35))
    readonly property string spectrumType: Config.options?.bar?.visualizer?.type ?? "bars"
    readonly property string spectrumBarsOrigin: Config.options?.bar?.visualizer?.barsOrigin ?? "bottom"
    readonly property real spectrumDensity: Math.max(4, Config.options?.bar?.visualizer?.density ?? 12)
    readonly property real spectrumGap: Math.max(0, Config.options?.bar?.visualizer?.gap ?? 2)
    readonly property int spectrumSmoothing: Math.max(0, Config.options?.bar?.visualizer?.smoothing ?? 2)
    readonly property string spectrumWaveMode: Config.options?.bar?.visualizer?.waveMode ?? "fill"
    readonly property real spectrumLineWidth: Math.max(1, Config.options?.bar?.visualizer?.lineWidth ?? 2)
    readonly property real spectrumEdgeInset: Math.max(0, Config.options?.bar?.visualizer?.edgeInset ?? 0)
    readonly property real spectrumEdgeSoftness: Math.max(0,
        Math.min(1, (Config.options?.bar?.visualizer?.edgeSoftness ?? 28) / 100))
    readonly property string spectrumFrequencyProfile: Config.options?.bar?.visualizer?.frequencyProfile ?? "flat"
    readonly property real spectrumAccentStrength: Math.max(0,
        Math.min(1, (Config.options?.bar?.visualizer?.accentStrength ?? 70) / 100))
    readonly property bool materialSectionSpectrum: root.isMaterial
        && (Config.options?.bar?.m3?.borderless ?? "separated") === "pills"

    function spectrumStartRatio(item): real {
        if (!item || !(root.width > 0))
            return 0
        return Math.max(0, Math.min(1, item.mapToItem(root, 0, 0).x / root.width))
    }

    function spectrumEndRatio(item): real {
        if (!item || !(root.width > 0))
            return 1
        const start = root.spectrumStartRatio(item)
        return Math.max(start,
            Math.min(1, (item.mapToItem(root, 0, 0).x + item.width) / root.width))
    }

    CavaProcess {
        id: barCava
        active: (root.wantsVisualizer || root.wantsBackgroundVisualizer)
            && root.audioPlaying
        sampleCount: root.wantsBackgroundVisualizer
            ? Math.max(50, Math.round(Math.max(1, root.width) / root.spectrumDensity))
            : 20
    }
    readonly property bool spectrumSignalActive: barCava.audioSignalActive

    component SurfaceSpectrum: CavaSpectrum {
        points: barCava.points
        normalizationCeiling: barCava.normalizationCeiling
        visualizerType: root.spectrumType
        spectrumOpacity: root.spectrumOpacity
        fillRatio: root.spectrumFillRatio
        spectrumColor: Appearance.colors.colPrimary
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
    }

    component SpectrumGroup: BarGroup {
        spectrumEnabled: root.wantsBackgroundVisualizer && root.spectrumSignalActive
        spectrumPoints: barCava.points
        spectrumCeiling: barCava.normalizationCeiling
        spectrumType: root.spectrumType
        spectrumOpacity: root.spectrumOpacity
        spectrumFillRatio: root.spectrumFillRatio
        spectrumBarsOrigin: root.spectrumBarsOrigin
        spectrumDensity: root.spectrumDensity
        spectrumGap: root.spectrumGap
        spectrumSmoothing: root.spectrumSmoothing
        spectrumWaveMode: root.spectrumWaveMode
        spectrumLineWidth: root.spectrumLineWidth
        spectrumEdgeInset: root.spectrumEdgeInset
        spectrumEdgeSoftness: root.spectrumEdgeSoftness
        spectrumFrequencyProfile: root.spectrumFrequencyProfile
        spectrumAccentStrength: root.spectrumAccentStrength
        spectrumDomain: root
    }

    // Every widget is loaded through a URL, so its optional inputs are wired
    // here rather than declared. `sharedPoints` must stay a binding: assigned
    // by value it would freeze on the first spectrum frame.
    function wireWidget(item, layout, idx) {
        if (!item) return
        if (item.hasOwnProperty("spectrumMirrored"))
            item.spectrumMirrored = root.getMirroredForIndex(layout, idx)
        if (item.hasOwnProperty("sharedPoints"))
            item.sharedPoints = Qt.binding(() => barCava.points)
        if (item.hasOwnProperty("sharedCeiling"))
            item.sharedCeiling = Qt.binding(() => barCava.normalizationCeiling)
        if (item.hasOwnProperty("sharedSignalActive"))
            item.sharedSignalActive = Qt.binding(() => barCava.audioSignalActive)
    }

    function shouldPaintMaterialPill(name) {
        if (Config.options?.bar?.m3?.cornerStyle !== 3) return false
        if (!(Config.options?.bar?.m3?.showBackground ?? true)) return false

        const groupStyle = Config.options?.bar?.m3?.borderless ?? "pills"
        if (groupStyle === "transparent") return false
        if (groupStyle === "separated") return name !== "divisor"

        // Preserve the Material hierarchy in joined mode: the section keeps
        // its base capsule while information-rich widgets retain tonal pills.
        const joinedBlacklist = [
            "workspaces", "divisor", "powerButton", "docktoPanel",
            "leftSidebarButton", "activeWindow", "visualizer",
            "notificationUnreadCount"
        ]
        return !joinedBlacklist.includes(name)
    }

    function getMaterialPillColor(name) {
        return M3Palette.pillContainer(name)
    }

    // Edge scroll: the M3 bar honours the same keys as the classic bar, so
    // brightness and volume stay where the user learned them.
    property var brightnessMonitor: Brightness.getMonitorForScreen(root.screen)
    readonly property string leftAction: Config.options?.bar?.leftScrollAction ?? "brightness"
    readonly property string rightAction: Config.options?.bar?.rightScrollAction ?? "volume"

    function performScrollAction(action: string, isUp: bool): void {
        if (action === "brightness") {
            const step = 0.05;
            root.brightnessMonitor?.setBrightness(root.brightnessMonitor.brightness + (isUp ? step : -step));
        } else if (action === "volume") {
            if (isUp) Audio.incrementVolume();
            else Audio.decrementVolume();
        } else if (action === "workspace") {
            let up = isUp;
            if (Config.options?.bar?.workspaces?.invertScroll ?? false) up = !up;

            if (CompositorService.isNiri) {
                if (up) NiriService.focusWorkspaceUp();
                else NiriService.focusWorkspaceDown();
            } else if (CompositorService.isHyprland) {
                Hyprland.dispatch(up ? "workspace r-1" : "workspace r+1");
            }
        }
    }

    function closeOSD(action: string): void {
        if (action === "brightness") GlobalStates.osdBrightnessOpen = false;
        else if (action === "volume") GlobalStates.osdVolumeOpen = false;
    }

    function getScrollIcon(action: string): string {
        if (action === "brightness") return "light_mode";
        if (action === "volume") return "volume_up";
        if (action === "workspace") return "workspaces";
        return "";
    }

    function getScrollTooltip(action: string): string {
        if (action === "brightness") return Translation.tr("Scroll to change brightness");
        if (action === "volume") return Translation.tr("Scroll to change volume");
        if (action === "workspace") return Translation.tr("Scroll to switch workspaces");
        return "";
    }

    property var screen: root.QsWindow.window?.screen
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0


    Rectangle {
        id: barBackground
        anchors.fill: parent
        anchors.margins: Config.options.bar.m3.cornerStyle === 1 ? Config.options.bar.m3.gapsOut : 0
        color: (!centerOnly && Config.options.bar.m3.showBackground && Config.options.bar.m3.cornerStyle !== 2 && !root.isMaterial)
            ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.m3.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: (!centerOnly && Config.options.bar.m3.cornerStyle === 1) ? 1 : 0
        border.color: Appearance.colors.colLayer0Border

        SurfaceSpectrum {
            id: backgroundVisualizer
            anchors.fill: parent
            active: root.wantsBackgroundVisualizer && !root.isMaterial
                && !root.centerOnly && root.spectrumSignalActive
            topLeftRadius: barBackground.radius
            topRightRadius: barBackground.radius
            bottomLeftRadius: barBackground.radius
            bottomRightRadius: barBackground.radius
        }
    }

    // center-only
    readonly property bool centerOnly: !root.isMaterial
        && root.effectiveLeftLayout.length === 0
        && root.effectiveRightLayout.length === 0

    Rectangle {
        id: centerPill
        visible: centerOnly && Config.options.bar.m3.showBackground && Config.options.bar.m3.cornerStyle !== 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: middleRow.implicitWidth + 10
        height: parent.height - (Config.options.bar.m3.cornerStyle === 1 ? Config.options.bar.m3.gapsOut * 2 : 0)
        color: Appearance.colors.colLayer0
        radius: Config.options.bar.m3.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.m3.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border

        bottomLeftRadius:  Config.options.bar.m3.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        bottomRightRadius: Config.options.bar.m3.cornerStyle === 0 && !Config.options.bar.bottom ? Appearance.rounding.screenRounding : radius
        topLeftRadius:     Config.options.bar.m3.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius
        topRightRadius:    Config.options.bar.m3.cornerStyle === 0 && Config.options.bar.bottom  ? Appearance.rounding.screenRounding : radius

        SurfaceSpectrum {
            anchors.fill: parent
            active: root.wantsBackgroundVisualizer && root.centerOnly
                && root.spectrumSignalActive
            topLeftRadius: centerPill.topLeftRadius
            topRightRadius: centerPill.topRightRadius
            bottomLeftRadius: centerPill.bottomLeftRadius
            bottomRightRadius: centerPill.bottomRightRadius
        }
    }

    Item {
        id: contentContainer
        anchors.fill: barBackground
        anchors.margins: root.barPadding

        // Declared before the sections so a widget always wins the click; only
        // the bare bar around them feeds these.
        FocusedScrollMouseArea {
            id: barLeftScrollArea
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: Math.max(0, absoluteCenter.x)

            onScrollDown: root.performScrollAction(root.leftAction, false)
            onScrollUp: root.performScrollAction(root.leftAction, true)
            onMovedAway: root.closeOSD(root.leftAction)

            ScrollHint {
                reveal: barLeftScrollArea.hovered
                    && (Config.options?.bar?.showScrollHints ?? true)
                    && root.leftAction !== "none"
                icon: root.getScrollIcon(root.leftAction)
                tooltipText: root.getScrollTooltip(root.leftAction)
                side: "left"
                anchors.right: parent.right
                anchors.rightMargin: Appearance.sizes.spacingLarge
                anchors.verticalCenter: parent.verticalCenter
                z: 1
            }
        }

        FocusedScrollMouseArea {
            id: barRightScrollArea
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: Math.max(0, parent.width - (absoluteCenter.x + absoluteCenter.width))

            onScrollDown: root.performScrollAction(root.rightAction, false)
            onScrollUp: root.performScrollAction(root.rightAction, true)
            onMovedAway: root.closeOSD(root.rightAction)

            ScrollHint {
                reveal: barRightScrollArea.hovered
                    && (Config.options?.bar?.showScrollHints ?? true)
                    && root.rightAction !== "none"
                icon: root.getScrollIcon(root.rightAction)
                tooltipText: root.getScrollTooltip(root.rightAction)
                side: "right"
                anchors.left: parent.left
                anchors.leftMargin: Appearance.sizes.spacingLarge
                anchors.verticalCenter: parent.verticalCenter
                z: 1
            }
        }

        // Left
        Item {
            anchors.left: parent.left
            anchors.leftMargin: root.isMaterial ? (Config.options.bar.m3.gapsOut || 5) : (Config.options.bar.m3.cornerStyle === 1 ? 4 : 10)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.isMaterial ? leftMaterialPill.implicitWidth : leftRow.implicitWidth

            // Material pill wrapper
            Rectangle {
                id: leftMaterialPill
                visible: root.isMaterial
                anchors.centerIn: parent
                implicitWidth: leftMaterialRow.implicitWidth + 10
                implicitHeight: leftMaterialRow.implicitHeight
                radius: Appearance.rounding.full
                color: (Config.options?.bar?.m3?.showBackground ?? true)
                    && (Config.options?.bar?.m3?.borderless ?? "separated") === "pills"
                    ? Appearance.colors.colLayer0 : "transparent"

                SurfaceSpectrum {
                    anchors.fill: parent
                    z: 2
                    active: root.wantsBackgroundVisualizer && root.materialSectionSpectrum
                        && leftMaterialPill.visible && root.spectrumSignalActive
                    sampleStartRatio: {
                        const geometryDependency = leftMaterialPill.x + leftMaterialPill.width
                            + (leftMaterialPill.parent?.x ?? 0)
                            + (leftMaterialPill.parent?.width ?? 0)
                        return root.spectrumStartRatio(leftMaterialPill)
                    }
                    sampleEndRatio: {
                        const geometryDependency = leftMaterialPill.x + leftMaterialPill.width
                            + (leftMaterialPill.parent?.x ?? 0)
                            + (leftMaterialPill.parent?.width ?? 0)
                        return root.spectrumEndRatio(leftMaterialPill)
                    }
                    topLeftRadius: leftMaterialPill.radius
                    topRightRadius: leftMaterialPill.radius
                    bottomLeftRadius: leftMaterialPill.radius
                    bottomRightRadius: leftMaterialPill.radius
                }

                RowLayout {
                    id: leftMaterialRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: root.effectiveLeftLayout
                        delegate: leftMaterialGroupDelegate
                    }

                    Component {
                        id: leftMaterialGroupDelegate
                        SpectrumGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            totalCount: root.effectiveLeftLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillHeight: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item)
                                        root.wireWidget(item, root.effectiveLeftLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            // Non-material layout
            RowLayout {
                id: leftRow
                visible: !root.isMaterial
                anchors.fill: parent
                spacing: Config.options.bar.m3.borderless === "transparent" ? -7 : 2

                Repeater {
                    model: root.effectiveLeftLayout
                    delegate: leftBarGroupDelegate
                }

                Component {
                    id: leftBarGroupDelegate
                    SpectrumGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: root.effectiveLeftLayout.length
                        Loader {
                            Layout.fillHeight: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                if (item)
                                    root.wireWidget(item, root.effectiveLeftLayout, index)
                            }
                        }
                    }
                }

                Component {
                    id: leftNoGroupDelegate
                    Loader {
                        Layout.fillHeight: false
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        Layout.alignment: Qt.AlignVCenter
                        source: root.getWidgetUrl(modelData)
                        onLoaded: {
                            if (item)
                                root.wireWidget(item, root.effectiveLeftLayout, index)
                        }
                    }
                }
            }
        }

        // Center
        Item {
            id: absoluteCenter
            anchors.centerIn: parent
            width: root.isMaterial ? centerMaterialPill.implicitWidth : middleRow.implicitWidth
            height: parent.height

            // Material pill wrapper
            Rectangle {
                id: centerMaterialPill
                visible: root.isMaterial
                anchors.centerIn: parent
                implicitWidth: centerMaterialRow.implicitWidth + 10
                implicitHeight: centerMaterialRow.implicitHeight
                radius: Appearance.rounding.full
                color: (Config.options?.bar?.m3?.showBackground ?? true)
                    && (Config.options?.bar?.m3?.borderless ?? "separated") === "pills"
                    ? Appearance.colors.colLayer0 : "transparent"

                SurfaceSpectrum {
                    anchors.fill: parent
                    z: 2
                    active: root.wantsBackgroundVisualizer && root.materialSectionSpectrum
                        && centerMaterialPill.visible && root.spectrumSignalActive
                    sampleStartRatio: {
                        const geometryDependency = centerMaterialPill.x + centerMaterialPill.width
                            + (centerMaterialPill.parent?.x ?? 0)
                            + (centerMaterialPill.parent?.width ?? 0)
                        return root.spectrumStartRatio(centerMaterialPill)
                    }
                    sampleEndRatio: {
                        const geometryDependency = centerMaterialPill.x + centerMaterialPill.width
                            + (centerMaterialPill.parent?.x ?? 0)
                            + (centerMaterialPill.parent?.width ?? 0)
                        return root.spectrumEndRatio(centerMaterialPill)
                    }
                    topLeftRadius: centerMaterialPill.radius
                    topRightRadius: centerMaterialPill.radius
                    bottomLeftRadius: centerMaterialPill.radius
                    bottomRightRadius: centerMaterialPill.radius
                }

                RowLayout {
                    id: centerMaterialRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: root.effectiveMiddleLayout
                        delegate: middleMaterialGroupDelegate
                    }

                    Component {
                        id: middleMaterialGroupDelegate
                        SpectrumGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            totalCount: root.effectiveMiddleLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillHeight: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item)
                                        root.wireWidget(item, root.effectiveMiddleLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            // Non-material layout
            RowLayout {
                id: middleRow
                visible: !root.isMaterial
                anchors.fill: parent
                spacing: Config.options.bar.m3.borderless === "transparent" ? -7 : 2

                Repeater {
                    model: root.effectiveMiddleLayout
                    delegate: middleBarGroupDelegate
                }

                Component {
                    id: middleBarGroupDelegate
                    SpectrumGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: root.effectiveMiddleLayout.length
                        Loader {
                            Layout.fillHeight: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                if (item)
                                    root.wireWidget(item, root.effectiveMiddleLayout, index)
                            }
                        }
                    }
                }

                Component {
                    id: middleNoGroupDelegate
                    Loader {
                        Layout.fillHeight: false
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        source: root.getWidgetUrl(modelData)
                        onLoaded: {
                            if (item)
                                root.wireWidget(item, root.effectiveMiddleLayout, index)
                        }
                    }
                }
            }
        }

        // Right
        Item {
            anchors.right: parent.right
            anchors.rightMargin: root.isMaterial ? (Config.options.bar.m3.gapsOut || 5) : (Config.options.bar.m3.cornerStyle === 1 ? 4 : 10)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.isMaterial ? rightMaterialPill.implicitWidth : rightRow.implicitWidth

            // Material pill wrapper
            Rectangle {
                id: rightMaterialPill
                visible: root.isMaterial
                anchors.centerIn: parent
                implicitWidth: rightMaterialRow.implicitWidth + 10
                implicitHeight: rightMaterialRow.implicitHeight
                radius: Appearance.rounding.full
                color: (Config.options?.bar?.m3?.showBackground ?? true)
                    && (Config.options?.bar?.m3?.borderless ?? "separated") === "pills"
                    ? Appearance.colors.colLayer0 : "transparent"

                SurfaceSpectrum {
                    anchors.fill: parent
                    z: 2
                    active: root.wantsBackgroundVisualizer && root.materialSectionSpectrum
                        && rightMaterialPill.visible && root.spectrumSignalActive
                    sampleStartRatio: {
                        const geometryDependency = rightMaterialPill.x + rightMaterialPill.width
                            + (rightMaterialPill.parent?.x ?? 0)
                            + (rightMaterialPill.parent?.width ?? 0)
                        return root.spectrumStartRatio(rightMaterialPill)
                    }
                    sampleEndRatio: {
                        const geometryDependency = rightMaterialPill.x + rightMaterialPill.width
                            + (rightMaterialPill.parent?.x ?? 0)
                            + (rightMaterialPill.parent?.width ?? 0)
                        return root.spectrumEndRatio(rightMaterialPill)
                    }
                    topLeftRadius: rightMaterialPill.radius
                    topRightRadius: rightMaterialPill.radius
                    bottomLeftRadius: rightMaterialPill.radius
                    bottomRightRadius: rightMaterialPill.radius
                }

                RowLayout {
                    id: rightMaterialRow
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: root.effectiveRightLayout
                        delegate: rightMaterialGroupDelegate
                    }

                    Component {
                        id: rightMaterialGroupDelegate
                        SpectrumGroup {
                            Layout.fillHeight: true
                            currentIndex: index
                            totalCount: root.effectiveRightLayout.length
                            paintMaterialPill: root.shouldPaintMaterialPill(modelData)
                            bgColor: root.getMaterialPillColor(modelData)
                            Loader {
                                Layout.fillHeight: true
                                source: root.getWidgetUrl(modelData)
                                onLoaded: {
                                    if (item)
                                        root.wireWidget(item, root.effectiveRightLayout, index)
                                }
                            }
                        }
                    }
                }
            }

            // Non-material layout
            RowLayout {
                id: rightRow
                visible: !root.isMaterial
                anchors.fill: parent
                spacing: Config.options.bar.m3.borderless === "transparent" ? -7 : 2

                Repeater {
                    model: root.effectiveRightLayout
                    delegate: rightBarGroupDelegate
                }

                Component {
                    id: rightBarGroupDelegate
                    SpectrumGroup {
                        Layout.fillHeight: true
                        currentIndex: index
                        totalCount: root.effectiveRightLayout.length
                        Loader {
                            Layout.fillHeight: true
                            source: root.getWidgetUrl(modelData)
                            onLoaded: {
                                if (item)
                                    root.wireWidget(item, root.effectiveRightLayout, index)
                            }
                        }
                    }
                }

                Component {
                    id: rightNoGroupDelegate
                    Loader {
                        Layout.fillHeight: false
                        Layout.topMargin: Config.options.bar.bottom ? -5 : 3
                        source: root.getWidgetUrl(modelData)
                        onLoaded: {
                            if (item)
                                root.wireWidget(item, root.effectiveRightLayout, index)
                        }
                    }
                }
            }
        }
    }
}
