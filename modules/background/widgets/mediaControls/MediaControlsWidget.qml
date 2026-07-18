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
        placementStrategy: "free", playerPreset: "full",
        visualizerType: "wave", visualizerPosition: "bottom",
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        x: 240, y: 240
    })

    readonly property real widgetWidth: Math.round(Appearance.sizes.mediaControlsWidth * scaleFactor)
    readonly property real widgetHeight: Math.round(Appearance.sizes.mediaControlsHeight * scaleFactor)

    // Media presets always draw their own card, so their ink must be resolved
    // against that card rather than against the wallpaper behind the widget.
    accentBackdrop: Appearance.colors.colLayer0
    readonly property color mediaSurfaceInk: root.forceLightInk ? root._inkLight
        : root.forceDarkInk ? root._inkDark
        : ColorUtils.ensureReadable(
            ColorUtils.boostInkSaturation(Appearance.colors.colOnLayer0, root.widgetAccent),
            Appearance.colors.colLayer0, 4.5)
    readonly property color mediaSurfaceInkMuted: ColorUtils.applyAlpha(root.mediaSurfaceInk, 0.66)
    readonly property QtObject _desktopInkOverride: QtObject {
        property color colOnLayer0: root.mediaSurfaceInk
        property color colSubtext: root.mediaSurfaceInkMuted
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
        ColumnLayout {
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

    // The desktop surface represents the active player only. Multi-player
    // browsing belongs to the media popups; stacking transient browser
    // providers here changes the widget's geometry during metadata handoff.
    readonly property MprisPlayer meaningfulPlayer: MprisController.activePlayer
    readonly property var meaningfulPlayers: root.meaningfulPlayer
        ? [root.meaningfulPlayer] : []

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    // Every preset can render the configured visualizer. Keep the shared Cava
    // subscription alive whenever a visible preset actually needs points.
    readonly property bool visualizerActive: root.vizPosition !== "none"
        && (Config.options?.background?.widgets?.mediaControls?.enable ?? false)
        && root.visible && root.powerActive && MprisController.isPlaying

    CavaProcess {
        id: cavaProcess
        active: root.visualizerActive
    }

    property list<real> visualizerPoints: cavaProcess.points

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
                        item.themeSourceColor = Qt.binding(() => root.widgetAccentVisible)
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

            PanelSurface {
                id: placeholderBackground
                anchors.centerIn: parent
                elevation: 1
                radiusOverride: root.popupRounding
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
                        color: ColorUtils.applyAlpha(root.widgetAccentVisible, 0.16)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "music_note"
                            iconSize: 28
                            color: root.widgetAccentVisible
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No active player")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: root.mediaSurfaceInk
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        color: root.mediaSurfaceInkMuted
                        text: Translation.tr("Play something to see controls here")
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
