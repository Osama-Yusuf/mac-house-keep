#!/usr/bin/env bash
# run-all.sh — run all cleanup scripts sequentially

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

scripts=(
    "$SCRIPT_DIR/docker.sh"
    "$SCRIPT_DIR/homebrew.sh"
    "$SCRIPT_DIR/xcode.sh"
    "$SCRIPT_DIR/dev-caches.sh"
    "$SCRIPT_DIR/app-caches.sh"
    "$SCRIPT_DIR/system.sh"
    "$SCRIPT_DIR/old-downloads.sh"
)

for script in "${scripts[@]}"; do
    if [[ -x "$script" ]]; then
        echo "=== Running $(basename "$script") ==="
        "$script" || echo "Warning: $(basename "$script") exited with code $?"
    fi
done

echo "=== All cleanup scripts finished ==="
