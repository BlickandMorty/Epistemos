#!/bin/bash
set -euo pipefail

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ] || [ -z "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
    exit 0
fi

RESOURCES_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
FRAMEWORKS_DIR="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
PACKAGE_FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR:-$TARGET_BUILD_DIR}/PackageFrameworks"
EDITOR_SOURCE_DIR="$SRCROOT/Epistemos/Resources/Editor"
EDITOR_BUNDLE_DIR="$RESOURCES_DIR/Editor"
CORE_EDITOR_SOURCE_DIR="$SRCROOT/Epistemos/Resources/CoreEditor"
CORE_EDITOR_BUNDLE_DIR="$RESOURCES_DIR/CoreEditor"
CORE_EDITOR_CHUNKS_SOURCE_DIR="$SRCROOT/Epistemos/Resources/CoreEditor/chunks"
CORE_EDITOR_CHUNKS_BUNDLE_DIR="$RESOURCES_DIR/chunks"
JUNE_WEB_SOURCE_DIR="$SRCROOT/.june-web-stage"
JUNE_WEB_BUNDLE_DIR="$RESOURCES_DIR/JuneWeb"

is_free_v1_build() {
    if [ -n "${EPISTEMOS_PRODUCT_EDITION:-}" ]; then
        [[ "$EPISTEMOS_PRODUCT_EDITION" == "FREE_V1" ]]
        return
    fi
    [[ "${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-}" == *"EPISTEMOS_FREE_V1"* ]]
}

bundle_editor_resources() {
    if [ ! -d "$EDITOR_SOURCE_DIR" ]; then
        return
    fi

    mkdir -p "$EDITOR_BUNDLE_DIR"
    rsync -a --delete "$EDITOR_SOURCE_DIR/" "$EDITOR_BUNDLE_DIR/"

    # Xcode's synchronized resource groups flatten generated editor files
    # into Contents/Resources. Keep the canonical Resources/Editor tree and
    # remove the duplicate root-level copies so the bundle stays small.
    while IFS= read -r -d '' source_file; do
        rm -f "$RESOURCES_DIR/$(basename "$source_file")"
    done < <(find "$EDITOR_SOURCE_DIR" -type f -print0)
}

bundle_coreeditor_resources() {
    if [ -d "$CORE_EDITOR_SOURCE_DIR" ]; then
        mkdir -p "$CORE_EDITOR_BUNDLE_DIR"
        rsync -a --delete "$CORE_EDITOR_SOURCE_DIR/" "$CORE_EDITOR_BUNDLE_DIR/"
    else
        rm -rf "$CORE_EDITOR_BUNDLE_DIR"
    fi

    if [ -d "$CORE_EDITOR_CHUNKS_SOURCE_DIR" ]; then
        mkdir -p "$CORE_EDITOR_CHUNKS_BUNDLE_DIR"
        rsync -a --delete "$CORE_EDITOR_CHUNKS_SOURCE_DIR/" "$CORE_EDITOR_CHUNKS_BUNDLE_DIR/"
    else
        rm -rf "$CORE_EDITOR_CHUNKS_BUNDLE_DIR"
    fi

    # Xcode may flatten CoreEditor/index.html into Contents/Resources.
    # The runtime loader uses the canonical CoreEditor/ directory first;
    # remove the flattened duplicate so a stale root index cannot mask a
    # missing chunk tree during manual bundle inspection.
    if [ -f "$CORE_EDITOR_SOURCE_DIR/index.html" ]; then
        rm -f "$RESOURCES_DIR/index.html"
    fi
}

bundle_required_package_frameworks() {
    # GRDB is linked by the Free V1 app module. Xcode places Swift Package
    # products in PackageFrameworks during a build, but that location is not
    # part of a shipped app bundle. Copy the real framework into Contents/
    # Frameworks so @rpath resolves after launch and in the hosted test app.
    [ -d "$PACKAGE_FRAMEWORKS_DIR" ] || return

    mkdir -p "$FRAMEWORKS_DIR"
    while IFS= read -r -d '' framework; do
        rsync -a --delete "$framework/" "$FRAMEWORKS_DIR/$(basename "$framework")/"
    done < <(find "$PACKAGE_FRAMEWORKS_DIR" -maxdepth 1 -type d -name 'GRDB_*.framework' -print0)
}

bundle_june_web() {
    if is_free_v1_build; then
        rm -rf "$JUNE_WEB_BUNDLE_DIR"
        return
    fi
    if [ ! -f "$JUNE_WEB_SOURCE_DIR/dist/index.html" ] ||
       [ ! -f "$JUNE_WEB_SOURCE_DIR/tauri-internals-shim.js" ]; then
        echo "ERROR: base app requires the staged June web bundle" >&2
        exit 1
    fi
    mkdir -p "$JUNE_WEB_BUNDLE_DIR"
    rsync -a --delete "$JUNE_WEB_SOURCE_DIR/" "$JUNE_WEB_BUNDLE_DIR/"
}

remove_free_v1_forbidden_resources() {
    # Defense in depth: retain only the editor inputs copied above and reject
    # stale paid, executable, local-server, or downloaded-code resources.
    if is_free_v1_build; then
        rm -rf "$RESOURCES_DIR/JuneWeb"
    fi
    rm -rf "$RESOURCES_DIR/DefaultSkills"
    rm -f "$RESOURCES_DIR/model_manifest.json"
    rm -rf "$RESOURCES_DIR/Pyodide"
    rm -rf "$RESOURCES_DIR/experimental-runtime"
    rm -rf "$RESOURCES_DIR/opencode-runtime"
    rm -rf "$RESOURCES_DIR/GooseRuntime"
    rm -rf "$RESOURCES_DIR/OpenChamberWeb"
    rm -f "$RESOURCES_DIR/pyodide.js"
    rm -f "$RESOURCES_DIR/pyodide.mjs"
    rm -f "$RESOURCES_DIR/pyodide.asm.mjs"
    rm -f "$RESOURCES_DIR/pyodide.asm.wasm"
    rm -f "$RESOURCES_DIR/python_stdlib.zip"
    rm -f "$RESOURCES_DIR/pyodide-lock.json"
    rm -f "$RESOURCES_DIR/goose"
    rm -f "$RESOURCES_DIR/goosed"
    rm -f "$RESOURCES_DIR/node"
    rm -f "$RESOURCES_DIR/codex"
    rm -f "$RESOURCES_DIR/rg"
    rm -f "$RESOURCES_DIR/bun"
    rm -f "$RESOURCES_DIR/opencode"
    rm -f "$RESOURCES_DIR/omega_mcp_stdio"
    rm -f "$RESOURCES_DIR/experimental-web.tar.gz"
    rm -f "$RESOURCES_DIR"/.bun-*-bun-darwin-*
    rm -f "$RESOURCES_DIR"/.opencode-*-opencode-darwin-*

}

bundle_editor_resources
bundle_coreeditor_resources
bundle_required_package_frameworks
bundle_june_web
remove_free_v1_forbidden_resources
