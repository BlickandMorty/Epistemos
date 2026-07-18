#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_YML="${ROOT_DIR}/project.yml"
DEFAULT_SCHEME="${ROOT_DIR}/Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme"
APPSTORE_APP=""
SEED_HIGH_FINDING="${KEELSTONE_SEED_HIGH_FINDING:-0}"
failures=0

usage() {
  cat <<'USAGE'
Usage: scripts/keelstone-release-gate.sh [--appstore-app /path/Epistemos.app]

MAS-only KEELSTONE gate:
  - one application target: Epistemos-AppStore
  - Free V1 retains Kokoro read-aloud and deterministic local note search
  - Free V1 rejects paid June, Goose, agent, and inference artifacts
  - retired Experimental/OpenChamber/external-Goose/MCP/Work paths are absent
  - supplied application bundles carry the App Sandbox entitlement
USAGE
}

pass() { printf 'PASS: %s\n' "$1"; }

fail() {
  printf '::error::%s\n' "$1" >&2
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  local label="$2"
  if [[ -f "${ROOT_DIR}/${path}" ]]; then
    pass "${label}"
  else
    fail "${label} missing ${path}"
  fi
}

require_absent() {
  local path="$1"
  local label="$2"
  if [[ ! -e "${ROOT_DIR}/${path}" ]]; then
    pass "${label}"
  else
    fail "${label} must be absent: ${path}"
  fi
}

require_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if [[ ! -f "${file}" ]]; then
    fail "${label} missing file ${file}"
  elif grep -Fq -- "${needle}" "${file}"; then
    pass "${label}"
  else
    fail "${label} missing ${needle}"
  fi
}

require_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if [[ ! -f "${file}" ]]; then
    fail "${label} missing file ${file}"
  elif grep -Fq -- "${needle}" "${file}"; then
    fail "${label} must not contain ${needle}"
  else
    pass "${label}"
  fi
}

require_app_absent() {
  local app="$1"
  local relative_path="$2"
  local label="$3"
  if [[ ! -e "${app}/${relative_path}" ]]; then
    pass "${label}"
  else
    fail "${label} must be absent: ${app}/${relative_path}"
  fi
}

require_appstore_free_v1_without_paid_inference_or_agent_runtimes() {
  local app="$1"
  local executable="${app}/Contents/MacOS/Epistemos"

  require_app_absent "${app}" "Contents/Frameworks/llama.framework" "Built free V1 artifact omits the local inference runtime"
  require_app_absent "${app}" "Contents/Frameworks/libagent_core.dylib" "Built free V1 artifact omits agent_core"
  require_app_absent "${app}" "Contents/Frameworks/libomega_mcp.dylib" "Built free V1 artifact omits omega_mcp"

  if [[ ! -f "${executable}" ]]; then
    fail "Built free V1 executable missing ${executable}"
  elif otool -L "${executable}" 2>/dev/null | grep -Eq 'llama\.framework|libagent_core\.dylib|libomega_mcp\.dylib'; then
    fail "Built free V1 executable links a forbidden paid inference or agent runtime"
  else
    pass "Built free V1 executable has no paid inference or agent linkage"
  fi
}

require_appstore_free_v1_without_paid_identity_strings() {
  local app="$1"
  local executable="${app}/Contents/MacOS/Epistemos"
  local strings_file
  strings_file="$(mktemp)"

  if [[ ! -f "${executable}" ]]; then
    fail "Built free V1 executable missing ${executable}"
    rm -f "${strings_file}"
    return
  fi

  LC_ALL=C strings -a "${executable}" >"${strings_file}"
  if grep -E -x -q \
    '(_claudeManagedSessionsEnabled|epistemos\.kimiModel|gguf|openai|anthropic|claude|agent_core|InferenceState|inferenceState|Local GGUF|EPISTEMOS_GGUF_TOOL_GRAMMAR_V0|June )' \
    "${strings_file}"; then
    fail "Built free V1 executable contains paid provider, June, inference, or agent identity"
    grep -E -x \
      '(_claudeManagedSessionsEnabled|epistemos\.kimiModel|gguf|openai|anthropic|claude|agent_core|InferenceState|inferenceState|Local GGUF|EPISTEMOS_GGUF_TOOL_GRAMMAR_V0|June )' \
      "${strings_file}" | sort -u >&2
  else
    pass "Built free V1 executable omits paid provider, June, inference, and agent identity"
  fi

  rm -f "${strings_file}"
}

require_appstore_no_parked_account_runtime_markers() {
  local app="$1"
  local scanner="${ROOT_DIR}/scripts/scan_appstore_bundle.sh"

  if [[ ! -f "${scanner}" ]]; then
    fail "App Store bundle scanner missing ${scanner}"
  elif EPISTEMOS_APPSTORE_SCAN_REPORT_DIR="${ROOT_DIR}/build/appstore-audit" \
    bash "${scanner}" "${app}"; then
    pass "Built App Store artifact omits parked account/backend runtime markers"
  else
    fail "Built App Store artifact failed the comprehensive bundle scan"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appstore-app)
      APPSTORE_APP="${2:?--appstore-app requires a path}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '::error::Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${SEED_HIGH_FINDING}" == "1" ]]; then
  fail "HIGH/CRITICAL hardening finding blocks release (seeded witness)"
fi

if [[ ! -f "${PROJECT_YML}" ]]; then
  fail "MAS project source-of-truth is missing"
else
  application_targets="$(awk '
    /^targets:$/ { targets = 1; next }
    /^packages:$/ || /^schemes:$/ { exit }
    targets && /^  [A-Za-z0-9_-]+:$/ { name = $0; sub(/^  /, "", name); sub(/:$/, "", name); next }
    targets && /^    type: application$/ { print name }
  ' "${PROJECT_YML}")"
  if [[ "${application_targets}" == "Epistemos-AppStore" ]]; then
    pass "Exactly one application target: Epistemos-AppStore"
  else
    fail "Expected only Epistemos-AppStore application target, found: ${application_targets:-none}"
  fi
  require_contains "${PROJECT_YML}" "EPISTEMOS_APP_STORE MAS_SANDBOX" "App Store target enables MAS compilation conditions"
  require_contains "${PROJECT_YML}" "ENABLE_APP_SANDBOX: true" "App Store target enables sandboxing"
  require_contains "${PROJECT_YML}" "EPISTEMOS_PRODUCT_EDITION: FREE_V1" "App Store target selects the free V1 edition"
  require_contains "${PROJECT_YML}" "EPISTEMOS_FREE_V1" "App Store target compiles the free V1 boundary"
  require_contains "${PROJECT_YML}" "KokoroPipeline" "App Store target retains Kokoro read-aloud"
  require_not_contains "${PROJECT_YML}" "build-june-web.sh" "Free App Store target has no June web prebuild"
  require_not_contains "${PROJECT_YML}" "build-agent-core.sh" "Free App Store target has no agent-core prebuild"
  require_not_contains "${PROJECT_YML}" "build-omega-mcp.sh" "Free App Store target has no Omega prebuild"
  require_not_contains "${PROJECT_YML}" "Epistemos-LegacyDev" "Project topology"
  require_not_contains "${PROJECT_YML}" "Epistemos-Experimental" "Project topology"
  require_not_contains "${PROJECT_YML}" "EPISTEMOS_EXPERIMENTAL" "Project topology"
  require_not_contains "${PROJECT_YML}" "build-opencode-runtime.sh" "App Store prebuild phase"
  require_not_contains "${PROJECT_YML}" "build-experimental-web.sh" "App Store prebuild phase"
fi

require_file "Epistemos/App/ProductCapabilityPolicy.swift" "Central free/paid product capability policy"
require_absent "Epistemos/JuneAgent" "Free V1 source tree omits JuneAgent"
require_contains "${ROOT_DIR}/bundle-app-runtime-assets.sh" "bundle_editor_resources" "Free runtime asset path keeps the editor"
require_contains "${ROOT_DIR}/bundle-app-runtime-assets.sh" "bundle_coreeditor_resources" "Free runtime asset path keeps CoreEditor"
require_contains "${ROOT_DIR}/bundle-app-runtime-assets.sh" "remove_free_v1_forbidden_resources" "Free runtime asset path removes forbidden resources"
require_contains "${ROOT_DIR}/Epistemos/App/EpistemosApp.swift" "EpistemosAgentReadAloud" "Free app retains Kokoro read-aloud"
require_contains "${ROOT_DIR}/build-epistemos-shadow.sh" "--no-default-features --features free-lexical" "Free note search uses the deterministic lexical shadow"

if [[ -f "${DEFAULT_SCHEME}" ]]; then
  pass "Normal Epistemos scheme exists"
  require_contains "${DEFAULT_SCHEME}" "BlueprintName = \"Epistemos-AppStore\"" "Normal scheme launches MAS target"
  require_not_contains "${DEFAULT_SCHEME}" "Epistemos-LegacyDev" "Normal scheme"
  require_not_contains "${DEFAULT_SCHEME}" "Epistemos-Experimental" "Normal scheme"
else
  fail "Normal Epistemos scheme is missing"
fi

for retired_path in \
  "Epistemos/ExperimentalAgent" \
  "Epistemos/Work" \
  "Epistemos/VaultMCP" \
  "Epistemos/Goose/GooseACPClient.swift" \
  "Epistemos/Goose/GooseACPProtocol.swift" \
  "Epistemos/Goose/GooseACPSourceProtocol.swift" \
  "Epistemos/Goose/GooseInProcessACPServer.swift" \
  "Epistemos/Goose/GooseRuntimeSupervisor.swift" \
  "Epistemos/Views/HTMLWorkspace/HTMLWorkspaceGooseRegenerator.swift" \
  "Epistemos/Views/Settings/VaultMCPServerSettingsRow.swift" \
  "agent_core/src/tools/cli_passthrough.rs" \
  "agent_core/src/work.rs" \
  "agent_core/src/work_lsp_tools.rs" \
  "omega-mcp/src/bin/omega_mcp_stdio.rs" \
  "build-experimental-web.sh" \
  "build-opencode-runtime.sh" \
  "Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-LegacyDev.xcscheme" \
  "Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-Experimental.xcscheme"
do
  require_absent "${retired_path}" "Retired lane"
done

if [[ -n "${APPSTORE_APP}" ]]; then
  if [[ ! -d "${APPSTORE_APP}" ]]; then
    fail "Supplied App Store app does not exist: ${APPSTORE_APP}"
  else
    entitlements_file="$(mktemp)"
    if codesign -d --entitlements :- "${APPSTORE_APP}" >"${entitlements_file}" 2>/dev/null &&
      /usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "${entitlements_file}" 2>/dev/null | grep -Fq true; then
      pass "Built App Store app has the App Sandbox entitlement"
    else
      fail "Built App Store app is missing the App Sandbox entitlement"
    fi
    rm -f "${entitlements_file}"

    require_app_absent "${APPSTORE_APP}" "Contents/Resources/JuneWeb" "Built free V1 artifact omits JuneWeb"
    require_app_absent "${APPSTORE_APP}" "Contents/Resources/model_manifest.json" "Built free V1 artifact omits the model manifest"
    require_app_absent "${APPSTORE_APP}" "Contents/Resources/DefaultSkills" "Built free V1 artifact omits agent skills"
    require_appstore_free_v1_without_paid_inference_or_agent_runtimes "${APPSTORE_APP}"
    require_appstore_free_v1_without_paid_identity_strings "${APPSTORE_APP}"
    require_appstore_no_parked_account_runtime_markers "${APPSTORE_APP}"
  fi
fi

if [[ "${failures}" -gt 0 ]]; then
  printf 'KEELSTONE MAS-only gate failed with %d finding(s).\n' "${failures}" >&2
  exit 1
fi

printf 'KEELSTONE MAS-only gate passed for the active product edition.\n'
