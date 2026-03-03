#!/usr/bin/env bash
# docker-cleanup.sh — prune all unused Docker resources and report space reclaimed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../utils/common.sh
source "$SCRIPT_DIR/../utils/common.sh"

load_config
acquire_lock

# --- Send email on unexpected errors ---

trap 'send_email "Mac House Keep — Docker Cleanup FAILED" "Docker cleanup failed on $(hostname) at $(date). Check logs at: $LOG_FILE"' ERR

# --- Check Docker is running ---

if ! docker info >/dev/null 2>&1; then
    log "Docker is not running or not installed."
    send_email \
        "Mac House Keep — Docker Cleanup Warning" \
        "Docker cleanup skipped: Docker is not running or not installed on $(hostname)."
    exit 0
fi

# --- Disk space before ---

get_disk_avail() {
    df -g / | awk 'NR==2 {print $4}'
}

SPACE_BEFORE=$(get_disk_avail)
log "=== Docker Cleanup Starting ==="
log "Disk available before: ${SPACE_BEFORE}G"

# --- Cleanup steps ---

SUMMARY=""

run_prune() {
    local label="$1"
    shift
    log "Running: $*"
    local output
    output=$("$@" 2>&1) || true
    log "$label: $output"
    SUMMARY+="$label:\n$output\n\n"
}

run_prune "Containers"  docker container prune -f
run_prune "Images"      docker image prune -a -f
run_prune "Volumes"     docker volume prune -a -f
run_prune "Networks"    docker network prune -f
run_prune "Build cache" docker builder prune -a -f

# --- Disk space after ---

SPACE_AFTER=$(get_disk_avail)
RECLAIMED=$((SPACE_AFTER - SPACE_BEFORE))

log "Disk available after: ${SPACE_AFTER}G"
log "Space reclaimed: ~${RECLAIMED}G"
log "=== Docker Cleanup Complete ==="

# --- Email summary ---

EMAIL_BODY="Docker cleanup completed on $(hostname) at $(date).

Disk space before: ${SPACE_BEFORE}G available
Disk space after:  ${SPACE_AFTER}G available
Reclaimed:         ~${RECLAIMED}G

--- Details ---
$(echo -e "$SUMMARY")"

send_email "Mac House Keep — Docker Cleanup Report" "$EMAIL_BODY"
