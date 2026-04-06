#!/bin/bash
set -e

# Xcode strips PATH — ensure cargo is available
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

if [ "${ENABLE_THREAD_SANITIZER:-NO}" = "YES" ]; then
    export CARGO_PROFILE_DEV_PANIC=abort
    export RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS } -C panic=abort"
fi

# SHIP_MODE: when set to "release", the Xcode build script skips the
# agent crates (omega-mcp, omega-ax, epistemos-core) entirely. Only
# graph-engine is built and linked. This gives a clean release binary
# with zero agent code. Default: build everything (development mode).
#
# To activate: set SHIP_MODE=release in the Xcode scheme environment
# variables, or export it before running xcodebuild.
#
# 2026-04-04: user wants to ship without agents but keep them for later.

cd "$(dirname "$0")/graph-engine"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    cargo build --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libgraph_engine.a"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libgraph_engine.a"
else
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libgraph_engine.a"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libgraph_engine.a"
fi

# Copy to a stable path that Xcode can reference
mkdir -p ../build-rust
rm -f ../build-rust/libgraph_engine.a
lipo -create "$ARM64_LIB_PATH" "$X86_64_LIB_PATH" -output ../build-rust/libgraph_engine.a
