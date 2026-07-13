#!/bin/bash
set -euo pipefail

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]; then
    exit 0
fi

RESOURCES_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
EDITOR_SOURCE_DIR="$SRCROOT/Epistemos/Resources/Editor"
EDITOR_BUNDLE_DIR="$RESOURCES_DIR/Editor"
CORE_EDITOR_SOURCE_DIR="$SRCROOT/Epistemos/Resources/CoreEditor"
CORE_EDITOR_BUNDLE_DIR="$RESOURCES_DIR/CoreEditor"
CORE_EDITOR_CHUNKS_SOURCE_DIR="$SRCROOT/Epistemos/Resources/CoreEditor/chunks"
CORE_EDITOR_CHUNKS_BUNDLE_DIR="$RESOURCES_DIR/chunks"
PYODIDE_SOURCE_DIR="${EPISTEMOS_PYODIDE_SOURCE:-$SRCROOT/Epistemos/Resources/Pyodide}"
PYODIDE_BUNDLE_DIR="$RESOURCES_DIR/Pyodide"
MODEL_MANIFEST_SOURCE="${EPISTEMOS_MODEL_MANIFEST_SOURCE:-$SRCROOT/config/model_manifest.json}"
MODEL_MANIFEST_DEST="$RESOURCES_DIR/model_manifest.json"
DEFAULT_SKILLS_SOURCE_DIR="$SRCROOT/.agents/skills"
DEFAULT_SKILLS_DIR="$RESOURCES_DIR/DefaultSkills"

is_app_store_build() {
    [[ "${EPISTEMOS_APP_STORE:-}" == "1" ]] ||
        [[ "${PRODUCT_BUNDLE_IDENTIFIER:-}" == "com.epistemos.appstore" ]] ||
        [[ "${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-}" == *"EPISTEMOS_APP_STORE"* ]]
}

is_free_v1_build() {
    [[ "${EPISTEMOS_PRODUCT_EDITION:-}" == "FREE_V1" ]] ||
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

is_complete_pyodide_tree() {
    local candidate="$1"
    [ -d "$candidate" ] &&
        [ -f "$candidate/pyodide.js" ] &&
        [ -f "$candidate/pyodide.mjs" ] &&
        [ -f "$candidate/pyodide.asm.mjs" ] &&
        [ -f "$candidate/pyodide.asm.wasm" ] &&
        [ -f "$candidate/python_stdlib.zip" ] &&
        [ -f "$candidate/pyodide-lock.json" ]
}

bundle_pyodide_resources() {
    if ! is_complete_pyodide_tree "$PYODIDE_SOURCE_DIR"; then
        rm -rf "$PYODIDE_BUNDLE_DIR"
        remove_flattened_pyodide_resources
        return
    fi

    mkdir -p "$PYODIDE_BUNDLE_DIR"
    rsync -a --delete \
        --include='pyodide.js' \
        --include='pyodide.mjs' \
        --include='pyodide.asm.mjs' \
        --include='pyodide.asm.wasm' \
        --include='python_stdlib.zip' \
        --include='pyodide-lock.json' \
        --include='package.json' \
        --include='README.md' \
        --exclude='*' \
        "$PYODIDE_SOURCE_DIR/" \
        "$PYODIDE_BUNDLE_DIR/"

    remove_flattened_pyodide_resources
}

remove_flattened_pyodide_resources() {
    if [ ! -d "$PYODIDE_SOURCE_DIR" ]; then
        return
    fi

    while IFS= read -r -d '' source_file; do
        rm -f "$RESOURCES_DIR/$(basename "$source_file")"
    done < <(find "$PYODIDE_SOURCE_DIR" -maxdepth 1 -type f -print0)
}

bundle_model_manifest() {
    if is_free_v1_build; then
        rm -f "$MODEL_MANIFEST_DEST"
        return
    fi
    if [ -f "$MODEL_MANIFEST_SOURCE" ]; then
        rsync -a "$MODEL_MANIFEST_SOURCE" "$MODEL_MANIFEST_DEST"
    else
        rm -f "$MODEL_MANIFEST_DEST"
    fi
}

bundle_default_skills() {
    if is_free_v1_build; then
        rm -rf "$DEFAULT_SKILLS_DIR"
        return
    fi
    if [ ! -d "$DEFAULT_SKILLS_SOURCE_DIR" ]; then
        rm -rf "$DEFAULT_SKILLS_DIR"
        return
    fi

    mkdir -p "$DEFAULT_SKILLS_DIR"
    rsync -a --delete --prune-empty-dirs \
        --include='*/' \
        --include='SKILL.md' \
        --exclude='*' \
        "$DEFAULT_SKILLS_SOURCE_DIR/" \
        "$DEFAULT_SKILLS_DIR/"
}

# MAS agent surface (Plan 1-MAS): the vendored June web bundle, staged by
# build-june-web.sh into .june-web-stage/ (outside Epistemos/Resources — the
# resources glob flattens directory payloads). AppStore target only.
JUNE_WEB_SOURCE_DIR="$SRCROOT/.june-web-stage"
JUNE_WEB_BUNDLE_DIR="$RESOURCES_DIR/JuneWeb"

is_complete_june_web_tree() {
    local candidate="$1"
    [ -d "$candidate" ] &&
        [ -f "$candidate/dist/index.html" ] &&
        [ -f "$candidate/tauri-internals-shim.js" ]
}

bundle_june_web() {
    if is_free_v1_build; then
        rm -rf "$JUNE_WEB_BUNDLE_DIR"
        return 0
    fi
    if ! is_app_store_build; then
        rm -rf "$JUNE_WEB_BUNDLE_DIR"
        return 0
    fi
    if ! is_complete_june_web_tree "$JUNE_WEB_SOURCE_DIR"; then
        rm -rf "$JUNE_WEB_BUNDLE_DIR"
        echo "ERROR: App Store build requires staged JuneWeb files: .june-web-stage/dist/index.html and .june-web-stage/tauri-internals-shim.js" >&2
        echo "Run build-june-web.sh before archiving, or keep it wired in the App Store prebuild phase." >&2
        return 1
    fi
    mkdir -p "$JUNE_WEB_BUNDLE_DIR"
    rsync -a --delete --exclude ".gitignore" "$JUNE_WEB_SOURCE_DIR/" "$JUNE_WEB_BUNDLE_DIR/"
}

remove_app_store_forbidden_runtime_artifacts() {
    # Defense in depth: a staged or restored bundle must not retain any retired
    # executable, local-server, or downloaded-code artifact.
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

    if is_free_v1_build; then
        rm -rf "$JUNE_WEB_BUNDLE_DIR"
        rm -rf "$DEFAULT_SKILLS_DIR"
        rm -f "$MODEL_MANIFEST_DEST"
    fi
}

bundle_editor_resources
bundle_coreeditor_resources
bundle_pyodide_resources
bundle_model_manifest
bundle_default_skills
bundle_june_web

remove_app_store_forbidden_runtime_artifacts
