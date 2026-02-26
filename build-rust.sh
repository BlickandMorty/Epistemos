#!/bin/bash
set -e

cd "$(dirname "$0")/graph-engine"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    LIB_PATH="target/aarch64-apple-darwin/debug/libgraph_engine.a"
else
    cargo build --release --target aarch64-apple-darwin
    LIB_PATH="target/aarch64-apple-darwin/release/libgraph_engine.a"
fi

# Copy to a stable path that Xcode can reference
mkdir -p ../build-rust
cp "$LIB_PATH" ../build-rust/libgraph_engine.a
