#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODEBUILD_WRAPPER="${ROOT_DIR}/scripts/xcodebuild_epistemos.sh"
DERIVED_DATA_PATH="${ROOT_DIR}/build/audit-derived-data"
SOURCE_APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug/Epistemos.app"
AUDIT_APP_PATH="${ROOT_DIR}/build/audit-app/EpistemosAudit.app"
AUDIT_BUNDLE_ID="com.epistemos.audit"
AUDIT_APP_NAME="Epistemos Audit"
AUDIT_DEFAULTS_DOMAIN="${AUDIT_BUNDLE_ID}"

should_build=1
minimal_home=0
root_shell_minimal=0
launch_app=1

usage() {
  cat <<'EOF'
Usage: ./scripts/launch_audit_app.sh [options]

Build the latest Debug app into a dedicated audit DerivedData folder, clone it
into an isolated "Epistemos Audit" bundle, reset sticky restore defaults for
the audit bundle id, and launch it.

Options:
  --no-build           Reuse the existing audit DerivedData build
  --minimal-home       Launch with EPI_HOME_WINDOW_MINIMAL_CONTENT=1
  --root-shell-minimal Launch with EPI_HOME_WINDOW_ROOT_SHELL_MINIMAL_CONTENT=1
  --no-launch          Prepare the isolated audit bundle without launching it
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      should_build=0
      ;;
    --minimal-home)
      minimal_home=1
      ;;
    --root-shell-minimal)
      root_shell_minimal=1
      ;;
    --no-launch)
      launch_app=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

plist_set_string() {
  local plist_path="$1"
  local key_path="$2"
  local value="$3"

  if /usr/libexec/PlistBuddy -c "Set ${key_path} ${value}" "${plist_path}" >/dev/null 2>&1; then
    return 0
  fi

  /usr/libexec/PlistBuddy -c "Add ${key_path} string ${value}" "${plist_path}" >/dev/null
}

plist_add_dict_if_missing() {
  local plist_path="$1"
  local key_path="$2"

  /usr/libexec/PlistBuddy -c "Add ${key_path} dict" "${plist_path}" >/dev/null 2>&1 || true
}

clear_audit_defaults() {
  defaults write "${AUDIT_DEFAULTS_DOMAIN}" epistemos.restoreLastSession -bool false
  defaults write "${AUDIT_DEFAULTS_DOMAIN}" epistemos.setupComplete -bool true
  defaults write "${AUDIT_DEFAULTS_DOMAIN}" epistemos.autoSaveInterval -int 0

  defaults delete "${AUDIT_DEFAULTS_DOMAIN}" epistemos.vaultBookmark >/dev/null 2>&1 || true
  defaults delete "${AUDIT_DEFAULTS_DOMAIN}" epistemos.lastVaultPath >/dev/null 2>&1 || true
  defaults delete "${AUDIT_DEFAULTS_DOMAIN}" epistemos.confirmedSuspiciousVaultPath >/dev/null 2>&1 || true
  defaults delete "${AUDIT_DEFAULTS_DOMAIN}" epistemos.skipWorkspaceRestoreOnce >/dev/null 2>&1 || true
  defaults delete "${AUDIT_DEFAULTS_DOMAIN}" epistemos.skipWorkspaceAutoSaveOnce >/dev/null 2>&1 || true
}

kill_existing_audit_processes() {
  pkill -f "${AUDIT_APP_PATH}/Contents/MacOS/Epistemos" >/dev/null 2>&1 || true
}

build_latest_app() {
  "${XCODEBUILD_WRAPPER}" \
    -project "${ROOT_DIR}/Epistemos.xcodeproj" \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    build
}

prepare_audit_bundle() {
  rm -rf "${AUDIT_APP_PATH}"
  mkdir -p "$(dirname "${AUDIT_APP_PATH}")"
  cp -R "${SOURCE_APP_PATH}" "${AUDIT_APP_PATH}"

  local plist_path="${AUDIT_APP_PATH}/Contents/Info.plist"

  plist_set_string "${plist_path}" ":CFBundleIdentifier" "${AUDIT_BUNDLE_ID}"
  plist_set_string "${plist_path}" ":CFBundleName" "${AUDIT_APP_NAME}"
  plist_set_string "${plist_path}" ":CFBundleDisplayName" "${AUDIT_APP_NAME}"
  plist_set_string "${plist_path}" ":CFBundleExecutable" "Epistemos"

  plist_add_dict_if_missing "${plist_path}" ":LSEnvironment"
  plist_set_string "${plist_path}" ":LSEnvironment:EPISTEMOS_SKIP_VAULT_RESTORE" "1"

  if [[ "${minimal_home}" == "1" ]]; then
    plist_set_string "${plist_path}" ":LSEnvironment:EPI_HOME_WINDOW_MINIMAL_CONTENT" "1"
  fi

  if [[ "${root_shell_minimal}" == "1" ]]; then
    plist_set_string "${plist_path}" ":LSEnvironment:EPI_HOME_WINDOW_ROOT_SHELL_MINIMAL_CONTENT" "1"
  fi

  codesign --force --deep --sign - "${AUDIT_APP_PATH}" >/dev/null
}

if [[ ! -x "${XCODEBUILD_WRAPPER}" ]]; then
  echo "Missing xcodebuild wrapper: ${XCODEBUILD_WRAPPER}" >&2
  exit 1
fi

if [[ "${should_build}" == "1" ]]; then
  build_latest_app
fi

if [[ ! -d "${SOURCE_APP_PATH}" ]]; then
  echo "Built app not found at ${SOURCE_APP_PATH}" >&2
  exit 1
fi

kill_existing_audit_processes
clear_audit_defaults
prepare_audit_bundle

if [[ "${launch_app}" == "1" ]]; then
  /usr/bin/open -na "${AUDIT_APP_PATH}"
fi

echo "Audit app ready:"
echo "  App bundle: ${AUDIT_APP_PATH}"
echo "  Bundle id:  ${AUDIT_BUNDLE_ID}"
echo "  Build app:  ${SOURCE_APP_PATH}"
if [[ "${launch_app}" == "1" ]]; then
  echo "  Launched:   yes"
else
  echo "  Launched:   no"
fi
