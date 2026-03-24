#!/bin/bash
set -e

# Xcode strips PATH — ensure cargo is available
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

cd "$(dirname "$0")/omega-mcp"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    LIB_PATH="target/aarch64-apple-darwin/debug/libomega_mcp.a"
else
    cargo build --release --target aarch64-apple-darwin
    LIB_PATH="target/aarch64-apple-darwin/release/libomega_mcp.a"
fi

# Copy static lib to a stable path Xcode can reference
mkdir -p ../build-rust
cp "$LIB_PATH" ../build-rust/libomega_mcp.a

# Generate Swift bindings from UDL
mkdir -p ../build-rust/swift-bindings
cargo run --bin uniffi_bindgen -- generate \
    uniffi/omega_mcp.udl \
    --language swift \
    --out-dir ../build-rust/swift-bindings/ 2>/dev/null || true

# Patch generated Swift for SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor compatibility
python3 ../patch-uniffi-bindings.py ../build-rust/swift-bindings/omega_mcp.swift

# Set up module directories for FFI import
mkdir -p ../build-rust/swift-bindings/omega_mcpFFI
cp ../build-rust/swift-bindings/omega_mcpFFI.h ../build-rust/swift-bindings/omega_mcpFFI/ 2>/dev/null || true
cp ../build-rust/swift-bindings/omega_mcpFFI.modulemap ../build-rust/swift-bindings/omega_mcpFFI/module.modulemap 2>/dev/null || true

echo "omega-mcp build complete"
