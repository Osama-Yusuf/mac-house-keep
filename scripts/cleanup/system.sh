#!/usr/bin/env bash
# system-cleanup.sh — clean user caches, logs, crash reports, and Trash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../utils/common.sh
source "$SCRIPT_DIR/../utils/common.sh"

load_config
acquire_lock

trap 'send_email "Mac House Keep — System Cleanup FAILED" "System cleanup failed on $(hostname) at $(date). Check logs at: $LOG_FILE"' ERR

# --- Disk space before ---

get_disk_avail() {
    df -g / | awk 'NR==2 {print $4}'
}

SPACE_BEFORE=$(get_disk_avail)
log "=== System Cleanup Starting ==="
log "Disk available before: ${SPACE_BEFORE}G"

SUMMARY=""

safe_du() {
    du -sh "$1" 2>/dev/null | head -1 | awk '{print $1}' || echo "unknown"
}

clean_dir() {
    local label="$1"
    local dir="$2"
    if [[ -d "$dir" ]]; then
        local size
        size=$(safe_du "$dir")
        log "Cleaning $label ($size): $dir"
        rm -rf "$dir"/* 2>/dev/null || true
        SUMMARY+="$label: $size cleaned\n"
    else
        log "Skipping $label (not found): $dir"
        SUMMARY+="$label: not found\n"
    fi
}

# --- User Caches ---

CACHE_SIZE=$(safe_du "$HOME/Library/Caches")
log "User caches total before: $CACHE_SIZE"
SUMMARY+="User caches total: $CACHE_SIZE\n"
clean_dir "User Caches" "$HOME/Library/Caches"

# --- User Logs ---

clean_dir "User Logs" "$HOME/Library/Logs"

# --- Crash Reports ---

clean_dir "User Crash Reports" "$HOME/Library/Logs/DiagnosticReports"
clean_dir "System Crash Reports" "/Library/Logs/DiagnosticReports"

# --- Mail Logs (notorious space hog) ---

clean_dir "Mail Logs" "$HOME/Library/Containers/com.apple.mail/Data/Library/Logs"

# --- Trash ---

if [[ -d "$HOME/.Trash" ]]; then
    TRASH_SIZE=$(safe_du "$HOME/.Trash")
    log "Emptying Trash ($TRASH_SIZE)"
    rm -rf "$HOME/.Trash"/* 2>/dev/null || true
    SUMMARY+="Trash: $TRASH_SIZE emptied\n"
else
    SUMMARY+="Trash: empty\n"
fi

# --- Disk space after ---

SPACE_AFTER=$(get_disk_avail)
RECLAIMED=$((SPACE_AFTER - SPACE_BEFORE))

log "Disk available after: ${SPACE_AFTER}G"
log "Space reclaimed: ~${RECLAIMED}G"
log "=== System Cleanup Complete ==="

EMAIL_BODY="System cleanup completed on $(hostname) at $(date).

Disk space before: ${SPACE_BEFORE}G available
Disk space after:  ${SPACE_AFTER}G available
Reclaimed:         ~${RECLAIMED}G

--- Details ---
$(echo -e "$SUMMARY")"

send_email "Mac House Keep — System Cleanup Report" "$EMAIL_BODY"
