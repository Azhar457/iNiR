pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// InnerTube browsing engine — wraps scripts/innertube.py (ytmusicapi).
// Public browsing needs NO cookies; replaces the flaky yt-dlp + browser-cookie path.
// Playback stays in YtMusic.qml (mpv/MPRIS); this service only fetches metadata.
//
// Each command has its own Process so independent surfaces (e.g. search from the UI and
// radio autoplay) never race over shared parser state.
Singleton {
    id: root

    readonly property bool enabled: Config.options?.sidebar?.ytmusic?.enable ?? false
    property bool ready: false
    property bool available: false   // ytmusicapi importable (probed via ping)

    // Per-surface results (InnerTune screens map onto these).
    property var searchResults: []
    property var homeShelves: []
    property var radioTracks: []
    property var artistPage: ({})
    property var albumPage: ({})
    property var playlistPage: ({})
    property var lyrics: ({})
    property string radioLyricsId: ""

    property bool searching: false
    property bool homeLoading: false
    property bool radioLoading: false
    property bool browseLoading: false
    property string error: ""

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log("[InnerTube]", ...args);
    }

    readonly property string _script: Directories.scriptPath + "/innertube.py"

    Component.onCompleted: {
        // P0-13: feature-gated singleton must short-circuit when disabled.
        if (!root.enabled) {
            root.ready = true;
            return;
        }
        _pingProc.running = true;
        root.ready = true;
    }

    // ---- ping (availability probe) ----
    Process {
        id: _pingProc
        command: ["python3", root._script, "ping"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    root.available = !!d.available;
                    if (!d.available) root._log("unavailable:", d.error);
                } catch (e) {
                    root.available = false;
                }
            }
        }
    }

    // Reusable JSONL parser factory state holder. Each streaming Process accumulates into
    // its own buffer, then commits on the {_done} sentinel.
    component StreamCollector: SplitParser {
        property var buffer: []
        property string lyricsId: ""
        signal finished(var items, string lyricsId)
        onRead: (line) => {
            if (!line) return;
            let obj;
            try { obj = JSON.parse(line); } catch (e) { return; }
            if (obj._meta) { if (obj.lyricsId !== undefined) lyricsId = obj.lyricsId; return; }
            if (obj.error) { root.error = obj.error; return; }
            if (obj._done) { finished(buffer, lyricsId); buffer = []; lyricsId = ""; return; }
            buffer.push(obj);
        }
    }

    // ---- search ----
    function search(query, filter): void {
        if (!query || !root.available) return;
        root.error = "";
        root.searching = true;
        _searchProc.exec(["python3", root._script, "search", query, filter || "songs"]);
    }
    Process {
        id: _searchProc
        stdout: StreamCollector { onFinished: (items) => { root.searchResults = items; root.searching = false; } }
    }

    // ---- radio (autoplay watch-playlist) ----
    function loadRadio(videoId): void {
        if (!videoId || !root.available) return;
        root.error = "";
        root.radioLoading = true;
        root.radioLyricsId = "";
        _radioProc.exec(["python3", root._script, "radio", videoId]);
    }
    Process {
        id: _radioProc
        stdout: StreamCollector {
            onFinished: (items, lid) => { root.radioTracks = items; root.radioLyricsId = lid; root.radioLoading = false; }
        }
    }

    // ---- playlist ----
    function loadPlaylist(playlistId): void {
        if (!playlistId || !root.available) return;
        root.error = "";
        root.browseLoading = true;
        _playlistProc.exec(["python3", root._script, "playlist", playlistId]);
    }
    Process {
        id: _playlistProc
        stdout: StreamCollector { onFinished: (items) => { root.playlistPage = { tracks: items }; root.browseLoading = false; } }
    }

    // ---- home ----
    function loadHome(): void {
        if (!root.available) return;
        root.error = "";
        root.homeLoading = true;
        _homeProc.exec(["python3", root._script, "home"]);
    }
    Process {
        id: _homeProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.homeLoading = false;
                try {
                    const d = JSON.parse(this.text);
                    if (d.error) { root.error = d.error; return; }
                    root.homeShelves = d.shelves || [];
                } catch (e) { root.error = "home parse error"; }
            }
        }
    }

    // ---- artist ----
    function loadArtist(browseId): void {
        if (!browseId || !root.available) return;
        root.error = "";
        root.browseLoading = true;
        _artistProc.exec(["python3", root._script, "artist", browseId]);
    }
    Process {
        id: _artistProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.browseLoading = false;
                try {
                    const d = JSON.parse(this.text);
                    if (d.error) { root.error = d.error; return; }
                    root.artistPage = d;
                } catch (e) { root.error = "artist parse error"; }
            }
        }
    }

    // ---- album ----
    function loadAlbum(browseId): void {
        if (!browseId || !root.available) return;
        root.error = "";
        root.browseLoading = true;
        _albumProc.exec(["python3", root._script, "album", browseId]);
    }
    Process {
        id: _albumProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.browseLoading = false;
                try {
                    const d = JSON.parse(this.text);
                    if (d.error) { root.error = d.error; return; }
                    root.albumPage = d;
                } catch (e) { root.error = "album parse error"; }
            }
        }
    }

    // ---- lyrics ----
    function loadLyrics(videoId, title, artist, duration): void {
        if (!videoId || !root.available) return;
        _lyricsProc.exec(["python3", root._script, "lyrics", videoId,
                          title || "", artist || "", String(Math.round(duration || 0))]);
    }
    Process {
        id: _lyricsProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    if (!d.error) root.lyrics = d;
                } catch (e) {}
            }
        }
    }
}
