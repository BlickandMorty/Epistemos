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

cd "$(dirname "$0")/epistemos-core"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    cargo build --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libepistemos_core.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libepistemos_core.dylib"
else
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libepistemos_core.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libepistemos_core.dylib"
fi

# Copy dylib to a stable path Xcode can reference
mkdir -p ../build-rust
rm -f ../build-rust/libepistemos_core.dylib
lipo -create "$ARM64_LIB_PATH" "$X86_64_LIB_PATH" -output ../build-rust/libepistemos_core.dylib

# Also update install name so macOS finds it next to the executable
install_name_tool -id "@rpath/libepistemos_core.dylib" ../build-rust/libepistemos_core.dylib

# Never let hosted tests resolve epistemos-core from PackageFrameworks. We only
# want dyld to load the signed copy bundled into the app itself.
if [ -n "$TARGET_BUILD_DIR" ]; then
    rm -f "$TARGET_BUILD_DIR/PackageFrameworks/libepistemos_core.dylib"
fi

if [ -n "$TARGET_BUILD_DIR" ] && [ -n "$FRAMEWORKS_FOLDER_PATH" ]; then
    bash ../embed-and-sign-rust-dylib.sh \
        ../build-rust/libepistemos_core.dylib \
        "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libepistemos_core.dylib"
fi

# Generate Swift bindings from UDL
mkdir -p ../build-rust/swift-bindings
cargo run --bin uniffi_bindgen -- generate \
    uniffi/epistemos_core.udl \
    --language swift \
    --out-dir ../build-rust/swift-bindings/

# Patch generated Swift for SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor compatibility
python3 ../patch-uniffi-bindings.py ../build-rust/swift-bindings/epistemos_core.swift

# Sync header + modulemap into module map directory
mkdir -p ../build-rust/swift-bindings/epistemos_coreFFI
cp ../build-rust/swift-bindings/epistemos_coreFFI.h ../build-rust/swift-bindings/epistemos_coreFFI/epistemos_coreFFI.h
cp ../build-rust/swift-bindings/epistemos_coreFFI.modulemap ../build-rust/swift-bindings/epistemos_coreFFI/module.modulemap

# Ad-hoc sign uniffi_bindgen build tools (prevents AMFI kills during code generation).
for bin in target/aarch64-apple-darwin/debug/uniffi_bindgen \
           target/x86_64-apple-darwin/debug/uniffi_bindgen \
           target/aarch64-apple-darwin/release/uniffi_bindgen \
           target/x86_64-apple-darwin/release/uniffi_bindgen; do
    [ -f "$bin" ] && codesign --force --sign - "$bin"
done

# Only ad-hoc sign the staging dylib if NOT running inside Xcode.
if [ -z "${TARGET_BUILD_DIR:-}" ]; then
    codesign --force --sign - ../build-rust/libepistemos_core.dylib
fi

echo "epistemos-core build complete"
