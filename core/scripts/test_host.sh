#!/usr/bin/env bash
# Build the host core + null renderer addon, compile the C smoke test
# against the ABI, and run it from the repo root (addons are scanned
# relative to it).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$CORE_DIR/.." && pwd)"

bash "$SCRIPT_DIR/build_host.sh" "${1:-debug}"
bash "$REPO_ROOT/addons/renderer-null/scripts/build_host.sh"

gcc -O1 -o "$CORE_DIR/build/host/host_test" \
    "$CORE_DIR/tests/host_test.c" \
    -L"$CORE_DIR/build/host" -ldsluck \
    -Wl,-rpath,"$CORE_DIR/build/host"

cd "$REPO_ROOT" && "$CORE_DIR/build/host/host_test"
