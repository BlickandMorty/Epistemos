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

cd "$(dirname "$0")/agent_core"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    cargo build --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libagent_core.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libagent_core.dylib"
else
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libagent_core.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libagent_core.dylib"
fi

mkdir -p ../build-rust
rm -f ../build-rust/libagent_core.a
rm -f ../build-rust/libagent_core.dylib
TEMP_OUTPUT="$(mktemp ../build-rust/libagent_core.XXXXXX.dylib)"
lipo -create "$ARM64_LIB_PATH" "$X86_64_LIB_PATH" -output "$TEMP_OUTPUT"
mv -f "$TEMP_OUTPUT" ../build-rust/libagent_core.dylib
install_name_tool -id "@rpath/libagent_core.dylib" ../build-rust/libagent_core.dylib

if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
    bash ../embed-and-sign-rust-dylib.sh \
        ../build-rust/libagent_core.dylib \
        "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libagent_core.dylib"
fi

mkdir -p ../build-rust/swift-bindings
HOST_TRIPLE="$(rustc -vV | sed -n 's/^host: //p')"
UNIFFI_BINDGEN="../epistemos-core/target/${HOST_TRIPLE}/debug/uniffi_bindgen"
if [ ! -x "$UNIFFI_BINDGEN" ]; then
    cargo build --manifest-path ../epistemos-core/Cargo.toml --target "$HOST_TRIPLE" --bin uniffi_bindgen
fi
# Sign uniffi_bindgen BEFORE invoking it — AMFI kills adhoc-signed
# binaries on hardened macOS. User's production log showed repeated
# kernel kills here when invoke-before-sign was the order.
for bin in "$UNIFFI_BINDGEN" \
           target/aarch64-apple-darwin/debug/uniffi_bindgen \
           target/x86_64-apple-darwin/debug/uniffi_bindgen \
           target/aarch64-apple-darwin/release/uniffi_bindgen \
           target/x86_64-apple-darwin/release/uniffi_bindgen \
           ../epistemos-core/target/*/debug/uniffi_bindgen \
           ../epistemos-core/target/*/release/uniffi_bindgen; do
    [ -f "$bin" ] && codesign --force --sign - "$bin" 2>/dev/null || true
done

HOST_LIB_PATH="$ARM64_LIB_PATH"
if [ "$HOST_TRIPLE" = "x86_64-apple-darwin" ]; then
    HOST_LIB_PATH="$X86_64_LIB_PATH"
fi
"$UNIFFI_BINDGEN" generate \
    --library "$HOST_LIB_PATH" \
    --crate agent_core \
    --language swift \
    --no-format \
    --out-dir ../build-rust/swift-bindings/

python3 ../patch-uniffi-bindings.py ../build-rust/swift-bindings/agent_core.swift

mkdir -p ../build-rust/swift-bindings/agent_coreFFI
cp ../build-rust/swift-bindings/agent_coreFFI.h ../build-rust/swift-bindings/agent_coreFFI/agent_coreFFI.h
cp ../build-rust/swift-bindings/agent_coreFFI.modulemap ../build-rust/swift-bindings/agent_coreFFI/module.modulemap

if [ -z "${TARGET_BUILD_DIR:-}" ]; then
    codesign --force --sign - ../build-rust/libagent_core.dylib
fi

echo "agent-core build complete"
