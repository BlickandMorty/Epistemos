---
state: canon
canon_promoted_on: 2026-05-06
covers: HELIOS V5 W24 Lean 4 sorry-budget anchor — E1-E7 + H1-H17 + PCF-1..PCF-10 theorem stubs
---

# HELIOS V5 — Lean 4 Theorem Substrate

Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W24 +
`docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §1.

Lake project pinning mathlib4 by tagged release. Each E1-E7
foundational theorem has its own file with statement + `sorry`
proof obligation. Per-id sorry budgets are enforced by
`Tools/sorry-budget/sorry-budget.sh` (W24).

## Layout

```
lean/Epistemos/
├── lakefile.lean         # Lake project definition + mathlib4 pin
├── lean-toolchain        # Lean toolchain pin (leanprover/lean4:v4.16.0)
├── Epistemos.lean        # Top-level lib entry — imports E1-E7
├── README.md             # This file
└── Epistemos/
    ├── E1.lean           # Density Theorem (12-plane bundle)
    ├── E2.lean           # Ultrametric-Sheaf Gluing
    ├── E3.lean           # Storage-Disaggregated Morph Field
    ├── E4.lean           # UST-1.5 / WBO-7 Master Inequality
    ├── E5.lean           # Duplex Fusion
    ├── E6.lean           # Error-Enriched Convergence (Epi_ε)
    ├── E7.lean           # Autogenous Kernel Identity
    ├── H1.lean .. H17.lean         # Operational claims (17 stubs)
    └── PCF-1.lean .. PCF-10.lean   # Parameter Connectome Family
                                     # (10 candidate stubs)
```

**Note on PCF naming:** PCF-N filenames contain a hyphen which
Lean's module resolution does not accept. The W24 sorry-budget
tracker reads them via awk on the filesystem (no `lake build`
required to count sorries). Renaming to `PCF_N.lean` lands per
W24.b when actual Lean elaboration starts.

## Sorry budget at lock

Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §1+§2+§3 + `docs/fusion/helios v5 first.md` PART 2 Q4:

### Foundational Seven (E1-E7) — substrate-foundational

| Theorem | Sorry budget | Current sorries |
|---|---|---|
| E1 Density | ≤ 2 | 1 |
| E2 Sheaf Gluing | ≤ 2 | 1 |
| E3 Morph Field | ≤ 1 | 0 |
| E4 WBO-7 | ≤ 2 | 1 |
| E5 Duplex Fusion | ≤ 2 | 2 |
| E6 Epi_ε | ≤ 1 | 1 |
| E7 Autogenous Kernel | ≤ 2 | 1 |
| **E-tier total** | **≤ 12** | **7** |

### Helios Operational Claims (H1-H17) — build/canon

H1–H10 budget ≤ 4 each; H11–H17 budget ≤ 7 each. H2, H4, and H17
currently carry 2 sorry placeholders; every other H-stub carries 1.

| Total H sorries | 20 |
| H-tier total budget | ≤ 89 |

### Parameter Connectome Family (PCF-1..PCF-10) — candidates

PCF-1..PCF-10 budget ≤ 7 each. Each currently carries 1 sorry
placeholder.

| Total PCF sorries (10 stubs × 1) | 10 |
| PCF-tier total budget | ≤ 70 |

### Aggregate at lock

| Total sorries (E + H + PCF) | 37 |
| Total budget (E + H + PCF) | ≤ 171 |

All 34 theorem ids are within their per-id budgets.

## Build

Requires Lean 4 (version per `lean-toolchain`):

```bash
# Install elan (Lean version manager) if not yet present:
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh

# Build the project:
cd lean/Epistemos
lake update      # fetch mathlib4 pin
lake build       # compile all theorem stubs
```

The build is **NOT** required for CI — the sorry-budget tracker
(`Tools/sorry-budget/sorry-budget.sh`) operates on the .lean files
without compiling them. CI Lean integration lands per W24.b
follow-up gated on:

1. Apple Developer machine has Lean 4 + elan installed
2. mathlib4 build cache is cacheable (~1-2 GB)
3. Build time fits the existing CI budget (~30-60 min)

Until then this directory is the **declarative anchor**: per-theorem
statements, `sorry` proof obligations, and the budget budget table
above. The sorry-budget tracker enforces budgets at PR time.

## How sorries enter the budget

Each `sorry` in a `.lean` file under `Epistemos/E*.lean` counts
toward that theorem's budget. The tracker greps for lines matching:

```
^\s*sorry\s*(--.*)?$
```

This counts **standalone** sorries on their own line. Inline `by sorry`
proofs at the end of a `theorem` block also count. Comment-only
`--   sorry` references do NOT count (the regex requires sorry NOT
in a comment prefix).

## Cross-references

- DOC 6 `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §1 (E1-E7 Lean anchors)
- W24 budget table in `Tools/sorry-budget/sorry-budget.sh`
- HELIOS V5 Canon Lock v2 §F sorry-budget protocol
