pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

FocusScope {
    id: root

    required property string monitorName

    readonly property string mode: GlobalStates.wallpaperLauncherMode
    readonly property var entries: mode === "animated"
        ? library.animatedEntries : library.staticEntries
    readonly property string selectionTarget: Wallpapers.currentSelectionTarget()
    readonly property string selectionMonitorName:
        (Config.options?.background?.multiMonitor?.enable ?? false) ? monitorName : ""
    readonly property string currentWallpaperPath:
        Wallpapers.currentWallpaperPathForTarget(selectionTarget, selectionMonitorName)
    readonly property int currentIndex: carousel.currentIndex
    readonly property int count: carousel.count
    readonly property string selectedPath: carousel.selectedPath
    readonly property real padding: Appearance.sizes.spacingLarge
    readonly property bool loading: library.scanning || Wallpapers.thumbnailGenerationRunning
    property string _pendingGridTarget: "main"
    property string _pendingGridMonitor: ""

    implicitWidth: Math.max(carousel.itemWidth * 3 + padding * 2,
        carousel.implicitWidth + padding * 2)
    implicitHeight: padding * 2 + modeControls.implicitHeight
        + listArea.implicitHeight + searchField.implicitHeight
        + Appearance.sizes.spacingMedium * 2
    focus: true

    function setMode(nextMode: string): void {
        if (nextMode !== "static" && nextMode !== "animated") return
        if (GlobalStates.wallpaperLauncherMode === nextMode) return
        Wallpapers.stopPreview()
        GlobalStates.wallpaperLauncherMode = nextMode
        searchField.text = ""
        Qt.callLater(carousel.syncCurrentIndex)
    }

    function applyPath(path: string): void {
        if (!path) return
        Wallpapers.stopPreview()
        Wallpapers.applySelectionTarget(path, root.selectionTarget,
            Appearance.m3colors.darkmode, root.selectionMonitorName)
    }

    function openGrid(): void {
        Wallpapers.stopPreview()
        root._pendingGridTarget = root.selectionTarget
        root._pendingGridMonitor = root.selectionMonitorName
        Config.setNestedValue("wallpaperSelector.style", "grid")
        GlobalStates.wallpaperLauncherOpen = false
        gridOpenTimer.restart()
    }

    function moveSelection(delta: int): void {
        carousel.moveSelection(delta)
    }

    function activateCurrent(): void {
        carousel.activateCurrent()
    }

    function statusJson(): string {
        return JSON.stringify({
            open: GlobalStates.wallpaperLauncherOpen,
            mode: root.mode,
            index: root.currentIndex,
            count: root.count,
            path: root.selectedPath,
            target: root.selectionTarget,
            monitor: root.selectionMonitorName
        })
    }

    Component.onCompleted: {
        library.refresh(Directories.wallpapersPath)
        Qt.callLater(() => {
            root.forceActiveFocus()
            carousel.syncCurrentIndex()
        })
    }

    Connections {
        target: GlobalStates

        function onWallpaperLauncherOpenChanged(): void {
            if (!GlobalStates.wallpaperLauncherOpen) return
            library.refresh(Directories.wallpapersPath)
            Qt.callLater(() => {
                root.forceActiveFocus()
                carousel.syncCurrentIndex()
            })
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.wallpaperLauncherOpen = false
            event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.setMode(root.mode === "static" ? "animated" : "static")
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            carousel.moveSelection(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            carousel.moveSelection(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            carousel.activateCurrent()
            event.accepted = true
        } else if (event.key === Qt.Key_Slash) {
            searchField.forceActiveFocus()
            event.accepted = true
        } else if (event.text.length > 0 && !(event.modifiers & Qt.ControlModifier)) {
            searchField.text += event.text
            searchField.cursorPosition = searchField.text.length
            searchField.forceActiveFocus()
            event.accepted = true
        }
    }

    WallpaperLibrary { id: library }

    Timer {
        id: gridOpenTimer
        interval: 80
        onTriggered: {
            GlobalStates.wallpaperSelectionTarget = root._pendingGridTarget
            GlobalStates.wallpaperSelectorTargetMonitor = root._pendingGridMonitor
            Config.setNestedValues({
                "wallpaperSelector.selectionTarget": root._pendingGridTarget,
                "wallpaperSelector.targetMonitor": root._pendingGridMonitor
            })
            GlobalStates.wallpaperSelectorOpen = true
        }
    }

    StyledRectangularShadow {
        target: panel
        visible: !Appearance.inirEverywhere && !Appearance.zzzEverywhere
    }

    GlassBackground {
        id: panel
        anchors.fill: parent
        fallbackColor: ColorUtils.applyAlpha(
            Appearance.zzzEverywhere ? Appearance.zzz.paper : Appearance.colors.colLayer0, 1)
        inirColor: Appearance.inir.colLayer0
        auroraTransparency: Appearance.aurora.overlayTransparentize
        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingLarge
            : Appearance.inirEverywhere ? Appearance.inir.roundingLarge
            : Appearance.rounding.large
        border.width: 1
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
            : Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
            : Appearance.colors.colLayer0Border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.padding
            spacing: Appearance.sizes.spacingMedium

            RowLayout {
                id: modeControls
                Layout.alignment: Qt.AlignHCenter
                spacing: Appearance.sizes.spacingSmall
                property int clickIndex: root.mode === "static" ? 0 : 1

                SelectionGroupButton {
                    Layout.fillWidth: false
                    Layout.fillHeight: false
                    leftmost: true
                    toggled: root.mode === "static"
                    buttonIcon: "image"
                    buttonText: Translation.tr("Static")
                    onClicked: root.setMode("static")
                }

                SelectionGroupButton {
                    Layout.fillWidth: false
                    Layout.fillHeight: false
                    rightmost: true
                    toggled: root.mode === "animated"
                    buttonIcon: "movie"
                    buttonText: Translation.tr("Animated")
                    onClicked: root.setMode("animated")
                }

                IconToolbarButton {
                    visible: root.mode === "animated"
                    implicitWidth: Appearance.sizes.baseBarHeight
                    implicitHeight: Appearance.sizes.baseBarHeight
                    text: root.loading ? "progress_activity" : "refresh"
                    enabled: !root.loading
                    onClicked: {
                        library.refresh(Directories.wallpapersPath)
                        Wallpapers.generateThumbnail("large")
                    }
                    StyledToolTip { text: Translation.tr("Refresh animated wallpapers") }
                }

                StyledText {
                    visible: root.loading
                    text: Translation.tr("Processing...")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSecondary
                }
            }

            Item {
                id: listArea
                Layout.fillWidth: true
                implicitHeight: carousel.implicitHeight

                WallpaperLauncherList {
                    id: carousel
                    anchors.centerIn: parent
                    width: Math.min(parent.width, implicitWidth)
                    height: implicitHeight
                    entries: root.entries
                    searchText: searchField.text
                    currentWallpaperPath: root.currentWallpaperPath
                    monitorName: root.monitorName
                    onApplyRequested: path => root.applyPath(path)
                }

                Column {
                    anchors.centerIn: parent
                    visible: !root.loading && carousel.count === 0
                    spacing: Appearance.sizes.spacingSmall
                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.mode === "animated" ? "motion_photos_off" : "image_not_supported"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.mode === "animated"
                            ? Translation.tr("No animated wallpapers found")
                            : Translation.tr("No wallpapers found")
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.mode === "animated"
                        text: Translation.tr("Add GIF or video files to your wallpaper folder")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.spacingSmall

                IconToolbarButton {
                    implicitWidth: Appearance.sizes.baseBarHeight
                    implicitHeight: Appearance.sizes.baseBarHeight
                    text: "grid_view"
                    onClicked: root.openGrid()
                    StyledToolTip { text: Translation.tr("Switch to grid view") }
                }

                IconToolbarButton {
                    implicitWidth: Appearance.sizes.baseBarHeight
                    implicitHeight: Appearance.sizes.baseBarHeight
                    text: "chevron_left"
                    enabled: carousel.count > 1
                    onClicked: {
                        carousel.moveSelection(-1)
                        root.forceActiveFocus()
                    }
                    StyledToolTip { text: Translation.tr("Previous wallpaper") }
                }

                ToolbarTextField {
                    id: searchField
                    Layout.fillWidth: true
                    implicitHeight: Appearance.sizes.baseBarHeight
                    leftPadding: Appearance.sizes.spacingLarge * 2
                    placeholderText: Translation.tr("Search wallpapers")
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            root.setMode(root.mode === "static" ? "animated" : "static")
                            root.forceActiveFocus()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                            carousel.moveSelection(1)
                            root.forceActiveFocus()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                            carousel.moveSelection(-1)
                            root.forceActiveFocus()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            carousel.activateCurrent()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            root.forceActiveFocus()
                            event.accepted = true
                        }
                    }

                    MaterialSymbol {
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.sizes.spacingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }
                }

                IconToolbarButton {
                    implicitWidth: Appearance.sizes.baseBarHeight
                    implicitHeight: Appearance.sizes.baseBarHeight
                    text: "chevron_right"
                    enabled: carousel.count > 1
                    onClicked: {
                        carousel.moveSelection(1)
                        root.forceActiveFocus()
                    }
                    StyledToolTip { text: Translation.tr("Next wallpaper") }
                }

                IconToolbarButton {
                    implicitWidth: Appearance.sizes.baseBarHeight
                    implicitHeight: Appearance.sizes.baseBarHeight
                    text: "check"
                    enabled: carousel.count > 0
                    onClicked: {
                        carousel.activateCurrent()
                        root.forceActiveFocus()
                    }
                    StyledToolTip { text: Translation.tr("Apply wallpaper") }
                }

                IconToolbarButton {
                    implicitWidth: Appearance.sizes.baseBarHeight
                    implicitHeight: Appearance.sizes.baseBarHeight
                    text: "close"
                    onClicked: GlobalStates.wallpaperLauncherOpen = false
                    StyledToolTip { text: Translation.tr("Close wallpaper selector") }
                }
            }
        }
    }
}
