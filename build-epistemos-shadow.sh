#!/bin/bash
set -e

# Wave 8.1 / 8.4 build script for the epistemos-shadow crate.
#
# Builds a fat libepistemos_shadow.dylib covering both arm64 and
# x86_64 macOS architectures, then installs it next to the executable
# via embed-and-sign-rust-dylib.sh — the same canonical pattern
# epistemos-core, agent-core, omega-mcp, and omega-ax already use.
#
# Why dylib (W8.7 follow-up): epistemos-shadow depends on `usearch`,
# whose cxxbridge generates C++ symbols (NativeIndex::*,
# `_cxxbridge1$rust_vec$f32$*`, …). graph-engine also depends on
# usearch and ships the same symbols. Linking BOTH static archives
# into the host app explodes ld with 268 duplicate symbols. Building
# epistemos-shadow as a dylib hides those internal C++ symbols
# behind the dylib boundary; only the `shadow_*` C ABI is exported.

if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

if [ "${ENABLE_THREAD_SANITIZER:-NO}" = "YES" ]; then
    export CARGO_PROFILE_DEV_PANIC=abort
    export RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS } -C panic=abort"
fi

cd "$(dirname "$0")/epistemos-shadow"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --target aarch64-apple-darwin
    cargo build --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libepistemos_shadow.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libepistemos_shadow.dylib"
else
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libepistemos_shadow.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libepistemos_shadow.dylib"
fi

mkdir -p ../build-rust
rm -f ../build-rust/libepistemos_shadow.dylib ../build-rust/libepistemos_shadow.a
TEMP_OUTPUT="$(mktemp ../build-rust/libepistemos_shadow.XXXXXX.dylib)"
lipo -create "$ARM64_LIB_PATH" "$X86_64_LIB_PATH" -output "$TEMP_OUTPUT"
mv -f "$TEMP_OUTPUT" ../build-rust/libepistemos_shadow.dylib

install_name_tool -id "@rpath/libepistemos_shadow.dylib" \
    ../build-rust/libepistemos_shadow.dylib

if [ -n "${TARGET_BUILD_DIR:-}" ]; then
    rm -f "$TARGET_BUILD_DIR/PackageFrameworks/libepistemos_shadow.dylib"
fi

if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
    bash ../embed-and-sign-rust-dylib.sh \
        ../build-rust/libepistemos_shadow.dylib \
        "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libepistemos_shadow.dylib"
fi

if [ -z "${TARGET_BUILD_DIR:-}" ]; then
    codesign --force --sign - ../build-rust/libepistemos_shadow.dylib
fi

echo "epistemos-shadow build complete (dylib)"
