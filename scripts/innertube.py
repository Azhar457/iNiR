#!/usr/bin/env python3
"""
InnerTube browsing helper for iNiR — wraps `ytmusicapi` (the InnerTube API client).
Replaces the flaky yt-dlp + browser-cookie path for search/browse/radio/lyrics.
Public browsing needs NO cookies; auth (oauth file) only enables personalized results.

Protocol mirrors ytmusic_rate.py: a subcommand prints JSON (or JSONL + a final
{"_done":true,"count":N} for paged streams) to stdout; errors print
{"error":...} and exit 1.

Usage:
  innertube.py ping
  innertube.py search <query> [filter]      # filter: songs|videos|albums|artists|playlists
  innertube.py home [limit]
  innertube.py radio <videoId>              # autoplay watch-playlist
  innertube.py artist <browseId>
  innertube.py album <browseId>
  innertube.py playlist <playlistId>
  innertube.py lyrics <videoId>
  innertube.py song <videoId>
"""
import sys
import json
import os

OAUTH_PATH = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "illogical-impulse", "ytmusic_oauth.json"
)


def _fail(msg, detail=""):
    out = {"error": str(msg)}
    if detail:
        out["detail"] = str(detail)[:300]
    print(json.dumps(out))
    sys.exit(1)


def _client():
    """Construct a YTMusic client — authenticated if an oauth file exists, else public."""
    try:
        from ytmusicapi import YTMusic
    except ImportError:
        _fail("ytmusicapi not installed")
    # Public browsing works fully unauthenticated. Auth only adds personalization;
    # an invalid/expired oauth file must never break public browsing, so fall back.
    if os.path.exists(OAUTH_PATH):
        try:
            return YTMusic(OAUTH_PATH)
        except Exception:
            pass
    return YTMusic()


def _best_thumb(thumbs):
    if not thumbs:
        return ""
    try:
        return max(thumbs, key=lambda t: t.get("width", 0) * t.get("height", 0)).get("url", "")
    except Exception:
        return thumbs[-1].get("url", "") if thumbs else ""


def _parse_duration(item):
    """Return integer seconds from ytmusicapi's duration_seconds or 'mm:ss' string."""
    secs = item.get("duration_seconds")
    if isinstance(secs, int):
        return secs
    dur = item.get("duration")
    if isinstance(dur, str) and ":" in dur:
        parts = [int(p) for p in dur.split(":") if p.isdigit()]
        out = 0
        for p in parts:
            out = out * 60 + p
        return out
    return 0


def _artists(item):
    arts = item.get("artists") or []
    names = [a.get("name", "") for a in arts if a.get("name")]
    return ", ".join(names)


def _track(item):
    """Normalize a song/video into iNiR's track shape."""
    vid = item.get("videoId") or ""
    album = item.get("album") or {}
    return {
        "type": "song",
        "videoId": vid,
        "title": item.get("title", ""),
        "artist": _artists(item),
        "thumbnail": _best_thumb(item.get("thumbnails")),
        "duration": _parse_duration(item),
        "url": f"https://music.youtube.com/watch?v={vid}" if vid else "",
        "album": album.get("name", "") if isinstance(album, dict) else "",
        "albumId": album.get("id", "") if isinstance(album, dict) else "",
    }


def _card(item):
    """Normalize any home/browse card (song, album, playlist, artist) by what id it carries."""
    if item.get("videoId"):
        return _track(item)
    if item.get("playlistId") or item.get("browseId"):
        bid = item.get("browseId", "") or ""
        # YouTube browseId prefixes are stable: UC…=artist, MPREb…=album, else playlist.
        if item.get("subscribers") is not None or item.get("type") == "artist" or bid.startswith("UC"):
            kind = "artist"
        elif item.get("type") == "album" or bid.startswith("MPREb"):
            kind = "album"
        else:
            kind = "playlist"
        return {
            "type": kind,
            "title": item.get("title") or item.get("artist", ""),
            "subtitle": _artists(item) or item.get("description", ""),
            "thumbnail": _best_thumb(item.get("thumbnails")),
            "browseId": item.get("browseId", ""),
            "playlistId": item.get("playlistId", ""),
        }
    return _track(item)


# ---- subcommands ----

def cmd_ping():
    try:
        import ytmusicapi
        _client()  # touch construction so a broken network surfaces here
        print(json.dumps({"available": True, "version": ytmusicapi.__version__}))
    except SystemExit:
        raise
    except Exception as e:
        print(json.dumps({"available": False, "error": str(e)[:200]}))


def cmd_search(query, filter_=None):
    yt = _client()
    valid = {"songs", "videos", "albums", "artists", "playlists", "community_playlists", "featured_playlists"}
    f = filter_ if filter_ in valid else "songs"
    try:
        results = yt.search(query, filter=f, limit=25)
    except Exception as e:
        _fail("search failed", e)
    count = 0
    for item in results:
        card = _card(item)
        if card.get("type") == "song" and not card.get("videoId"):
            continue
        print(json.dumps(card), flush=True)
        count += 1
    print(json.dumps({"_done": True, "count": count}), flush=True)


def cmd_home(limit=None):
    yt = _client()
    try:
        shelves = yt.get_home(limit=int(limit) if limit else 3)
    except Exception as e:
        _fail("home failed", e)
    out = []
    for shelf in shelves:
        items = [_card(c) for c in shelf.get("contents", []) if c]
        out.append({"title": shelf.get("title", ""), "items": items})
    print(json.dumps({"shelves": out}))


def cmd_radio(video_id):
    yt = _client()
    try:
        wp = yt.get_watch_playlist(videoId=video_id, limit=50)
    except Exception as e:
        _fail("radio failed", e)
    print(json.dumps({"lyricsId": wp.get("lyrics") or "", "_meta": True}), flush=True)
    count = 0
    for t in wp.get("tracks", []):
        card = _track(t)
        if not card.get("videoId"):
            continue
        print(json.dumps(card), flush=True)
        count += 1
    print(json.dumps({"_done": True, "count": count}), flush=True)


def cmd_artist(browse_id):
    yt = _client()
    try:
        a = yt.get_artist(browse_id)
    except Exception as e:
        _fail("artist failed", e)
    songs = [_track(s) for s in (a.get("songs", {}) or {}).get("results", [])]
    albums = [_card(s) for s in (a.get("albums", {}) or {}).get("results", [])]
    singles = [_card(s) for s in (a.get("singles", {}) or {}).get("results", [])]
    print(json.dumps({
        "name": a.get("name", ""),
        "description": a.get("description", ""),
        "thumbnail": _best_thumb(a.get("thumbnails")),
        "songs": songs,
        "albums": albums,
        "singles": singles,
    }))


def cmd_album(browse_id):
    yt = _client()
    try:
        al = yt.get_album(browse_id)
    except Exception as e:
        _fail("album failed", e)
    tracks = [_track(t) for t in al.get("tracks", [])]
    print(json.dumps({
        "title": al.get("title", ""),
        "artist": _artists(al),
        "year": al.get("year", ""),
        "thumbnail": _best_thumb(al.get("thumbnails")),
        "trackCount": al.get("trackCount", len(tracks)),
        "tracks": tracks,
    }))


def cmd_playlist(playlist_id):
    yt = _client()
    try:
        pl = yt.get_playlist(playlist_id, limit=200)
    except Exception as e:
        _fail("playlist failed", e)
    print(json.dumps({
        "title": pl.get("title", ""),
        "thumbnail": _best_thumb(pl.get("thumbnails")),
        "trackCount": pl.get("trackCount", 0),
        "_meta": True,
    }), flush=True)
    count = 0
    for t in pl.get("tracks", []):
        card = _track(t)
        if not card.get("videoId"):
            continue
        print(json.dumps(card), flush=True)
        count += 1
    print(json.dumps({"_done": True, "count": count}), flush=True)


def _parse_lrc(lrc):
    """Parse LRC text into [{t: seconds, line: str}] sorted by time."""
    import re
    out = []
    tag = re.compile(r"\[(\d+):(\d+)(?:[.:](\d+))?\]")
    for raw in lrc.splitlines():
        stamps = list(tag.finditer(raw))
        if not stamps:
            continue
        text = raw[stamps[-1].end():].strip()
        for m in stamps:
            mins = int(m.group(1)); secs = int(m.group(2))
            frac = m.group(3)
            t = mins * 60 + secs + (int(frac) / (1000.0 if len(frac) == 3 else 100.0) if frac else 0)
            out.append({"t": round(t, 2), "line": text})
    out.sort(key=lambda x: x["t"])
    return out


def _lrclib_synced(title, artist, duration):
    """Fetch synced lyrics from LrcLib (public, no auth). Returns LRC text or None."""
    import urllib.request, urllib.parse
    q = urllib.parse.urlencode({"track_name": title, "artist_name": artist})
    req = urllib.request.Request("https://lrclib.net/api/search?" + q,
                                 headers={"User-Agent": "iNiR (https://github.com/snowarch/inir)"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            tracks = json.loads(resp.read())
    except Exception:
        return None
    candidates = [t for t in tracks if t.get("syncedLyrics")]
    if not candidates:
        return None
    if duration > 0:
        candidates.sort(key=lambda t: abs((t.get("duration") or 0) - duration))
    return candidates[0].get("syncedLyrics")


def cmd_lyrics(video_id, title="", artist="", duration="0"):
    try:
        dur = int(float(duration or 0))
    except ValueError:
        dur = 0
    # Prefer LrcLib synced lyrics (what InnerTune shows), like InnerTune's lrclib module.
    synced = None
    if title and artist:
        lrc = _lrclib_synced(title, artist, dur)
        if lrc:
            synced = _parse_lrc(lrc)
    # Fall back to ytmusicapi plain lyrics.
    plain = ""
    source = "LrcLib" if synced else ""
    try:
        yt = _client()
        wp = yt.get_watch_playlist(videoId=video_id, limit=1)
        lid = wp.get("lyrics")
        if lid:
            ly = yt.get_lyrics(lid)
            plain = ly.get("lyrics") or ""
            if not source:
                source = ly.get("source") or ""
    except Exception:
        pass
    print(json.dumps({"plain": plain, "synced": synced, "source": source}))


def cmd_song(video_id):
    yt = _client()
    try:
        s = yt.get_song(video_id)
    except Exception as e:
        _fail("song failed", e)
    vd = (s.get("videoDetails") or {})
    print(json.dumps({
        "videoId": vd.get("videoId", video_id),
        "title": vd.get("title", ""),
        "artist": vd.get("author", ""),
        "thumbnail": _best_thumb((vd.get("thumbnail") or {}).get("thumbnails")),
        "duration": int(vd.get("lengthSeconds", 0) or 0),
        "url": f"https://music.youtube.com/watch?v={video_id}",
    }))


_COMMANDS = {
    "ping": (cmd_ping, 0),
    "search": (cmd_search, 1),       # +optional filter
    "home": (cmd_home, 0),           # +optional limit
    "radio": (cmd_radio, 1),
    "artist": (cmd_artist, 1),
    "album": (cmd_album, 1),
    "playlist": (cmd_playlist, 1),
    "lyrics": (cmd_lyrics, 1),
    "song": (cmd_song, 1),
}


def main():
    if len(sys.argv) < 2:
        _fail("Usage: innertube.py <command> [args]")
    action = sys.argv[1]
    entry = _COMMANDS.get(action)
    if not entry:
        _fail(f"Unknown command: {action}")
    fn, _min = entry
    args = sys.argv[2:]
    if len(args) < _min:
        _fail(f"'{action}' needs {_min} argument(s)")
    fn(*args[: fn.__code__.co_argcount])


if __name__ == "__main__":
    main()
