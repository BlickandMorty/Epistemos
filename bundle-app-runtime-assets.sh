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
GOOSE_BINARY_DEST="$RESOURCES_DIR/goose"
GOOSED_BINARY_DEST="$RESOURCES_DIR/goosed"

is_app_store_build() {
    [[ "${EPISTEMOS_APP_STORE:-}" == "1" ]] ||
        [[ "${PRODUCT_BUNDLE_IDENTIFIER:-}" == "com.epistemos.appstore" ]] ||
        [[ "${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-}" == *"EPISTEMOS_APP_STORE"* ]]
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
    if [ -f "$MODEL_MANIFEST_SOURCE" ]; then
        rsync -a "$MODEL_MANIFEST_SOURCE" "$MODEL_MANIFEST_DEST"
    else
        rm -f "$MODEL_MANIFEST_DEST"
    fi
}

bundle_default_skills() {
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

host_cargo_target_triple() {
    case "$(uname -m)" in
        arm64) printf '%s\n' "aarch64-apple-darwin" ;;
        x86_64) printf '%s\n' "x86_64-apple-darwin" ;;
        *) printf '%s\n' "" ;;
    esac
}

# Emit candidate source paths for a Goose runtime binary by name ("goose" or
# "goosed"). Mirrors GooseRuntimeSupervisor.gooseBinaryCandidates(binaryName:)
# so the Swift resolver and the bundler agree on where each binary lives.
goose_binary_candidates() {
    local binary_name="${1:-goose}"

    # Per-binary explicit override (EPISTEMOS_GOOSE_BINARY / EPISTEMOS_GOOSED_BINARY).
    local override_var
    if [ "$binary_name" = "goosed" ]; then
        override_var="EPISTEMOS_GOOSED_BINARY"
    else
        override_var="EPISTEMOS_GOOSE_BINARY"
    fi
    if [ -n "${!override_var:-}" ]; then
        printf '%s\n' "${!override_var}"
    fi
    if [ -n "${EPISTEMOS_GOOSE_RUNTIME_DIR:-}" ]; then
        printf '%s\n' "$EPISTEMOS_GOOSE_RUNTIME_DIR/$binary_name"
    fi

    local target_root="$SRCROOT/.research-clones/work/goose/target"
    local host_triple
    host_triple="$(host_cargo_target_triple)"
    if [ -n "$host_triple" ]; then
        printf '%s\n' "$target_root/$host_triple/release/$binary_name"
        printf '%s\n' "$target_root/$host_triple/debug/$binary_name"
    fi
    printf '%s\n' "$target_root/release/$binary_name"
    printf '%s\n' "$target_root/debug/$binary_name"
}

# Stage one Goose runtime binary by name into the given bundle destination.
# Used for both the lean `goose` (default backend) and `goosed` (Option B). Both
# are staged during the parity-gated transition so EPISTEMOS_GOOSE_BACKEND can
# select either without a rebuild (single-point rollback); the final cutover
# drops `goose`. Missing source is non-fatal — it just leaves that backend
# unavailable, exactly like before this change for `goose`.
bundle_goose_runtime_binary_named() {
    local binary_name="$1"
    local dest="$2"

    if is_app_store_build; then
        rm -f "$dest"
        return
    fi

    local source=""
    while IFS= read -r candidate; do
        if [ -x "$candidate" ]; then
            source="$candidate"
            break
        fi
    done < <(goose_binary_candidates "$binary_name")

    if [ -z "$source" ]; then
        rm -f "$dest"
        return
    fi

    rsync -a "$source" "$dest"
    chmod 755 "$dest"
}

bundle_goose_runtime_binary() {
    bundle_goose_runtime_binary_named "goose" "$GOOSE_BINARY_DEST"
    bundle_goose_runtime_binary_named "goosed" "$GOOSED_BINARY_DEST"
}

# MAS agent surface (Plan 1-MAS): the vendored June web bundle, staged by
# build-june-web.sh into .june-web-stage/ (outside Epistemos/Resources — the
# resources glob flattens directory payloads). AppStore target only.
JUNE_WEB_SOURCE_DIR="$SRCROOT/.june-web-stage"
JUNE_WEB_BUNDLE_DIR="$RESOURCES_DIR/JuneWeb"

bundle_june_web() {
    if ! is_app_store_build; then
        rm -rf "$JUNE_WEB_BUNDLE_DIR"
        return 0
    fi
    if [ ! -f "$JUNE_WEB_SOURCE_DIR/dist/index.html" ]; then
        # Stage absent: dev builds fall back to the fork working copy
        # (JuneWebAssets DEBUG candidate); nothing to bundle.
        rm -rf "$JUNE_WEB_BUNDLE_DIR"
        return 0
    fi
    mkdir -p "$JUNE_WEB_BUNDLE_DIR"
    rsync -a --delete --exclude ".gitignore" "$JUNE_WEB_SOURCE_DIR/" "$JUNE_WEB_BUNDLE_DIR/"
}

remove_app_store_forbidden_runtime_artifacts() {
    # Xcode's synchronized resource groups flatten runtime bin/ sentinels into
    # Contents/Resources. MAS builds must not ship Pro-only process runtimes or
    # stdio MCP binaries, even when their source folders exist for direct builds.
    rm -f "$RESOURCES_DIR/goose"
    rm -f "$RESOURCES_DIR/goosed"
    rm -f "$RESOURCES_DIR/node"
    rm -f "$RESOURCES_DIR/bun"
    rm -f "$RESOURCES_DIR/opencode"
    rm -f "$RESOURCES_DIR/omega_mcp_stdio"
    rm -f "$RESOURCES_DIR"/.bun-*-bun-darwin-*
    rm -f "$RESOURCES_DIR"/.opencode-*-opencode-darwin-*
}

bundle_editor_resources
bundle_coreeditor_resources
bundle_pyodide_resources
bundle_model_manifest
bundle_default_skills
bundle_june_web

if is_app_store_build; then
    remove_app_store_forbidden_runtime_artifacts
else
    bundle_goose_runtime_binary
fi
