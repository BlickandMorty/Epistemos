#!/bin/bash
set -e

# Wave 5 build script for the substrate-rt crate.
# Produces a fat libsubstrate_rt.a that the host links via the
# EPISTEMOS_LINK_SUBSTRATE_RT Swift compilation condition. With the
# flag off, RustEventRingClient.swift compiles to nothing and the host
# uses InMemoryEventRingClient (the test stub).

if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

if [ "${ENABLE_THREAD_SANITIZER:-NO}" = "YES" ]; then
    export CARGO_PROFILE_DEV_PANIC=abort
    export RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS } -C panic=abort"
fi

cd "$(dirname "$0")/substrate-rt"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    cargo build --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libsubstrate_rt.a"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libsubstrate_rt.a"
else
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libsubstrate_rt.a"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libsubstrate_rt.a"
fi

mkdir -p ../build-rust
rm -f ../build-rust/libsubstrate_rt.a
lipo -create "$ARM64_LIB_PATH" "$X86_64_LIB_PATH" -output ../build-rust/libsubstrate_rt.a
