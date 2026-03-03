#!/usr/bin/env bash
# run-all.sh — run all cleanup and backup scripts

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Running cleanup scripts ==="
"$SCRIPT_DIR/cleanup/run-all.sh" || true

echo ""
echo "=== Running backup scripts ==="
"$SCRIPT_DIR/backup/run-all.sh" || true

echo ""
echo "=== All scripts finished ==="
