#!/usr/bin/env bash
# app-caches.sh — clean browser and Electron app caches that live outside ~/Library/Caches
# (Service Worker storage, Code Cache, GPU caches under ~/Library/Application Support).
# Apps that are currently running are skipped and picked up on the next run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../utils/common.sh
source "$SCRIPT_DIR/../utils/common.sh"

load_config
acquire_lock

trap 'send_email "Mac House Keep — App Caches Cleanup FAILED" "App caches cleanup failed on $(hostname) at $(date). Check logs at: $LOG_FILE"' ERR

shopt -s nullglob

AS="$HOME/Library/Application Support"

# --- Disk space before ---

get_disk_avail() {
    df -g / | awk 'NR==2 {print $4}'
}

SPACE_BEFORE=$(get_disk_avail)
log "=== App Caches Cleanup Starting ==="
log "Disk available before: ${SPACE_BEFORE}G"

SUMMARY=""

# Clean the given cache dirs for an app, but only if the app is not running —
# deleting Service Worker storage under a live app can break its open pages.
clean_app() {
    local label="$1"
    local proc="$2"
    shift 2

    if pgrep -f "$proc" &>/dev/null; then
        log "Skipping $label (currently running)"
        SUMMARY+="$label: skipped (running)\n"
        return 0
    fi

    local cleaned=0
    local dir size
    for dir in "$@"; do
        [[ -d "$dir" ]] || continue
        size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
        log "Cleaning $label ($size): $dir"
        rm -rf "$dir" 2>/dev/null || true
        SUMMARY+="$label: $size cleaned ($(basename "$dir"))\n"
        cleaned=1
    done

    if [[ $cleaned -eq 0 ]]; then
        log "Skipping $label (no cache dirs found)"
        SUMMARY+="$label: nothing to clean\n"
    fi
}

# --- Chromium-family browsers (per-profile Service Worker storage + compiled JS cache) ---

clean_app "Google Chrome" "Google Chrome.app" \
    "$AS/Google/Chrome/"*/"Service Worker/CacheStorage" \
    "$AS/Google/Chrome/"*/"Code Cache" \
    "$AS/Google/Chrome/GrShaderCache" \
    "$AS/Google/Chrome/ShaderCache"

clean_app "Brave" "Brave Browser.app" \
    "$AS/BraveSoftware/Brave-Browser/"*/"Service Worker/CacheStorage" \
    "$AS/BraveSoftware/Brave-Browser/"*/"Code Cache" \
    "$AS/BraveSoftware/Brave-Browser/GrShaderCache"

clean_app "Microsoft Edge" "Microsoft Edge.app" \
    "$AS/Microsoft Edge/"*/"Service Worker/CacheStorage" \
    "$AS/Microsoft Edge/"*/"Code Cache"

clean_app "Arc" "Arc.app" \
    "$AS/Arc/User Data/"*/"Service Worker/CacheStorage" \
    "$AS/Arc/User Data/"*/"Code Cache"

# --- Electron / desktop apps ---

clean_app "Slack" "Slack.app" \
    "$AS/Slack/Cache" \
    "$AS/Slack/Code Cache" \
    "$AS/Slack/GPUCache" \
    "$AS/Slack/Service Worker/CacheStorage"

clean_app "Discord" "Discord.app" \
    "$AS/discord/Cache" \
    "$AS/discord/Code Cache" \
    "$AS/discord/GPUCache"

clean_app "Notion" "Notion.app" \
    "$AS/Notion/Partitions/"*/Cache \
    "$AS/Notion/Partitions/"*/"Code Cache" \
    "$AS/Notion/Partitions/"*/GPUCache \
    "$AS/Notion/Partitions/"*/"Service Worker/CacheStorage"

clean_app "Figma" "Figma.app" \
    "$AS/Figma/Cache" \
    "$AS/Figma/Code Cache" \
    "$AS/Figma/GPUCache"

clean_app "Postman" "Postman.app" \
    "$AS/Postman/Partitions/"*/Cache \
    "$AS/Postman/Partitions/"*/"Code Cache" \
    "$AS/Postman/Partitions/"*/GPUCache

clean_app "Spotify" "Spotify.app" \
    "$AS/Spotify/PersistentCache"

# --- Editors ---

clean_app "VS Code" "Visual Studio Code.app" \
    "$AS/Code/Cache" \
    "$AS/Code/CachedData" \
    "$AS/Code/Code Cache" \
    "$AS/Code/GPUCache" \
    "$AS/Code/CachedExtensionVSIXs" \
    "$AS/Code/Service Worker/CacheStorage" \
    "$AS/Code/logs"

clean_app "Cursor" "Cursor.app" \
    "$AS/Cursor/Cache" \
    "$AS/Cursor/CachedData" \
    "$AS/Cursor/Code Cache" \
    "$AS/Cursor/GPUCache" \
    "$AS/Cursor/Service Worker/CacheStorage" \
    "$AS/Cursor/logs"

clean_app "Windsurf" "Windsurf.app" \
    "$AS/Windsurf/Cache" \
    "$AS/Windsurf/CachedData" \
    "$AS/Windsurf/Code Cache" \
    "$AS/Windsurf/GPUCache" \
    "$AS/Windsurf/CachedExtensionVSIXs" \
    "$AS/Windsurf/logs"

clean_app "Kiro" "Kiro.app" \
    "$AS/Kiro/Cache" \
    "$AS/Kiro/CachedData" \
    "$AS/Kiro/Code Cache" \
    "$AS/Kiro/GPUCache" \
    "$AS/Kiro/CachedExtensionVSIXs" \
    "$AS/Kiro/logs"

# --- Media ---

clean_app "Stremio" "[Ss]tremio" \
    "$AS/stremio-server/stremio-cache"

# --- Disk space after ---

SPACE_AFTER=$(get_disk_avail)
RECLAIMED=$((SPACE_AFTER - SPACE_BEFORE))

log "Disk available after: ${SPACE_AFTER}G"
log "Space reclaimed: ~${RECLAIMED}G"
log "=== App Caches Cleanup Complete ==="

EMAIL_BODY="App caches cleanup completed on $(hostname) at $(date).

Disk space before: ${SPACE_BEFORE}G available
Disk space after:  ${SPACE_AFTER}G available
Reclaimed:         ~${RECLAIMED}G

--- Details ---
$(echo -e "$SUMMARY")"

send_email "Mac House Keep — App Caches Cleanup Report" "$EMAIL_BODY"
