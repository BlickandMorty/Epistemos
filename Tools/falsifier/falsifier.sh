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

# Registry rows: id|crate|features|cargo_test_filter
#
# Stage 14 (loop iteration 2): registry expanded to per-crate
# dispatch so PCF + epistemos-research + epistemos-vault tests run
# from their own crate directories with the right feature flag.
# Stage 0/7 hardcoded `cd agent_core` which silently broke for
# non-agent_core protocols.
REGISTRY=$(cat <<'REGISTRY_BODY'
E1|epistemos-research|research|theorems::e1_density
E2|epistemos-research|research|theorems::e2_sheaf_gluing
E3|agent_core|default|storage::vault
E4|agent_core|default|scope_rex::metal::softmax
E5|epistemos-research|research|theorems::e5_duplex_fusion
E6|epistemos-research|research|theorems::e6_epi_epsilon
E7|epistemos-research|research|theorems::e7_kernel_identity
H2|agent_core|default|scope_rex::metal::softmax
H3|agent_core|default|scope_rex::metal::asa_index
H7|agent_core|default|scope_rex::residency
H17|agent_core|default|scope_rex::retrieval::hopfield
W1|agent_core|default|scope_rex::answer_packet
W5|agent_core|default|scope_rex::btm_semantic
W6|agent_core|default|scope_rex::metal::asa_index
W8|agent_core|default|scope_rex::kv::direct_gate
W12|agent_core|default|scope_rex::kernels::t_mac
W13|agent_core|default|scope_rex::kernels::bitnet
W14|agent_core|default|scope_rex::kernels::sparse_ternary_gemm
PCF-1|epistemos-research|research|vpd::extract
PCF-2|epistemos-research|research|vpd::qk_edge
PCF-3|epistemos-research|research|vpd::attribution_graph
PCF-4|epistemos-research|research|vpd::component_route
PCF-5|epistemos-vault|vault|runtime::active_rank_one
PCF-6|epistemos-vault|vault|surgery::envelope
PCF-7|epistemos-research|research|vpd::dual_trace
PCF-8|epistemos-research|research|vpd::connectome_sheaf
PCF-9|epistemos-vault|vault|distill::connectome
PCF-10|epistemos-vault|vault|runtime::transfer
REGISTRY_BODY
)

# Build the cargo test invocation for one row of the registry.
# Returns 0 on success, 1 on failure.
run_one() {
  local id="$1"
  local row
  row=$(echo "${REGISTRY}" | awk -F'|' -v t="${id}" '$1 == t {print $0; exit}')
  if [ -z "${row}" ]; then
    echo "::error::W25 falsifier: no protocol registered for id '${id}'"
    return 1
  fi
  local crate features filter
  crate=$(echo "${row}" | awk -F'|' '{print $2}')
  features=$(echo "${row}" | awk -F'|' '{print $3}')
  filter=$(echo "${row}" | awk -F'|' '{print $4}')

  local feature_arg=""
  if [ "${features}" != "default" ] && [ -n "${features}" ]; then
    feature_arg="--features ${features}"
  fi

  echo "[W25] running protocol for ${id} (cd ${crate}; cargo test --lib ${feature_arg} ${filter})"
  # shellcheck disable=SC2086
  ( cd "${REPO_ROOT}/${crate}" && cargo test --lib --quiet ${feature_arg} "${filter}" ) || {
    echo "::error::W25 falsifier: protocol ${id} FAILED"
    return 1
  }
  echo "[W25] ${id} ✓"
}

case "${1:-}" in
  --list)
    echo "id|crate|features|cargo_test_filter"
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
