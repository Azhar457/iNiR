pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects as GE
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Detached "now playing"-style flyout shown to the side of the selected card.
// Carries the selected workspace's identity and a live, interactive list of its
// open windows: click a row to focus, hover to reveal a close (×) control, and
// drag a row onto any rail card to move that window to another workspace.
//
// Surface skin (every global style, incl. zzz chamfer) comes from PanelSurface.
PanelSurface {
    id: detail

    property string wsName: ""
    property int wsIndex: 0
    property string focusedTitle: ""
    property string focusedAppId: ""
    property var wsWindows: []
    property bool isActiveWs: false
    property bool showAppIcons: true
    property bool showPreviews: true

    // Shared drag proxy owned by WorkspaceStrip; rows drive it so a window can be
    // dragged onto a rail card. Null disables drag-to-move.
    property Item dragProxy: null

    signal windowActivated(var win)
    signal windowCloseRequested(var win)

    readonly property bool _zzz: Appearance.zzzEverywhere
    readonly property bool _isNiri: CompositorService.isNiri

    // Compact, capped window list — scroll when a workspace is busy.
    readonly property int rowHeight: 38
    readonly property int rowSpacing: 4
    readonly property int maxVisibleRows: 6

    elevation: 2
    cardStyle: true

    implicitHeight: column.implicitHeight + 32

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: -1
    }

    Column {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 16
        }
        spacing: 10

        // ── Header: focused app icon + workspace identity ──
        Row {
            spacing: 10
            width: parent.width

            IconImage {
                id: appIcon
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 34
                source: detail.showAppIcons && detail.focusedAppId.length > 0
                    ? AppSearch.getIconSource(detail.focusedAppId) : ""
                visible: source.toString().length > 0
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (appIcon.visible ? appIcon.implicitSize + 10 : 0)
                spacing: 1

                StyledText {
                    width: parent.width
                    text: detail.isActiveWs
                        ? Translation.tr("Now active").toUpperCase()
                        : Translation.tr("Workspace").toUpperCase()
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    color: detail._zzz ? Appearance.zzz.accent : Appearance.colors.colPrimary
                }

                StyledText {
                    width: parent.width
                    text: detail._zzz
                        ? `${Translation.tr("WS")} / ${detail.wsName}`.toUpperCase()
                        : `${Translation.tr("Workspace")} ${detail.wsName}`
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: detail._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer1
                }
            }
        }

        // ── Window list (focus / close / drag-to-move) ──
        Flickable {
            id: listFlick
            width: parent.width
            height: Math.min(
                listColumn.implicitHeight,
                detail.maxVisibleRows * detail.rowHeight
                    + (detail.maxVisibleRows - 1) * detail.rowSpacing)
            contentHeight: listColumn.implicitHeight
            contentWidth: width
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: contentHeight > height

            ScrollBar.vertical: StyledScrollBar {
                policy: listFlick.contentHeight > listFlick.height
                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const max = Math.max(0, listFlick.contentHeight - listFlick.height)
                    listFlick.contentY = Math.max(0, Math.min(max,
                        listFlick.contentY - event.angleDelta.y))
                }
            }

            Column {
                id: listColumn
                width: listFlick.width
                spacing: detail.rowSpacing

                // Honest empty state.
                Item {
                    visible: detail.wsWindows.length === 0
                    width: parent.width
                    height: visible ? detail.rowHeight : 0
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "check_box_outline_blank"
                            iconSize: 18
                            color: Appearance.colors.colSubtext
                            opacity: 0.7
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Translation.tr("Empty workspace")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                Repeater {
                    model: detail.wsWindows

                    Item {
                        id: row
                        required property var modelData
                        required property int index

                        readonly property var win: modelData
                        readonly property int winId: detail._isNiri ? (win?.id ?? 0) : 0
                        readonly property string winAppId: detail._isNiri
                            ? (win?.app_id ?? "")
                            : (win?.appId ?? "")
                        readonly property string winTitle: win?.title
                            || winAppId || Translation.tr("Untitled window")
                        readonly property bool winFocused: detail._isNiri
                            ? (win?.is_focused ?? false)
                            : (win?.activated ?? false)
                        readonly property bool dragging: detail.dragProxy
                            && detail.dragProxy.dragging
                            && detail.dragProxy.win === win

                        width: listColumn.width
                        height: detail.rowHeight
                        opacity: dragging ? 0.35 : 1
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }

                        Rectangle {
                            id: rowBg
                            anchors.fill: parent
                            radius: detail._zzz ? Appearance.zzz.controlRadius
                                : Appearance.rounding.small
                            color: row.winFocused
                                ? (detail._zzz
                                    ? Appearance.zzz.bg3
                                    : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85))
                                : rowHover.hovered
                                    ? (detail._zzz ? Appearance.zzz.bg2 : Appearance.colors.colLayer2Hover)
                                    : "transparent"
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                            border.width: row.winFocused && !detail._zzz ? 1 : 0
                            border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)
                        }

                        Row {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 6
                                rightMargin: 6
                            }
                            spacing: 8

                            // Per-window thumbnail (Niri preview) with icon fallback.
                            Item {
                                id: thumb
                                anchors.verticalCenter: parent.verticalCenter
                                width: 42
                                height: 26

                                Rectangle {
                                    anchors.fill: parent
                                    radius: detail._zzz ? 0 : Appearance.rounding.unsharpen
                                    color: detail._zzz ? Appearance.zzz.bg0 : Appearance.colors.colLayer2
                                    visible: detail.showPreviews && preview.ready
                                }

                                Image {
                                    id: preview
                                    anchors.fill: parent
                                    readonly property bool ready: status === Image.Ready && source.toString().length > 0
                                    source: (detail.showPreviews && detail._isNiri && row.winId > 0)
                                        ? WindowPreviewService.getPreviewUrl(row.winId) : ""
                                    asynchronous: true
                                    cache: false
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    mipmap: true
                                    visible: ready
                                    layer.enabled: ready
                                    layer.effect: GE.OpacityMask {
                                        maskSource: Rectangle {
                                            width: preview.width
                                            height: preview.height
                                            radius: detail._zzz ? 0 : Appearance.rounding.unsharpen
                                        }
                                    }
                                    // Reassign only when the URL actually changes
                                    // (captureComplete fires on every open even
                                    // with no new capture); cache:false would
                                    // otherwise reload an identical frame.
                                    function _apply(): void {
                                        const next = WindowPreviewService.getPreviewUrl(row.winId)
                                        if (next === source.toString()) return
                                        source = next
                                    }
                                    Connections {
                                        target: WindowPreviewService
                                        enabled: detail._isNiri && row.winId > 0
                                        function onPreviewUpdated(id: int): void {
                                            if (id === row.winId) preview._apply()
                                        }
                                        function onCaptureComplete(): void {
                                            if (row.winId > 0) preview._apply()
                                        }
                                    }
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 22
                                    source: detail.showAppIcons && row.winAppId.length > 0
                                        ? AppSearch.getIconSource(row.winAppId) : ""
                                    visible: !preview.visible
                                }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 42 - 8
                                    - (closeBtn.visible ? closeBtn.width + 8 : 0)
                                text: row.winTitle
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: row.winFocused ? Font.DemiBold : Font.Normal
                                color: row.winFocused
                                    ? (detail._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer1)
                                    : Appearance.colors.colOnLayer1
                            }
                        }

                        // Close (×) — revealed on hover.
                        RippleButton {
                            id: closeBtn
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                rightMargin: 6
                            }
                            implicitWidth: 24
                            implicitHeight: 24
                            buttonRadius: detail._zzz ? Appearance.zzz.controlRadius : width / 2
                            visible: (rowHover.hovered || closeHover.hovered) && !row.dragging
                            colBackground: "transparent"
                            colBackgroundHover: detail._zzz
                                ? Appearance.zzz.bg4
                                : ColorUtils.transparentize(Appearance.colors.colLayer3, 0.2)
                            downAction: () => detail.windowCloseRequested(row.win)

                            HoverHandler { id: closeHover }

                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                text: "close"
                                iconSize: 16
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        HoverHandler { id: rowHover }

                        // Click to focus; press-drag to move onto a rail card.
                        MouseArea {
                            id: rowDrag
                            anchors.fill: parent
                            anchors.rightMargin: closeBtn.visible ? closeBtn.width + 10 : 0
                            hoverEnabled: false
                            preventStealing: true

                            property real _pressX: 0
                            property real _pressY: 0
                            property bool _dragging: false

                            onPressed: mouse => {
                                _pressX = mouse.x
                                _pressY = mouse.y
                                _dragging = false
                                if (detail.dragProxy)
                                    detail.dragProxy.placeAt(this, mouse.x, mouse.y)
                            }
                            onPositionChanged: mouse => {
                                if (!pressed || !detail.dragProxy) return
                                if (!_dragging) {
                                    const dx = Math.abs(mouse.x - _pressX)
                                    const dy = Math.abs(mouse.y - _pressY)
                                    if (dx > 8 || dy > 8) {
                                        _dragging = true
                                        detail.dragProxy.beginDrag(row.win, row.winTitle, row.winAppId)
                                    }
                                }
                                if (_dragging)
                                    detail.dragProxy.moveTo(this, mouse.x, mouse.y)
                            }
                            onReleased: {
                                if (_dragging && detail.dragProxy) {
                                    detail.dragProxy.endDrag()
                                } else if (!_dragging) {
                                    detail.windowActivated(row.win)
                                }
                                _dragging = false
                            }
                            onCanceled: {
                                if (detail.dragProxy) detail.dragProxy.cancelDrag()
                                _dragging = false
                            }
                        }
                    }
                }
            }
        }

        // ── Active-state accent rail ──
        Rectangle {
            width: parent.width
            height: 3
            radius: detail._zzz ? 0 : Appearance.rounding.full
            color: detail._zzz ? Appearance.zzz.hairlineStrong
                : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.3)

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: parent.width * (detail.isActiveWs ? 1 : 0.34)
                radius: parent.radius
                color: detail._zzz ? Appearance.zzz.accent : Appearance.colors.colPrimary
                Behavior on width {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }
            }
        }
    }
}
