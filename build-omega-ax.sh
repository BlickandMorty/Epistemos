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

cd "$(dirname "$0")/omega-ax"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    cargo build --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libomega_ax.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libomega_ax.dylib"
else
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libomega_ax.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libomega_ax.dylib"
fi

# Copy dylib to a stable path Xcode can reference
mkdir -p ../build-rust
rm -f ../build-rust/libomega_ax.a
rm -f ../build-rust/libomega_ax.dylib
lipo -create "$ARM64_LIB_PATH" "$X86_64_LIB_PATH" -output ../build-rust/libomega_ax.dylib
install_name_tool -id "@rpath/libomega_ax.dylib" ../build-rust/libomega_ax.dylib

if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
    bash ../embed-and-sign-rust-dylib.sh \
        ../build-rust/libomega_ax.dylib \
        "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libomega_ax.dylib"
fi

# Generate Swift bindings from UDL
mkdir -p ../build-rust/swift-bindings
cargo run --bin uniffi_bindgen -- generate \
    uniffi/omega_ax.udl \
    --language swift \
    --out-dir ../build-rust/swift-bindings/ 2>/dev/null || true

# Patch generated Swift for SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor compatibility
python3 ../patch-uniffi-bindings.py ../build-rust/swift-bindings/omega_ax.swift

# Set up module directories for FFI import
mkdir -p ../build-rust/swift-bindings/omega_axFFI
cp ../build-rust/swift-bindings/omega_axFFI.h ../build-rust/swift-bindings/omega_axFFI/ 2>/dev/null || true
cp ../build-rust/swift-bindings/omega_axFFI.modulemap ../build-rust/swift-bindings/omega_axFFI/module.modulemap 2>/dev/null || true

# Fix: [Issue 1 - AMFI Binary Signing] — ad-hoc sign all binaries to prevent
# "Unrecoverable CT signature issue" kernel kills.
for bin in target/aarch64-apple-darwin/debug/uniffi_bindgen \
           target/x86_64-apple-darwin/debug/uniffi_bindgen \
           target/aarch64-apple-darwin/release/uniffi_bindgen \
           target/x86_64-apple-darwin/release/uniffi_bindgen; do
    [ -f "$bin" ] && codesign --force --sign - "$bin"
done
codesign --force --sign - ../build-rust/libomega_ax.dylib

echo "omega-ax build complete"
