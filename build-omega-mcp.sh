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

cd "$(dirname "$0")/omega-mcp"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    cargo build --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libomega_mcp.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libomega_mcp.dylib"
else
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libomega_mcp.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libomega_mcp.dylib"
fi

# Copy dylib to a stable path Xcode can reference
mkdir -p ../build-rust
rm -f ../build-rust/libomega_mcp.a
rm -f ../build-rust/libomega_mcp.dylib
lipo -create "$ARM64_LIB_PATH" "$X86_64_LIB_PATH" -output ../build-rust/libomega_mcp.dylib
install_name_tool -id "@rpath/libomega_mcp.dylib" ../build-rust/libomega_mcp.dylib

if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
    bash ../embed-and-sign-rust-dylib.sh \
        ../build-rust/libomega_mcp.dylib \
        "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libomega_mcp.dylib"
fi

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
