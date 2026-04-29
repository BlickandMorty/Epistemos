#!/usr/bin/env bash
# Tools/build_pipeline_archive.sh — Simulation Mode S4 / S14 helper
#
# Per IMPLEMENTATION.md §3-S4 the simulation's Metal pipeline state
# is meant to be pre-compiled into an `MTLBinaryArchive` so app
# launches never trigger main-thread shader compilation
# (DOCTRINE I-15). At S4 we ship the **manual offline build** form
# — invoke this script to produce a `Companion.metallib` from the
# canonical `Companion.metal` source. The runtime falls back to
# Xcode's default metal compilation when this archive isn't
# present, so this script is OPTIONAL at S4 and load-bearing at
# S14 (final perf gate).
#
# Usage:
#   bash Tools/build_pipeline_archive.sh
#
# Output:
#   build-rust/metal/Companion.air      (intermediate AIR)
#   build-rust/metal/Companion.metallib (loadable Metal library)
#
# Exit codes:
#   0  success
#   1  xcrun toolchain missing
#   2  compile error (see stderr)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun not found; install Xcode command line tools" >&2
    exit 1
fi

SHADER="Epistemos/Simulation/Shaders/Companion.metal"
OUT_DIR="build-rust/metal"
AIR="${OUT_DIR}/Companion.air"
METALLIB="${OUT_DIR}/Companion.metallib"

if [ ! -f "$SHADER" ]; then
    echo "shader source missing: $SHADER" >&2
    exit 2
fi

mkdir -p "$OUT_DIR"

echo "→ compiling $SHADER → $AIR"
xcrun -sdk macosx metal -c "$SHADER" -o "$AIR" -frecord-sources

echo "→ linking $AIR → $METALLIB"
xcrun -sdk macosx metallib "$AIR" -o "$METALLIB"

echo "✓ Companion.metallib built at $METALLIB"
echo "  ($(stat -f '%z bytes' "$METALLIB"))"
echo ""
echo "Note: at S4 the runtime uses Xcode's default Metal library,"
echo "      which is compiled automatically from the same .metal"
echo "      source. The archive built here is a placeholder for"
echo "      the S14 cold-start optimization that loads pre-compiled"
echo "      pipeline state via MTLBinaryArchive."
