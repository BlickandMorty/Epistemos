#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_YML="${ROOT_DIR}/project.yml"
HARDENING_FINDINGS_PATH="${KEELSTONE_HARDENING_FINDINGS:-${ROOT_DIR}/build/keelstone-hardening-findings.jsonl}"
if [[ "${HARDENING_FINDINGS_PATH}" != /* ]]; then
  HARDENING_FINDINGS_PATH="${ROOT_DIR}/${HARDENING_FINDINGS_PATH}"
fi
SEED_HIGH_FINDING="${KEELSTONE_SEED_HIGH_FINDING:-0}"

DIRECT_APP=""
APPSTORE_APP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --direct-app)
      DIRECT_APP="${2:?--direct-app requires a path}"
      shift 2
      ;;
    --appstore-app)
      APPSTORE_APP="${2:?--appstore-app requires a path}"
      shift 2
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/keelstone-release-gate.sh [--direct-app /path/Epistemos.app] [--appstore-app /path/Epistemos.app]

Source-level KEELSTONE release gate guardrails:
  - exactly two application targets: Epistemos and Epistemos-AppStore
  - target-scoped EPISTEMOS_EXPERIMENTAL / EPISTEMOS_APP_STORE / KINDRED_ENABLED macros
  - no retired branded-surface residue in sources, tests, scripts, or project.yml
  - data-safety soak and first-run/upgrade witness tests remain wired
  - HIGH/CRITICAL hardening findings block release
  - source entitlement plists match the approved direct and MAS posture

If app paths are supplied, the script also validates effective codesign entitlements.

Optional environment:
  KEELSTONE_HARDENING_FINDINGS=/path/findings.jsonl
  KEELSTONE_SEED_HIGH_FINDING=1
USAGE
      exit 0
      ;;
    *)
      echo "::error::Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

failures=0

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf '::error::%s\n' "$1" >&2
  failures=$((failures + 1))
}

section_project_base_settings() {
  awk '
    /^settings:$/ { in_settings = 1; next }
    in_settings && /^targets:$/ { exit }
    in_settings && /^  base:$/ { in_base = 1; next }
    in_base && /^  configs:$/ { exit }
    in_base { print }
  ' "${PROJECT_YML}"
}

target_section() {
  local target="$1"
  awk -v marker="  ${target}:" '
    /^targets:$/ { in_targets = 1; next }
    /^packages:$/ || /^schemes:$/ { exit }
    in_targets && $0 == marker { in_target = 1; print; next }
    in_target && /^  [A-Za-z0-9_-]+:$/ { exit }
    in_target { print }
  ' "${PROJECT_YML}"
}

application_targets() {
  awk '
    /^targets:$/ { in_targets = 1; next }
    /^packages:$/ || /^schemes:$/ { exit }
    in_targets && /^  [A-Za-z0-9_-]+:$/ {
      current = $0
      sub(/^  /, "", current)
      sub(/:$/, "", current)
      next
    }
    in_targets && current != "" && /^    type: application$/ {
      print current
    }
  ' "${PROJECT_YML}"
}

count_token() {
  local token="$1"
  grep -o "${token}" | wc -l | tr -d ' '
}

swift_compilation_conditions() {
  grep -F "SWIFT_ACTIVE_COMPILATION_CONDITIONS:" || true
}

require_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if printf '%s' "${haystack}" | grep -Fq "${needle}"; then
    pass "${label}"
  else
    fail "${label} missing ${needle}"
  fi
}

require_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if printf '%s' "${haystack}" | grep -Fq "${needle}"; then
    fail "${label} must not contain ${needle}"
  else
    pass "${label}"
  fi
}

require_token_count() {
  local haystack="$1"
  local token="$2"
  local expected="$3"
  local label="$4"
  local actual
  actual="$(printf '%s' "${haystack}" | count_token "${token}")"
  if [[ "${actual}" == "${expected}" ]]; then
    pass "${label}: ${token} count ${actual}"
  else
    fail "${label}: expected ${expected} ${token} occurrence(s), found ${actual}"
  fi
}

require_plist_key() {
  local plist="$1"
  local key="$2"
  local label="$3"
  if /usr/libexec/PlistBuddy -c "Print :${key}" "${plist}" >/dev/null 2>&1; then
    pass "${label} has ${key}"
  else
    fail "${label} missing ${key}"
  fi
}

require_plist_no_key() {
  local plist="$1"
  local key="$2"
  local label="$3"
  if /usr/libexec/PlistBuddy -c "Print :${key}" "${plist}" >/dev/null 2>&1; then
    fail "${label} must not contain ${key}"
  else
    pass "${label} omits ${key}"
  fi
}

effective_entitlements() {
  local app_path="$1"
  local output_path="$2"
  if [[ ! -d "${app_path}" ]]; then
    fail "Built app not found: ${app_path}"
    return 1
  fi
  if codesign -d --entitlements :- "${app_path}" >"${output_path}" 2>/dev/null; then
    return 0
  fi
  fail "Could not read effective codesign entitlements from ${app_path}"
  return 1
}

require_file_contains() {
  local relative_path="$1"
  local needle="$2"
  local label="$3"
  local path="${ROOT_DIR}/${relative_path}"
  if [[ ! -f "${path}" ]]; then
    fail "${label} missing file ${relative_path}"
    return
  fi
  if grep -Fq "${needle}" "${path}"; then
    pass "${label}"
  else
    fail "${label} missing '${needle}' in ${relative_path}"
  fi
}

check_hardening_findings() {
  local findings_path="$1"
  local seeded_path=""
  local high_report="${ROOT_DIR}/build/keelstone-high-hardening-findings.txt"

  mkdir -p "$(dirname "${high_report}")"

  if [[ "${SEED_HIGH_FINDING}" == "1" ]]; then
    seeded_path="$(mktemp "${TMPDIR:-/tmp}/keelstone-high-finding.XXXXXX")"
    printf '{"severity":"HIGH","category":"seed","message":"seeded KEELSTONE hardening finding"}\n' >"${seeded_path}"
    findings_path="${seeded_path}"
  elif [[ ! -f "${findings_path}" ]]; then
    : >"${high_report}"
    pass "No hardening findings file present (${findings_path})"
    return
  fi

  if rg -n '"severity"[[:space:]]*:[[:space:]]*"(HIGH|CRITICAL)"|severity[[:space:]]*=[[:space:]]*(HIGH|CRITICAL)|(^|[[:space:]])(HIGH|CRITICAL)[[:space:]]+finding' \
    "${findings_path}" >"${high_report}"; then
    fail "HIGH/CRITICAL hardening finding blocks release; see ${high_report}"
    sed -n '1,80p' "${high_report}" >&2
  else
    : >"${high_report}"
    pass "No HIGH/CRITICAL hardening findings"
  fi

  if [[ -n "${seeded_path}" ]]; then
    rm -f "${seeded_path}"
  fi
}

echo "==> KEELSTONE §9.4 target and macro drift"
app_targets=()
while IFS= read -r target_name; do
  app_targets+=("${target_name}")
done < <(application_targets)
if [[ "${#app_targets[@]}" -eq 2 && "${app_targets[0]}" == "Epistemos" && "${app_targets[1]}" == "Epistemos-AppStore" ]]; then
  pass "Exactly two application targets: Epistemos, Epistemos-AppStore"
else
  fail "Expected exactly two application targets [Epistemos, Epistemos-AppStore], found [${app_targets[*]}]"
fi

base_settings="$(section_project_base_settings)"
require_not_contains "${base_settings}" "EPISTEMOS_EXPERIMENTAL" "Shared/base build settings"
require_not_contains "${base_settings}" "EPISTEMOS_APP_STORE" "Shared/base build settings"
require_not_contains "${base_settings}" "KINDRED_ENABLED" "Shared/base build settings"

epistemos_target="$(target_section "Epistemos")"
appstore_target="$(target_section "Epistemos-AppStore")"
epistemos_conditions="$(printf '%s' "${epistemos_target}" | swift_compilation_conditions)"
appstore_conditions="$(printf '%s' "${appstore_target}" | swift_compilation_conditions)"
require_token_count "${epistemos_conditions}" "EPISTEMOS_EXPERIMENTAL" "3" "Epistemos target Swift conditions"
require_token_count "${epistemos_conditions}" "KINDRED_ENABLED" "3" "Epistemos target Swift conditions"
require_not_contains "${epistemos_target}" "EPISTEMOS_APP_STORE" "Epistemos target"
require_not_contains "${epistemos_target}" "MAS_SANDBOX" "Epistemos target"
require_token_count "${appstore_conditions}" "EPISTEMOS_APP_STORE" "2" "Epistemos-AppStore target Swift conditions"
require_token_count "${appstore_conditions}" "MAS_SANDBOX" "2" "Epistemos-AppStore target Swift conditions"
require_not_contains "${appstore_target}" "EPISTEMOS_EXPERIMENTAL" "Epistemos-AppStore target"
require_not_contains "${appstore_target}" "KINDRED_ENABLED" "Epistemos-AppStore target"

echo ""
echo "==> KEELSTONE §9.4 retired-surface drift"
residue_report="${ROOT_DIR}/build/keelstone-release-gate-retired-surfaces.txt"
mkdir -p "$(dirname "${residue_report}")"
legacy_surface_a="Open"
legacy_surface_b="Chamber"
legacy_surface_lower_a="open"
legacy_surface_lower_b="chamber"
legacy_agent_a="Pro"
legacy_agent_b="Agent"
legacy_flag_a="PRO"
legacy_flag_b="BUILD"
legacy_residue_pattern="${legacy_surface_a}${legacy_surface_b}|${legacy_agent_a}${legacy_agent_b}|${legacy_flag_a}_${legacy_flag_b}|${legacy_surface_lower_a}${legacy_surface_lower_b}"
if rg -n "${legacy_residue_pattern}" \
  "${ROOT_DIR}/Epistemos" \
  "${ROOT_DIR}/EpistemosTests" \
  "${ROOT_DIR}/project.yml" \
  "${ROOT_DIR}/scripts" \
  --glob '!Build/**' \
  --glob '!scripts/keelstone-release-gate.sh' \
  >"${residue_report}"; then
  fail "Retired branded-surface residue remains; see ${residue_report}"
  sed -n '1,80p' "${residue_report}" >&2
else
  : >"${residue_report}"
  pass "No retired branded-surface residue in guarded source paths"
fi

echo ""
echo "==> KEELSTONE §9.4 source entitlement posture"
direct_entitlements="${ROOT_DIR}/Epistemos/Epistemos.entitlements"
appstore_entitlements="${ROOT_DIR}/Epistemos/Epistemos-AppStore.entitlements"

require_plist_no_key "${direct_entitlements}" "com.apple.security.app-sandbox" "Direct entitlements"
require_plist_key "${direct_entitlements}" "com.apple.security.cs.allow-jit" "Direct entitlements"
require_plist_key "${direct_entitlements}" "com.apple.security.cs.disable-library-validation" "Direct entitlements"
require_plist_key "${direct_entitlements}" "com.apple.security.files.user-selected.read-write" "Direct entitlements"
require_plist_key "${direct_entitlements}" "com.apple.security.files.bookmarks.app-scope" "Direct entitlements"

require_plist_key "${appstore_entitlements}" "com.apple.security.app-sandbox" "App Store entitlements"
require_plist_key "${appstore_entitlements}" "com.apple.security.files.user-selected.read-write" "App Store entitlements"
require_plist_key "${appstore_entitlements}" "com.apple.security.files.bookmarks.app-scope" "App Store entitlements"
require_plist_no_key "${appstore_entitlements}" "com.apple.security.cs.allow-jit" "App Store entitlements"
require_plist_no_key "${appstore_entitlements}" "com.apple.security.cs.disable-library-validation" "App Store entitlements"
require_plist_no_key "${appstore_entitlements}" "com.apple.security.files.bookmarks.document-scope" "App Store entitlements"

echo ""
echo "==> KEELSTONE §9.1-§9.3 data-safety and upgrade witnesses"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func killNineDuringVaultReplacementNeverLeavesPartialNote()" "Data-safety soak witness: kill -9 during vault replacement"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "killNineVaultReplacementTrialCount = 1_000" "Data-safety soak witness: kill -9 vault replacement runs 1,000 trials"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func vaultNoteEditorProductionSeamUsesCoordinatedVaultIO()" "Data-safety witness: agent note editor default seam uses coordinated vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func codeFileServiceSourceWritesUseAtomicVaultWriter()" "Data-safety witness: code source vault writes use coordinated vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func vaultRenameMoveAndDeleteMutationsUseNSFileCoordinator()" "Data-safety witness: vault move/delete mutations use coordinated vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func vaultChatMutatorVerifiedWriterUsesAtomicVaultWriter()" "Data-safety witness: approved agent vault writes use coordinated vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func skillVaultFileWritesUseAtomicVaultWriter()" "Data-safety witness: skill vault writes use coordinated vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func epistemosSidecarsUseAtomicVaultWriter()" "Data-safety witness: vault JSON sidecars use coordinated vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func experimentalAgentVaultNoteWritesUseAtomicVaultWriterOffMain()" "Data-safety witness: Experimental agent note creation uses coordinated off-main vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func artifactTextExportsUseAtomicVaultWriterOffMain()" "Data-safety witness: artifact text exports use coordinated off-main IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func firstRunBootstrapMetadataUsesAtomicVaultWriter()" "Data-safety witness: first-run vault metadata uses coordinated vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func agentSessionLineageMetadataUsesAtomicVaultWriter()" "Data-safety witness: agent session lineage metadata uses coordinated vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func vaultLifecycleGraphWritesUseAtomicVaultWriter()" "Data-safety witness: vault lifecycle graph writes use coordinated vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func keelstoneDatasetArtifactRoutingIsExtensibleAndNonAuthoritative()" "Data-safety witness: dataset artifacts route outside the note index"
require_file_contains "Epistemos/Sync/AtomicVaultWriter.swift" "func write(_ data: Data, to targetURL: URL)" "Data-safety witness: binary artifact writes use AtomicVaultWriter whole-buffer Data overload"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func keelstoneIncrementalReconcileEqualsFreshRebuild()" "Data-safety soak witness: incremental reconcile equals fresh rebuild"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func vaultSyncServiceFSEventsClassificationIsExecutable()" "Data-safety witness: FSEvents escalation classifier is executable"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func vaultSyncServiceFSEventsStartIDReplaysPerVaultCheckpoint()" "Data-safety witness: FSEvents checkpoint replay is executable"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func vaultSyncServiceRootUnavailableFreezesMountedVault()" "Data-safety witness: root unavailability freezes active vault IO"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func dirtyLiveEditorExternalEditCreatesConflictCopy()" "Data-safety soak witness: dirty external edit conflict-copy flow"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func keelstoneBodyTruthHasNoProductionSidecarWriters()" "Body-truth witness: production note saves are vault-md-first"
require_file_contains "EpistemosTests/VaultSyncServiceAuditTests.swift" "func fileFirstBodySaveWritesVaultMarkdownAndLeavesNoDurableSidecar()" "Body-truth witness: in-app edit reaches vault markdown without durable sidecar"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func vaultSyncServiceSelfWriteWindowStillReconcilesEvents()" "Data-safety soak witness: sync-race/self-write event reconcile"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func iCloudMaterializerUsesAsyncMetadataQuery()" "Data-safety soak witness: async iCloud materialization"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func keelstoneSearchIndexCorruptionQuarantinesAndRebuildsFromSnapshots()" "Data-safety soak witness: corrupt index quarantine and rebuild"
require_file_contains "EpistemosTests/AppStoreHardeningTests.swift" "func experimentalBackendQuitReapsProcessTreeForHundredCycleSoak()" "Hardening soak witness: Experimental child process cleanup across 100 quit cycles"
require_file_contains "EpistemosTests/FirstRunBootstrapTests.swift" "func simulatedFirstRunEndToEnd()" "Upgrade matrix witness: fresh first-run empty vault"
require_file_contains "EpistemosTests/FirstRunBootstrapTests.swift" "func partialScaffoldRecovers()" "Upgrade matrix witness: partial first-run scaffold recovery"
require_file_contains "EpistemosTests/FirstRunBootstrapTests.swift" "func idempotentBootstrap()" "Upgrade matrix witness: relaunch/idempotent bootstrap"
require_file_contains "EpistemosTests/VaultSyncServiceAuditTests.swift" "func startupBookmarkValidationRejectsStaleBookmarks()" "Upgrade matrix witness: stale bookmark blocks automatic restore"
require_file_contains "EpistemosTests/VaultSyncServiceAuditTests.swift" "func masStartupBookmarkValidationRejectsPlainResolvedBookmarks()" "Upgrade matrix witness: MAS rejects non-security-scoped bookmark restore"
require_file_contains "EpistemosTests/VaultSyncServiceAuditTests.swift" "func masPersistVaultSelectionRefusesPlainBookmarkFallback()" "Upgrade matrix witness: MAS refuses plain bookmark fallback"
require_file_contains "EpistemosTests/VaultSyncServiceAuditTests.swift" "func switchingFromDisconnectedCacheClearsStaleNotesAndGraphBeforeImportingSelectedVault()" "Upgrade matrix witness: switching vaults clears disconnected stale cache"
require_file_contains "EpistemosTests/VaultSyncServiceAuditTests.swift" "func securityScopedBookmarkRoundTripsAcrossWriteCycle()" "Upgrade matrix witness: bookmark survives write-cycle re-resolve"
require_file_contains "EpistemosTests/VaultSyncServiceAuditTests.swift" "func rootWatcherUnavailabilityFreezesWritesAndPreservesLocalState()" "Upgrade matrix witness: root watcher unavailability preserves state and blocks writes"
require_file_contains ".github/workflows/ci.yml" "./scripts/keelstone-release-gate.sh --appstore-app" "Release workflow witness: App Store built app participates in KEELSTONE gate"
require_file_contains ".github/workflows/release.yml" "./scripts/keelstone-release-gate.sh --direct-app" "Release workflow witness: direct built app participates in KEELSTONE gate"
require_file_contains ".github/workflows/ci.yml" "KEELSTONE_SEED_HIGH_FINDING=1 ./scripts/keelstone-release-gate.sh" "Release workflow witness: seeded HIGH hardening finding blocks the gate"
require_file_contains ".github/workflows/ci.yml" "KEELSTONE_SEED_PERF_REGRESSION=1 ./scripts/check-perf-budgets.sh" "Release workflow witness: seeded KEELSTONE perf regression blocks the gate"

echo ""
echo "==> KEELSTONE §7 hardening finding gate"
check_hardening_findings "${HARDENING_FINDINGS_PATH}"

if [[ -n "${DIRECT_APP}" || -n "${APPSTORE_APP}" ]]; then
  echo ""
  echo "==> KEELSTONE §9.4 effective built entitlements"
fi

if [[ -n "${DIRECT_APP}" ]]; then
  direct_effective="$(mktemp)"
  if effective_entitlements "${DIRECT_APP}" "${direct_effective}"; then
    require_plist_no_key "${direct_effective}" "com.apple.security.app-sandbox" "Built direct app entitlements"
    require_plist_key "${direct_effective}" "com.apple.security.files.user-selected.read-write" "Built direct app entitlements"
  fi
  rm -f "${direct_effective}"
fi

if [[ -n "${APPSTORE_APP}" ]]; then
  appstore_effective="$(mktemp)"
  if effective_entitlements "${APPSTORE_APP}" "${appstore_effective}"; then
    require_plist_key "${appstore_effective}" "com.apple.security.app-sandbox" "Built App Store entitlements"
    require_plist_key "${appstore_effective}" "com.apple.security.files.user-selected.read-write" "Built App Store entitlements"
    require_plist_key "${appstore_effective}" "com.apple.security.files.bookmarks.app-scope" "Built App Store entitlements"
    require_plist_no_key "${appstore_effective}" "com.apple.security.cs.allow-jit" "Built App Store entitlements"
    require_plist_no_key "${appstore_effective}" "com.apple.security.cs.disable-library-validation" "Built App Store entitlements"
  fi
  rm -f "${appstore_effective}"
fi

echo ""
if [[ "${failures}" -gt 0 ]]; then
  echo "::error::KEELSTONE release gate failed with ${failures} finding(s)"
  exit 1
fi

echo "KEELSTONE release gate passed"
