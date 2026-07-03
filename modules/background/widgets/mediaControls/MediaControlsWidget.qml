pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import qs.services
import qs
import qs.modules.common.functions
import qs.modules.background.widgets
import qs.modules.mediaControls.presets

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

AbstractBackgroundWidget {
    id: root

    configEntryName: "mediaControls"
    defaultConfig: ({
        placementStrategy: "leastBusy", playerPreset: "full",
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        x: 100, y: 100
    })

    readonly property real widgetWidth: Math.round(Appearance.sizes.mediaControlsWidth * scaleFactor)
    readonly property real widgetHeight: Math.round(Appearance.sizes.mediaControlsHeight * scaleFactor)

    // Desktop players skip the per-track album-art scheme (blendedColors) in favor of
    // the shell's wallpaper palette, but that leaves their on-surface text reading the
    // raw, near-neutral Appearance.colors token instead of the boosted ink every other
    // background widget gets via colText. This overrides just the two ink properties
    // presets actually use for text (colOnLayer0/colSubtext) — everything else presets
    // read off blendedColors is left undefined here, so `blendedColors?.x ?? Appearance.colors.x`
    // falls through to the normal token untouched.
    readonly property QtObject _desktopInkOverride: QtObject {
        property color colOnLayer0: ColorUtils.boostInkSaturation(Appearance.colors.colOnLayer0, Appearance.m3colors.m3primary)
        property color colSubtext: ColorUtils.boostInkSaturation(Appearance.colors.colSubtext, Appearance.m3colors.m3primary)
    }
    property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
    resizableAxes: ({ uniform: "widgetScale" })
    resizeMinWidth: 160
    resizeMinHeight: 80
    needsColText: true

    // ── Accent from shared desktop-widget identity (already region-visible) ──
    readonly property color accentPrimary: root.widgetAccent

    readonly property string vizType: Config.getNestedValue("background.widgets.mediaControls.visualizerType", "wave")
    readonly property string vizPosition: Config.getNestedValue("background.widgets.mediaControls.visualizerPosition", "bottom")

    editPopoverContent: Component {
        Column {
            spacing: 6
            // Preset selector
            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: "Full", icon: "view_agenda", value: "full" },
                        { label: "Compact", icon: "view_compact", value: "compact" },
                        { label: "Minimal", icon: "minimize", value: "minimal" },
                        { label: "Album", icon: "album", value: "albumart" },
                        { label: "Viz", icon: "graphic_eq", value: "visualizer" },
                        { label: "Classic", icon: "music_note", value: "classic" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.selectedPreset === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.mediaControls.playerPreset", modelData.value)
                    }
                }
            }
            // Visualizer type
            GridLayout {
                columns: 2
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: "Wave", icon: "waves", value: "wave" },
                        { label: "Bars", icon: "equalizer", value: "bars" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.vizType === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.mediaControls.visualizerType", modelData.value)
                    }
                }
            }
            // Visualizer position
            GridLayout {
                columns: 4
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: "Bottom", icon: "vertical_align_bottom", value: "bottom" },
                        { label: "Top", icon: "vertical_align_top", value: "top" },
                        { label: "Fill", icon: "fullscreen", value: "fill" },
                        { label: "Off", icon: "visibility_off", value: "none" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.vizPosition === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.mediaControls.visualizerPosition", modelData.value)
                    }
                }
            }
        }
    }

    // Use MprisController.displayPlayers - centralized filtering.
    // Spread into a plain JS array: ScriptModel.values expects a QVariantList,
    // but displayPlayers is a typed list<MprisPlayer> (QQmlListReference) which
    // cannot be assigned to QVariantList directly (silent failure → empty widget).
    readonly property var meaningfulPlayers: [...MprisController.displayPlayers]

    implicitWidth: widgetWidth
    implicitHeight: playerColumnLayout.implicitHeight

    readonly property bool visualizerActive: (Config.options?.background?.widgets?.mediaControls?.enable ?? false)
        && root.visible && MprisController.isPlaying

    CavaProcess {
        id: cavaProcess
        active: root.visualizerActive
    }

    property list<real> visualizerPoints: cavaProcess.points

    // Dim factor (0..1)
    property real dimFactor: {
        const v = Config.getNestedValue("background.widgets.mediaControls.dim", 0);
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    readonly property point widgetScreenPos: root.mapToItem(null, 0, 0)
    
    // Get selected preset component
    readonly property string selectedPreset: Config.getNestedValue("background.widgets.mediaControls.playerPreset", "full")
    readonly property Component presetComponent: {
        switch (selectedPreset) {
            case "compact": return compactPlayerComponent
            case "minimal": return minimalPlayerComponent
            case "albumart": return albumArtPlayerComponent
            case "visualizer": return visualizerPlayerComponent
            case "classic": return classicPlayerComponent
            case "full":
            default: return fullPlayerComponent
        }
    }
    
    // Preset components
    Component {
        id: fullPlayerComponent
        FullPlayer {}
    }
    
    Component {
        id: compactPlayerComponent
        CompactPlayer {}
    }
    
    Component {
        id: minimalPlayerComponent
        MinimalPlayer {}
    }
    
    Component {
        id: albumArtPlayerComponent
        AlbumArtPlayer {}
    }
    
    Component {
        id: visualizerPlayerComponent
        VisualizerPlayer {}
    }
    
    Component {
        id: classicPlayerComponent
        ClassicPlayer {}
    }

    ColumnLayout {
        id: playerColumnLayout
        anchors.fill: parent
        spacing: -Appearance.sizes.elevationMargin
        opacity: 1.0 - root.dimFactor * 0.6

        Repeater {
            model: ScriptModel {
                values: root.meaningfulPlayers
            }
            delegate: Item {
                id: delegateRoot
                required property MprisPlayer modelData
                Layout.preferredWidth: root.widgetWidth
                Layout.preferredHeight: root.widgetHeight

                // Soft contact shadow behind the card — the shell's own shadow
                // vocabulary, so the desktop player floats with the same edge as every
                // other surface instead of a bolted-on outline. Declared before the
                // card (renders behind). Input untouched (it never replaces the card).
                StyledRectangularShadow {
                    target: playerLoader
                    radius: root.popupRounding
                }

                Loader {
                    id: playerLoader
                    anchors.fill: parent
                    sourceComponent: root.presetComponent

                    onLoaded: {
                        item.player = delegateRoot.modelData
                        // Desktop players live on the wallpaper, so they follow the generated
                        // shell palette (not the album-art scheme the floating popup uses).
                        // _desktopInkOverride only defines colOnLayer0/colSubtext, so every
                        // other `?? Appearance.colors.x` fallback still wins.
                        item.blendedColors = root._desktopInkOverride
                        item.themeSourceColor = Qt.binding(() => Appearance.colors.colPrimary)
                        item.visualizerPoints = Qt.binding(() => root.visualizerPoints)
                        item.radius = root.popupRounding
                        item.screenX = Qt.binding(() => root.widgetScreenPos.x)
                        item.screenY = Qt.binding(() => root.widgetScreenPos.y)
                        item.width = Qt.binding(() => root.widgetWidth)
                        item.height = Qt.binding(() => root.widgetHeight)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            visible: root.meaningfulPlayers.length === 0
            implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
            implicitHeight: placeholderBackground.implicitHeight + Appearance.sizes.elevationMargin

            Rectangle {
                id: placeholderBackground
                anchors.centerIn: parent
                color: ColorUtils.applyAlpha(root.colText, 0.10)
                radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : root.popupRounding
                border { width: 1; color: ColorUtils.applyAlpha(root.colText, 0.08) }
                property real padding: 24
                implicitWidth: placeholderLayout.implicitWidth + padding * 2
                implicitHeight: placeholderLayout.implicitHeight + padding * 2

                ColumnLayout {
                    id: placeholderLayout
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialShape {
                        Layout.alignment: Qt.AlignHCenter
                        implicitSize: 56
                        shape: MaterialShape.Shape.Cookie4Sided
                        color: ColorUtils.applyAlpha(root.accentPrimary, 0.16)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "music_note"
                            iconSize: 28
                            color: root.accentPrimary
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No active player")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: root.colText
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        color: ColorUtils.applyAlpha(root.colText, 0.5)
                        text: Translation.tr("Play something to see controls here")
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
