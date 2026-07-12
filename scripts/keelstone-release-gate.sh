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
  - June plus the in-process agent_core bridge are the sole agent route
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
  if grep -Fq -- "${needle}" "${file}"; then
    pass "${label}"
  else
    fail "${label} missing ${needle}"
  fi
}

require_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "${needle}" "${file}"; then
    fail "${label} must not contain ${needle}"
  else
    pass "${label}"
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
  require_contains "${PROJECT_YML}" "build-agent-core.sh" "App Store target builds the in-process agent core"
  require_contains "${PROJECT_YML}" "build-june-web.sh" "App Store target stages June web assets"
  require_not_contains "${PROJECT_YML}" "Epistemos-LegacyDev" "Project topology"
  require_not_contains "${PROJECT_YML}" "Epistemos-Experimental" "Project topology"
  require_not_contains "${PROJECT_YML}" "EPISTEMOS_EXPERIMENTAL" "Project topology"
  require_not_contains "${PROJECT_YML}" "build-opencode-runtime.sh" "App Store prebuild phase"
  require_not_contains "${PROJECT_YML}" "build-experimental-web.sh" "App Store prebuild phase"
fi

require_file "Epistemos/JuneAgent/JuneAgentGateway.swift" "June gateway source"
require_file "Epistemos/Goose/GooseMASAgentCoreRunner.swift" "In-process MAS Goose runner"
require_file "agent_core/src/lib.rs" "In-process agent core source"
require_contains "${ROOT_DIR}/Epistemos/JuneAgent/JuneAgentGateway.swift" "GooseMASAgentCoreRunner" "June routes through the in-process runner"
require_contains "${ROOT_DIR}/Epistemos/AgentWorkspace/AgentWorkspaceSession.swift" "GooseMASAgentCoreRunner" "Agent Workspace routes through the in-process runner"
require_not_contains "${ROOT_DIR}/agent_core/src/lib.rs" "cli_passthrough" "agent_core module surface"
require_not_contains "${ROOT_DIR}/agent_core/src/lib.rs" "pub mod work;" "agent_core module surface"

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
    entitlements="$(codesign -d --entitlements :- "${APPSTORE_APP}" 2>/dev/null || true)"
    if printf '%s' "${entitlements}" | grep -A1 -F 'com.apple.security.app-sandbox' | grep -Fq '<true/>'; then
      pass "Built App Store app has the App Sandbox entitlement"
    else
      fail "Built App Store app is missing the App Sandbox entitlement"
    fi
  fi
fi

if [[ "${failures}" -gt 0 ]]; then
  printf 'KEELSTONE MAS-only gate failed with %d finding(s).\n' "${failures}" >&2
  exit 1
fi

printf 'KEELSTONE MAS-only gate passed.\n'
