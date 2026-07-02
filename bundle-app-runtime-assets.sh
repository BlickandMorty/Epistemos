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
GOOSE_WEB_UI_DEST="$RESOURCES_DIR/goose-desktop"
BROWSER_USE_PRO_BUNDLE_DEST="$RESOURCES_DIR/BrowserUsePro.bundle"
BROWSER_USE_PRO_PACKAGE_RESULT_DEST="$RESOURCES_DIR/PACKAGE_RESULT.json"
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

browser_use_pro_bundle_candidates() {
    if [ -n "${EPISTEMOS_BROWSER_USE_PRO_BUNDLE_SOURCE:-}" ]; then
        printf '%s\n' "$EPISTEMOS_BROWSER_USE_PRO_BUNDLE_SOURCE"
    fi
    printf '%s\n' "$SRCROOT/build/browser-use-pro/BrowserUsePro.bundle"
}

signature_manifest_has_required_browser_use_pro_evidence() {
    local signature_manifest="$1"
python3 - "$signature_manifest" <<'PY'
import json
import os
import stat
import sys
from pathlib import Path

expected_repos = {
    "browser-use": "https://github.com/browser-use/browser-use.git",
    "web-ui": "https://github.com/browser-use/web-ui.git",
    "cdp-use": "https://github.com/browser-use/cdp-use.git",
}
expected_commits = {
    "browser-use": "2454d3e2551705232333c906ded8fc31ab0fc9f2",
    "web-ui": "61962296c38a0d064e0ba02c827192b7a81d1819",
    "cdp-use": "a318684daab5ab3a9a516fcab447ed4bdfb92be9",
}
expected_versions = {
    "browser-use": "0.13.2",
    "web-ui": None,
    "cdp-use": "1.4.5",
}
expected_playwright = {
    "chromium": "1223",
    "chromium_headless_shell": "1223",
    "ffmpeg": "1011",
}
expected_manifest_keys = {
    "schema_version",
    "package_name",
    "runtime_lane",
    "signature_type",
    "signing_identity",
    "payload_root",
    "file_count",
    "python",
    "browser_use_version",
    "component_repos",
    "component_commits",
    "component_versions",
    "playwright_revisions",
    "created_utc",
    "codesign_contract",
}
expected_codesign_contract = (
    "BrowserUsePro.bundle must pass codesign --verify --deep --strict before bundling "
    "and strict Security.framework validation at runtime."
)


def reject():
    sys.exit(1)


def path_has_symlink_component(path):
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = Path.cwd() / candidate

    current = Path(candidate.anchor)
    for part in candidate.parts[1:]:
        current = current / part
        if str(current) in {"/etc", "/tmp", "/var"}:
            continue
        if current.is_symlink():
            return True
    return False


def is_second_precision_utc_timestamp(value):
    if len(value) != 20:
        return False
    punctuation = {
        4: "-",
        7: "-",
        10: "T",
        13: ":",
        16: ":",
        19: "Z",
    }
    for index, character in enumerate(value):
        expected = punctuation.get(index)
        if expected is not None:
            if character != expected:
                return False
        elif not character.isdigit():
            return False
    return True


def required_string(manifest, key):
    value = manifest.get(key)
    if not isinstance(value, str) or not value.strip():
        reject()
    return value


def read_manifest_no_follow(path):
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_size <= 0 or metadata.st_size > 1024 * 1024:
            reject()
        with os.fdopen(fd, "rb") as handle:
            fd = None
            data = handle.read(1024 * 1024 + 1)
    finally:
        if fd is not None:
            os.close(fd)
    if len(data) > 1024 * 1024:
        reject()
    return data.decode("utf-8")


try:
    manifest_path = Path(sys.argv[1])
    if path_has_symlink_component(manifest_path) or manifest_path.is_symlink() or not manifest_path.is_file():
        reject()
    manifest = json.loads(read_manifest_no_follow(manifest_path))
except Exception:
    reject()

if not isinstance(manifest, dict):
    reject()
if set(manifest.keys()) != expected_manifest_keys:
    reject()
if manifest.get("schema_version") != 1:
    reject()
if required_string(manifest, "package_name") != "BrowserUsePro":
    reject()
if required_string(manifest, "runtime_lane") != "pro-developer-id-only":
    reject()
if required_string(manifest, "payload_root") != "Contents/Resources/BrowserUsePro":
    reject()
if required_string(manifest, "signature_type") not in {"ad-hoc", "apple-development", "developer-id"}:
    reject()
required_string(manifest, "signing_identity")
file_count = manifest.get("file_count")
if type(file_count) is not int or file_count <= 0 or file_count > 250000:
    reject()
if not required_string(manifest, "python").startswith("Python 3.11."):
    reject()
if required_string(manifest, "browser_use_version") != "0.13.2":
    reject()
created_utc = required_string(manifest, "created_utc")
if not is_second_precision_utc_timestamp(created_utc):
    reject()
if required_string(manifest, "codesign_contract") != expected_codesign_contract:
    reject()
if manifest.get("component_repos") != expected_repos:
    reject()
if manifest.get("component_commits") != expected_commits:
    reject()
if manifest.get("component_versions") != expected_versions:
    reject()
if manifest.get("playwright_revisions") != expected_playwright:
    reject()
PY
}

package_result_has_required_browser_use_pro_evidence() {
    local package_result="$1"
python3 - "$package_result" <<'PY'
import json
import os
import stat
import sys
from pathlib import Path

expected_result_keys = {
    "schema_version",
    "package_name",
    "bundle",
    "signature_manifest",
    "signature_type",
    "python",
    "codesign_verified",
    "smoke_suite_entrypoint",
    "smoke_suite_args",
    "notarization",
    "secrets",
    "created_utc",
}


def reject():
    sys.exit(1)


def path_has_symlink_component(path):
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = Path.cwd() / candidate

    current = Path(candidate.anchor)
    for part in candidate.parts[1:]:
        current = current / part
        if str(current) in {"/etc", "/tmp", "/var"}:
            continue
        if current.is_symlink():
            return True
    return False


def is_second_precision_utc_timestamp(value):
    if len(value) != 20:
        return False
    punctuation = {
        4: "-",
        7: "-",
        10: "T",
        13: ":",
        16: ":",
        19: "Z",
    }
    for index, character in enumerate(value):
        expected = punctuation.get(index)
        if expected is not None:
            if character != expected:
                return False
        elif not character.isdigit():
            return False
    return True


def required_string(result, key):
    value = result.get(key)
    if not isinstance(value, str) or not value.strip():
        reject()
    return value


def read_result_no_follow(path):
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_size <= 0 or metadata.st_size > 64 * 1024:
            reject()
        with os.fdopen(fd, "rb") as handle:
            fd = None
            data = handle.read(64 * 1024 + 1)
    finally:
        if fd is not None:
            os.close(fd)
    if len(data) > 64 * 1024:
        reject()
    return data.decode("utf-8")


try:
    package_result_path = Path(sys.argv[1])
    if path_has_symlink_component(package_result_path) or package_result_path.is_symlink() or not package_result_path.is_file():
        reject()
    result = json.loads(read_result_no_follow(package_result_path))
except Exception:
    reject()

if not isinstance(result, dict):
    reject()
if set(result.keys()) != expected_result_keys:
    reject()
if result.get("schema_version") != 1:
    reject()
if required_string(result, "package_name") != "BrowserUsePro":
    reject()
if required_string(result, "bundle") != "BrowserUsePro.bundle":
    reject()
if required_string(result, "signature_manifest") != "BrowserUsePro.bundle/Contents/Resources/BrowserUsePro/SIGNATURE_MANIFEST.json":
    reject()
if required_string(result, "signature_type") not in {"ad-hoc", "apple-development", "developer-id"}:
    reject()
if not required_string(result, "python").startswith("Python 3.11."):
    reject()
if result.get("codesign_verified") is not True:
    reject()
if required_string(result, "smoke_suite_entrypoint") != "scripts/browser-use-pro-smoke-suite.sh":
    reject()
if result.get("smoke_suite_args") != ["--signed-bundle", "BrowserUsePro.bundle"]:
    reject()
if required_string(result, "notarization") != "not recorded; release notarization remains distribution ops":
    reject()
if required_string(result, "secrets") != "not recorded":
    reject()
created_utc = required_string(result, "created_utc")
if not is_second_precision_utc_timestamp(created_utc):
    reject()
PY
}

is_signed_browser_use_pro_bundle() {
    local candidate="$1"
    local signature_manifest="$candidate/Contents/Resources/BrowserUsePro/SIGNATURE_MANIFEST.json"
    local package_result
    package_result="$(dirname "$candidate")/PACKAGE_RESULT.json"
    [ -d "$candidate" ] &&
        [ -f "$candidate/Contents/Info.plist" ] &&
        [ -f "$candidate/Contents/Resources/BrowserUsePro/VENDOR_MANIFEST.json" ] &&
        [ -f "$candidate/Contents/Resources/BrowserUsePro/BUILD_MANIFEST.json" ] &&
        [ -f "$signature_manifest" ] &&
        [ ! -L "$signature_manifest" ] &&
        signature_manifest_has_required_browser_use_pro_evidence "$signature_manifest" &&
        [ -f "$package_result" ] &&
        [ ! -L "$package_result" ] &&
        package_result_has_required_browser_use_pro_evidence "$package_result" &&
        [ -x "$candidate/Contents/Resources/BrowserUsePro/epistemos_agent_browser.py" ] &&
        /usr/bin/codesign --verify --deep --strict --verbose=2 "$candidate" >/dev/null 2>&1
}

bundle_browser_use_pro() {
    if is_app_store_build; then
        rm -rf "$BROWSER_USE_PRO_BUNDLE_DEST"
        rm -f "$BROWSER_USE_PRO_PACKAGE_RESULT_DEST"
        return
    fi

    local source=""
    while IFS= read -r candidate; do
        if is_signed_browser_use_pro_bundle "$candidate"; then
            source="$candidate"
            break
        fi
        if [ -n "${EPISTEMOS_BROWSER_USE_PRO_BUNDLE_SOURCE:-}" ] && [ "$candidate" = "$EPISTEMOS_BROWSER_USE_PRO_BUNDLE_SOURCE" ]; then
            echo "Explicit browser-use Pro bundle is not signed or is incomplete: $candidate" >&2
            exit 66
        fi
    done < <(browser_use_pro_bundle_candidates)

    if [ -z "$source" ]; then
        rm -rf "$BROWSER_USE_PRO_BUNDLE_DEST"
        rm -f "$BROWSER_USE_PRO_PACKAGE_RESULT_DEST"
        return
    fi

    local package_result_source
    package_result_source="$(dirname "$source")/PACKAGE_RESULT.json"
    mkdir -p "$(dirname "$BROWSER_USE_PRO_BUNDLE_DEST")"
    rsync -a --delete "$source/" "$BROWSER_USE_PRO_BUNDLE_DEST/"
    rsync -a "$package_result_source" "$BROWSER_USE_PRO_PACKAGE_RESULT_DEST"
    if ! is_signed_browser_use_pro_bundle "$BROWSER_USE_PRO_BUNDLE_DEST"; then
        echo "Bundled browser-use Pro bundle failed post-copy signature verification." >&2
        rm -rf "$BROWSER_USE_PRO_BUNDLE_DEST"
        rm -f "$BROWSER_USE_PRO_PACKAGE_RESULT_DEST"
        exit 66
    fi
}

bundle_editor_resources
bundle_coreeditor_resources
bundle_pyodide_resources
bundle_model_manifest
bundle_default_skills

if is_app_store_build; then
    rm -f "$GOOSE_BINARY_DEST"
    rm -f "$GOOSED_BINARY_DEST"
    rm -rf "$BROWSER_USE_PRO_BUNDLE_DEST"
    rm -f "$BROWSER_USE_PRO_PACKAGE_RESULT_DEST"
else
    bundle_goose_runtime_binary
    bundle_browser_use_pro
fi
bundle_goose_web_ui
