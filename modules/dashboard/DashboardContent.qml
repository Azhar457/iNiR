pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.modules.sidebarRight.events

/**
 * Dashboard hub composition. Three widget columns driven by
 * Config.options.dashboard.layout.{left,center,right} — same modular pattern
 * as bar.layout: the arrays are the source of truth, any widget id can live
 * in any column, empty columns collapse.
 */
Item {
    id: root
    property int screenWidth: 1920
    property int screenHeight: 1080

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool angelEverywhere: Appearance.angelEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool showHeader: Config.options?.dashboard?.showHeader ?? true

    // ═══ Modular widget registry ═══════════════════════════════════════
    readonly property var _widgetMap: ({
        "welcome": welcomeComponent,
        "clock": clockComponent,
        "weather": weatherComponent,
        "calendar": calendarComponent,
        "media": mediaComponent,
        "notifications": notificationsComponent,
        "todo": todoComponent,
        "system": systemComponent,
        "github": githubComponent,
        "agenda": agendaComponent,
        "notes": notesComponent,
    })
    // Widgets that absorb the column's remaining height
    readonly property var _fillIds: ["notifications", "todo", "notes"]

    // ═══ Shared events dialog (agenda widget) ══════════════════════════
    property var _agendaEditEvent: null
    property bool _agendaDialogShown: false
    property bool _agendaDialogLoaded: false
    function openAgendaDialog(evt) {
        root._agendaEditEvent = evt ?? null
        root._agendaDialogLoaded = true
        if (agendaDialogLoader.item) {
            if (evt) agendaDialogLoader.item.loadEvent(evt)
            else agendaDialogLoader.item.resetForm()
        }
        root._agendaDialogShown = true
    }

    function _column(name, fallback) {
        const a = Config.options?.dashboard?.layout?.[name]
        return (a && a.length >= 0) ? a : fallback
    }

    // ═══ In-panel edit mode ═════════════════════════════════════════════
    property bool editMode: false
    readonly property var _columnOrder: ["left", "center", "right"]
    readonly property var _editIconMap: ({
        welcome: "waving_hand", clock: "schedule", system: "monitoring",
        github: "deployed_code", notifications: "notifications", todo: "checklist",
        media: "music_note", weather: "partly_cloudy_day", calendar: "calendar_month",
        agenda: "event_upcoming", notes: "edit_note"
    })
    function _colArr(name) {
        const a = Config.options?.dashboard?.layout?.[name]
        return (a && a.length >= 0) ? a.slice() : []
    }
    function moveWithin(zone, idx, dir) {
        const arr = root._colArr(zone)
        const next = idx + dir
        if (idx < 0 || next < 0 || next >= arr.length) return
        const [m] = arr.splice(idx, 1)
        arr.splice(next, 0, m)
        Config.setNestedValue("dashboard.layout." + zone, arr)
    }
    function moveAcross(id, fromZone, dir) {
        const ci = root._columnOrder.indexOf(fromZone)
        const target = root._columnOrder[ci + dir]
        if (!target) return
        const src = root._colArr(fromZone)
        const dst = root._colArr(target)
        const idx = src.indexOf(id)
        if (idx === -1) return
        src.splice(idx, 1)
        dst.push(id)
        let u = {}
        u["dashboard.layout." + fromZone] = src
        u["dashboard.layout." + target] = dst
        Config.setNestedValues(u)
    }
    function hideWidget(zone, idx) {
        const arr = root._colArr(zone)
        if (idx < 0 || idx >= arr.length) return
        arr.splice(idx, 1)
        Config.setNestedValue("dashboard.layout." + zone, arr)
    }
    function showWidget(id) {
        // Re-add to the emptiest column so the layout stays balanced
        let target = "center", best = Infinity
        for (const z of root._columnOrder) {
            const n = root._colArr(z).length
            if (n < best) { best = n; target = z }
        }
        const arr = root._colArr(target)
        arr.push(id)
        Config.setNestedValue("dashboard.layout." + target, arr)
    }
    readonly property var hiddenIds: {
        const placed = root.leftIds.concat(root.centerIds).concat(root.rightIds)
        return Object.keys(root._editIconMap).filter(id => placed.indexOf(id) === -1)
    }
    readonly property var leftIds: root._column("left", ["welcome", "clock", "system"])
    readonly property var centerIds: root._column("center", ["notifications", "todo"])
    readonly property var rightIds: root._column("right", ["media", "weather", "calendar"])

    Component { id: welcomeComponent; DashWelcome {} }
    Component { id: clockComponent; DashClock {} }
    Component { id: weatherComponent; DashWeather {} }
    Component { id: calendarComponent; DashCalendar {} }
    Component { id: mediaComponent; DashMedia {} }
    Component { id: notificationsComponent; DashNotifications {} }
    Component { id: todoComponent; DashTodo {} }
    Component { id: systemComponent; DashSystem {} }
    Component { id: githubComponent; DashGithub {} }
    Component { id: notesComponent; DashNotes {} }
    Component {
        id: agendaComponent
        DashAgenda {
            onRequestEventsDialog: evt => root.openAgendaDialog(evt)
        }
    }

    readonly property string wallpaperUrl: Wallpapers.effectiveWallpaperUrl
    readonly property bool useWallpaperBackdrop: root.auroraEverywhere && !root.inirEverywhere && !Appearance.gameModeMinimal && root.wallpaperUrl.length > 0

    ColorQuantizer {
        id: wallpaperColorQuantizer
        source: (Appearance.auroraEverywhere || Appearance.angelEverywhere) ? root.wallpaperUrl : ""
        depth: 0
        rescaleSize: 10
    }

    readonly property color wallpaperDominantColor: (wallpaperColorQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
    readonly property QtObject blendedColors: AdaptedMaterialScheme {
        color: ColorUtils.mix(root.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    }

    // Shadow
    StyledRectangularShadow {
        target: background
        visible: (Appearance.angelEverywhere || (!root.inirEverywhere && !root.auroraEverywhere)) && !Appearance.gameModeMinimal
    }

    Rectangle {
        id: background
        anchors.fill: parent

        color: root.inirEverywhere ? Appearance.inir.colLayer0
             : root.auroraEverywhere ? ColorUtils.applyAlpha((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
             : Appearance.colors.colLayer0

        radius: root.angelEverywhere ? Appearance.angel.roundingLarge
            : root.inirEverywhere ? Appearance.inir.roundingLarge
            : Appearance.rounding.large

        border.width: 1
        border.color: root.angelEverywhere ? Appearance.angel.colBorder
                    : root.inirEverywhere ? Appearance.inir.colBorder
                    : root.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : Appearance.colors.colLayer0Border

        clip: true

        layer.enabled: root.useWallpaperBackdrop
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        // Aurora blurred wallpaper backdrop
        Image {
            id: blurredWallpaper
            anchors.centerIn: parent
            width: root.screenWidth
            height: root.screenHeight
            visible: root.useWallpaperBackdrop
            source: root.useWallpaperBackdrop ? root.wallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screenWidth
            sourceSize.height: root.screenHeight
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled && root.auroraEverywhere && !root.inirEverywhere
            layer.effect: MultiEffect {
                source: blurredWallpaper
                anchors.fill: source
                saturation: root.angelEverywhere
                    ? Appearance.angel.blurSaturation
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled ? 1 : 0
            }

            Rectangle {
                anchors.fill: parent
                color: root.angelEverywhere
                    ? ColorUtils.transparentize((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity)
                    : ColorUtils.transparentize((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        // Angel inset glow — top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: root.angelEverywhere
            color: Appearance.angel.colInsetGlow
            z: 10
        }

        ColumnLayout {
            readonly property bool compact: (Config.options?.dashboard?.appearance?.density ?? "comfortable") === "compact"
            anchors.fill: parent
            anchors.margins: compact ? 12 : 16
            spacing: compact ? 8 : 12

            Loader {
                Layout.fillWidth: true
                active: root.showHeader
                visible: active
                sourceComponent: DashboardHeader {}
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                component EditButton: RippleButton {
                    id: editBtn
                    property string buttonIcon: ""
                    implicitWidth: 26
                    implicitHeight: 26
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: editBtn.buttonIcon
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer2
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                component WidgetColumn: ColumnLayout {
                    id: widgetColumn
                    property var ids: []
                    property string columnName: "center"
                    property real widthWeight: 1
                    visible: ids.length > 0 || root.editMode
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 100 * widthWeight
                    spacing: 12

                    Repeater {
                        model: widgetColumn.ids
                        delegate: Loader {
                            id: widgetLoader
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: root._fillIds.indexOf(modelData) !== -1
                            sourceComponent: root._widgetMap[modelData] ?? null
                            visible: sourceComponent !== null

                            // Edit-mode overlay: outlined scrim with move/hide
                            // controls. One object, fades with the mode.
                            Rectangle {
                                anchors.fill: parent
                                z: 5
                                radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                                    : root.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                                color: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.55)
                                border.width: 2
                                border.color: Appearance.colors.colPrimary
                                opacity: root.editMode ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }

                                MouseArea { anchors.fill: parent } // swallow clicks under the controls

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    EditButton {
                                        buttonIcon: "chevron_left"
                                        enabled: root._columnOrder.indexOf(widgetColumn.columnName) > 0
                                        onClicked: root.moveAcross(widgetLoader.modelData, widgetColumn.columnName, -1)
                                    }
                                    EditButton {
                                        buttonIcon: "keyboard_arrow_up"
                                        enabled: widgetLoader.index > 0
                                        onClicked: root.moveWithin(widgetColumn.columnName, widgetLoader.index, -1)
                                    }
                                    EditButton {
                                        buttonIcon: "keyboard_arrow_down"
                                        enabled: widgetLoader.index < widgetColumn.ids.length - 1
                                        onClicked: root.moveWithin(widgetColumn.columnName, widgetLoader.index, 1)
                                    }
                                    EditButton {
                                        buttonIcon: "chevron_right"
                                        enabled: root._columnOrder.indexOf(widgetColumn.columnName) < root._columnOrder.length - 1
                                        onClicked: root.moveAcross(widgetLoader.modelData, widgetColumn.columnName, 1)
                                    }
                                    EditButton {
                                        buttonIcon: "visibility_off"
                                        onClicked: root.hideWidget(widgetColumn.columnName, widgetLoader.index)
                                    }
                                }
                            }
                        }
                    }

                    // Soak up slack when no widget in this column fills
                    Item {
                        Layout.fillHeight: true
                        visible: !widgetColumn.ids.some(id => root._fillIds.indexOf(id) !== -1)
                    }
                }

                // Side/center weights follow the reference composition (27/46/27)
                WidgetColumn { ids: root.leftIds; columnName: "left"; widthWeight: 27 }
                WidgetColumn { ids: root.centerIds; columnName: "center"; widthWeight: 46 }
                WidgetColumn { ids: root.rightIds; columnName: "right"; widthWeight: 27 }
            }

            // Hidden-widget tray, only while editing: tap a chip to bring the
            // widget back into the emptiest column.
            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: root.editMode && root.hiddenIds.length > 0

                Repeater {
                    model: root.hiddenIds
                    delegate: RippleButton {
                        id: hiddenChip
                        required property string modelData
                        implicitHeight: 28
                        implicitWidth: chipRow.implicitWidth + 20
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: root.showWidget(modelData)
                        contentItem: RowLayout {
                            id: chipRow
                            spacing: 4
                            MaterialSymbol {
                                text: root._editIconMap[hiddenChip.modelData] ?? "widgets"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer2
                            }
                            MaterialSymbol {
                                text: "add"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }
            }
        }

        // Edit-mode toggle: morphs between edit and done
        RippleButton {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            z: 25
            implicitWidth: 40
            implicitHeight: 40
            buttonRadius: root.editMode ? Appearance.rounding.normal : Appearance.rounding.full
            Behavior on buttonRadius {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            colBackground: root.editMode ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
            colBackgroundHover: root.editMode ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
            colRipple: root.editMode ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer2Active
            onClicked: root.editMode = !root.editMode
            StyledToolTip { text: root.editMode ? Translation.tr("Done") : Translation.tr("Edit layout") }
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: root.editMode ? "done" : "edit"
                iconSize: Appearance.font.pixelSize.larger
                color: root.editMode ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Events dialog overlay (created on first use, covers the panel)
        Loader {
            id: agendaDialogLoader
            anchors.fill: parent
            z: 30
            active: root._agendaDialogLoaded
            sourceComponent: EventsDialog {}
            onLoaded: {
                item.show = Qt.binding(() => root._agendaDialogShown)
                if (root._agendaEditEvent) item.loadEvent(root._agendaEditEvent)
                else item.resetForm()
                item.forceActiveFocus()
            }
            Connections {
                target: agendaDialogLoader.item
                function onDismiss() { root._agendaDialogShown = false }
            }
        }
    }
}
