#!/bin/bash
set -e

# Xcode strips PATH — ensure cargo is available
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

cd "$(dirname "$0")/epistemos-core"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    LIB_PATH="target/aarch64-apple-darwin/debug/libepistemos_core.a"
else
    cargo build --release --target aarch64-apple-darwin
    LIB_PATH="target/aarch64-apple-darwin/release/libepistemos_core.a"
fi

# Copy static lib to a stable path Xcode can reference
mkdir -p ../build-rust
cp "$LIB_PATH" ../build-rust/libepistemos_core.a

# Generate Swift bindings from UDL
mkdir -p ../build-rust/swift-bindings
cargo run --bin uniffi_bindgen -- generate \
    uniffi/epistemos_core.udl \
    --language swift \
    --out-dir ../build-rust/swift-bindings/ 2>/dev/null || true

echo "epistemos-core build complete"
