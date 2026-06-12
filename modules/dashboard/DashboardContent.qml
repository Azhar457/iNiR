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
    })
    // Widgets that absorb the column's remaining height
    readonly property var _fillIds: ["notifications", "todo"]

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
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

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
                    property real widthWeight: 1
                    visible: ids.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 100 * widthWeight
                    spacing: 12

                    Repeater {
                        model: widgetColumn.ids
                        delegate: Loader {
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: root._fillIds.indexOf(modelData) !== -1
                            sourceComponent: root._widgetMap[modelData] ?? null
                            visible: sourceComponent !== null
                        }
                    }

                    // Soak up slack when no widget in this column fills
                    Item {
                        Layout.fillHeight: true
                        visible: !widgetColumn.ids.some(id => root._fillIds.indexOf(id) !== -1)
                    }
                }

                // Side/center weights follow the reference composition (27/46/27)
                WidgetColumn { ids: root.leftIds; widthWeight: 27 }
                WidgetColumn { ids: root.centerIds; widthWeight: 46 }
                WidgetColumn { ids: root.rightIds; widthWeight: 27 }
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
