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
CORE_EDITOR_CHUNKS_SOURCE_DIR="$SRCROOT/Epistemos/Resources/chunks"
CORE_EDITOR_CHUNKS_BUNDLE_DIR="$RESOURCES_DIR/chunks"
DEFAULT_SKILLS_SOURCE_DIR="$SRCROOT/.agents/skills"
DEFAULT_SKILLS_DIR="$RESOURCES_DIR/DefaultSkills"
GOOSE_BINARY_DEST="$RESOURCES_DIR/goose"
GOOSE_WEB_UI_DEST="$RESOURCES_DIR/goose-desktop"
GOOSE_WEB_UI_STAGE_SCRIPT="${EPISTEMOS_GOOSE_UI_STAGE_SCRIPT:-$SRCROOT/stage-goose-web-ui.sh}"
STAGED_GOOSE_WEB_UI_SOURCE=""

cleanup_runtime_asset_staging() {
    if [ -n "$STAGED_GOOSE_WEB_UI_SOURCE" ] && [ -d "$STAGED_GOOSE_WEB_UI_SOURCE" ]; then
        rm -rf "$STAGED_GOOSE_WEB_UI_SOURCE"
    fi
}
trap cleanup_runtime_asset_staging EXIT

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

goose_binary_candidates() {
    if [ -n "${EPISTEMOS_GOOSE_BINARY:-}" ]; then
        printf '%s\n' "$EPISTEMOS_GOOSE_BINARY"
    fi
    if [ -n "${EPISTEMOS_GOOSE_RUNTIME_DIR:-}" ]; then
        printf '%s\n' "$EPISTEMOS_GOOSE_RUNTIME_DIR/goose"
    fi

    local target_root="$SRCROOT/.research-clones/work/goose/target"
    local host_triple
    host_triple="$(host_cargo_target_triple)"
    if [ -n "$host_triple" ]; then
        printf '%s\n' "$target_root/$host_triple/release/goose"
        printf '%s\n' "$target_root/$host_triple/debug/goose"
    fi
    printf '%s\n' "$target_root/release/goose"
    printf '%s\n' "$target_root/debug/goose"
}

bundle_goose_runtime_binary() {
    if is_app_store_build; then
        rm -f "$GOOSE_BINARY_DEST"
        return
    fi

    local source=""
    while IFS= read -r candidate; do
        if [ -x "$candidate" ]; then
            source="$candidate"
            break
        fi
    done < <(goose_binary_candidates)

    if [ -z "$source" ]; then
        rm -f "$GOOSE_BINARY_DEST"
        return
    fi

    rsync -a "$source" "$GOOSE_BINARY_DEST"
    chmod 755 "$GOOSE_BINARY_DEST"
}

goose_web_ui_explicit_candidates() {
    if [ -n "${EPISTEMOS_GOOSE_UI_BUNDLE_SOURCE:-}" ]; then
        printf '%s\n' "$EPISTEMOS_GOOSE_UI_BUNDLE_SOURCE"
    fi
    if [ -n "${EPISTEMOS_GOOSE_UI_OUT:-}" ]; then
        printf '%s\n' "$EPISTEMOS_GOOSE_UI_OUT"
    fi
}

goose_web_ui_fallback_candidates() {
    printf '%s\n' "$SRCROOT/.research-clones/work/goose/ui/desktop/dist"
}

is_acp_goose_web_ui() {
    local candidate="$1"
    [ -f "$candidate/index.html" ] &&
        [ -f "$candidate/.epistemos-goose-webui.json" ] &&
        grep -q '"acpMode"[[:space:]]*:[[:space:]]*true' "$candidate/.epistemos-goose-webui.json" &&
        goose_web_ui_contains_required_markers "$candidate"
}

goose_web_ui_contains_required_markers() {
    local candidate="$1"
    local marker
    local search_paths=("$candidate/index.html")
    if [ -d "$candidate/assets" ]; then
        search_paths+=("$candidate/assets")
    fi
    for marker in \
        "providersList_unstable" \
        "providersCatalogList_unstable" \
        "providersSetupCatalogList_unstable" \
        "providersCatalogTemplate_unstable" \
        "shared-getAcpClient-provider-inventory" \
        "local-acp-config-GOOSE_TELEMETRY_ENABLED" \
        "__epistemosGooseACPRequestSerialization" \
        "__epistemosGooseProviderInventoryEvents" \
        "__epistemosGooseProviderCatalogEvents" \
        "provider-catalog-template-choice"; do
        if ! grep -R -q -- "$marker" "${search_paths[@]}" 2>/dev/null; then
            return 1
        fi
    done
}

bundle_goose_web_ui() {
    if is_app_store_build; then
        rm -rf "$GOOSE_WEB_UI_DEST"
        return
    fi

    local source=""
    while IFS= read -r candidate; do
        if is_acp_goose_web_ui "$candidate"; then
            source="$candidate"
            break
        fi
    done < <(goose_web_ui_explicit_candidates)

    if [ -z "$source" ] && [ -x "$GOOSE_WEB_UI_STAGE_SCRIPT" ]; then
        local staged_source
        staged_source="$(mktemp -d "${TMPDIR:-/tmp}/epistemos-goose-webui-bundle.XXXXXX")"
        if "$GOOSE_WEB_UI_STAGE_SCRIPT" "$staged_source"; then
            if is_acp_goose_web_ui "$staged_source"; then
                source="$staged_source"
                STAGED_GOOSE_WEB_UI_SOURCE="$staged_source"
            else
                echo "Fresh Goose Web UI stage did not produce an ACP artifact manifest." >&2
                rm -rf "$staged_source"
            fi
        else
            rm -rf "$staged_source"
        fi
    fi

    if [ -z "$source" ]; then
        while IFS= read -r candidate; do
            if is_acp_goose_web_ui "$candidate"; then
                source="$candidate"
                break
            fi
        done < <(goose_web_ui_fallback_candidates)
    fi

    if [ -z "$source" ]; then
        rm -rf "$GOOSE_WEB_UI_DEST"
        return
    fi

    mkdir -p "$GOOSE_WEB_UI_DEST"
    rsync -a --delete "$source/" "$GOOSE_WEB_UI_DEST/"
}

bundle_editor_resources
bundle_coreeditor_resources
bundle_default_skills

if is_app_store_build; then
    rm -f "$GOOSE_BINARY_DEST"
    rm -rf "$GOOSE_WEB_UI_DEST"
else
    bundle_goose_runtime_binary
    bundle_goose_web_ui
fi
