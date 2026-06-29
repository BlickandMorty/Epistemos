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
STAGING_LOCK="../build-rust/.libepistemos_core.lock"
TEMP_OUTPUT="$(mktemp ../build-rust/libepistemos_core.XXXXXX)"
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
install_name_tool -id "@rpath/libepistemos_core.dylib" "$TEMP_OUTPUT"

acquire_staging_lock
rm -f ../build-rust/libepistemos_core.dylib
mv -f "$TEMP_OUTPUT" ../build-rust/libepistemos_core.dylib

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
# Sign uniffi_bindgen BEFORE invoking it (AMFI kills adhoc-signed
# binaries on hardened macOS; `cargo run` would build + execute before
# any sign step could run).
mkdir -p ../build-rust/swift-bindings
cargo build --bin uniffi_bindgen --target aarch64-apple-darwin 2>/dev/null || true
for bin in target/aarch64-apple-darwin/debug/uniffi_bindgen \
           target/x86_64-apple-darwin/debug/uniffi_bindgen \
           target/aarch64-apple-darwin/release/uniffi_bindgen \
           target/x86_64-apple-darwin/release/uniffi_bindgen; do
    [ -f "$bin" ] && codesign --force --sign - "$bin" 2>/dev/null || true
done
UNIFFI_BIN="target/aarch64-apple-darwin/debug/uniffi_bindgen"
if [ ! -f "$UNIFFI_BIN" ]; then
    UNIFFI_BIN="target/aarch64-apple-darwin/release/uniffi_bindgen"
fi
if [ -f "$UNIFFI_BIN" ]; then
    "$UNIFFI_BIN" generate \
        uniffi/epistemos_core.udl \
        --language swift \
        --no-format \
        --out-dir ../build-rust/swift-bindings/
fi

# Patch generated Swift for SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor compatibility
python3 ../patch-uniffi-bindings.py ../build-rust/swift-bindings/epistemos_core.swift

# Sync header + modulemap into module map directory
mkdir -p ../build-rust/swift-bindings/epistemos_coreFFI
cp ../build-rust/swift-bindings/epistemos_coreFFI.h ../build-rust/swift-bindings/epistemos_coreFFI/epistemos_coreFFI.h
cp ../build-rust/swift-bindings/epistemos_coreFFI.modulemap ../build-rust/swift-bindings/epistemos_coreFFI/module.modulemap

# Only ad-hoc sign the staging dylib if NOT running inside Xcode.
if [ -z "${TARGET_BUILD_DIR:-}" ]; then
    codesign --force --sign - ../build-rust/libepistemos_core.dylib
fi

cleanup_temp_output
trap - EXIT

echo "epistemos-core build complete"
