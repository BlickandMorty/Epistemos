#!/usr/bin/env bash
#
# HELIOS V5 W25 — Hardware falsifier rig.
#
# HELIOS-W25 guard
#
# Per docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md §3 W25 +
# docs/fusion/helios v5 first.md PART 4 §11:
#
#   "tools/falsifier/ — Swift + Rust harness; reads YAML protocols,
#    runs on attached M2 Max, posts results to ClaimLedger as
#    TypedArtifacts. Nightly on dev rig."
#
# Stage 0 scaffold: maps each E/H/W invariant id to a corresponding
# cargo test filter that exercises the substrate. Real M2 Max
# falsifier YAML + Metal-kernel runs land per follow-up slices.
#
# Portable: avoids bash 4+ `declare -A` (macOS ships bash 3.2).
#
# Exit codes:
#   0 — all protocols passed
#   1 — at least one protocol failed
#   2 — usage error
#
# Usage:
#   ./falsifier.sh             Run all protocols
#   ./falsifier.sh --list      List protocols
#   ./falsifier.sh <id>        Run a single protocol

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Registry rows: id|cargo_test_filter
REGISTRY=$(cat <<'REGISTRY_BODY'
E3|storage::vault
H2|scope_rex::metal::softmax
H3|scope_rex::metal::asa_index
H7|scope_rex::residency
H17|scope_rex::retrieval::hopfield
W1|scope_rex::answer_packet
W5|scope_rex::btm_semantic
W8|scope_rex::kv::direct_gate
W12|scope_rex::kernels::t_mac
W13|scope_rex::kernels::bitnet
W14|scope_rex::kernels::sparse_ternary_gemm
REGISTRY_BODY
)

run_one() {
  local id="$1"
  local filter
  filter=$(echo "${REGISTRY}" | awk -F'|' -v t="${id}" '$1 == t {print $2}')
  if [ -z "${filter}" ]; then
    echo "::error::W25 falsifier: no protocol registered for id '${id}'"
    return 1
  fi
  echo "[W25] running protocol for ${id} (cargo test --lib ${filter})"
  ( cd "${REPO_ROOT}/agent_core" && cargo test --lib --quiet "${filter}" ) || {
    echo "::error::W25 falsifier: protocol ${id} FAILED"
    return 1
  }
  echo "[W25] ${id} ✓"
}

case "${1:-}" in
  --list)
    echo "id|cargo_test_filter"
    echo "${REGISTRY}"
    exit 0
    ;;
  --protocols)
    # List all M2 Max YAML protocol files alongside the registered
    # cargo-test ids. Stage-0 only — the future runner reads these
    # YAML files for hardware-specific dispatch.
    proto_dir="$(dirname "$0")/protocols"
    echo "id|registered|yaml_protocol"
    while IFS='|' read -r id _; do
      [ -z "${id}" ] && continue
      yaml="${proto_dir}/${id}.yaml"
      if [ -f "${yaml}" ]; then
        echo "${id}|yes|${yaml}"
      else
        echo "${id}|yes|(missing)"
      fi
    done <<< "${REGISTRY}"
    # Surface any orphan YAML files (protocols without registered
    # cargo dispatch).
    for yaml in "${proto_dir}"/*.yaml; do
      [ -f "${yaml}" ] || continue
      id=$(basename "${yaml}" .yaml)
      if ! echo "${REGISTRY}" | awk -F'|' -v t="${id}" 'BEGIN{found=0} $1 == t {found=1} END{exit !found}'; then
        echo "${id}|orphan|${yaml}"
      fi
    done
    exit 0
    ;;
  --help|-h)
    cat <<USAGE
HELIOS V5 W25 — Hardware falsifier rig (stage-0 scaffold).

Usage:
  falsifier.sh                 Run every registered protocol.
  falsifier.sh --list          List protocols without running.
  falsifier.sh --protocols     List YAML protocol manifests + cross-ref to registered ids.
  falsifier.sh <id>            Run one protocol (e.g. E3, H7, W12).

Real M2 Max falsifier YAML + Metal-kernel runs land per follow-up
slices. Stage-0 scaffold runs the corresponding cargo tests as a
substrate-presence proxy. The YAML manifests under protocols/
declare what real M2 Max-specific runs will check.
USAGE
    exit 0
    ;;
  "")
    failures=0
    while IFS='|' read -r id _; do
      [ -z "${id}" ] && continue
      if ! run_one "${id}"; then
        failures=$((failures + 1))
      fi
    done <<< "${REGISTRY}"
    if [ "${failures}" -gt 0 ]; then
      echo "::error::W25 falsifier: ${failures} protocol(s) failed"
      exit 1
    fi
    echo "W25 falsifier: ALL PROTOCOLS PASS"
    exit 0
    ;;
  *)
    run_one "$1"
    ;;
esac
