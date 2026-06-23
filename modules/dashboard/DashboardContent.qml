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

    // ═══ Shared events dialog (agenda + calendar widgets) ══════════════
    property var _agendaEditEvent: null
    property var _agendaPrefillDate: null
    property bool _agendaDialogShown: false
    property bool _agendaDialogLoaded: false
    // Accepts: an event object (edit), a Date (new event prefilled to that day),
    // or null (blank new event). Calendar day-clicks pass a Date; agenda rows
    // pass the event — both land in one shared dialog.
    function openAgendaDialog(arg) {
        const isDate = arg instanceof Date
        root._agendaEditEvent = (arg && !isDate) ? arg : null
        root._agendaPrefillDate = isDate ? arg : null
        root._agendaDialogLoaded = true
        if (agendaDialogLoader.item) {
            if (root._agendaEditEvent) agendaDialogLoader.item.loadEvent(root._agendaEditEvent)
            else {
                agendaDialogLoader.item.resetForm()
                if (root._agendaPrefillDate) agendaDialogLoader.item.eventDate = root._agendaPrefillDate
            }
        }
        root._agendaDialogShown = true
    }

    function _column(name, fallback) {
        // Respect a stored column even when empty (user cleared it in edit mode);
        // fall back only when the key is absent entirely.
        const a = Config.options?.dashboard?.layout?.[name]
        return Array.isArray(a) ? a : fallback
    }

    // ═══ In-panel edit mode ═════════════════════════════════════════════
    property bool editMode: false
    // Latches true the first time editing opens, so the editor sheet Loader
    // stays inactive (zero cost) until actually used.
    property bool _editSheetSeen: false
    onEditModeChanged: if (editMode) _editSheetSeen = true

    readonly property var leftIds: root._column("left", ["welcome", "clock", "system"])
    readonly property var centerIds: root._column("center", ["notifications", "todo"])
    readonly property var rightIds: root._column("right", ["media", "weather", "calendar"])

    Component { id: welcomeComponent; DashWelcome {} }
    Component { id: clockComponent; DashClock {} }
    Component { id: weatherComponent; DashWeather {} }
    Component {
        id: calendarComponent
        DashCalendar {
            onRequestEventsDialog: arg => root.openAgendaDialog(arg)
        }
    }
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

        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
            : root.angelEverywhere ? Appearance.angel.roundingLarge
            : root.inirEverywhere ? Appearance.inir.roundingLarge
            : Appearance.rounding.large

        border.width: Appearance.zzzEverywhere ? Appearance.zzz.borderThick : 1
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
                    : root.angelEverywhere ? Appearance.angel.colBorder
                    : root.inirEverywhere ? Appearance.inir.colBorder
                    : root.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : Appearance.colors.colLayer0Border

        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        clip: true

        // ZZZ: mask to rounded shape so children never re-square the corners.
        layer.enabled: root.useWallpaperBackdrop || (root.zzzEverywhere && !Appearance.gameModeMinimal)
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

        ZzzPanelBackdrop {
            anchors.fill: parent
            label: "AUTONOMIC STRIDER"
            index: "52"
            ghostText: "DASH"
            accentColor: Appearance.zzz.accent
            burstTriad: true
            showTicks: false
            showGrid: false
            horizontalBias: 0.1
            verticalBias: -0.06
            ghostWidthFactor: 0.78
            ghostStrength: 0.7
            z: 0
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
                            // Live widgets dim and stop taking input while editing;
                            // all layout changes happen in the DashLayoutEditor sheet.
                            opacity: root.editMode ? 0.5 : 1
                            enabled: !root.editMode
                            Behavior on opacity {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
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
        }

        // Edit sheet — the single drag-and-drop editor, shared with Settings.
        // Morphs up from the bottom edge over the dimmed live widgets; one
        // editing model wherever the user reaches it. Loaded on first edit.
        Loader {
            id: editSheetLoader
            anchors.fill: parent
            anchors.margins: 0
            z: 20
            active: root._editSheetSeen
            visible: opacity > 0
            opacity: root.editMode ? 1 : 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            sourceComponent: Item {
                anchors.fill: parent

                // Scrim catches outside clicks → exit edit mode.
                MouseArea { anchors.fill: parent; onClicked: root.editMode = false }

                Rectangle {
                    id: editSheet
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: root.angelEverywhere ? 12 : 14
                    height: Math.min(parent.height - 28, editScroll.contentHeight + editHeader.implicitHeight + 36)
                    radius: root.angelEverywhere ? Appearance.angel.roundingLarge
                        : root.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.large
                    color: root.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.colors.colLayer1
                    border.width: 1
                    border.color: root.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
                    // Grow from the bottom edge (origin) — organic morph.
                    transform: Translate { y: root.editMode ? 0 : 24 }
                    Behavior on height { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

                    StyledRectangularShadow { target: editSheet }

                    MouseArea { anchors.fill: parent } // swallow clicks inside the sheet

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        RowLayout {
                            id: editHeader
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol { text: "dashboard_customize"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colPrimary }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Customize dashboard")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        Flickable {
                            id: editScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: editorInner.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            DashLayoutEditor { id: editorInner; width: editScroll.width }
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
                else {
                    item.resetForm()
                    if (root._agendaPrefillDate) item.eventDate = root._agendaPrefillDate
                }
                item.forceActiveFocus()
            }
            Connections {
                target: agendaDialogLoader.item
                function onDismiss() { root._agendaDialogShown = false }
            }
        }
    }
}
