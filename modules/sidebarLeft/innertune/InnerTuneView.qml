pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.deferred
import qs.modules.sidebarLeft.innertune

// Top-level InnerTune surface for the ii sidebar — modeled on the InnerTune Android app:
// a search app-bar, a Home/Search body, a bottom NavigationBar (Home/Songs/Artists/
// Albums/Playlists), the MiniPlayer above it, and a full Player that expands over all.
// Browse data comes from InnerTube (no cookies); playback flows through YtMusic.
Item {
    id: root
    property alias inputField: searchField   // sidebar focus contract

    property string route: "home"
    readonly property bool searchMode: searchField.text.trim().length > 0
    property bool playerExpanded: false
    property string detail: ""        // "" | "album" | "artist"

    property bool _homeLoaded: false
    onVisibleChanged: if (visible) _ensureHome()
    Component.onCompleted: if (visible) _ensureHome()
    function _ensureHome() {
        if (_homeLoaded || !InnerTube.available) return;
        _homeLoaded = true;
        InnerTube.loadHome();
    }
    Connections {
        target: InnerTube
        function onAvailableChanged() { if (InnerTube.available && root.visible) root._ensureHome(); }
        // Playlists (from Home cards) play directly; albums/artists open a detail screen.
        function onPlaylistPageChanged() {
            const t = InnerTube.playlistPage?.tracks;
            if (t && t.length > 0) YtMusic.playFromPlaylist(t, 0, "playlist");
        }
    }
    function openAlbum(browseId) { InnerTube.loadAlbum(browseId); root.detail = "album"; }
    function openArtist(browseId) { InnerTube.loadArtist(browseId); root.detail = "artist"; }

    // ===== Main column: search bar · body · mini-player · nav bar =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Search app bar + account button.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: ITDimens.appBarHeight
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 4
            MaterialTextField {
                id: searchField
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                placeholderText: Translation.tr("Search songs, albums, artists")
                onAccepted: if (text.trim().length > 0) YtMusic.search(text.trim())
            }
            ITIconButton {
                Layout.alignment: Qt.AlignVCenter
                symbol: InnerTube.authenticated ? "account_circle" : "account_circle"
                color: InnerTube.authenticated ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurfaceVariant
                onClicked: root.detail = (root.detail === "account" ? "" : "account")
            }
        }

        // Body.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            InnerTuneHome {
                anchors.fill: parent
                opacity: (!root.searchMode && root.route === "home" && root.detail === "") ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) } }
                onPlayRequested: (item) => YtMusic.play(Object.assign({}, item, { enableRelatedQueue: true }))
                onAlbumRequested: (browseId) => root.openAlbum(browseId)
                onPlaylistRequested: (playlistId) => InnerTube.loadPlaylist(playlistId)
                onArtistRequested: (browseId) => root.openArtist(browseId)
            }

            // Opaque backing behind detail screens.
            Rectangle {
                anchors.fill: parent
                visible: root.detail !== ""
                color: Appearance.m3colors.m3background
            }

            // Album detail.
            ITAlbumScreen {
                anchors.fill: parent
                visible: root.detail === "album"
                album: InnerTube.albumPage
                onBackRequested: root.detail = ""
                onPlayRequested: (index, shuffle) => {
                    const t = InnerTube.albumPage?.tracks ?? [];
                    if (shuffle) YtMusic.shuffleMode = true;
                    if (t.length > 0) YtMusic.playFromPlaylist(t, index, "album");
                }
            }

            // Artist detail.
            ITArtistScreen {
                anchors.fill: parent
                visible: root.detail === "artist"
                artist: InnerTube.artistPage
                onBackRequested: root.detail = ""
                onPlaySong: (index) => {
                    const s = InnerTube.artistPage?.songs ?? [];
                    if (s.length > 0) YtMusic.playFromPlaylist(s, index, "artist");
                }
                onShuffleRequested: {
                    const s = InnerTube.artistPage?.songs ?? [];
                    if (s.length > 0) { YtMusic.shuffleMode = true; YtMusic.playFromPlaylist(s, 0, "artist"); }
                }
                onRadioRequested: {
                    const s = InnerTube.artistPage?.songs ?? [];
                    if (s.length > 0) YtMusic.play(Object.assign({}, s[0], { enableRelatedQueue: true }));
                }
                onAlbumRequested: (browseId) => root.openAlbum(browseId)
            }

            // Account / login.
            ITAccountScreen {
                anchors.fill: parent
                visible: root.detail === "account"
                onBackRequested: root.detail = ""
            }

            InnerTuneSearch {
                anchors.fill: parent
                results: YtMusic.searchResults
                opacity: (root.searchMode && root.detail === "") ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) } }
                onPlayRequested: (index) => YtMusic.playFromSearch(index)
            }

            // Library routes (Songs/Artists/Albums/Playlists) need account data — placeholder.
            StyledText {
                anchors.centerIn: parent
                visible: !root.searchMode && root.route !== "home" && root.detail === ""
                text: Translation.tr("Sign in to see your library")
                color: Appearance.m3colors.m3onSurfaceVariant
            }
        }

        // Mini player (above nav bar).
        ITMiniPlayer {
            Layout.fillWidth: true
            visible: YtMusic.currentVideoId !== "" && !root.playerExpanded
            onExpandRequested: root.playerExpanded = true
        }

        // Bottom navigation bar.
        ITNavigationBar {
            Layout.fillWidth: true
            currentRoute: root.route
            onSelected: (r) => { root.route = r; searchField.text = ""; }
        }
    }

    // ===== Full player overlay (slides up over everything) =====
    ITPlayer {
        id: player
        width: parent.width
        height: parent.height
        y: root.playerExpanded ? 0 : parent.height
        visible: y < parent.height
        onCollapseRequested: root.playerExpanded = false
        Behavior on y {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveEnter.duration)
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
    }
}
