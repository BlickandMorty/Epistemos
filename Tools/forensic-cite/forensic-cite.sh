#!/usr/bin/env bash
#
# HELIOS V5 W23 — Forensic citation registry tool.
#
# HELIOS-W23 guard
#
# Per docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md §3 W23 +
# docs/fusion/helios v5 first.md PART 1 (forensic citation surface):
#
#   "tools/forensic-cite/ — takes a T<N> ID and prints arXiv ID +
#    DOI + mathlib4 path"
#
# Generalized in v5.2 namespace hardening to cover E1-E7 + H1-H17
# + PCF-1..PCF-10. Each id maps to (arXiv ID, DOI / journal anchor,
# mathlib4 path or "n/a").
#
# Exit codes:
#   0 — id resolved; tuple printed
#   1 — usage error
#   2 — id not in registry
#
# Usage:
#   ./forensic-cite.sh E1
#   ./forensic-cite.sh H17
#   ./forensic-cite.sh PCF-2
#   ./forensic-cite.sh --list

set -euo pipefail

print_usage() {
  cat <<USAGE
HELIOS V5 W23 — Forensic citation registry.

Usage:
  forensic-cite.sh <id>      Resolve one id to (arXiv, DOI, mathlib4) tuple.
  forensic-cite.sh --list    Print the full registry.
  forensic-cite.sh --help    This message.

Recognized id namespaces:
  E1..E7     Epistemos Core Theorems (substrate-foundational)
  H1..H17    Helios Operational Claims
  PCF-1..PCF-10  Parameter Connectome Family

Cross-references:
  docs/HELIOS_V5_DOC_0_INDEX.md §0.2 (theorem status table)
  docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md §C+§D+§B
USAGE
}

# Registry. Format per row:
#   id|arxiv|doi_or_journal|mathlib4_path
#
# Sourced from docs/fusion/helios v5 first.md and helios v5 updated.md.
# n/a indicates the field is not yet pinned (e.g. mathlib4 path
# materializes only after the Lean repo lands per W24).

REGISTRY=$(cat <<'REGISTRY_BODY'
E1|arXiv:N/A|MCSS 2:303-314 (Stone-Weierstrass / Cybenko 1989)|Mathlib.Topology.Algebra.StoneWeierstrass
E2|arXiv:2202.04579|J. Applied & Computational Topology 3(4):315-358 (Hansen-Ghrist 2019)|n/a
E3|arXiv:2309.06180|SOSP 2023 (PagedAttention)|n/a
E4|arXiv:N/A|HELIOS v3 master inequality (WBO-7)|n/a
E5|arXiv:N/A|HELIOS v3 Duplex Fusion (architecture-level)|n/a
E6|arXiv:N/A|HELIOS v4 Epi_e structure-preserving embeddings|n/a
E7|arXiv:N/A|HELIOS v3 Autogenous Kernel Identity (ULP-bounded)|n/a
H1|arXiv:N/A|HELIOS v3 WBO-7 (operational view of E4)|n/a
H2|arXiv:N/A|HELIOS v3 half-softmax post-not-pre|n/a
H3|arXiv:N/A|HELIOS v3 Active-Support Atlas|n/a
H4|arXiv:2507.18553|Chen et al. ICLR 2026 (LatticeCoder/Babai)|n/a
H5|arXiv:N/A|HELIOS v3 Morph DSL determinism|n/a
H6|arXiv:2501.12352|Wang-Shi-Fox (TestTimeRegressor unification)|n/a
H7|arXiv:N/A|HELIOS v3 six-tier memory L0-L_SE|n/a
H8|arXiv:2103.01931|Cruttwell et al. ESOP 2022 (LNCS 13240)|n/a
H9|arXiv:N/A|HELIOS v4 Cortical Packet Runtime (PARN/CAFTI)|n/a
H10|arXiv:N/A|jlrs 0.23 + arrow 53 (Bilaminar Substrate)|n/a
H11|arXiv:2202.04579|Bodnar et al. NeurIPS 2022 (Neural Sheaf Diffusion)|n/a
H12|arXiv:N/A|Berry 1984 / Simon 1983 (Berry-phase routing holonomy)|n/a
H13|arXiv:N/A|Amari (Information-Geometric KL Bridge)|n/a
H14|arXiv:2307.02749|Annals 200(2):749-770 (Apollonian local-global FALSE)|n/a
H15|arXiv:2405.11134|Krishnachandran (Madhava series correction)|n/a
H16|arXiv:N/A|CRT-based storage routing (HELIOS v3)|n/a
H17|arXiv:2008.02217|Ramsauer et al. ICLR 2021 (Modern Hopfield)|n/a
PCF-1|arXiv:2506.20790|Bushnaq-Braun-Sharkey 2025 (SPD ParamAnchor)|n/a
PCF-2|arXiv:2506.20790|QK Edge Anchor (Goodfire VPD May 5 2026)|n/a
PCF-3|arXiv:N/A|HELIOS v5 ParamAttributionGraph|n/a
PCF-4|arXiv:N/A|HELIOS v5 ComponentRoute (Lane 3, deferred until PCF-1 verified)|n/a
PCF-5|arXiv:N/A|HELIOS v5 ActiveRankOneExecution (Lane 5 Vault)|n/a
PCF-6|arXiv:N/A|HELIOS v5 ModelSurgeryEnvelope (Lane 5 Vault)|n/a
PCF-7|arXiv:N/A|Bushnaq+SPD + Bricken+SAE (Dual Connectome Trace)|n/a
PCF-8|arXiv:2202.04579|Hansen-Ghrist + Bodnar (Sheaf Consistency)|n/a
PCF-9|arXiv:N/A|HELIOS v5 Connectome Distillation (Lane 5 Vault)|n/a
PCF-10|arXiv:N/A|HELIOS v5 Interpretability-to-Runtime Transfer|n/a
REGISTRY_BODY
)

case "${1:-}" in
  ""|--help|-h)
    print_usage
    exit 0
    ;;
  --list)
    echo "id|arxiv|doi_or_journal|mathlib4_path"
    echo "${REGISTRY}"
    exit 0
    ;;
esac

target="$1"
match=$(echo "${REGISTRY}" | awk -F'|' -v t="${target}" '$1 == t')
if [ -z "${match}" ]; then
  echo "::error::id '${target}' not in registry" 1>&2
  echo "::error::valid namespaces: E1-E7, H1-H17, PCF-1..PCF-10" 1>&2
  exit 2
fi
echo "${match}"
