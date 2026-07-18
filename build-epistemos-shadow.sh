#!/bin/bash
set -e

# Free V1 build script for the epistemos-shadow lexical crate.
#
# Builds a fat libepistemos_shadow.dylib covering both arm64 and
# x86_64 macOS architectures, then installs it next to the executable
# via embed-and-sign-rust-dylib.sh. The explicit feature selection is
# part of the Free build boundary: no semantic/model dependency may be
# selected implicitly by Cargo defaults.

if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

if [ "${ENABLE_THREAD_SANITIZER:-NO}" = "YES" ]; then
    export CARGO_PROFILE_DEV_PANIC=abort
    export RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS } -C panic=abort"
fi

cd "$(dirname "$0")/epistemos-shadow"

if [ "$CONFIGURATION" = "Debug" ]; then
    cargo build --no-default-features --features free-lexical --target aarch64-apple-darwin
    cargo build --no-default-features --features free-lexical --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/debug/libepistemos_shadow.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/debug/libepistemos_shadow.dylib"
else
    cargo build --release --no-default-features --features free-lexical --target aarch64-apple-darwin
    cargo build --release --no-default-features --features free-lexical --target x86_64-apple-darwin
    ARM64_LIB_PATH="target/aarch64-apple-darwin/release/libepistemos_shadow.dylib"
    X86_64_LIB_PATH="target/x86_64-apple-darwin/release/libepistemos_shadow.dylib"
fi

mkdir -p ../build-rust
STAGING_LOCK="../build-rust/.libepistemos_shadow.lock"
TEMP_OUTPUT="$(mktemp ../build-rust/libepistemos_shadow.XXXXXX)"
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
install_name_tool -id "@rpath/libepistemos_shadow.dylib" "$TEMP_OUTPUT"

acquire_staging_lock
rm -f ../build-rust/libepistemos_shadow.dylib ../build-rust/libepistemos_shadow.a
mv -f "$TEMP_OUTPUT" ../build-rust/libepistemos_shadow.dylib

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

cleanup_temp_output
trap - EXIT

echo "epistemos-shadow build complete (dylib)"
