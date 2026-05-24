# T14 Five-Plane UAS + No-Orphan Audit - 2026-05-24

Status: PASS for the Terminal G bridge slice on this branch.

Scope: Tier 1 MAS code in `agent_core` and Settings UI, with Tier 3
research doctrine preserved at the crate boundary. No hidden cloud
fallbacks were added. Research-only ACS/five-plane canon remains in
`epistemos-research`; MAS code consumes mirrored, product-safe types
under `agent_core::uas`.

## PR Required Fields

- Motion: Lift/Ingest adds UAS/plane/residency metadata to DAG and
  substrate records; Project/Compress/Recall surfaces plane counts and
  falsifier artifacts; Mutate/Promote is limited to docs/register status,
  not model behavior.
- UAS: `NodeKind` carries `Option<UasAddress>` and the new MAS-safe ACS
  registry exposes keyed substrate anchors.
- Plane: `RuntimePlane` is present on every DAG `NodeKind` variant and
  counted by `substrate_health_unified_json`.
- Residency: `ResidencyTier` is present on every DAG `NodeKind` variant
  and exported through the Settings substrate floor.
- WBO: `Option<LatticeBudget>` is added only to approximate/compressed
  records (`HeliosPage`, `ScanProgram<T>`, `KvPair`).
- Witness: `PlanePlacementHealthRow`, the doctrine lint, Swift source
  guard, and falsifier artifacts make the bridge visible.
- Falsifier: `F-UAS-CopyCount` and `F-ACS-AnchorLookup` pass on one
  measured M2 Pro run.
- Tier: Tier 1 MAS bridge + Tier 3 preserved research hooks; no Tier 2
  Pro activation and no Vault promotion.
- Rollback: revert this commit. Serde defaults preserve legacy DAG JSON,
  `NodeId` excludes placement metadata, and the Swift row degrades to
  `agent_core FFI unavailable` if the FFI payload is removed.

## LLM-Address Granularity

- Direct row touched: **Row 3 - KV cache page**. `KvPair` gains a WBO
  budget hook and `F-UAS-CopyCount` includes the KV view in the zero-copy
  hot-path fixture.
- Preserved Tier 3 hooks only: **Row 7 - Active assembly** and **Row 8 -
  Attention head / SSM state** through scan/page-gather substrate types.
  This PR does not claim production active-assembly routing or model-head
  addressing.
- Rows not changed: whole-model call, output schema, weight-bit layout,
  adapter delta, MoE expert, parameter anchor, cross-layer circuit.

## 7 Laws Honored

1. Density: DAG nodes keep content-addressed identity while adding typed
   substrate coordinates.
2. Address: `NodeId` hashing excludes residency/plane/UAS metadata, so
   address identity is stable across placement changes.
3. Active-support: ACS anchors carry theorem/source/packet compatibility
   fields for future support lookup.
4. Lattice-error: approximate/compressed classes now carry
   `Option<LatticeBudget>`.
5. Glue: Swift Settings surfaces the bridge in the unified substrate
   health cluster.
6. Duplex: MAS mirrors the product-safe subset; research crate remains
   preserved and non-shipping.
7. Witness: two falsifier harnesses emit JSON artifacts and doc rows.

## No-Orphan Checklist

| Data class | UAS address | Plane | Residency | WBO if approximate | WRV if product-facing | Result |
|---|---|---|---|---|---|---|
| `NodeKind::{Note,Claim,Evidence,Skill,Tool,Procedure,Event,Companion,Capability,Model}` | `Option<UasAddress>` on every variant | `RuntimePlane` on every variant | `ResidencyTier` on every variant | Waived: exact DAG nodes, not compression | Internal; surfaced via row below | PASS |
| `AcsAnchor` | `anchor_id` plus theorem/source fields | `RuntimePlane` | `ResidencyTier` | Waived: exact anchor record | Internal falsifier target | PASS |
| `AcsAnchorRegistry` | keyed by anchor address/id | Episodic registry witness | VerifiedFloor default usage | Waived: exact hash lookup | F-ACS-AnchorLookup artifact | PASS |
| `HeliosPage` | existing page address fields preserved | page-gather substrate | existing page residency preserved | `lattice_budget: Option<LatticeBudget>` | Research/page-gather, not product visible here | PASS |
| `ScanProgram<T>` | scan program identity preserved by caller | scan/verification substrate | caller-owned | `lattice_budget: Option<LatticeBudget>` | Research/compiler substrate | PASS |
| `KvPair` | KV slot identity owned by KV caller | state/KV substrate | hot-path caller-owned | `lattice_budget: Option<LatticeBudget>` | Internal gate | PASS |
| `PlanePlacementHealthRow` | `settings/plane-placement-health-row` | Verification | CurrentApp | Waived: UI witness, exact display | Visible in Substrate Health panel | PASS |
| New Rust/Swift declarations | CI doctrine lint requires header | CI doctrine lint requires header | CI doctrine lint requires header | explicit waiver path | Swift mirror test probes orphan class | PASS |

## Orphans And Waivers

- W-22 remains open: vault `hybrid_search` does not yet return
  `Vec<UasAddress>`. T14 supplies the MAS-safe address/plane/residency
  vocabulary needed by that migration.
- W-44 remains open: Tri-Fusion ABI does not yet carry all 6 IR
  primitives as UAS-typed expressions. `ScanProgram<T>` now has the
  WBO budget hook needed for scan lowering.
- Live per-plane DAG telemetry is claimed only for `NodeKind::plane()`
  counts from `substrate_health_unified_json`. No model-internal neural
  assembly, attention-head, or per-KV runtime telemetry is claimed.
- Product-facing WRV is limited to the Substrate Health row and source
  guard tests in this slice; no release claim is made.

## W-Rows Advanced

- W-24: every DAG `NodeKind` variant carries `uas`, `anchor`, `plane`,
  and `residency`.
- W-28: `ResidencyTier` is now visible through DAG metadata and the
  Settings plane-placement row.
- W-22: partially unblocked by MAS-safe UAS/five-plane re-exports, but
  vault retrieval is not migrated in this PR.
- W-44: partially unblocked by `ScanProgram<T>::lattice_budget`, but the
  six-IR Tri-Fusion ABI remains future work.

## Falsifiers

- F-UAS-CopyCount: PASS. Command:
  `cargo +stable run --manifest-path agent_core/Cargo.toml --bin uas_copy_count`.
  Artifact: `artifacts/falsifiers/uas_copy_count/result.json`.
  Scope: instrumented shared-backing UAS fixture; tensor-copy counter
  only. Measured tensor copies: 0.
- F-ACS-AnchorLookup: PASS. Command:
  `cargo +stable run --manifest-path agent_core/Cargo.toml --bin acs_anchor_lookup`.
  Artifact: `artifacts/falsifiers/acs_anchor_lookup/result.json`.
  Scope: 10,000 MAS `AcsAnchor` lookups through `AcsAnchorRegistry`.
  Measured average lookup: 516 ns.

## Tier Classification

- Tier 1 MAS: `agent_core::uas` mirror types, cognitive DAG metadata,
  WBO budget hooks, falsifier binaries, Settings row, CI/source guards.
- Tier 2 Pro flagged-OFF: no Pro-only code added.
- Tier 3 Research: `epistemos-research` remains the preserved doctrine
  source; MAS does not depend on it.
- Vault: no speculative implementation moved into product code.

## Verification Notes

- Focused Rust bridge test passed after the 2026-05-24 rebase:
  `cargo +stable test --manifest-path agent_core/Cargo.toml substrate_health_unified_json_surfaces_t14_plane_counts --lib`.
- Falsifier binaries reran after the rebase:
  `cargo +stable run --manifest-path agent_core/Cargo.toml --bin uas_copy_count`
  and
  `cargo +stable run --manifest-path agent_core/Cargo.toml --bin acs_anchor_lookup`.
- `git diff --check` passed.
- Targeted rustfmt passed for the new T14 Rust files using
  `rustfmt +stable --edition 2021 --config skip_children=true --check ...`.
  Whole-file `bridge.rs` rustfmt remains intentionally unmodified because
  it reports pre-existing formatting churn outside this patch.
- Swift parser passed over the T14 Settings row/panel/test slice via
  `xcrun swiftc -parse-as-library -parse ...`.
- Isolated Swift typecheck of the Settings subset was not a useful signal:
  it requires broader app types such as `UIState` and `EpistemosTheme`.
- Standalone doctrine-linter tests passed via
  `CARGO_PKG_VERSION=0.1.0 rustc +stable --edition=2021 --test agent_core/src/bin/epistemos_doctrine_lint.rs`.
- Standalone doctrine-linter run passed against this worktree, including
  the No-Orphan gate over committed, staged, working-tree, and untracked
  Rust/Swift declarations.
- Static scan after fixture updates found no direct `NodeKind` literals
  missing UAS metadata fields.
- Swift source guard includes a deliberate orphan-class probe and accepts
  both full headers and explicit `// UAS-EXEMPT:` waivers.
