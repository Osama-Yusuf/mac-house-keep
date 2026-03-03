#!/usr/bin/env bash
# run-all.sh — run all backup scripts sequentially

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

scripts=(
    "$SCRIPT_DIR/keepass.sh"
)

for script in "${scripts[@]}"; do
    if [[ -x "$script" ]]; then
        echo "=== Running $(basename "$script") ==="
        "$script" || echo "Warning: $(basename "$script") exited with code $?"
    fi
done

echo "=== All backup scripts finished ==="
