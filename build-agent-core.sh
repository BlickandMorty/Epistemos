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

FEATURE_ARGS=()
# V2.3 (2026-05-05): the lsp-runtime feature ships the in-process LSP
# kernel + the lsp_send_message_json / lsp_poll_response_json /
# lsp_lifecycle_state_debug FFI exports the Swift `RustLSPTransport`
# consumes. Carries zero new Cargo dependencies (hand-rolled
# JSON-RPC over serde_json which is already a dep) so this is a
# free addition for both MAS + Pro builds.
if [ "${TARGET_NAME:-}" = "Epistemos-AppStore" ] || [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" = "com.epistemos.appstore" ]; then
    FEATURE_ARGS+=(--no-default-features --features "mas-build,lsp-runtime")
else
    # Keep the Plan 3 PDF parser wired when the direct/pro app build disables
    # Cargo defaults. The older liteparse/PDFium path stays opt-in.
    FEATURE_ARGS+=(--no-default-features --features "pro-build,lsp-runtime,edgeparse-pdf,parser-unpdf")
fi

CARGO_TARGET_ARGS=(--lib)
if [ "${AGENT_CORE_BUILD_BINS:-0}" = "1" ]; then
    CARGO_TARGET_ARGS=()
fi

REQUESTED_ARCHS="${ARCHS:-${CURRENT_ARCH:-${NATIVE_ARCH_ACTUAL:-arm64 x86_64}}}"
BUILD_ARM64=0
BUILD_X86_64=0
case " $REQUESTED_ARCHS " in
    *" arm64 "*) BUILD_ARM64=1 ;;
esac
case " $REQUESTED_ARCHS " in
    *" x86_64 "*) BUILD_X86_64=1 ;;
esac
if [ "$BUILD_ARM64" -eq 0 ] && [ "$BUILD_X86_64" -eq 0 ]; then
    BUILD_ARM64=1
fi

if [ "$CONFIGURATION" = "Debug" ]; then
    if [ "$BUILD_ARM64" -eq 1 ]; then
        cargo build "${CARGO_TARGET_ARGS[@]}" "${FEATURE_ARGS[@]}" --target aarch64-apple-darwin
    fi
    if [ "$BUILD_X86_64" -eq 1 ]; then
        cargo build "${CARGO_TARGET_ARGS[@]}" "${FEATURE_ARGS[@]}" --target x86_64-apple-darwin
    fi
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libagent_core.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libagent_core.dylib"
else
    if [ "$BUILD_ARM64" -eq 1 ]; then
        cargo build "${CARGO_TARGET_ARGS[@]}" "${FEATURE_ARGS[@]}" --release --target aarch64-apple-darwin
    fi
    if [ "$BUILD_X86_64" -eq 1 ]; then
        cargo build "${CARGO_TARGET_ARGS[@]}" "${FEATURE_ARGS[@]}" --release --target x86_64-apple-darwin
    fi
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libagent_core.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libagent_core.dylib"
fi

mkdir -p ../build-rust
rm -f ../build-rust/libagent_core.a
rm -f ../build-rust/libagent_core.dylib
TEMP_OUTPUT="$(mktemp ../build-rust/libagent_core.XXXXXX)"
cleanup_temp_output() {
    rm -f "$TEMP_OUTPUT"
}
trap cleanup_temp_output EXIT
LIPO_INPUTS=()
if [ "$BUILD_ARM64" -eq 1 ]; then
    LIPO_INPUTS+=("$ARM64_LIB_PATH")
fi
if [ "$BUILD_X86_64" -eq 1 ]; then
    LIPO_INPUTS+=("$X86_64_LIB_PATH")
fi
if [ "${#LIPO_INPUTS[@]}" -eq 1 ]; then
    cp "${LIPO_INPUTS[0]}" "$TEMP_OUTPUT"
else
    lipo -create "${LIPO_INPUTS[@]}" -output "$TEMP_OUTPUT"
fi
mv -f "$TEMP_OUTPUT" ../build-rust/libagent_core.dylib
trap - EXIT
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

HOST_LIB_PATH="${LIPO_INPUTS[0]}"
if [ "$HOST_TRIPLE" = "aarch64-apple-darwin" ] && [ "$BUILD_ARM64" -eq 1 ]; then
    HOST_LIB_PATH="$ARM64_LIB_PATH"
elif [ "$HOST_TRIPLE" = "x86_64-apple-darwin" ] && [ "$BUILD_X86_64" -eq 1 ]; then
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
