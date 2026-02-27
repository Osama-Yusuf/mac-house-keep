#!/usr/bin/env bash
# homebrew-cleanup.sh — clean Homebrew cached downloads, old versions, and orphaned deps

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_config
acquire_lock

trap 'send_email "Mac House Keep — Homebrew Cleanup FAILED" "Homebrew cleanup failed on $(hostname) at $(date). Check logs at: $LOG_FILE"' ERR

# --- Check Homebrew is installed ---

if ! command -v brew &>/dev/null; then
    log "Homebrew is not installed — skipping."
    send_email \
        "Mac House Keep — Homebrew Cleanup Warning" \
        "Homebrew cleanup skipped: brew not found on $(hostname)."
    exit 0
fi

# --- Disk space before ---

get_disk_avail() {
    df -g / | awk 'NR==2 {print $4}'
}

SPACE_BEFORE=$(get_disk_avail)
log "=== Homebrew Cleanup Starting ==="
log "Disk available before: ${SPACE_BEFORE}G"

SUMMARY=""

# --- Cache size before ---

CACHE_DIR="$(brew --cache 2>/dev/null)"
if [[ -d "$CACHE_DIR" ]]; then
    CACHE_SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
    log "Homebrew cache before: $CACHE_SIZE ($CACHE_DIR)"
    SUMMARY+="Cache before: $CACHE_SIZE\n"
fi

# --- Remove orphaned dependencies ---

log "Running: brew autoremove"
output=$(brew autoremove 2>&1) || true
log "Autoremove: $output"
SUMMARY+="Autoremove:\n$output\n\n"

# --- Clean old downloads and outdated versions ---

log "Running: brew cleanup --prune=all -s"
output=$(brew cleanup --prune=all -s 2>&1) || true
log "Cleanup: $output"
SUMMARY+="Cleanup:\n$output\n\n"

# --- Cache size after ---

if [[ -d "$CACHE_DIR" ]]; then
    CACHE_SIZE_AFTER=$(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
    log "Homebrew cache after: $CACHE_SIZE_AFTER"
    SUMMARY+="Cache after: $CACHE_SIZE_AFTER\n"
fi

# --- Disk space after ---

SPACE_AFTER=$(get_disk_avail)
RECLAIMED=$((SPACE_AFTER - SPACE_BEFORE))

log "Disk available after: ${SPACE_AFTER}G"
log "Space reclaimed: ~${RECLAIMED}G"
log "=== Homebrew Cleanup Complete ==="

EMAIL_BODY="Homebrew cleanup completed on $(hostname) at $(date).

Disk space before: ${SPACE_BEFORE}G available
Disk space after:  ${SPACE_AFTER}G available
Reclaimed:         ~${RECLAIMED}G

--- Details ---
$(echo -e "$SUMMARY")"

send_email "Mac House Keep — Homebrew Cleanup Report" "$EMAIL_BODY"
