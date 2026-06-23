import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

/**
 * Drag-and-drop dashboard layout editor. Three zones (left, center, right) each
 * render their widget rows in a soft container with a DropArea; rows drag across
 * zones AND from the "Available" tray. Adapted from BarModuleOrderEditor — same
 * uniform-row drop math (insert index = round(y / pitch)) and dragLayer reparent
 * so a lifted row floats above every zone. Writes go per-leaf through Config
 * (never assign a whole object to the dashboard.layout JsonObject).
 *
 * Used in BOTH the Settings page and the in-panel edit sheet, so the editing
 * model is identical wherever the user reaches it.
 */
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 12

    readonly property int rowH: 38
    readonly property int rowGap: 4
    readonly property real pitch: rowH + rowGap
    readonly property string availableZone: "__available__"
    readonly property var zones: ["left", "center", "right"]

    // Widget catalog — id → display metadata. Single source for the editor.
    readonly property var catalog: ({
        welcome:       { icon: "waving_hand",         label: Translation.tr("Welcome") },
        clock:         { icon: "schedule",            label: Translation.tr("Clock") },
        system:        { icon: "monitoring",          label: Translation.tr("System usage") },
        github:        { icon: "deployed_code",       label: Translation.tr("GitHub activity") },
        notifications: { icon: "notifications",       label: Translation.tr("Notifications") },
        todo:          { icon: "checklist",           label: Translation.tr("To Do") },
        media:         { icon: "music_note",          label: Translation.tr("Media player") },
        weather:       { icon: "partly_cloudy_day",   label: Translation.tr("Weather") },
        calendar:      { icon: "calendar_month",      label: Translation.tr("Calendar") },
        agenda:        { icon: "event_upcoming",      label: Translation.tr("Agenda") },
        notes:         { icon: "edit_note",           label: Translation.tr("Notes") }
    })
    readonly property var allIds: Object.keys(catalog)

    function _meta(id) { return root.catalog[id] ?? ({ icon: "widgets", label: id }) }
    function _icon(id) { return root._meta(id).icon }
    function _label(id) { return root._meta(id).label }
    function _zoneLabel(z) {
        return ({ left: Translation.tr("Left"), center: Translation.tr("Center"),
            right: Translation.tr("Right") })[z] || z
    }
    function _zoneIcon(z) {
        return ({ left: "align_horizontal_left", center: "align_horizontal_center",
            right: "align_horizontal_right" })[z] || "widgets"
    }

    // ─── Reactive layout view ───────────────────────────────────────────
    readonly property var _defaults: ({
        left: ["welcome", "clock", "system"],
        center: ["notifications", "todo"],
        right: ["media", "weather", "calendar"]
    })
    function _getZone(name) {
        const a = Config.options?.dashboard?.layout?.[name]
        return Array.isArray(a) ? a : (root._defaults[name] ?? [])
    }
    function _placed() {
        let s = []
        for (let i = 0; i < root.zones.length; i++) s = s.concat(root._getZone(root.zones[i]))
        return s
    }
    readonly property var placedIds: root._placed()
    readonly property var availableIds: root.allIds.filter(id => root.placedIds.indexOf(id) === -1)

    // ─── Mutators (per-leaf only) ───────────────────────────────────────
    function _addToZone(id, toZone, atIndex) {
        const dst = root._getZone(toZone).slice()
        if (dst.indexOf(id) !== -1) return
        const idx = (atIndex === undefined || atIndex < 0) ? dst.length : Math.max(0, Math.min(atIndex, dst.length))
        dst.splice(idx, 0, id)
        Config.setNestedValue("dashboard.layout." + toZone, dst)
    }
    function _remove(zone, idx) {
        const arr = root._getZone(zone).slice()
        arr.splice(idx, 1)
        Config.setNestedValue("dashboard.layout." + zone, arr)
    }
    function _dropMove(srcZone, srcIdx, srcId, dstZone, dstIdx) {
        if (srcZone === root.availableZone) { root._addToZone(srcId, dstZone, dstIdx); return }
        if (srcZone === dstZone) {
            const arr = root._getZone(srcZone).slice()
            const [m] = arr.splice(srcIdx, 1)
            arr.splice(Math.max(0, Math.min(dstIdx, arr.length)), 0, m)
            Config.setNestedValue("dashboard.layout." + srcZone, arr)
        } else {
            const src = root._getZone(srcZone).slice()
            const dst = root._getZone(dstZone).slice()
            const [m] = src.splice(srcIdx, 1)
            dst.splice(Math.max(0, Math.min(dstIdx, dst.length)), 0, m)
            let u = {}
            u["dashboard.layout." + srcZone] = src
            u["dashboard.layout." + dstZone] = dst
            Config.setNestedValues(u)
        }
    }
    function _resetToDefaults() {
        Config.setNestedValues({
            "dashboard.layout.left": root._defaults.left,
            "dashboard.layout.center": root._defaults.center,
            "dashboard.layout.right": root._defaults.right
        })
    }

    // ─── Drag state ─────────────────────────────────────────────────────
    property var dragInfo: null      // { zone, index, id }
    property string dropZone: ""
    property int dropIndex: -1
    readonly property bool dragging: dragInfo !== null
    function _indexFromY(y, count) { return Math.max(0, Math.min(Math.round(y / root.pitch), count)) }
    function _commitDrop(dstZone) {
        if (root.dragInfo && root.dropIndex >= 0)
            root._dropMove(root.dragInfo.zone, root.dragInfo.index, root.dragInfo.id, dstZone, root.dropIndex)
        root._endDrag()
    }
    function _endDrag() { root.dragInfo = null; root.dropZone = ""; root.dropIndex = -1 }

    // Floating layer the dragged row reparents into so it travels over all zones.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 0
        z: 100
        clip: false
        Item { id: dragLayer; width: root.width; height: root.height }
    }

    // ─── Header ─────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Drag widgets between columns, or drag from the tray to add. Drop a widget on the tray to remove it.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }
        RippleButton {
            implicitWidth: 30; implicitHeight: 30
            buttonRadius: Appearance.rounding.full
            onClicked: root._resetToDefaults()
            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "restart_alt"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
            StyledToolTip { text: Translation.tr("Reset dashboard layout to defaults") }
        }
    }

    // ─── Draggable row ──────────────────────────────────────────────────
    component WidgetRow: Rectangle {
        id: rowRoot
        property string widgetId: ""
        property string zone: ""
        property int rowIndex: -1
        readonly property bool beingDragged: root.dragInfo && root.dragInfo.id === widgetId && root.dragInfo.zone === zone && root.dragInfo.index === rowIndex

        width: parent ? parent.width : implicitWidth
        height: root.rowH
        radius: Appearance.rounding.small
        color: beingDragged ? Appearance.colors.colLayer2
            : (dragMa.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1)
        border.color: beingDragged ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
        border.width: 1
        scale: beingDragged ? 1.03 : 1
        rotation: beingDragged ? 0.6 : 0
        Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on rotation { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

        StyledRectangularShadow {
            target: rowRoot.beingDragged ? rowRoot : null
            visible: rowRoot.beingDragged
            z: -1
        }

        Drag.active: dragMa.drag.active
        Drag.source: rowRoot
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        states: State {
            when: dragMa.drag.active
            ParentChange { target: rowRoot; parent: dragLayer }
            PropertyChanges { rowRoot { z: 200 } }
        }

        MouseArea {
            id: dragMa
            anchors.fill: parent
            hoverEnabled: true
            // preventStealing: the editor is nested inside a Flickable (the
            // settings ContentPage scroll, and the in-panel `editScroll`).
            // Without this the Flickable steals the vertical drag gesture the
            // moment the cursor moves past its threshold, so the row never
            // actually drags and the drop never commits.
            preventStealing: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: rowRoot
            drag.axis: Drag.XAndYAxis
            onPressed: {
                root.dragInfo = { zone: rowRoot.zone, index: rowRoot.rowIndex, id: rowRoot.widgetId }
            }
            onReleased: {
                if (rowRoot.Drag.target) rowRoot.Drag.drop()
                else root._endDrag()
            }
            onCanceled: root._endDrag()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 8
            MaterialSymbol { text: "drag_indicator"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext }
            MaterialSymbol { text: root._icon(rowRoot.widgetId); iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnLayer1 }
            StyledText {
                Layout.fillWidth: true
                text: root._label(rowRoot.widgetId)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }
            RippleButton {
                implicitWidth: 26; implicitHeight: 26
                buttonRadius: Appearance.rounding.full
                onClicked: root._remove(rowRoot.zone, rowRoot.rowIndex)
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "remove_circle_outline"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                StyledToolTip { text: Translation.tr("Remove from layout") }
            }
        }
    }

    // ─── Zones ──────────────────────────────────────────────────────────
    Repeater {
        model: root.zones
        delegate: Rectangle {
            id: zoneCard
            required property string modelData
            readonly property string zoneName: modelData
            readonly property var zoneItems: root._getZone(zoneName)
            readonly property bool dropActive: root.dragging && root.dropZone === zoneName

            Layout.fillWidth: true
            implicitHeight: zoneInner.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: dropActive ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.92)
                : Appearance.colors.colLayer0
            border.color: dropActive ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
            border.width: 1
            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
            Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

            ColumnLayout {
                id: zoneInner
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        implicitWidth: 24; implicitHeight: 24
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                        MaterialSymbol { anchors.centerIn: parent; text: root._zoneIcon(zoneCard.zoneName); iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colPrimary }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root._zoneLabel(zoneCard.zoneName)
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }
                    Rectangle {
                        implicitHeight: 18
                        implicitWidth: Math.max(22, countLabel.implicitWidth + 12)
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.92)
                        StyledText {
                            id: countLabel
                            anchors.centerIn: parent
                            text: zoneCard.zoneItems.length + ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                DropArea {
                    id: zoneDrop
                    Layout.fillWidth: true
                    implicitHeight: Math.max(rowCol.implicitHeight, root.rowH)
                    readonly property string zoneName: zoneCard.zoneName
                    readonly property int liveCount: zoneCard.zoneItems.length
                        - ((root.dragInfo && root.dragInfo.zone === zoneName) ? 1 : 0)
                    function _update(y) {
                        root.dropZone = zoneName
                        root.dropIndex = root._indexFromY(y, zoneDrop.liveCount)
                    }
                    onEntered: drag => zoneDrop._update(drag.y)
                    onPositionChanged: drag => zoneDrop._update(drag.y)
                    onExited: if (root.dropZone === zoneName) { root.dropZone = ""; root.dropIndex = -1 }
                    onDropped: root._commitDrop(zoneName)

                    Rectangle {
                        visible: zoneDrop.liveCount === 0
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: zoneCard.dropActive ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9) : "transparent"
                        border.color: zoneCard.dropActive ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                        border.width: 1
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                text: zoneCard.dropActive ? "download" : "drag_handle"
                                iconSize: Appearance.font.pixelSize.normal
                                color: zoneCard.dropActive ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: zoneCard.dropActive ? Translation.tr("Release to drop") : Translation.tr("Drop widgets here")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: zoneCard.dropActive ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }
                        }
                    }

                    Column {
                        id: rowCol
                        width: parent.width
                        spacing: root.rowGap
                        Repeater {
                            model: zoneCard.zoneItems
                            delegate: WidgetRow {
                                required property string modelData
                                required property int index
                                widgetId: modelData
                                zone: zoneCard.zoneName
                                rowIndex: index
                            }
                        }
                        Item {
                            visible: root.dragInfo && root.dragInfo.zone === zoneDrop.zoneName
                            width: parent.width
                            height: visible ? root.rowH : 0
                        }
                    }

                    Rectangle {
                        id: dropSlot
                        visible: zoneCard.dropActive && root.dropIndex >= 0 && zoneDrop.liveCount > 0
                        x: 6
                        width: parent.width - 12
                        height: 4
                        radius: 2
                        color: Appearance.colors.colPrimary
                        y: Math.min(root.dropIndex, zoneDrop.liveCount) * root.pitch - root.rowGap / 2 - height / 2
                        z: 50
                        Behavior on y {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        Rectangle { width: 8; height: 8; radius: 4; color: parent.color; anchors.verticalCenter: parent.verticalCenter; x: -4 }
                        Rectangle { width: 8; height: 8; radius: 4; color: parent.color; anchors.verticalCenter: parent.verticalCenter; x: parent.width - 4 }
                    }
                }
            }
        }
    }

    // ─── Available (unplaced) widgets — chip tray, also a remove target ──
    DropArea {
        id: trayDrop
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: tray.implicitHeight
        readonly property bool removeActive: root.dragging && root.dragInfo
            && root.dragInfo.zone !== root.availableZone && root.dropZone === root.availableZone
        onEntered: drag => { root.dropZone = root.availableZone; root.dropIndex = -1 }
        onExited: if (root.dropZone === root.availableZone) root.dropZone = ""
        onDropped: {
            // Dropping a placed row here removes it from its zone.
            if (root.dragInfo && root.dragInfo.zone !== root.availableZone)
                root._remove(root.dragInfo.zone, root.dragInfo.index)
            root._endDrag()
        }

        Rectangle {
            id: tray
            width: parent.width
            implicitHeight: trayInner.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: trayDrop.removeActive ? ColorUtils.transparentize(Appearance.colors.colError, 0.9) : Appearance.colors.colLayer0
            border.color: trayDrop.removeActive ? Appearance.colors.colError : Appearance.colors.colOutlineVariant
            border.width: 1
            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

            ColumnLayout {
                id: trayInner
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        implicitWidth: 24; implicitHeight: 24
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(trayDrop.removeActive ? Appearance.colors.colError : Appearance.colors.colPrimary, 0.85)
                        MaterialSymbol { anchors.centerIn: parent; text: trayDrop.removeActive ? "delete" : "add_box"; iconSize: Appearance.font.pixelSize.small; color: trayDrop.removeActive ? Appearance.colors.colError : Appearance.colors.colPrimary }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: trayDrop.removeActive ? Translation.tr("Release to remove")
                            : (root.availableIds.length > 0 ? Translation.tr("Available widgets") : Translation.tr("All widgets placed"))
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: trayDrop.removeActive ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    visible: root.availableIds.length > 0
                    spacing: 6
                    Repeater {
                        model: root.availableIds
                        delegate: Rectangle {
                            id: chip
                            required property string modelData
                            readonly property string widgetId: modelData
                            readonly property bool beingDragged: root.dragInfo && root.dragInfo.zone === root.availableZone && root.dragInfo.id === widgetId

                            implicitHeight: 32
                            implicitWidth: chipRow.implicitWidth + 18
                            radius: Appearance.rounding.full
                            color: chipMa.containsMouse || beingDragged
                                ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                                : ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.95)
                            border.color: beingDragged ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                            border.width: 1
                            opacity: beingDragged ? 0.92 : 1
                            scale: beingDragged ? 1.04 : 1
                            Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                            Drag.active: chipMa.drag.active
                            Drag.source: chip
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2
                            states: State {
                                when: chipMa.drag.active
                                ParentChange { target: chip; parent: dragLayer }
                                PropertyChanges { chip { z: 200 } }
                            }

                            MouseArea {
                                id: chipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                drag.target: chip
                                drag.axis: Drag.XAndYAxis
                                onPressed: root.dragInfo = { zone: root.availableZone, index: -1, id: chip.widgetId }
                                onReleased: {
                                    if (chip.Drag.target) chip.Drag.drop()
                                    else root._endDrag()
                                }
                                onCanceled: root._endDrag()
                                // Single tap adds to the emptiest column — fast path
                                // for users who don't want to drag.
                                onClicked: {
                                    let target = "center", best = Infinity
                                    for (const z of root.zones) {
                                        const n = root._getZone(z).length
                                        if (n < best) { best = n; target = z }
                                    }
                                    root._addToZone(chip.widgetId, target, -1)
                                }
                            }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialSymbol { text: root._icon(chip.widgetId); iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                                StyledText {
                                    text: root._label(chip.widgetId)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                }
                                MaterialSymbol { text: "add"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                            }
                        }
                    }
                }
            }
        }
    }
}
