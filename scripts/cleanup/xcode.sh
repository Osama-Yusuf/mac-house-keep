#!/usr/bin/env bash
# xcode-cleanup.sh — clean Xcode DerivedData, old simulators, device support, previews, and caches

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../utils/common.sh
source "$SCRIPT_DIR/../utils/common.sh"

load_config
acquire_lock

trap 'send_email "Mac House Keep — Xcode Cleanup FAILED" "Xcode cleanup failed on $(hostname) at $(date). Check logs at: $LOG_FILE"' ERR

# --- Disk space before ---

get_disk_avail() {
    df -g / | awk 'NR==2 {print $4}'
}

SPACE_BEFORE=$(get_disk_avail)
log "=== Xcode Cleanup Starting ==="
log "Disk available before: ${SPACE_BEFORE}G"

SUMMARY=""

clean_dir() {
    local label="$1"
    local dir="$2"
    if [[ -d "$dir" ]]; then
        local size
        size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
        log "Cleaning $label ($size): $dir"
        rm -rf "$dir"/*
        SUMMARY+="$label: $size cleaned\n"
    else
        log "Skipping $label (not found): $dir"
        SUMMARY+="$label: not found\n"
    fi
}

# --- DerivedData (build artifacts — rebuilds on next build) ---

clean_dir "DerivedData" "$HOME/Library/Developer/Xcode/DerivedData"

# --- Archives (old .xcarchive bundles) ---

clean_dir "Archives" "$HOME/Library/Developer/Xcode/Archives"

# --- iOS Device Support (debug symbols per iOS version) ---

clean_dir "iOS Device Support" "$HOME/Library/Developer/Xcode/iOS DeviceSupport"

# --- watchOS Device Support ---

clean_dir "watchOS Device Support" "$HOME/Library/Developer/Xcode/watchOS DeviceSupport"

# --- tvOS Device Support ---

clean_dir "tvOS Device Support" "$HOME/Library/Developer/Xcode/tvOS DeviceSupport"

# --- CoreSimulator Caches ---

clean_dir "CoreSimulator Caches" "$HOME/Library/Developer/CoreSimulator/Caches"

# --- Xcode Previews (SwiftUI) ---

if command -v xcrun &>/dev/null; then
    log "Running: xcrun simctl --set previews delete all"
    output=$(xcrun simctl --set previews delete all 2>&1) || true
    log "Previews: $output"
    SUMMARY+="Previews: cleaned\n"
fi

# --- Delete unavailable simulator runtimes ---

if command -v xcrun &>/dev/null; then
    log "Running: xcrun simctl delete unavailable"
    output=$(xcrun simctl delete unavailable 2>&1) || true
    log "Unavailable simulators: $output"
    SUMMARY+="Unavailable simulators: cleaned\n"
fi

# --- Xcode Caches ---

clean_dir "Xcode Caches" "$HOME/Library/Caches/com.apple.dt.Xcode"

# --- Xcode Playground Data ---

clean_dir "Playground Data" "$HOME/Library/Developer/XCPGDevices"

# --- Disk space after ---

SPACE_AFTER=$(get_disk_avail)
RECLAIMED=$((SPACE_AFTER - SPACE_BEFORE))

log "Disk available after: ${SPACE_AFTER}G"
log "Space reclaimed: ~${RECLAIMED}G"
log "=== Xcode Cleanup Complete ==="

EMAIL_BODY="Xcode cleanup completed on $(hostname) at $(date).

Disk space before: ${SPACE_BEFORE}G available
Disk space after:  ${SPACE_AFTER}G available
Reclaimed:         ~${RECLAIMED}G

--- Details ---
$(echo -e "$SUMMARY")"

send_email "Mac House Keep — Xcode Cleanup Report" "$EMAIL_BODY"
