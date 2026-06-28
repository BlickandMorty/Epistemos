#!/usr/bin/env bash
set -euo pipefail

# Plan 2 Stage 5 prep: vendor the full MarkEdit source deterministically.
#
# This script intentionally does not cherry-pick files. It clones the pinned
# MarkEdit source, removes only shell items that cannot coexist inside
# Epistemos, removes the nested .git directory so this repository owns the
# vendored source directly, and writes a small manifest recording the source.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MARKEDIT_REPO_URL="${MARKEDIT_REPO_URL:-https://github.com/MarkEdit-app/MarkEdit.git}"
MARKEDIT_REF="${MARKEDIT_REF:-7d56e2e64322e983c43aa789bc08e238860f0069}"
TARGET_DIR="${MARKEDIT_TARGET_DIR:-${ROOT_DIR}/LocalPackages/MarkEdit}"
MANIFEST_NAME="EPISTEMOS_VENDOR_MARKEDIT.txt"

DROP_PATHS=(
  "MarkEditMac/Sources/Main/Application"
  "MarkEditMac/Sources/Main/AppDocumentController.swift"
  "MarkEdit.xcodeproj"
  "MarkEditMac/Info.entitlements"
  "FinderExtension"
  "PreviewExtension"
)

usage() {
  cat <<USAGE
Usage: scripts/vendor_markedit.sh [--replace] [--print-plan]

Clones MarkEdit into LocalPackages/MarkEdit at a pinned commit, then removes
only the app-shell items that cannot coexist with Epistemos:
  - MarkEdit @main/AppDelegate/Application shell
  - MarkEdit AppDocumentController
  - MarkEdit.xcodeproj
  - MarkEdit Info.entitlements
  - FinderExtension and PreviewExtension .appex sources

Environment:
  MARKEDIT_REPO_URL   Default: ${MARKEDIT_REPO_URL}
  MARKEDIT_REF        Default: ${MARKEDIT_REF}
  MARKEDIT_TARGET_DIR Default: ${TARGET_DIR}

Options:
  --replace     Remove an existing target directory before cloning.
  --print-plan  Print the pinned source/prune plan without mutating files.
USAGE
}

print_plan() {
  printf 'repo=%s\n' "${MARKEDIT_REPO_URL}"
  printf 'ref=%s\n' "${MARKEDIT_REF}"
  printf 'target=%s\n' "${TARGET_DIR}"
  printf 'drop_paths=\n'
  local path
  for path in "${DROP_PATHS[@]}"; do
    printf '  %s\n' "${path}"
  done
}

require_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "vendor_markedit.sh: git is required on PATH" >&2
    exit 1
  fi
}

assert_safe_target() {
  local target="$1"
  local normalized
  normalized="$(cd "$(dirname "${target}")" 2>/dev/null && pwd)/$(basename "${target}")"
  local expected="${ROOT_DIR}/LocalPackages/MarkEdit"
  if [[ "${normalized}" != "${expected}" && -z "${MARKEDIT_TARGET_DIR:-}" ]]; then
    echo "vendor_markedit.sh: refusing unexpected target ${normalized}" >&2
    exit 2
  fi
  if [[ -L "${target}" ]]; then
    echo "vendor_markedit.sh: refusing to write through symlink ${target}" >&2
    exit 2
  fi
}

remove_shell_items() {
  local source_dir="$1"
  local path
  for path in "${DROP_PATHS[@]}"; do
    rm -rf "${source_dir}/${path}"
  done
}

write_manifest() {
  local source_dir="$1"
  local resolved_commit="$2"
  {
    printf 'Plan: Plan 2 Stage 5 MarkEdit full-source vendor\n'
    printf 'Source Repo: %s\n' "${MARKEDIT_REPO_URL}"
    printf 'Pinned Ref: %s\n' "${MARKEDIT_REF}"
    printf 'Resolved Commit: %s\n' "${resolved_commit}"
    printf '\n'
    printf 'Pruned Shell Items:\n'
    local path
    for path in "${DROP_PATHS[@]}"; do
      printf -- '- %s\n' "${path}"
    done
    printf '\n'
    printf 'Notes:\n'
    printf -- '- This is vendored source, not a git submodule or worktree.\n'
    printf -- '- Do not restore MarkEdit @main, AppDocumentController, .xcodeproj, entitlements, or .appex sources inside Epistemos.\n'
    printf -- '- Harvest MAS-safe document-type/build-settings hardening into Epistemos explicitly before wiring project.yml.\n'
  } > "${source_dir}/${MANIFEST_NAME}"
}

replace_existing=0
print_only=0

for arg in "$@"; do
  case "${arg}" in
    --replace)
      replace_existing=1
      ;;
    --print-plan)
      print_only=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "vendor_markedit.sh: unknown argument ${arg}" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ "${print_only}" == "1" ]]; then
  print_plan
  exit 0
fi

require_git
assert_safe_target "${TARGET_DIR}"

if [[ -e "${TARGET_DIR}" ]]; then
  if [[ "${replace_existing}" != "1" ]]; then
    echo "vendor_markedit.sh: ${TARGET_DIR} already exists; pass --replace to refresh it" >&2
    exit 3
  fi
  rm -rf "${TARGET_DIR}"
fi

mkdir -p "$(dirname "${TARGET_DIR}")"
tmp_dir="$(mktemp -d "${ROOT_DIR}/LocalPackages/.MarkEdit.clone.XXXXXX")"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

git clone "${MARKEDIT_REPO_URL}" "${tmp_dir}"
git -C "${tmp_dir}" checkout --detach "${MARKEDIT_REF}"
resolved_commit="$(git -C "${tmp_dir}" rev-parse HEAD)"

remove_shell_items "${tmp_dir}"
rm -rf "${tmp_dir}/.git"
write_manifest "${tmp_dir}" "${resolved_commit}"

mv "${tmp_dir}" "${TARGET_DIR}"
trap - EXIT

echo "vendor_markedit.sh: vendored MarkEdit ${resolved_commit} into ${TARGET_DIR}"
