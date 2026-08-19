#!/usr/bin/env bash
# Build the null renderer plugin next to its spec (host dev loop).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LDC="${LDC:-ldc2}"

"$LDC" -betterC -shared -O2 \
    -of="$ADDON_DIR/librenderer_null.so" \
    "$ADDON_DIR/source/null_renderer.d"

echo "==> ok: $ADDON_DIR/librenderer_null.so"
