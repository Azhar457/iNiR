pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * Toast content for the morphing pill body: icon tile, app eyebrow, summary
 * with critical ember dot, optional body text and action pills, dismiss glyph
 * on the right. Draws no background of its own; the pill body behind it
 * provides the washi material. Clicking the body jumps to the source app;
 * dismiss and action pills consume their clicks. Auto-expires via
 * PillNotifs.expireAt unless the notification is critical.
 */
Item {
    id: root

    property real s: 1
    property bool live: true
    required property var notif

    /** iNiR exposes urgency as a string, not the Quickshell enum. */
    readonly property bool critical: String(notif.urgency) === "Critical"
    readonly property var acts: (notif.actions ?? []).filter(a => a.text.length > 0)

    implicitHeight: Math.max(iconTile.height, col.implicitHeight)

    /**
     * Deadline is snapshotted once: binding the interval to PillNotifs.expireAt
     * restarts the timer (and drifts the lifetime) every time an unrelated
     * notification replaces the map.
     */
    property double deadline: 0
    Component.onCompleted: deadline = PillNotifs.expireAt[notif.notificationId] || (Date.now() + 6000)

    Timer {
        interval: Math.max(300, root.deadline - Date.now())
        running: root.deadline > 0 && root.live && !root.critical
        onTriggered: PillNotifs.removePopup(root.notif)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            PillNotifs.activateNotif(root.notif);
            PillNotifs.removePopup(root.notif);
        }
    }

    Rectangle {
        id: iconTile
        anchors.left: parent.left
        anchors.top: parent.top
        width: 28 * root.s
        height: 28 * root.s
        radius: 9 * root.s
        color: PillTheme.tileBg
        border.width: 1
        border.color: PillTheme.border

        Image {
            id: toastImg
            anchors.fill: parent
            anchors.margins: root.notif.image ? 0 : 6 * root.s
            source: PillNotifs.iconFor(root.notif)
            sourceSize.width: 56
            sourceSize.height: 56
            fillMode: Image.PreserveAspectCrop
            smooth: true
            visible: source.toString().length > 0
        }

        Rectangle {
            anchors.centerIn: parent
            visible: !toastImg.visible
            width: 7 * root.s
            height: 7 * root.s
            radius: 2 * root.s
            rotation: 45
            color: root.critical ? PillTheme.vermLit : PillTheme.verm
        }
    }

    Text {
        id: dismiss
        anchors.right: parent.right
        anchors.top: parent.top
        text: "✕"
        color: dismissArea.containsMouse ? PillTheme.cream : PillTheme.dim
        font.family: PillTheme.font
        font.pixelSize: 11 * root.s

        Behavior on color {
            ColorAnimation { duration: PillMotion.fast }
        }

        MouseArea {
            id: dismissArea
            anchors.fill: parent
            anchors.margins: -6 * root.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: PillNotifs.removePopup(root.notif)
        }
    }

    Column {
        id: col
        anchors.left: iconTile.right
        anchors.leftMargin: 10 * root.s
        anchors.right: dismiss.left
        anchors.rightMargin: 8 * root.s
        anchors.top: parent.top
        spacing: 3 * root.s

        Text {
            width: parent.width
            text: (root.notif.appName && root.notif.appName.length) ? root.notif.appName : "System"
            color: PillTheme.dim
            font.family: PillTheme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.4 * root.s
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            spacing: 5 * root.s

            Item {
                visible: root.critical
                anchors.verticalCenter: parent.verticalCenter
                width: 8 * root.s
                height: 8 * root.s

                Rectangle {
                    anchors.centerIn: parent
                    width: 8 * root.s
                    height: 8 * root.s
                    radius: 999
                    color: PillTheme.flameGlow
                    opacity: 0.3
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 4 * root.s
                    height: 4 * root.s
                    radius: 999
                    color: PillTheme.flameGlow
                }
            }

            Text {
                width: parent.width - (root.critical ? 13 * root.s : 0)
                text: root.notif.summary
                color: PillTheme.cream
                font.family: PillTheme.font
                font.pixelSize: 11.5 * root.s
                font.weight: Font.DemiBold
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }

        Text {
            width: parent.width
            visible: root.notif.body.length > 0
            text: root.notif.body
            color: PillTheme.dim
            font.family: PillTheme.font
            font.pixelSize: 10.5 * root.s
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        Row {
            visible: root.acts.length > 0
            spacing: 6 * root.s
            topPadding: 4 * root.s

            Repeater {
                model: root.acts

                Rectangle {
                    id: actPill
                    required property var modelData
                    required property int index

                    height: 20 * root.s
                    width: actText.implicitWidth + 18 * root.s
                    radius: 999
                    color: PillTheme.tileBg
                    border.width: 1
                    border.color: PillTheme.border

                    Text {
                        id: actText
                        anchors.centerIn: parent
                        text: actPill.modelData.text
                        color: actPill.index === 0 ? PillTheme.vermLit : PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // iNiR's action objects are plain data; the server
                            // invokes them by id, they carry no invoke() of their own.
                            Notifications.attemptInvokeAction(root.notif.notificationId,
                                                              actPill.modelData.identifier);
                            if (actPill.modelData.identifier === "default")
                                PillNotifs.raiseWindow(root.notif);
                            PillNotifs.removePopup(root.notif);
                        }
                    }
                }
            }
        }
    }
}
