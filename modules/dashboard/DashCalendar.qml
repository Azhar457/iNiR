import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.calendar

/**
 * Calendar card. Reuses the sidebar month calendar (events included).
 */
DashCard {
    id: root

    CalendarWidget {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
    }
}
