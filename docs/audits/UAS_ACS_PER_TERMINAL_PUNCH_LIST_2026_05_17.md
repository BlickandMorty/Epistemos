---
state: per-terminal-punch-list
created_on: 2026-05-17
terminal: T3 — UAS-ACS Canonical Architecture (handoff artifact)
branch: codex/t3-uasacs-2026-05-16
authority: T3 final handoff `docs/audits/UAS_ACS_FINAL_HANDOFF_2026_05_17.md` §5 + 5 audit-of-audit cycles.
purpose: Single per-terminal punch list for work T3 deferred. Use this AFTER merging the T-terminal branches to know what's left per terminal.
---

# UAS-ACS Per-Terminal Punch List — 2026-05-17

> Consolidates every deferred item from T3's 62-iter Phase A + Phase B work into **one punch list per
> terminal**, sorted by which T-terminal needs to do it after merge. This is the reference doc to read
> after `git merge` brings everything to `main` — for each terminal, the rows tell you what code is missing.

## §1. How to read this doc

Each section is one terminal (T1 … T8) + the Swift/Metal lane + Phase C cross-cutting.
For each row:
- **Item** — what's missing
- **Where** — file/path + iter or commit cross-link if applicable
- **Why** — what depends on it (downstream gate or feature)
- **Acceptance** — how to tell it's done

## §2. T1 — tri_fusion (Content fabric)

T3 produced types T1 needs to refine. T1 owns `agent_core/src/research/hyperdynamic_schemas/` adjacent +
tri_fusion proper.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **UasKind variant review** | `agent_core/src/uas/kind.rs` (lands at T3 iter 22 commit `0ac612c3b`) | T3 proposed 8 known + `Other(String)` escape; T1 may add/rename for tri-fusion content blocks. Overdue 32 iters past iter-30 cap. | T1 accepts the variant set OR proposes a merge resolution. Forward-compat already preserved via `Other(String)` + 0xFF wire sentinel in path-3 KV-metadata wire format. |
| **TriFusionBlock UasKind variant wire-up** | same | T3's `UasKind::TriFusionBlock` variant exists as a placeholder; T1 wires it to its actual tri-fusion content blocks | T1's content-fabric code emits `UasAddress { kind: UasKind::TriFusionBlock, ... }` |
| **MD ⇄ JSON ⇄ HTML deterministic schema** | T1's tri_fusion lane (T3 stays out per scope lock) | Driver §4.A Tri-Fusion content fabric mission | T1's deliverable; T3 only consumes via UasKind |

## §3. T2 — agent_runtime

T3 produced types T2 reads passively. T2 owns `agent_core/src/agent_runtime/`.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **UasAddress + AcsAnchor emission in agent_runtime traces** | `agent_core/src/agent_runtime/` (T3 doesn't edit) | T3's `UasKind::AgentTrace` variant exists; T2 emits traces tagged with that | T2's trace records carry `UasAddress { kind: UasKind::AgentTrace, ... }` |
| **WitnessedState ↔ UasStateWitness wiring** | `agent_core/src/scope_rex/witnessed_state.rs` (W1 SCOPE-Rex substrate) + `agent_core/src/uas/witness.rs` | T3 produced `UasStateWitness` trait (iter 25); T2 (or scope_rex-track) consumes by impl'ing it on `WitnessedState::record_uas_event` | T2 / scope_rex track's `WitnessedState` implements `UasStateWitness`; iter-25 integration test runs against production witness instead of `CollectingWitness` |

## §4. T4 — vault retrieval

T3 produced Shadow-paging substrate T4 consumes. T4 owns `agent_core/src/storage/vault.rs` + F-VaultRecall-50
(§4.H ladder gate #1).

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **Shadow-paging consumer wire-up** | `agent_core/src/storage/vault.rs` (T4 owns) consumes `agent_core/src/research/page_gather/{helios_page, sketch_topk, residual_rescore, escalation_policy}.rs` (T3 iters 43-46) | F-VaultRecall-50 needs the sketch → residual → exact escalation pattern | vault retrieval calls `EscalationPolicy::escalate(query_sketch, query_residual, corpus)` and uses the `EscalationVerdict` to decide read path |
| **F-VaultRecall-50 dataset + harness** | T4's lane (NOT T3 scope) | §4.H first user-facing AI fix; gates the whole UAS-ACS substrate's credibility | T4 produces `F_VAULT_RECALL_50_DIAGNOSIS_*.md` + harness; passes ≥ 95% recall on the 50-note ground-truth set |
| **Vault Context Contract enforcement** | T4 lane | Driver §4.H "Qwen listed only the first 7 vault notes and they were not relevant" must NEVER happen again | T4-side validation; provenance card visible in UI per §4.H acceptance |

## §5. T5 — EML-IR (six IR layer)

T3 coordinates as a consumer. T5 owns `agent_core/src/research/scan_ir/` + 5 sibling IR modules per
`project_terminal_t5_override_2026_05_17`.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **Scan-IR primitive types** | `agent_core/src/research/scan_ir/` (T5 lane; doesn't exist on T3 branch) | T3's F-SemiseparableBlockScan harness (iter 53 `19965e65`) uses `helios/ssd_block_scan.rs` as de-facto Scan-IR; promote to formal types | T3-side iter-53 test refactors to consume `ScanIR::SemiseparableBlock { ... }` from T5's lane |
| **Six IR layer landing** | T5 worktree `/Users/jojo/Downloads/Epistemos-t5-emlir` (codex/t5-emlir-2026-05-16) | Driver §4.I EML-IR Primitive Stack — kernel-grade IR family | T5 publishes 6 IR types; agent_core consumes via merge |
| **oxieml::EmlTree TYPE definition (vs eval_real RUNTIME — T7)** | T5 lane (per coord doc §5 iter-57 boundary clarification) | F-ULP-Oracle harness needs `EmlTree` type to call `eval_real(point)` against | T5 publishes `pub struct EmlTree { ... }` + serde |

## §6. T6 — UI

T3 stays out of UI per scope lock. T6 owns UI surfacing of T3's substrate types.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **AnswerPacket / SCOPE-Rex badge surface in chat UI** | `Epistemos/Views/Halo/` + chat-row Swift code (T6 lane) | T3's `agent_core::scope_rex::answer_packet::AnswerPacket` already emits; T6 renders | per-emission badge visible in chat row per §4.G acceptance "user-facing surfaces" tier |
| **ResidencyTier indicator** | UI surface for Current App vs Verified Floor vs Capability Ceiling | T3 LOCKed the §4.G three tiers (iter 23); T6 surfaces them when a feature is research-tier vs ship-claimed | UI shows the tier for any UAS-tagged artifact |
| **Cognitive DAG visualization (Phase 8.E+)** | `Epistemos/Views/Graph/` (T6 lane) | T3's `agent_core::cognitive_dag` substrate already lands; T6 visualizes | DAG nodes + edges rendered with resonance walks |

## §7. T7 — EML integration runtime + F-ULP-Oracle reference

T3 consumes T7's oracle reference. T7 owns runtime-layer EML integration per
`project_terminal_t7_override_2026_05_17`.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **oxieml::EmlTree::eval_real runtime evaluator** | `agent_core/src/research/eml/ulp_oracle.rs` (T7 lane; T3 stays read-only) | T3's F-ULP-Oracle gate (W1 falsifier doc landed iter 15 `e432b54f`) needs this as the fp64 reference for the Metal kernel | T7 publishes `fn eval_real(point: f64) -> f64`; T3 wires it into the harness |
| **§4.B runtime-layer EML integration** | T7 worktree `/Users/jojo/Downloads/Epistemos-t7-eml` (codex/t7-eml-2026-05-16) | Driver §4.B Deep EML integration | T7 deliverable; runtime piping for EML expressions into AnswerPacket emission |
| **Morph DSL evaluator kernel `Epistemos/Shaders/morph_eval_reduced.metal v0.1`** | Swift-side under T7 / shared territory | Per V6.1 foundation intake — Morph kernel gated by F-ULP-Oracle. Resolved iter 14 Morph deep-dive (`08137d05`). | Metal kernel lands; F-ULP-Oracle harness can run; max ULP ≤ 2 fp16 in [0.5, 2.0] over 412k+2k points in ≤ 90 s |

## §8. T8 — biometric (no current T3 touch)

T3 doesn't interact with biometric per scope lock. T8 owns §4.D biometric privacy + lockable surfaces.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| (no T3-deferred items for T8) | — | T8's §4.D is deferred until §4.A/§4.B/§4.C land per driver §4.D | T8 deliverable independent of T3 |

## §9. Swift / Metal lane (cross-terminal — affects T6 + T7 + scope_rex track)

The Swift-side Metal kernel work blocks several T3 gates from reaching production-PASS. This is its own
work track.

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **`Epistemos/Shaders/PageGather.metal` v2 (production)** | currently a stub per `agent_core/src/helios/page_gather.rs` line 16 doc | F-PageGather-M2Pro gate #5 — Metal kernel must reach ≥ 70% of MEASURED M2 Pro STREAM at 256/512/1024 MB | Swift `XCTest` at `EpistemosTests/HeliosPageGatherBandwidthTests.swift` passes per F-PageGather falsifier §3 |
| **`Epistemos/Shaders/PacketRouter1bit.metal`** | currently a stub | F-PacketRouter1bit gate #10 production-PASS — Metal p99 < 100 µs | Swift integration test verifies Metal kernel matches T3's `helios::route_1bit` CPU ref bit-for-bit + meets latency budget |
| **`Epistemos/Shaders/ControllerKernelPack.metal`** | not yet | F-ControllerKernelPack #11 production-PASS — Metal p99 < 50 µs per kernel | per-kernel Metal correctness vs CPU ref + sequence wall-clock |
| **`Epistemos/Shaders/SemiseparableBlockScan.metal`** | not yet | F-SemiseparableBlockScan #8 production Track A | Metal kernel matches `helios::ssd_block_scan_scalar` + `ssd_minimal.py` reference within 1e-3 fp16 over 100 seeds |
| **`Epistemos/Shaders/LocalRecallIsland.metal`** | not yet | F-LocalRecallIsland #9 production — 32K Core | Metal kernel + live model integration |
| **`Epistemos/Shaders/morph_eval_reduced.metal v0.1`** | not yet — Morph DSL evaluator | F-ULP-Oracle W1 gate (see §7 T7 row) | per F-ULP-Oracle falsifier doc spec |
| **IOSurface integration for UMA-shared buffers** | Swift Metal driver lane | F-UAS-ZeroCopy-Spine path 6 (page-gather scatter 256/512/1024 MB) | Caller-allocated IOSurface buffers carry 256-1024 MB working sets without copy |

## §10. Phase C cross-cutting (T3 work, but needs external substrate first)

These are T3-owned but blocked on Swift/Metal landing OR live model integration. Phase C territory
(blueprint iter 80+).

| Item | Where | Why | Acceptance |
|---|---|---|---|
| **F-KV-Direct-Gate harness** | `EpistemosIntegrationTests/KVDirectColdSpillTests.swift` (Swift-side) + agent_core wiring | §4.G ladder gate #7 | Qwen 3 8B at 128k context · peak RAM < 13 GB · D_KL/token < 0.08 · decode ≥ 10 tok/s on M2 Pro 16 GB |
| **F-SemiseparableBlockScan Track B (live model)** | Swift integration test driving Mamba-2 2.8B + Qwen 3 8B side-by-side at 32k | §4.G ladder gate #8 production | Mamba-2 within 0.10 weighted-score of Qwen on RULER+BABILong; throughput ratio ≥ 2.0× |
| **F-70B-Cocktail-Composition harness** | `agent_core/tests/cocktail_composition_study.rs` (research-only) + Swift live-model side | §4.G ladder gate #12 (ceiling falsifier) | Synthetic substrate-floor + live 7-component composition; identifies primary bottleneck |
| **ClaimLedger ↔ AcsAnchor production integration** | `agent_core/src/provenance/ledger.rs::ClaimLedger` accepts typed `AcsAnchor` field | F-ACS-Anchor-Addressing production-PASS (T3 substrate-floor PASS at iter 29 `0368d76b`) | Stage 3 audit canonicalization goes through real ClaimLedger; iter-29 harness swaps JSON-as-canonicalization for ReplayBundle |
| **ClaimLedger snapshot ≤ 1 alloc refactor** | `agent_core/src/provenance/ledger.rs::ClaimLedger::snapshot()` | F-UAS-ZeroCopy path 5 production target (T3 iter 41 substrate-floor PASS ≤ 100 alloc; falsifier-spec aspirational ≤ 1 alloc) | snapshot allocates ≤ 1 Vec via arena/SmallVec refactor |

## §11. Optional substrate harnesses (no gate dependency)

T3 could have written but didn't — these are research-tier substrate coverage that's not on the §4.G critical
path. Skip if other priorities are higher.

| Item | Where | Why optional |
|---|---|---|
| **Wave J3 continual_learning substrate harness** | `agent_core/tests/continual_learning_*.rs` | Not in §4.G ladder; research-tier (Capability Ceiling). Pattern matches J1 ternary (iter 58) + J7 sherry (iter 59). |
| **Wave J2 kv_implant / weight_patcher / glass_pipe / pipeline harnesses** | `agent_core/tests/cognition_observatory_*.rs` | Iter 61 covered SAE (the doctrine §3.36 AUC 0.90 gated module). Other 4 modules are research-tier without gates. |
| **Wave J6 hyperdynamic_schemas diff.rs harness** | `agent_core/tests/hyperdynamic_schema_diff.rs` | Iter 62 covered repair.rs; diff.rs (SchemaChange + SchemaDiff + diff_schemas) is a future iter candidate. |
| **F-UAS-ZeroCopy path 6 substrate-floor** | `agent_core/tests/uas_zero_copy_spine_path_6_page_gather.rs` | Subsumed by #5 F-PageGather-M2Pro. CPU twin at iter 54 covers the scatter shape; Metal scatter is the real gate. |

## §12. Pre-merge sanity check

Before merging T3's `codex/t3-uasacs-2026-05-16` to `main`:

1. **Run cargo on a clean checkout to confirm baseline**:
   ```bash
   git checkout codex/t3-uasacs-2026-05-16
   cargo test --manifest-path agent_core/Cargo.toml --lib  # expect ≥ 1709
   cargo test --manifest-path agent_core/Cargo.toml --lib --features research  # expect ≥ 3567
   ```
2. **Check integration tests** (some need `--features research`):
   ```bash
   for t in agent_core/tests/*.rs; do
     name=$(basename "$t" .rs)
     cargo test --manifest-path agent_core/Cargo.toml --test "$name" --features research 2>&1 | grep "test result"
   done
   ```
3. **Verify the 5 audit-of-audit docs are consistent** with current state — read them in order:
   `iter_19` → `iter_30` → `iter_40` → `iter_50` → `iter_60`. Each one should be additive; none should
   contradict a prior.
4. **Confirm `agent_core/src/lib.rs` has `pub mod uas;`** (T3 added at line 72; merge conflicts here are
   the most likely surface).

## §13. Cross-references

- **Final handoff**: `docs/audits/UAS_ACS_FINAL_HANDOFF_2026_05_17.md` (§5 deferral table — this doc
  reorganizes those rows by terminal)
- **Coord doc**: `docs/audits/UAS_ACS_T_TERMINAL_COORDINATION_2026_05_17.md` (handshake protocol details)
- **5 audit-of-audit docs**: iters 19, 30, 40, 50, 60
- **Canonical doctrine**: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md` §5 register (every
  concept reconciled) + §6 MASTER_FUSION §3.x cross-link (full 41-row coverage)
- **Driver authority**: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G hierarchy + 3 residency
  tiers + 12-gate falsifier ladder

When in doubt about a deferred item's full context, the iter-specific commit message has the most detail
(`git log --oneline main..HEAD` then `git show <sha>`).
