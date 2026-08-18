#!/usr/bin/env bash
# D's Luck — cross-compile the core to Android (.so) via LDC + NDK.
#
# Mobile-first per spec: arm64-v8a is the primary target.
# Additional ABIs can be enabled by appending to the ABI list below.
#
# Usage:  core/scripts/build_android.sh <path-to-ndk> [debug|release]
# Produces: core/build/android/<abi>/libdsluck.so
set -euo pipefail

NDK="${1:?usage: build_android.sh <ndk-path> [debug|release]}"
MODE="${2:-release}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$CORE_DIR/build/android"
LDC="${LDC:-ldc2}"
API=26   # minSdk 26 — Vulkan-era devices, matches hub config

# ABI list: "triple|abi-folder" pairs. arm64 first (primary target).
# armeabi-v7a is shipped because many Android Go / low-end devices run a
# 32-bit userspace on 64-bit silicon — an arm64-only core won't load there.
ABIS=(
    "aarch64-unknown-linux-android|arm64-v8a"
    "armv7a-linux-androideabi|armeabi-v7a"
    # "x86_64-unknown-linux-android|x86_64"
)

mapfile -t SOURCES < <(find "$CORE_DIR/source" -name '*.d' | sort)

PREBUILT="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"

for entry in "${ABIS[@]}"; do
    TRIPLE="${entry%%|*}"
    ABI="${entry##*|}"

    # Pick matching NDK clang driver for linking.
    case "$ABI" in
        arm64-v8a)     CLANG="$PREBUILT/aarch64-linux-android${API}-clang" ;;
        armeabi-v7a)   CLANG="$PREBUILT/armv7a-linux-androideabi${API}-clang" ;;
        x86_64)        CLANG="$PREBUILT/x86_64-linux-android${API}-clang" ;;
    esac

    mkdir -p "$OUT_DIR/$ABI"

    FLAGS=(
        -betterC
        -shared
        "-mtriple=$TRIPLE"
        "--gcc=$CLANG"
        -I="$CORE_DIR/source"
        "-of=$OUT_DIR/$ABI/libdsluck.so"
        "-L-soname" "-Llibdsluck.so"
        -link-defaultlib-shared=false
    )
    if [[ "$MODE" == "release" ]]; then
        FLAGS+=(-O3 -release)
    else
        FLAGS+=(-O1 -g)
    fi

    echo "==> [$ABI] ldc2 ${TRIPLE}"
    "$LDC" "${FLAGS[@]}" "${SOURCES[@]}"
done

echo "==> ok: $OUT_DIR"
