#!/bin/bash
set -e

# Wave 8.1 / 8.4 build script for the epistemos-shadow crate.
# Mirrors build-syntax-core.sh — Xcode strips PATH so we re-source
# cargo's env, then build a fat libepistemos_shadow.a covering both
# arm64 and x86_64 macOS architectures.

if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

if [ "${ENABLE_THREAD_SANITIZER:-NO}" = "YES" ]; then
    export CARGO_PROFILE_DEV_PANIC=abort
    export RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS } -C panic=abort"
fi

cd "$(dirname "$0")/epistemos-shadow"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    cargo build --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libepistemos_shadow.a"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libepistemos_shadow.a"
else
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libepistemos_shadow.a"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libepistemos_shadow.a"
fi

mkdir -p ../build-rust
rm -f ../build-rust/libepistemos_shadow.a
lipo -create "$ARM64_LIB_PATH" "$X86_64_LIB_PATH" -output ../build-rust/libepistemos_shadow.a
