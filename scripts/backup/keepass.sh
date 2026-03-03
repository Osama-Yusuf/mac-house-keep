#!/usr/bin/env bash
# keepass.sh — backup KeePass database locally and/or to a private GitHub repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../utils/common.sh
source "$SCRIPT_DIR/../utils/common.sh"

load_config
acquire_lock

trap 'send_email "Mac House Keep — KeePass Backup FAILED" "KeePass backup failed on $(hostname) at $(date). Check logs at: $LOG_FILE"' ERR

# --- Load KeePass config ---

KEEPASS_CONF="$CONFIG_DIR/keepass.conf"

if [[ -f "$KEEPASS_CONF" ]]; then
    # shellcheck source=/dev/null
    source "$KEEPASS_CONF"
else
    log "KeePass config not found at: $KEEPASS_CONF"
    log "Copy config/keepass.conf.example to config/keepass.conf and edit it."
    send_email \
        "Mac House Keep — KeePass Backup Warning" \
        "KeePass backup skipped: config not found at $KEEPASS_CONF on $(hostname). Copy keepass.conf.example to keepass.conf and set your paths."
    exit 0
fi

KDBX_SOURCE="${KDBX_SOURCE:-}"
BACKUP_MODE="${BACKUP_MODE:-local}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.keepass-backups}"
MAX_BACKUPS="${MAX_BACKUPS:-30}"
BACKUP_REPO="${BACKUP_REPO:-keepass-backup}"

# --- Validate source ---

if [[ -z "$KDBX_SOURCE" || ! -f "$KDBX_SOURCE" ]]; then
    log "KeePass database not found at: ${KDBX_SOURCE:-<not set>}"
    log "Check KDBX_SOURCE in $KEEPASS_CONF"
    send_email \
        "Mac House Keep — KeePass Backup Warning" \
        "KeePass backup skipped: database not found at ${KDBX_SOURCE:-<not set>} on $(hostname)."
    exit 0
fi

log "=== KeePass Backup Starting ==="
log "Source: $KDBX_SOURCE"
log "Mode: $BACKUP_MODE"

BASENAME=$(basename "$KDBX_SOURCE" .kdbx)
TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
SUMMARY=""

# --- Local backup ---

do_local_backup() {
    mkdir -p "$BACKUP_DIR"

    local backup_file="$BACKUP_DIR/${BASENAME}_${TIMESTAMP}.kdbx"
    cp "$KDBX_SOURCE" "$backup_file"
    log "Local backup created: $backup_file ($(du -sh "$backup_file" | awk '{print $1}'))"

    # Rotate old backups
    local count
    count=$(find "$BACKUP_DIR" -name "${BASENAME}_*.kdbx" -type f | wc -l | tr -d ' ')

    if [[ $count -gt $MAX_BACKUPS ]]; then
        local remove=$((count - MAX_BACKUPS))
        log "Rotating: removing $remove old backup(s) (keeping last $MAX_BACKUPS)"
        find "$BACKUP_DIR" -name "${BASENAME}_*.kdbx" -type f -print0 \
            | sort -z \
            | head -z -n "$remove" \
            | xargs -0 rm -f
        count=$MAX_BACKUPS
    fi

    log "Total local backups: $count"
    SUMMARY+="Local: $backup_file ($count total, keeping last $MAX_BACKUPS)\n"
}

# --- Remote backup (GitHub private repo) ---

do_remote_backup() {
    if ! command -v gh &>/dev/null; then
        log "gh CLI not installed — skipping remote backup"
        SUMMARY+="Remote: skipped (gh CLI not installed)\n"
        return
    fi

    if ! gh auth status &>/dev/null; then
        log "gh not authenticated — skipping remote backup"
        SUMMARY+="Remote: skipped (gh not authenticated)\n"
        return
    fi

    # Resolve full repo name (add username if needed)
    local repo="$BACKUP_REPO"
    if [[ "$repo" != */* ]]; then
        local gh_user
        gh_user=$(gh api user --jq '.login' 2>/dev/null) || true
        if [[ -z "$gh_user" ]]; then
            log "Could not determine GitHub username — skipping remote backup"
            SUMMARY+="Remote: skipped (could not determine GitHub username)\n"
            return
        fi
        repo="$gh_user/$BACKUP_REPO"
    fi

    local repo_dir="$BACKUP_DIR/.remote-repo"

    # Create private repo if it doesn't exist
    if ! gh repo view "$repo" &>/dev/null; then
        log "Creating private repo: $repo"
        gh repo create "$repo" --private --description "KeePass database backup (auto-managed by mac-house-keep)" || {
            log "Failed to create repo $repo"
            SUMMARY+="Remote: failed to create repo\n"
            return
        }
        # Small delay for GitHub to provision the repo
        sleep 2
    fi

    # Clone or pull
    if [[ -d "$repo_dir/.git" ]]; then
        log "Pulling latest from $repo"
        git -C "$repo_dir" pull --rebase --quiet 2>/dev/null || true
    else
        log "Cloning $repo"
        rm -rf "$repo_dir"
        gh repo clone "$repo" "$repo_dir" -- --quiet 2>/dev/null || {
            # Repo might be empty (just created), init locally
            mkdir -p "$repo_dir"
            git -C "$repo_dir" init --quiet
            git -C "$repo_dir" remote add origin "https://github.com/$repo.git" 2>/dev/null || true
            git -C "$repo_dir" branch -M main
        }
    fi

    # Copy database to repo
    cp "$KDBX_SOURCE" "$repo_dir/$BASENAME.kdbx"

    # Commit and push
    git -C "$repo_dir" add "$BASENAME.kdbx"

    if git -C "$repo_dir" diff --cached --quiet 2>/dev/null; then
        log "Remote: no changes to push (database unchanged)"
        SUMMARY+="Remote: no changes (database unchanged)\n"
    else
        git -C "$repo_dir" commit --quiet -m "backup: $TIMESTAMP"
        git -C "$repo_dir" push --quiet -u origin main 2>&1 || {
            log "Failed to push to $repo"
            SUMMARY+="Remote: push failed\n"
            return
        }
        local commit_hash
        commit_hash=$(git -C "$repo_dir" rev-parse --short HEAD)
        log "Remote: pushed to $repo ($commit_hash)"
        SUMMARY+="Remote: pushed to github.com/$repo ($commit_hash)\n"
    fi
}

# --- Run based on mode ---

case "$BACKUP_MODE" in
    local)
        do_local_backup
        ;;
    remote)
        do_remote_backup
        ;;
    both)
        do_local_backup
        do_remote_backup
        ;;
    *)
        log "Unknown BACKUP_MODE: $BACKUP_MODE (expected: local, remote, or both)"
        exit 1
        ;;
esac

log "=== KeePass Backup Complete ==="

send_email \
    "Mac House Keep — KeePass Backup Report" \
    "KeePass backup completed on $(hostname) at $(date).

Source: $KDBX_SOURCE
Mode: $BACKUP_MODE

$(echo -e "$SUMMARY")"
