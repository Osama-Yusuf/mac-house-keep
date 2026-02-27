#!/usr/bin/env bash
# common.sh — shared library sourced by all scripts

set -euo pipefail

# Resolve project root from this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LOG_DIR="$PROJECT_ROOT/logs"
LOCK_DIR="$PROJECT_ROOT/.locks"
CONFIG_DIR="$PROJECT_ROOT/config"
CONFIG_FILE="$CONFIG_DIR/email.conf"

mkdir -p "$LOG_DIR" "$LOCK_DIR"

# Derive log file name from the calling script
_CALLER="$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}" .sh)"
LOG_FILE="$LOG_DIR/${_CALLER}.log"

# --- Logging ---

log() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

# --- Locking (mkdir-based, macOS-safe) ---

_LOCK_PATH=""

acquire_lock() {
    local name="${1:-$_CALLER}"
    _LOCK_PATH="$LOCK_DIR/${name}.lock"

    if mkdir "$_LOCK_PATH" 2>/dev/null; then
        echo $$ > "$_LOCK_PATH/pid"
        trap 'release_lock' EXIT
        return 0
    fi

    # Lock exists — check for stale PID
    local pid_file="$_LOCK_PATH/pid"
    if [[ -f "$pid_file" ]]; then
        local old_pid
        old_pid=$(cat "$pid_file")
        if ! kill -0 "$old_pid" 2>/dev/null; then
            log "Removing stale lock (PID $old_pid no longer running)"
            rm -rf "$_LOCK_PATH"
            if mkdir "$_LOCK_PATH" 2>/dev/null; then
                echo $$ > "$_LOCK_PATH/pid"
                trap 'release_lock' EXIT
                return 0
            fi
        fi
    fi

    log "Another instance is already running (lock: $_LOCK_PATH). Exiting."
    exit 0
}

release_lock() {
    if [[ -n "$_LOCK_PATH" && -d "$_LOCK_PATH" ]]; then
        rm -rf "$_LOCK_PATH"
    fi
}

# --- Config ---

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    else
        log "Warning: email config not found at $CONFIG_FILE — email notifications disabled"
        log "Run scripts/setup-email.sh to configure."
    fi
}

# --- Email via Resend ---

send_email() {
    local subject="$1"
    local body="$2"

    if [[ -z "${RESEND_API_KEY:-}" || -z "${TO_EMAIL:-}" ]]; then
        log "Email not configured — skipping notification."
        return 0
    fi

    # Build JSON payload using python for proper escaping
    local json
    json=$(python3 -c "
import json, sys
print(json.dumps({
    'from': 'Mac House Keep <onboarding@resend.dev>',
    'to': [sys.argv[1]],
    'subject': sys.argv[2],
    'text': sys.argv[3]
}))
" "$TO_EMAIL" "$subject" "$body")

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "https://api.resend.com/emails" \
        -H "Authorization: Bearer $RESEND_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json") || true

    if [[ "$http_code" == "200" ]]; then
        log "Email sent to $TO_EMAIL: $subject"
    else
        log "Warning: email send failed (HTTP $http_code) — continuing anyway."
    fi
}
