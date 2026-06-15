import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.deferred
import qs.modules.sidebarLeft.innertune

// Account / login surface (translates LoginScreen.kt + AccountScreen.kt). Signed-out shows a
// one-tap device-flow sign-in (YouTube-TV client → youtube.com/activate); signed-in shows the
// account and a sign-out. Auth is owned by InnerTube; personalized home/library follow.
StyledFlickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    signal backRequested()

    ColumnLayout {
        id: column
        width: root.width
        spacing: 0

        // Back chevron.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: ITDimens.appBarHeight
            ITIconButton {
                anchors.verticalCenter: parent.verticalCenter
                x: 8
                symbol: "arrow_back"
                onClicked: root.backRequested()
            }
        }

        // Hero icon.
        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 24
            text: InnerTube.authenticated ? "account_circle" : "account_circle"
            iconSize: 96
            fill: InnerTube.authenticated ? 1 : 0
            color: Appearance.m3colors.m3primary
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            text: InnerTube.authenticated
                ? (InnerTube.accountName || Translation.tr("Signed in"))
                : Translation.tr("Sign in to YouTube Music")
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.title
            font.weight: Font.Bold
            color: Appearance.m3colors.m3onSurface
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: !InnerTube.authenticated && !InnerTube.loggingIn
            text: Translation.tr("Personalized home, your library, liked songs and playlists.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.m3colors.m3onSurfaceVariant
        }

        // Device-code panel (while logging in).
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.fillWidth: true
            visible: InnerTube.loggingIn
            implicitHeight: codeCol.implicitHeight + 32
            radius: Appearance.rounding.normal
            color: Appearance.m3colors.m3secondaryContainer

            ColumnLayout {
                id: codeCol
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 6
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("Go to %1 and enter:").arg(InnerTube.loginVerificationUrl || "google.com/device")
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: InnerTube.loginUserCode || "…"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.Bold
                    color: Appearance.m3colors.m3primary
                }
                MaterialLoadingIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                }
            }
        }

        // Action button.
        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            buttonRadius: Appearance.rounding.full
            colBackground: InnerTube.authenticated ? "transparent" : Appearance.m3colors.m3primary
            materialIcon: InnerTube.authenticated ? "logout" : (InnerTube.loggingIn ? "open_in_new" : "login")
            mainText: InnerTube.authenticated ? Translation.tr("Sign out")
                : (InnerTube.loggingIn ? Translation.tr("Open page") : Translation.tr("Sign in"))
            releaseAction: () => {
                if (InnerTube.authenticated) InnerTube.logout();
                else if (InnerTube.loggingIn) Qt.openUrlExternally(InnerTube.loginVerificationUrl || "https://www.google.com/device");
                else InnerTube.startLogin();
            }
        }
        // Cancel during login.
        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            visible: InnerTube.loggingIn
            buttonRadius: Appearance.rounding.full
            colBackground: "transparent"
            materialIcon: "close"
            mainText: Translation.tr("Cancel")
            releaseAction: () => InnerTube.cancelLogin()
        }

        Item { Layout.preferredHeight: 24 }
    }
}
