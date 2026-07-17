pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.sidebar
import qs.modules.sidebarLeft
import QtQuick
import Quickshell

Scope {
    id: root

    SidebarHost {
        edge: "left"
    }

    // Detached AI chat remains process-global and is owned by one wrapper only.
    Loader {
        active: GlobalStates.aiChatDetached
        sourceComponent: FloatingWindow {
            id: aiChatWindow
            visible: true
            title: "iNiR AI Chat"
            implicitWidth: 520
            implicitHeight: 780
            minimumSize: Qt.size(380, 400)
            color: Appearance.colors.colLayer0

            onVisibleChanged: {
                if (!visible)
                    GlobalStates.aiChatDetached = false
            }

            AiChat {
                anchors.fill: parent
                anchors.margins: 8
            }
        }
    }
}
