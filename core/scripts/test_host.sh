#!/usr/bin/env bash
# Build the host core, compile the C smoke test against it, and run it.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/build_host.sh" "${1:-debug}"

gcc -O1 -o "$CORE_DIR/build/host/host_test" \
    "$CORE_DIR/tests/host_test.c" \
    -L"$CORE_DIR/build/host" -ldsluck \
    -Wl,-rpath,"$CORE_DIR/build/host"

"$CORE_DIR/build/host/host_test"
