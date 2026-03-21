#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_PATH="${1:-${ROOT_DIR}/docs/audits/dead-code-report-$(date +%F).md}"

mkdir -p "$(dirname "${REPORT_PATH}")"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

package_resolved="${ROOT_DIR}/Epistemos.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
pbxproj="${ROOT_DIR}/Epistemos.xcodeproj/project.pbxproj"

python3 - "${package_resolved}" > "${tmpdir}/resolved_identities.txt" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
for pin in data.get("pins", []):
    print(pin["identity"])
PY

rg -o 'XCRemoteSwiftPackageReference "([^"]+)"' "${pbxproj}" \
  | sed -E 's/.*"([^"]+)"/\1/' \
  | tr '[:upper:]' '[:lower:]' \
  | sort -u > "${tmpdir}/project_packages.txt"

comm -23 <(sort -u "${tmpdir}/resolved_identities.txt") "${tmpdir}/project_packages.txt" > "${tmpdir}/non_direct_pins.txt"

find "${ROOT_DIR}/scripts/models" -maxdepth 1 -type f | sort > "${tmpdir}/model_scripts.txt"
> "${tmpdir}/orphaned_model_scripts.txt"
while IFS= read -r script_path; do
  script_name="$(basename "${script_path}")"
  hits="$(rg -n --glob '!scripts/models/*' "${script_name}" "${ROOT_DIR}" || true)"
  if [[ -z "${hits}" ]]; then
    printf '%s\n' "${script_path}" >> "${tmpdir}/orphaned_model_scripts.txt"
  fi
done < "${tmpdir}/model_scripts.txt"

rg -n "TODO|FIXME|HACK|XXX" \
  "${ROOT_DIR}/Epistemos" \
  "${ROOT_DIR}/graph-engine/src" \
  "${ROOT_DIR}/scripts" \
  "${ROOT_DIR}/docs" \
  --glob '!scripts/audit/*' \
  --glob '!docs/audits/dead-code-report-*' > "${tmpdir}/todo_hits.txt" || true

rg -n "DeepSeek|reasoner|sidecar" \
  "${ROOT_DIR}/Epistemos" \
  "${ROOT_DIR}/graph-engine" \
  "${ROOT_DIR}/scripts" \
  "${ROOT_DIR}/docs" \
  --glob '!scripts/audit/*' \
  --glob '!docs/audits/dead-code-report-*' > "${tmpdir}/legacy_ai_hits.txt" || true

{
  echo "# Dead Code Report"
  echo
  echo "- Generated: $(date)"
  echo "- Root: \`${ROOT_DIR}\`"
  echo
  echo "## Non-Direct SwiftPM Pins"
  echo "- These are pins in \`Package.resolved\` that are not direct Xcode package references."
  echo "- They may be legitimate transitive dependencies; review before deleting."
  if [[ -s "${tmpdir}/non_direct_pins.txt" ]]; then
    sed 's/^/- `/' "${tmpdir}/non_direct_pins.txt" | sed 's/$/`/'
  else
    echo "- none"
  fi
  echo
  echo "## Potentially Orphaned Model Scripts"
  if [[ -s "${tmpdir}/orphaned_model_scripts.txt" ]]; then
    sed 's/^/- `/' "${tmpdir}/orphaned_model_scripts.txt" | sed 's/$/`/'
  else
    echo "- none"
  fi
  echo
  echo "## TODO / FIXME / HACK / XXX Hits"
  if [[ -s "${tmpdir}/todo_hits.txt" ]]; then
    sed 's/^/- /' "${tmpdir}/todo_hits.txt"
  else
    echo "- none"
  fi
  echo
  echo "## Legacy AI Stack References"
  if [[ -s "${tmpdir}/legacy_ai_hits.txt" ]]; then
    sed 's/^/- /' "${tmpdir}/legacy_ai_hits.txt"
  else
    echo "- none"
  fi
} > "${REPORT_PATH}"

printf 'Wrote %s\n' "${REPORT_PATH}"
