---
state: canon
canon_promoted_on: 2026-05-06
covers: HELIOS V5 W24 Lean 4 sorry-budget anchor — E1-E7 + H1-H17 + PCF-1..PCF-10 theorem stubs + Primitive IR schemas
---

# HELIOS V5 — Lean 4 Theorem Substrate

Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W24 +
`docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §1.

Lake project pinning mathlib4 by tagged release. Each E1-E7
foundational theorem has its own file with statement + `sorry`
proof obligation. The Primitive IR stack also has Lean schema modules
for EML, Tropical, Scan, Operator, Info, and Geometry. Per-id and
per-schema sorry budgets are enforced by
`Tools/sorry-budget/sorry-budget.sh` (W24 + T5 Lean-first extension).

## Layout

```
lean/Epistemos/
├── lakefile.lean         # Lake project definition + mathlib4 pin
├── lean-toolchain        # Lean toolchain pin (leanprover/lean4:v4.16.0)
├── Epistemos.lean        # Top-level lib entry — imports schema modules + E1-E7
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
    ├── PCF-1.lean .. PCF-10.lean   # Parameter Connectome Family
    │                                # (10 candidate stubs)
    ├── EML.lean                    # EML-IR schema authority
    ├── Tropical.lean               # Tropical-IR schema authority
    ├── Scan.lean                   # Scan-IR schema authority
    ├── Operator.lean               # Operator-IR schema authority
    ├── Info.lean                   # Info-IR schema authority
    └── Geometry.lean               # Geometry-IR schema authority
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

### Primitive IR Schema Modules — proof-carrying substrate

Each Primitive IR schema module has a zero-sorry budget. Generated Rust
certificate emitters target these schemas before any typechecked Lean
claim is made.

| Schema module | Rust mirror | Sorry budget | Current sorries |
|---|---|---:|---:|
| EML.lean | `agent_core/src/research/eml/` | 0 | 0 |
| Tropical.lean | `agent_core/src/research/tropical_ir/` | 0 | 0 |
| Scan.lean | `agent_core/src/research/scan_ir/` | 0 | 0 |
| Operator.lean | `agent_core/src/research/operator_ir/` | 0 | 0 |
| Info.lean | `agent_core/src/research/info_ir/` | 0 | 0 |
| Geometry.lean | `agent_core/src/research/geometry_ir/` | 0 | 0 |

#### Primitive IR proof-obligation predicates

Generated Rust certificates now target named schema predicates instead
of embedding bare placeholder truth fields or runtime-style function
names. These predicates are the current closure targets once
`LEAN-TOOLCHAIN` and `LAKE-BUILD` resolve.

| Schema module | Named open obligation surface |
|---|---|
| EML.lean | `BranchSafe`, `BranchObligation.discharge`, `Expr.eval_one`, `eval_eml_right_one_positive`, `CertificateTarget.positive_value`; one-leaf source emits named schema theorem sources |
| Tropical.lean | `scalarTropicalSemiringLaws` via `TropicalSemiringLawObligation` |
| Scan.lean | `scanAssociativeOp`, `scanLeftIdentity`, `ssdEquivalentToSequential` |
| Operator.lean | `fourierModeBound`, `fourierIsometry`, `operatorFNOEquivalent` |
| Info.lean | `logPartitionConvex`, `bregmanNonnegative`, `bregmanZeroIffEqual`, `mirrorDescentEquivalent` |
| Geometry.lean | `rotorCandidate`, `rotorUnitNorm`, `cliffordBasisSquares`, `cliffordBasisAnticommutative`, `rotorSandwichPreservesNorm`, `rotorCompositionAssociativeSandwich` |

### Aggregate at lock

| Total sorries (E + H + PCF + Primitive IR schemas) | 37 |
| Total budget (E + H + PCF + Primitive IR schemas) | ≤ 171 |

All 34 theorem ids are within their per-id budgets, and all six
Primitive IR schema modules are within their zero-sorry budgets.

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

`lake build` is not claimed unless it has actually run and succeeded.
As of the T5 Lean-first pivot, build verification is gated by
`docs/T5_BLOCKER_LEDGER.md` rows `LEAN-TOOLCHAIN` and `LAKE-BUILD`.
The sorry-budget tracker (`Tools/sorry-budget/sorry-budget.sh`)
continues to operate on the .lean files without compiling them.
CI Lean integration lands once:

1. Apple Developer machine has Lean 4 + elan installed
2. mathlib4 build cache is cacheable (~1-2 GB)
3. Build time fits the existing CI budget (~30-60 min)

Until the blocker rows resolve, this directory is the Lean source and
schema anchor: per-theorem statements, explicit `sorry` proof
obligations, Primitive IR schema modules, and the budget table above.
The sorry-budget tracker enforces budgets at PR time.

## How sorries enter the budget

Each `sorry` in a `.lean` file under `Epistemos/E*.lean`, H*.lean,
PCF_*.lean, or the six Primitive IR schema modules counts toward that
file's budget. Primitive IR schema modules have budget 0. The tracker
greps for lines matching:

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
- T5 blocker ledger `docs/T5_BLOCKER_LEDGER.md`
- Primitive IR doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` §3
