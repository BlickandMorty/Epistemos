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
GOOSED_BINARY_DEST="$RESOURCES_DIR/goosed"
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
        goose_web_ui_referenced_assets_exist "$candidate" &&
        goose_web_ui_contains_required_markers "$candidate"
}

goose_web_ui_referenced_assets_exist() {
    local candidate="$1"
    node - "$candidate" <<'NODE'
const fs = require('fs');
const path = require('path');

const root = process.argv[2];
let html;
try {
  html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
} catch {
  process.exit(1);
}

const references = Array.from(html.matchAll(/(?:src|href)\s*=\s*["']([^"']+)["']/gi), match => match[1]);
for (const rawReference of references) {
  const reference = String(rawReference || '').trim();
  if (
    !reference ||
    reference.startsWith('#') ||
    reference.startsWith('data:') ||
    reference.startsWith('blob:') ||
    reference.startsWith('http://') ||
    reference.startsWith('https://') ||
    reference.startsWith('ws://') ||
    reference.startsWith('wss://') ||
    reference.startsWith('//') ||
    reference.startsWith('/')
  ) {
    if (reference.startsWith('/')) process.exit(1);
    continue;
  }
  const withoutFragment = reference.split('#', 1)[0];
  const withoutQuery = withoutFragment.split('?', 1)[0];
  const normalized = withoutQuery.startsWith('./') ? withoutQuery.slice(2) : withoutQuery;
  if (!normalized || normalized.includes('../')) process.exit(1);
  const resolved = path.resolve(root, normalized);
  const rootWithSeparator = path.resolve(root) + path.sep;
  if (!resolved.startsWith(rootWithSeparator) || !fs.existsSync(resolved)) {
    process.exit(1);
  }
}
NODE
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

copy_goose_web_ui_atomically() {
    local source="$1"
    local destination="$2"
    local parent
    parent="$(dirname "$destination")"
    mkdir -p "$parent"

    local staged_copy previous_copy
    staged_copy="$(mktemp -d "$parent/.goose-desktop.copy.XXXXXX")"
    previous_copy="$parent/.goose-desktop.previous.$$"
    rm -rf "$previous_copy"

    rsync -a --delete "$source/" "$staged_copy/"
    if ! is_acp_goose_web_ui "$staged_copy"; then
        echo "Fresh Goose Web UI copy failed self-validation." >&2
        rm -rf "$staged_copy"
        return 1
    fi

    if [ -e "$destination" ]; then
        mv "$destination" "$previous_copy"
    fi
    if ! mv "$staged_copy" "$destination"; then
        if [ -e "$previous_copy" ]; then
            mv "$previous_copy" "$destination"
        fi
        rm -rf "$staged_copy"
        return 1
    fi
    rm -rf "$previous_copy"
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

    copy_goose_web_ui_atomically "$source" "$GOOSE_WEB_UI_DEST"
}

bundle_editor_resources
bundle_coreeditor_resources
bundle_default_skills

if is_app_store_build; then
    rm -f "$GOOSE_BINARY_DEST"
    rm -f "$GOOSED_BINARY_DEST"
    rm -rf "$GOOSE_WEB_UI_DEST"
else
    bundle_goose_runtime_binary
    bundle_goose_web_ui
fi
