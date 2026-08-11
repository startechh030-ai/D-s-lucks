#!/usr/bin/env bash
# D's Luck — build the core as a host shared library (Linux/macOS dev loop).
# Usage:  core/scripts/build_host.sh [debug|release]
set -euo pipefail

MODE="${1:-debug}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$CORE_DIR/build/host"
LDC="${LDC:-ldc2}"

mkdir -p "$OUT_DIR"

# All D sources: ABI surface + core systems.
mapfile -t SOURCES < <(find "$CORE_DIR/source" -name '*.d' | sort)

FLAGS=(-betterC -shared -I="$CORE_DIR/source" -of="$OUT_DIR/libdsluck.so")
if [[ "$MODE" == "release" ]]; then
    FLAGS+=(-O3 -release)
else
    FLAGS+=(-O1 -g)
fi

echo "==> ldc2 (${MODE}) -> ${OUT_DIR}/libdsluck.so"
"$LDC" "${FLAGS[@]}" "${SOURCES[@]}"
echo "==> ok"
