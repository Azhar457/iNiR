#!/usr/bin/env bash
# Instant dark<->light palette cache for iNiR's MaterialThemeLoader.
#
#   get <dark|light> : if a cached palette for <mode> was generated with the
#                      same generation key (wallpaper, seed, scheme, terminal
#                      params — everything except the mode), copy it over
#                      colors.json so the shell applies it instantly instead
#                      of waiting for a full regeneration. Exit 0 on hit,
#                      1 on miss (caller regenerates as usual).
#   put <dark|light> : called after a successful generation; stores the
#                      current colors.json as the cache for <mode>.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
GEN_DIR="$STATE_DIR/user/generated"
COLORS="$GEN_DIR/colors.json"
META="$GEN_DIR/theme-meta.json"

command -v jq >/dev/null 2>&1 || exit 1
[[ "${2:-}" == "dark" || "${2:-}" == "light" ]] || exit 1
mode="$2"
cache="$GEN_DIR/colors.$mode.json"
keyfile="$GEN_DIR/colors.$mode.key"

[[ -s "$META" ]] || exit 1
current_key="$(jq -r 'del(.mode)' "$META")"

case "${1:-}" in
    get)
        [[ -s "$cache" && -s "$keyfile" ]] || exit 1
        if [[ -z "$current_key" ]]; then exit 1; fi
        if ! printf '%s' "$current_key" | diff -q - "$keyfile" >/dev/null 2>&1; then
            exit 1
        fi
        # cache key matches the current generation identity -> instant swap
        cp "$cache" "$COLORS"
        echo "[mode-cache] instant swap: applied cached $mode palette"
        ;;
    put)
        [[ -s "$COLORS" ]] || exit 1
        mkdir -p "$GEN_DIR"
        printf '%s' "$current_key" > "$keyfile"
        cp "$COLORS" "$cache"
        ;;
    *)
        exit 1
        ;;
esac
