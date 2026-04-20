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

cd "$(dirname "$0")/syntax-core"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    cargo build --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libsyntax_core.a"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libsyntax_core.a"
else
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libsyntax_core.a"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libsyntax_core.a"
fi

mkdir -p ../build-rust
rm -f ../build-rust/libsyntax_core.a
lipo -create "$ARM64_LIB_PATH" "$X86_64_LIB_PATH" -output ../build-rust/libsyntax_core.a
