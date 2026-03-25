#!/bin/bash
set -e

# Xcode strips PATH — ensure cargo is available
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

cd "$(dirname "$0")/epistemos-core"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    LIB_PATH="target/aarch64-apple-darwin/debug/libepistemos_core.dylib"
else
    cargo build --release --target aarch64-apple-darwin
    LIB_PATH="target/aarch64-apple-darwin/release/libepistemos_core.dylib"
fi

# Copy dylib to a stable path Xcode can reference
mkdir -p ../build-rust
cp "$LIB_PATH" ../build-rust/libepistemos_core.dylib

# Also update install name so macOS finds it next to the executable
install_name_tool -id "@rpath/libepistemos_core.dylib" ../build-rust/libepistemos_core.dylib

# Generate Swift bindings from UDL
mkdir -p ../build-rust/swift-bindings
cargo run --bin uniffi_bindgen -- generate \
    uniffi/epistemos_core.udl \
    --language swift \
    --out-dir ../build-rust/swift-bindings/ 2>/dev/null || true

# Sync header into module map directory
cp ../build-rust/swift-bindings/epistemos_coreFFI.h ../build-rust/swift-bindings/epistemos_coreFFI/epistemos_coreFFI.h

echo "epistemos-core build complete"
