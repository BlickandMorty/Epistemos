---
state: falsifier
gate: F-ACS-Anchor-Addressing
ladder_position: 3 (after F-UAS-ZeroCopy-Spine, before F-ShadowFirst-PageEscalation)
owner: T3
created_on: 2026-05-17
authority: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G falsifier ladder (LOCK)
target_phase: Phase B.G.B3
target_rig: M2 Pro 16 GB
---

# F-ACS-Anchor-Addressing

> Gate #3 in the §4.G falsifier ladder. **Typed ACS anchor object round-trips through agent runtime + lookup +
> audit + projection without silent loss.** Until this gate passes, the ACS layer (COORDINATE SYSTEM) cannot
> claim ship-readiness.

## §1. Why this gate exists

Per the §4.G hierarchy, ACS = *Anchored Cognitive Substrate*: the coordinate system that maps every UAS-addressed
artifact to a typed anchor carrying provenance, theorem labels, plane coordinates, and a §4.G residency tier.

The anchor has to survive **four** boundaries without silent loss:

1. **Agent runtime** — the anchor is attached to a claim emerging from the local-agent loop (`agent_core::
   agent_runtime`).
2. **Lookup** — a downstream caller pulls the anchor back via `UasAddress`.
3. **Audit** — the anchor is canonicalized into a `LedgerSnapshot` / `ReplayBundle` and verified by
   `epistemos_trace verify`.
4. **Projection** — the anchor is projected onto the V6.1 five-plane formalism (State / Episodic / Assembly /
   Controller / Verification) for downstream use (Cognitive DAG node placement, provenance plane indexing).

Driver §4.G prose:

> **F-ACS-Anchor-Addressing** — typed anchor object (theorem tag, plane coord, residency tier, source hash,
> active packet id) round-trips through agent runtime + lookup + audit + projection without silent loss.

## §2. The Anchor type (Phase B.G.B3 target)

The harness lands at `agent_core/src/research/acs/anchor.rs` (gap as of 2026-05-17, see audit §C). The
typed-anchor shape is:

```rust
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct AcsAnchor {
    /// Theorem tag — one of the E1-E7 Foundational Seven or future H-series
    /// (per epistemos-research/src/theorem_status.rs).
    pub theorem_tag: TheoremTag,

    /// V6.1 plane coord — one of State / Episodic / Assembly / Controller
    /// / Verification (per epistemos-research/src/five_planes.rs).
    pub plane: RuntimePlane,

    /// §4.G residency tier (Current App / Verified Floor / Capability Ceiling).
    /// NOT the same as scope_rex::residency::Residency.
    pub tier: ResidencyTier,

    /// BLAKE3 hash of the source bytes (provenance lock).
    pub source_hash: blake3::Hash,

    /// AnswerPacket emission id that produced this anchor, if any.
    pub active_packet_id: Option<AnswerPacketId>,
}
```

## §3. Pass/fail recipe (the test that decides)

A `#[test]` in `agent_core/tests/acs_anchor_addressing.rs` (lands in Phase B.G.B3) runs a 4-stage round trip on
`N = 1000` randomly-generated `AcsAnchor` instances:

```rust
let original = AcsAnchor::random(&mut seed);

// Stage 1 — agent runtime emission
let claim = ClaimLedger::file_with_anchor(original.clone());

// Stage 2 — lookup
let recovered_by_lookup = registry.lookup_anchor(original.uas_address())
    .expect("anchor must be lookup-recoverable");
assert_eq!(recovered_by_lookup, original);

// Stage 3 — audit
let snapshot = ledger.snapshot();
let bundle = ReplayBundle::from(snapshot);
let bytes = bundle.to_epbundle_bytes()?;
let recovered_bundle = ReplayBundle::from_epbundle_bytes(&bytes)?;
let recovered_by_audit = recovered_bundle.lookup_anchor(original.uas_address())
    .expect("anchor must survive audit canonicalization");
assert_eq!(recovered_by_audit, original);

// Stage 4 — projection onto the 5-plane formalism
let projection = original.project_to_plane();
assert_eq!(projection.plane(), original.plane);
let recovered_by_projection = registry.lookup_via_projection(projection);
assert_eq!(recovered_by_projection, original);
```

Gate **fails** if any of the four `assert_eq!` comparisons fails. Gate **passes** when all `N = 1000` random
anchors complete the round trip with bytewise equality at every stage.

### §3.1 Random-anchor generator

The `AcsAnchor::random(&mut seed)` helper draws uniformly from:

- `theorem_tag` — E1..E7 + H1..H17 + PCF-1..PCF-9 (per `epistemos-research::theorem_status`).
- `plane` — State · Episodic · Assembly · Controller · Verification (5 variants).
- `tier` — Current App · Verified Floor · Capability Ceiling.
- `source_hash` — BLAKE3 of `seed.next_u64().to_le_bytes()` × 8.
- `active_packet_id` — `None` w.p. 0.3, else a random u64.

Seeding uses a `ChaCha20Rng::from_seed([…])` with the fixed seed `[0xAC, 0x5A, …]` so failures are reproducible.

### §3.2 "Silent loss" definition

The gate's definition of "silent loss":

- Any field that survives Stage N-1 but does not survive Stage N (e.g. `active_packet_id: Some(x)` becomes
  `None`, or `theorem_tag: E2` becomes `theorem_tag: E1`).
- Any field that is silently *changed* (e.g. `source_hash` is recomputed at Stage 3 from the new bytes and no
  longer matches the original).
- Any anchor whose `lookup` at Stage 2 returns `None` despite Stage 1 having filed the claim.
- Any anchor whose `project_to_plane` at Stage 4 cannot be inverted (one-way projection = silent loss).

The gate does **not** count these as silent loss (acceptable transforms):

- Wire-format canonicalization (e.g. field reordering in serialized JSON).
- Explicit `None → None` propagation (the field was already absent).
- Hash recomputation that produces the same value (Stage 3 verifies hash equality, not byte equality of the
  bundle).

## §4. M2 Pro 16 GB budget

| Stage | `wall_us_p50` | `wall_us_p99` | Memory |
|---|---|---|---|
| 1 — agent runtime emission | < 20 µs | < 80 µs | 1 allocation (the claim record) |
| 2 — lookup | < 10 µs | < 40 µs | 0 allocations (hashmap probe) |
| 3 — audit (canonicalize + recover) | < 200 µs | < 800 µs | ~64 KB serialized bytes |
| 4 — projection onto 5-plane | < 5 µs | < 20 µs | 0 allocations (enum dispatch) |
| **End-to-end p99** | — | **< 1 ms** | — |

The end-to-end p99 budget is set by the V6.1 "Attention as Interrupt" posture: anchor round-trips must not
dominate the inter-token interrupt window.

## §5. Measurement methodology

Same infrastructure as F-UAS-ZeroCopy-Spine §4 (cargo test --release, 100-warmup, 1000-timed, median-of-3-runs,
Spotlight off on `target/`, CPU governor pinned). Additional methodology for this gate:

- **Reproducibility seed** is logged with every harness run; failures must include the seed in the BLOCKER
  commit so the user can rerun deterministically.
- **Field-level diff on failure**: when `assert_eq!` fails, the harness emits a structured diff
  (`pretty_assertions::assert_eq` or equivalent) so the offending field is obvious.
- **Per-stage instrumentation**: each stage records its own latency; failures need to attribute to a specific
  stage so the fix is local.
- **Sheaf-consistency cross-check** (optional, Phase B follow-up): if `epistemos-research::theorems::e2_sheaf_gluing`
  exposes a sheaf-consistency predicate, the harness can additionally assert that two overlapping anchors
  satisfy the sheaf-gluing equation. Out-of-scope for v1 of this gate.

## §6. Fallback if the gate fails

Per §4.G "No silent skips":

1. **Identify the offending stage**. The harness reports per-stage results; failing stage is the one with the
   `assert_eq!` panic.
2. **Classify the loss**.
   - **Stage 1 → 2 loss (lookup miss)**: the registry's hashmap is keyed on the wrong field. Check
     `UasAddress::hash` implementation; ensure it includes all anchor-distinguishing fields.
   - **Stage 2 → 3 loss (audit canonicalization)**: the `ReplayBundle::to_epbundle_bytes` serialization is
     dropping a field. Check `serde` field attributes; `#[serde(skip)]` is the most likely culprit.
   - **Stage 3 → 4 loss (projection inversion)**: the `project_to_plane` function is many-to-one for some
     anchors. Either the projection must be made injective (add tiebreaker), or `lookup_via_projection` must
     return a result set, not a unique anchor.
3. **Mitigation tier** (least invasive first):
   - **Tier 1 — field-attribute fix**: change `#[serde(skip)]` to `#[serde(default)]` (or remove). Re-run.
   - **Tier 2 — hash-key fix**: extend `UasAddress::hash` to include the missing distinguishing field.
   - **Tier 3 — projection redefinition**: split `project_to_plane` into `project_to_plane_set` returning
     `BTreeSet<AcsAnchor>`; require lookup to disambiguate.
   - **Tier 4 — Anchor schema rev**: if a field is fundamentally non-round-trippable (e.g. an `Rc<T>` was
     introduced), refactor the offending field to a fully-`Serialize` form.
   - **Tier 5 — STALLED**: file a STALLED row in `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §5
     register row #5 + BLOCKER commit. Do not push.
4. **Document the mitigation** on the source: `// F-ACS-Anchor-Addressing: round-trip preserved via X; see
   docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md §6.`

## §7. Acceptance bar (gate-pass criteria)

The gate **passes** when ALL of the following are true on M2 Pro 16 GB:

- [ ] `N = 1000` random anchors complete the 4-stage round trip with bytewise field equality.
- [ ] Reproducibility: the same fixed seed produces the same 1000 anchors across 3 runs.
- [ ] All four `wall_us_p99` budgets in §4 are met; end-to-end p99 < 1 ms.
- [ ] `cargo test` count remains ≥ 1671 + (new acs_anchor_addressing tests). No regressions.
- [ ] The Anchor type lands at `agent_core/src/research/acs/anchor.rs` (no longer a gap per audit §C).
- [ ] Doctrine doc §5 register row #5 status updates from `scaffolded` → `landed`.
- [ ] `Co-Authored-By: Codex (T3)` on every commit landing the gate.

## §8. Dependencies + downstream gates

**Depends on**:

- Phase B.G.B1: `UasAddress` (so the anchor has an address to be looked up by).
- Phase B.G.B2: F-UAS-ZeroCopy-Spine pass (the audit-stage canonicalization runs through the same FFI
  surface; if zero-copy fails, this gate's measured latency will be hiding allocation cost).
- Existing infrastructure: `epistemos-research::theorem_status` (TheoremTag), `epistemos-research::five_planes`
  (RuntimePlane), `agent_core::provenance::{ledger, replay}` (Stage 3 audit canonicalization).

**Unblocks**:

- Gate #4 F-ShadowFirst-PageEscalation (the page escalation policy reads the anchor's `tier` field to decide
  sketch-vs-residual-vs-exact).
- Gate #6 F-ActiveAssembly-Minimal (the active-pull selector consumes anchor `plane` + `theorem_tag` to decide
  which packet fires).
- Downstream consumer: Cognitive DAG (Phase 8.x) — the `NodeId` will incorporate an `AcsAnchor` once this gate
  passes.

## §9. Cross-references

- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §4 ladder + §5 register row #5.
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §A row #5 + §B.3.
- Driver authority: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G ladder gate #3.
- TheoremTag substrate: `epistemos-research/src/theorem_status.rs` + `theorems/{e1..e7,mod}.rs`.
- Plane substrate: `epistemos-research/src/five_planes.rs` (V6.1 §3 plane LOCK; numbers 1..5 fixed).
- Provenance ledger (Stage 3): `agent_core/src/provenance/{ledger.rs, replay.rs}` + `agent_core/src/bin/
  epistemos_trace.rs` (verify-replay CLI).
- ResidencyTier substrate: `agent_core/src/uas/residency_tier.rs` (gap — lands in Phase B.G.B1).
