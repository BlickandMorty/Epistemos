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

# This script only builds the graph-engine static library. The additional
# Rust dylibs are built by the sibling Xcode prebuild scripts so archive
# and release artifacts keep the same runtime dependencies as debug.

cd "$(dirname "$0")/graph-engine"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --features bolt-graph,shared-position-buffers --target aarch64-apple-darwin
    cargo build --features bolt-graph,shared-position-buffers --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libgraph_engine.a"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libgraph_engine.a"
else
    cargo build --release --features bolt-graph,shared-position-buffers --target aarch64-apple-darwin
    cargo build --release --features bolt-graph,shared-position-buffers --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libgraph_engine.a"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libgraph_engine.a"
fi

# Copy to a stable path that Xcode can reference
mkdir -p ../build-rust
STAGING_LOCK="../build-rust/.libgraph_engine.lock"
TEMP_OUTPUT="$(mktemp ../build-rust/libgraph_engine.XXXXXX)"
cleanup_temp_output() {
    rm -f "$TEMP_OUTPUT"
    if [ -d "$STAGING_LOCK" ] && [ "$(cat "$STAGING_LOCK/pid" 2>/dev/null || true)" = "$$" ]; then
        rm -f "$STAGING_LOCK/pid"
        rmdir "$STAGING_LOCK" 2>/dev/null || true
    fi
}
acquire_staging_lock() {
    while ! mkdir "$STAGING_LOCK" 2>/dev/null; do
        if [ -f "$STAGING_LOCK/pid" ]; then
            lock_pid="$(cat "$STAGING_LOCK/pid" 2>/dev/null || true)"
            if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
                rm -rf "$STAGING_LOCK"
                continue
            fi
        fi
        sleep 0.2
    done
    echo "$$" > "$STAGING_LOCK/pid"
}
trap cleanup_temp_output EXIT
lipo -create "$ARM64_LIB_PATH" "$X86_64_LIB_PATH" -output "$TEMP_OUTPUT"
acquire_staging_lock
rm -f ../build-rust/libgraph_engine.a
mv -f "$TEMP_OUTPUT" ../build-rust/libgraph_engine.a
trap - EXIT
