#!/usr/bin/env bash
# dev-caches-cleanup.sh — clean package manager caches (npm, yarn, pnpm, bun, pip, CocoaPods, Go, Cargo, Gradle, Composer, gem)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_config
acquire_lock

trap 'send_email "Mac House Keep — Dev Caches Cleanup FAILED" "Dev caches cleanup failed on $(hostname) at $(date). Check logs at: $LOG_FILE"' ERR

# --- Disk space before ---

get_disk_avail() {
    df -g / | awk 'NR==2 {print $4}'
}

SPACE_BEFORE=$(get_disk_avail)
log "=== Dev Caches Cleanup Starting ==="
log "Disk available before: ${SPACE_BEFORE}G"

SUMMARY=""

# Helper: clean via command if available
clean_cmd() {
    local label="$1"
    local cmd="$2"
    shift 2

    if command -v "$cmd" &>/dev/null; then
        log "Running: $cmd $*"
        local output
        output=$("$cmd" "$@" 2>&1) || true
        log "$label: $output"
        SUMMARY+="$label: cleaned\n"
    else
        log "Skipping $label ($cmd not installed)"
        SUMMARY+="$label: skipped (not installed)\n"
    fi
}

# Helper: clean directory if it exists
clean_dir() {
    local label="$1"
    local dir="$2"
    if [[ -d "$dir" ]]; then
        local size
        size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
        log "Cleaning $label ($size): $dir"
        rm -rf "$dir"
        SUMMARY+="$label: $size cleaned\n"
    else
        log "Skipping $label (not found): $dir"
        SUMMARY+="$label: skipped (not found)\n"
    fi
}

# --- npm ---

clean_cmd "npm" npm cache clean --force

# --- yarn ---

clean_cmd "yarn" yarn cache clean

# --- pnpm ---

if command -v pnpm &>/dev/null; then
    clean_cmd "pnpm" pnpm store prune
fi

# --- bun ---

clean_dir "bun cache" "$HOME/.bun/install/cache"

# --- pip ---

clean_cmd "pip" pip cache purge
# Fallback: clean directory directly
clean_dir "pip cache dir" "$HOME/Library/Caches/pip"

# --- CocoaPods ---

if command -v pod &>/dev/null; then
    clean_cmd "CocoaPods" pod cache clean --all
else
    clean_dir "CocoaPods cache" "$HOME/Library/Caches/CocoaPods"
fi

# --- Go modules ---

clean_cmd "Go modules" go clean -modcache

# --- Cargo (Rust) ---

clean_dir "Cargo registry cache" "$HOME/.cargo/registry/cache"
clean_dir "Cargo registry src" "$HOME/.cargo/registry/src"

# --- Gradle ---

clean_dir "Gradle caches" "$HOME/.gradle/caches"

# --- Maven ---

clean_dir "Maven repository" "$HOME/.m2/repository"

# --- Composer (PHP) ---

if command -v composer &>/dev/null; then
    clean_cmd "Composer" composer clear-cache
else
    clean_dir "Composer cache" "$HOME/.composer/cache"
fi

# --- Ruby gems (old versions) ---

clean_cmd "Ruby gems" gem cleanup

# --- Conda / Anaconda ---

if command -v conda &>/dev/null; then
    clean_cmd "Conda" conda clean --all --yes
fi

# --- Disk space after ---

SPACE_AFTER=$(get_disk_avail)
RECLAIMED=$((SPACE_AFTER - SPACE_BEFORE))

log "Disk available after: ${SPACE_AFTER}G"
log "Space reclaimed: ~${RECLAIMED}G"
log "=== Dev Caches Cleanup Complete ==="

EMAIL_BODY="Dev caches cleanup completed on $(hostname) at $(date).

Disk space before: ${SPACE_BEFORE}G available
Disk space after:  ${SPACE_AFTER}G available
Reclaimed:         ~${RECLAIMED}G

--- Details ---
$(echo -e "$SUMMARY")"

send_email "Mac House Keep — Dev Caches Cleanup Report" "$EMAIL_BODY"
