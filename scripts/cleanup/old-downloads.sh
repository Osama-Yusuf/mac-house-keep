#!/usr/bin/env bash
# old-downloads-cleanup.sh — remove .dmg/.pkg installers and abandoned partial
# downloads (.crdownload, .part, .partial, Safari .download bundles) older than
# 10 days from ~/Downloads

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../utils/common.sh
source "$SCRIPT_DIR/../utils/common.sh"

load_config
acquire_lock

trap 'send_email "Mac House Keep — Downloads Cleanup FAILED" "Downloads cleanup failed on $(hostname) at $(date). Check logs at: $LOG_FILE"' ERR

DOWNLOADS_DIR="$HOME/Downloads"
MAX_AGE_DAYS=10

# --- Disk space before ---

get_disk_avail() {
    df -g / | awk 'NR==2 {print $4}'
}

SPACE_BEFORE=$(get_disk_avail)
log "=== Downloads Cleanup Starting ==="
log "Disk available before: ${SPACE_BEFORE}G"
log "Removing installers and partial downloads older than ${MAX_AGE_DAYS} days from $DOWNLOADS_DIR"

SUMMARY=""
TOTAL_COUNT=0
TOTAL_SIZE=0

# Installers and abandoned partial downloads (Chrome, Firefox, curl/wget)
FILE_PATTERNS=("*.dmg" "*.pkg" "*.crdownload" "*.part" "*.partial")

remove_old_files() {
    local pattern="$1"
    while IFS= read -r -d '' file; do
        size=$(stat -f%z "$file" 2>/dev/null || echo 0)
        size_mb=$(( size / 1048576 ))
        log "Removing: $(basename "$file") (${size_mb}MB)"
        SUMMARY+="$(basename "$file") — ${size_mb}MB\n"
        rm -f "$file"
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        TOTAL_SIZE=$((TOTAL_SIZE + size))
    done < <(find "$DOWNLOADS_DIR" -maxdepth 1 -name "$pattern" -type f -mtime +${MAX_AGE_DAYS} -print0 2>/dev/null)
}

for pattern in "${FILE_PATTERNS[@]}"; do
    remove_old_files "$pattern"
done

# --- Safari partial downloads (*.download bundles are directories) ---

while IFS= read -r -d '' bundle; do
    size_kb=$(du -sk "$bundle" 2>/dev/null | awk '{print $1}')
    size=$(( ${size_kb:-0} * 1024 ))
    size_mb=$(( size / 1048576 ))
    log "Removing: $(basename "$bundle") (${size_mb}MB)"
    SUMMARY+="$(basename "$bundle") — ${size_mb}MB\n"
    rm -rf "$bundle"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    TOTAL_SIZE=$((TOTAL_SIZE + size))
done < <(find "$DOWNLOADS_DIR" -maxdepth 1 -name "*.download" -type d -mtime +${MAX_AGE_DAYS} -print0 2>/dev/null)

TOTAL_SIZE_MB=$((TOTAL_SIZE / 1048576))

# --- Disk space after ---

SPACE_AFTER=$(get_disk_avail)
RECLAIMED=$((SPACE_AFTER - SPACE_BEFORE))

log "Removed $TOTAL_COUNT files (${TOTAL_SIZE_MB}MB)"
log "Disk available after: ${SPACE_AFTER}G"
log "Space reclaimed: ~${RECLAIMED}G"
log "=== Downloads Cleanup Complete ==="

if [[ $TOTAL_COUNT -gt 0 ]]; then
    EMAIL_BODY="Downloads cleanup completed on $(hostname) at $(date).

Removed $TOTAL_COUNT installer(s)/partial download(s) older than ${MAX_AGE_DAYS} days (${TOTAL_SIZE_MB}MB total).

Disk space before: ${SPACE_BEFORE}G available
Disk space after:  ${SPACE_AFTER}G available
Reclaimed:         ~${RECLAIMED}G

--- Files Removed ---
$(echo -e "$SUMMARY")"
else
    EMAIL_BODY="Downloads cleanup completed on $(hostname) at $(date).

No installers or partial downloads older than ${MAX_AGE_DAYS} days found in $DOWNLOADS_DIR.

Disk space: ${SPACE_BEFORE}G available"
fi

send_email "Mac House Keep — Downloads Cleanup Report" "$EMAIL_BODY"
