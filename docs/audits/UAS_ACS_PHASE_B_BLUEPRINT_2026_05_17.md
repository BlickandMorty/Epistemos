---
state: blueprint
created_on: 2026-05-17
terminal: T3 — UAS-ACS Canonical Architecture
branch: codex/t3-uasacs-2026-05-16
scope: Phase A iter 18 — concrete iter-by-iter blueprint for Phase B (iters 21-50). Each iter has a slice, expected files, expected line-count band, expected dependencies, and acceptance gate.
authority: driver §4.G Phase B mission steps + falsifier docs landed iters 3-15 + audit §C gap list + T-terminal coord doc.
---

# UAS-ACS Phase B Implementation Blueprint — 2026-05-17

> Phase A iter 18. Hands off Phase A's doctrine + falsifier-spec corpus into Phase B's implementation work
> as a concrete iter-by-iter plan. Each iter is ONE slice (per driver discipline), targeted at one
> deliverable, with explicit dependencies + acceptance gate. Reviewable at iter granularity.

## §1. Phase A → Phase B handoff posture

Phase A landed:

- **Substrate-floor audit** (40-row register · 11 module-by-module sub-audits · gap list).
- **Canonical doctrine** (LOCKed hierarchy + residency tiers + 12-gate ladder + 43-row no-loss register +
  full 41-row MASTER_FUSION cross-link).
- **12 falsifier-doc specs** (11 §4.G ladder gates T3-owned + F-ULP-Oracle W1 V6.1 foundation).
- **Morph resolution** (open question from iter 1 closed via primary-source archeology).
- **T-terminal coordination handle matrix** (T1/T4/T5/T7 handshakes spelled out).

Phase B begins at iter 21 (after Phase A close-out at iter 20). The blueprint below is the concrete plan.

## §2. Phase B sequence — iters 21-50

Iter naming convention: `B.<gate>.<step>` (e.g. `B.G.B1.a` = Phase B, gate G.B1, step a).

### §2.1 Iters 21-26 — UAS module scaffold (G.B1)

| Iter | Slice | Files | Lines (band) | Depends on | Acceptance |
|---|---|---|---|---|---|
| 21 | `agent_core/src/uas/{mod, address}.rs` + `lib.rs` registration | 3 files | ~150-200 | (none — fresh module) | compiles · ≥ 1 unit test on UasAddress round-trip · cargo test ≥ 1671 + new |
| 22 | `agent_core/src/uas/kind.rs` (UasKind enum + Other(SmolStr) escape hatch) | 1 file | ~80-120 | iter 21 + T1 review (`COORDINATION:` blocker per coord doc §2) | compiles · variant-set test · serialization round-trip |
| 23 | `agent_core/src/uas/residency_tier.rs` (§4.G three tiers; tail-comment LOCK distinguishing from scope_rex::residency::Residency) | 1 file | ~80-100 | iter 21 + audit §F Q5 closure | compiles · tier-enum test · tail-comment on scope_rex/residency.rs reciprocal |
| 24 | `agent_core/src/uas/residency_lease.rs` (ResidencyLease handle with TTL + drop semantics) | 1 file | ~150-200 | iters 21-23 | compiles · TTL-eviction test · drop-runs-on-scope-exit test |
| 25 | `agent_core/tests/uas_address_round_trip.rs` (UasAddress round-trips serialization, lookups across residency, SCOPE-Rex witness emission) | 1 file | ~180-250 | iters 21-24 | gate: UasAddress round-trips AND emits SCOPE-Rex witness on state change |
| 26 | Push beat — verify diff with `git show $SHA -- file \| grep <signature>` per [[feedback_verify_commit_diff_after_concurrent_edits]] | (no new file) | (verify only) | iters 21-25 landed | git push -u; remote tracks iter 26 |

**Phase B.G.B1 acceptance** (per driver §4.G G.B1): UasAddress round-trips serialization, can be looked up
regardless of residency, emits a SCOPE-Rex witness on any state change. Iters 21-25 deliver this.

### §2.2 Iters 27-31 — F-UAS-ZeroCopy-Spine harness (G.B2)

| Iter | Slice | Files | Lines (band) | Depends on | Acceptance |
|---|---|---|---|---|---|
| 27 | `agent_core/tests/uas_zero_copy_spine_path1_embedding.rs` (designated hot-path 1 from F-UAS-ZeroCopy-Spine §2.1) | 1 file | ~150-200 | B.G.B1 + falsifier doc | gate: copy_count == 0 on embedding query → search-index hot path |
| 28 | `agent_core/tests/uas_zero_copy_spine_path2_logits.rs` (path 2 — logit stream → AnswerPacket) | 1 file | ~150-200 | iter 27 | copy_count == 0 on logit stream path |
| 29 | `agent_core/tests/uas_zero_copy_spine_path5_provenance.rs` (path 5 — ClaimLedger snapshot; in-process, no FFI; already lands via existing infrastructure) | 1 file | ~120-160 | iter 27 + existing provenance ledger | gate: ≤ 1 allocation; same harness shape |
| 30 | `agent_core/src/uas/copy_counter.rs` (the tracking-allocator shim used by the harness; thread-local counters) | 1 file | ~120-180 | iter 27 | unit test: allocator counters increment/reset correctly |
| 31 | Doctrine-doc update: §5 register row #1-3 (UasAddress / ResidencyLease / UasKind) status `not yet` → `landed` once iters 21-30 are green | EDIT canonical doctrine + audit | ~30-50 | iters 21-30 | drift-gate `provenance_storage_in_episodic_audit_in_verification`-style gate added to lock the UAS registration |

**Phase B.G.B2 acceptance**: harness exists with `#[test]` that fails if copy_count > 0 for designated
hot-path operations. Iters 27-31 deliver the harness; full gate-PASS depends on hot-path operations being
zero-copy in production (the harness exposes the problem if they aren't, but doesn't fix them — fixes go
in Tier 1-4 follow-ups per fallback ladder).

### §2.3 Iters 32-36 — F-ACS-Anchor-Addressing (G.B3)

| Iter | Slice | Files | Lines (band) | Depends on | Acceptance |
|---|---|---|---|---|---|
| 32 | `agent_core/src/research/acs/anchor.rs` (typed AcsAnchor: theorem_tag · plane · tier · source_hash · active_packet_id) | 1 file | ~200-280 | B.G.B1 + epistemos-research::theorem_status + five_planes | compiles · AcsAnchor round-trip test |
| 33 | `agent_core/src/research/acs/anchor_registry.rs` (lookup-by-UasAddress + lookup-via-projection) | 1 file | ~180-250 | iter 32 | compiles · lookup tests for both axes |
| 34 | `agent_core/tests/acs_anchor_addressing.rs` (4-stage round trip per F-ACS-Anchor-Addressing §3) | 1 file | ~250-330 | iters 32-33 + provenance ledger | gate: 1000 random anchors complete 4-stage round trip with bytewise equality |
| 35 | Push beat — verify diff post-commit | (no new file) | (verify only) | iters 32-34 landed | git push |
| 36 | Doctrine-doc update: §5 row #5 status `scaffolded` → `landed` + audit row #5 + drift-gate for AcsAnchor schema | EDIT canonical + audit | ~30-50 | iters 32-34 | doctrine consistency reconciled |

**Phase B.G.B3 acceptance**: AcsAnchor type lands; 4-stage round trip passes for 1000 random anchors.

### §2.4 Iters 37-43 — F-ShadowFirst-PageEscalation harness (G.B4)

| Iter | Slice | Files | Lines (band) | Depends on | Acceptance |
|---|---|---|---|---|---|
| 37 | `agent_core/src/research/page_gather/{mod, helios_page}.rs` (HeliosPage three-stage struct: sketch INT8 / residual Sherry-1.25-bit / exact bf16) | 2 files | ~250-350 | F-PageGather kernel substrate at helios/page_gather.rs | compiles · field-access tests |
| 38 | `agent_core/src/research/page_gather/sketch_topk.rs` (INT8 sketch dot-product + top-K128 over corpus) | 1 file | ~180-240 | iter 37 | unit test: top-K128 matches brute-force on small corpus |
| 39 | `agent_core/src/research/page_gather/residual_rescore.rs` (residual rescoring; K128 → K32 promotion) | 1 file | ~150-200 | iter 37 | unit test: K32 result is a strict subset of K128 input |
| 40 | `agent_core/src/research/page_gather/escalation_policy.rs` (margin-based escalation; thresholds tunable) | 1 file | ~180-240 | iters 37-39 | unit test: deterministic policy for fixed inputs |
| 41 | `agent_core/tests/page_gather_shadow_escalation.rs` (synthetic corpus + Q=200 queries + per-difficulty-bucket KL) | 1 file | ~300-400 | iters 37-40 | gate: KL/token mean < 0.06 AND max < 0.20 AND exact-decode rate < 25% |
| 42 | Push beat — verify diff post-commit | (no new file) | (verify only) | iters 37-41 landed | git push |
| 43 | Doctrine-doc update: §5 row #8 + #41 status `not yet` → `landed`; coord-doc update T4 handshake (Shadow-paging consumer API now stable) | EDIT canonical + audit + coord | ~30-50 | iters 37-41 | T4 can wire vault.rs against the API |

**Phase B.G.B4 acceptance**: harness exists; KL drift target measured. PASS condition is in production code
that consumes the policy (which is T4's job per scope lock).

### §2.5 Iters 44-50 — F-PageGather-M2Pro Metal kernel + driver (G.B5)

| Iter | Slice | Files | Lines (band) | Depends on | Acceptance |
|---|---|---|---|---|---|
| 44 | `agent_core/src/research/page_gather/metal_driver.rs` (FFI scaffold to call into Swift-side Metal kernel) | 1 file | ~150-200 | iters 37-43 + existing helios/page_gather.rs CPU ref | compiles · FFI signature test |
| 45 | `Epistemos/Shaders/PageGather.metal` v2 (production kernel; replaces stub) | 1 file (Swift-side) | ~200-300 | iter 44 + Metal compile pipeline | xcodebuild test on a minimal Metal compile + dispatch |
| 46 | `EpistemosTests/HeliosPageGatherBandwidthTests.swift` (Swift-side bandwidth measurement per F-PageGather-M2Pro §3) | 1 file (Swift-side) | ~250-350 | iter 45 + STREAM baseline | gate: sustained_scatter ≥ 70% of MEASURED STREAM at 256/512/1024 MB |
| 47 | `agent_core/tests/page_gather_m2pro.rs` (Rust CPU twin for cross-check) | 1 file | ~180-240 | iter 44 + helios/page_gather.rs | gate: bit-for-bit Rust vs Metal on fixed-seed inputs |
| 48 | (Mitigation hold) — if iter 46 fails 70% target, run §6 fallback Tier 1-2 (threadgroup tune + uint4 vector load) and iterate | EDIT Metal kernel | ~50-100 | iter 46 fail | next 46 run passes |
| 49 | Push beat — full Phase B.G.B1-B5 work pushed | (no new file) | (verify only) | iters 44-48 landed | git push |
| 50 | Doctrine-doc update: §5 row #9 + #10 + #11 + #42 status `scaffolded` → `landed` | EDIT canonical + audit | ~30-50 | iter 49 | doctrine consistency |

**Phase B.G.B5 acceptance**: Metal kernel passes the bandwidth gate at all three working-set sizes
(256/512/1024 MB).

## §3. Phase B → Phase C handoff (iters 51-80)

Iters 51-80 cover Phase B.G.B6 (F-ActiveAssembly-Minimal) + the first half of Phase C
(F-KV-Direct-Gate + F-SemiseparableBlockScan Track A only; Track B / live-model integration deferred to
Phase C proper).

Sketch (one line per iter; not the full blueprint detail — that's Phase C blueprint, iter 79 deliverable):

- iters 51-58: `agent_core/src/research/active_assembly/` scaffold + synthetic graph builder + selector +
  harness; F-ActiveAssembly-Minimal gate.
- iters 59-65: Morph kernel + F-ULP-Oracle harness (T7 oxieml handshake required); AnswerPacket schema
  freeze unlock.
- iters 66-72: F-SemiseparableBlockScan Track A (Metal kernel + numerical-equivalence harness). Track B
  deferred (live-model dependency on Mamba-2 2.8B + Qwen 3 8B).
- iters 73-78: F-KV-Direct-Gate Phase C bring-up (warm-tier residency-lease tier policy + cold-spill
  manager scaffold). Full gate live in Phase C.
- iter 79: Phase C blueprint doc.
- iter 80: Phase B close-out + audit-of-audit per §7 cadence.

## §4. Acceptance gates per phase

| Phase | Iter | Acceptance |
|---|---|---|
| A close-out | iter 20 | All Phase A docs landed · §5.0 reconciliation gate clean · canonical doctrine + audit + coord doc + 12 falsifier docs on remote |
| B.G.B1 | iter 26 | UasAddress round-trips · ResidencyLease + UasKind landed · T1 review handshake closed |
| B.G.B2 | iter 31 | F-UAS-ZeroCopy-Spine harness lands with `#[test]` enforcement |
| B.G.B3 | iter 36 | AcsAnchor type + 4-stage round trip + drift gate |
| B.G.B4 | iter 43 | Shadow-first paging policy + harness · KL drift measured · T4 handshake API stable |
| B.G.B5 | iter 50 | Metal page-gather kernel + bandwidth gate PASS |
| B.G.B6 | iter 58 | Active assembly selector + harness · two-sided constraint PASS |
| B (full) | iter 80 | All 6 B.G.B steps landed; phase-close audit-of-audit · Phase C blueprint |

## §5. Risk + mitigation matrix

| Risk | Likelihood | Mitigation |
|---|---|---|
| T1 UasKind review delays past iter 30 | medium | initial enum has `Other(SmolStr)` escape hatch; harness is variant-set agnostic; T1 can add variants without breaking harness |
| F-PageGather-M2Pro fails 70% bandwidth target | medium-high | F-PageGather doc §6 has 5-tier fallback (threadgroup sweep · uint4 vector load · prefetch hints · CSR-style index reshape · STALLED); iter 48 reserved for fallback iteration |
| F-ULP-Oracle T7 oxieml API changes mid-Phase-B | low | F-ULP-Oracle doc references API surface; harness adapts via thin wrapper trait |
| Cargo baseline regression on a Phase B iter | medium | per-iter discipline runs cargo before commit; revert + investigate before next iter |
| Other terminal's commit accidentally lands in T3 worktree | very low | per [[feedback_parallel_terminal_needs_worktree]] worktrees are separate; per [[feedback_verify_commit_diff_after_concurrent_edits]] verify-after-commit catches it |

## §6. Discipline reinforcements (LOCK)

- **ONE slice per iter.** Phase B iters do NOT bundle multiple gates or multiple new files (except where
  obvious twin-files like `mod.rs` + the module's first file land together — that's still one slice).
- **Cargo baseline check every iter.** Before commit: `cargo test --manifest-path agent_core/Cargo.toml
  --lib` and confirm ≥ 1671 + new (count grows as harness tests land).
- **§5.0 reconciliation grep-verify every iter.** Doctrine claims must match grep'able code.
- **Push every 5-10 iters.** Iters 26, 35, 42, 49 are pre-planned push beats above.
- **COORDINATION: line in commit when crossing T-boundary** (per coord doc §8).
- **Verify commit diff post-commit** (per memory [[feedback_verify_commit_diff_after_concurrent_edits]]):
  `git show $SHA -- <file> | grep <signature>`.
- **Per `feedback_plan_is_authority`**: when doctrine and code disagree, fix code to match doctrine; never
  edit doctrine to match drift (unless doctrine itself is wrong, which surfaces as a §5.0 reconciliation-
  gate finding).

## §7. Cross-references

- Driver authority: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G Phase B mission steps (G.B1-B6).
- Falsifier doc set: `docs/falsifiers/F-*_2026_05_17.md` (11 §4.G ladder docs + F-ULP-Oracle W1).
- Coordination doc: `docs/audits/UAS_ACS_T_TERMINAL_COORDINATION_2026_05_17.md`.
- Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §5 register rows referenced
  per iter above.
- Substrate-floor audit: `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_2026_05_17.md` §C gap list (the source-of-
  truth for "what's missing").
- Morph deep-dive: `docs/audits/UAS_ACS_MORPH_DEEP_DIVE_2026_05_17.md` (Phase B iter 59-65 Morph + F-ULP-
  Oracle context).
