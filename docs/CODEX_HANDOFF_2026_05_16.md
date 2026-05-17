# Codex Handoff — Current State of Epistemos (2026-05-16)

**For**: Codex (or any AI agent picking up Epistemos cold)
**Author**: Claude Opus 4.7 (1M context), closing out a multi-day 7-terminal session
**main tip at hand-off**: `988de854f merge(B): run-b-post-v1-research → main (V6.1 substrate + Wave I A2UI catalog 24/24 + research-tier)`

---

## TL;DR — what just happened

Over multiple days, **7 parallel autonomous loops** (Terminals A/B/C/D/E/F + a maintenance loop on `codex/research-snapshot-2026-05-08`) ran simultaneously across 7 git worktrees doing different parts of the post-V1 work. All 6 active terminals were stopped tonight (2026-05-16) via a coordinated STOP directive. **All 6 branches successfully merged into `main`** with full audit. **`lane-A` was NOT merged** (its 601-commit content was already salvaged into main 3 weeks ago).

Result: **+477 cargo lib tests** on main (1194 → 1671) + substantial new research substrate + per-feature decision research + integration artifacts.

---

## Architecture inventory — what's where on main RIGHT NOW

### 1. `agent_core/src/research/` — V6.1 + Wave I + Wave J substrate (NEW from B's merge)

| Module | LOC | What it is |
|---|---|---|
| **`a2ui/`** | 5,452 | **25 A2UI components** with schemars schemas + Swift mirrors + Validator tests (accordion · alert · breadcrumbs · capability_chip · carousel · chart · citation_block · code_block · confidence_badge · diff · key_value_grid · markdown · modal · navigation_rail · pagination · progress_bar · provenance_trace · quote · table · table_of_contents · tabs · toast · tool_call_trace · tooltip) |
| **`acs/`** | 2,660 | **ACS (Anchored Cognitive Substrate)** — `autopoiesis.rs` (18 KB) + `governance.rs` (18 KB, VSM recursive) + **`kuramoto.rs` (21 KB — real Kuramoto oscillator implementation)** + mod.rs. This is the J5 portfolio: Kuramoto + Notch-Delta + autopoiesis + VSM all in code. |
| **`ternary/`** | 3,385 | **J1 ternary substrate** — 11 files: pack · gemv · residual_island · fused_rmsnorm · kv_fingerprint · activation_tap · steering · trit · backend · kernel_kind. Decode-first kernel portfolio. |
| **`continual_learning/`** | 3,476 | **J3 portfolio** — SEAL-DoRA + OFTv2 + DSC + Titans-MAC + Never Retrain |
| **`cognition_observatory/`** | 2,358 | **Wave J2 + B2-H11** — SAE Cognition Observatory (AUC ≥ 0.90 hallucination detection target) |
| **`sherry_lattice/`** | 1,582 | **J7** — Sherry 1.25-bit + E8/Leech lattice VQ. `codebook.rs` + `leech.rs` + `sparse_ternary.rs` |
| **`paper_registry/`** | 1,369 | **J9** — paper-claim registry (research citations + verification gates) |
| **`eml/`** | 1,232 | **EML expression library** — W1 floor work, F-ULP-Oracle base substrate |
| **`hyperdynamic_schemas/`** | 1,141 | **J5 Meta-Schemas** that repair themselves |
| **`ane_direct/`** | 865 | **J8** — Apple Neural Engine direct access scaffolding |

Plus single-file modules: `attention_sinks.rs`, `belnap.rs` (K3 Belnap 4-valued logic), `biometric_gate.rs`, `brain_routing.rs`, `compute_steering.rs`, `confidence_floors.rs`, `hybrid_memory.rs`, `interrupt_calibration.rs` (V6.1), `koopman.rs` (B.6 Koopman lift + Bauer-Fike), `mamba3.rs`, `nano_training_recipe.rs`, `nightbrain_tasks.rs`, `para_lens.rs`, `run_ledger.rs`, `rwkv7.rs` (RWKV-7 Goose), `substrate_independence.rs`, `test_time_regression.rs`, `tropical.rs`.

**Activation status**: `pub mod research;` is registered at `agent_core/src/lib.rs:45`, feature-gated via `research = []` in `agent_core/Cargo.toml:22`. Each module is buildable + tested.

### 2. ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack) — DUAL SURFACE

- **Doctrine spine**: `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md §3.8` — 11-facet table with naming-drift disambiguation
- **Lane 3 research-only substrate**: `epistemos-research/src/acs.rs` (6.2 KB) — `AcsAnchor` + `CmsXField` + `ACS_CANONICAL_PLANE = RuntimePlane::Episodic`. **Never ships in MAS per file:17 header.**
- **agent_core research substrate (NEW)**: `agent_core/src/research/acs/` — 2,660 LOC across autopoiesis + governance + kuramoto + mod. This IS the J5 ACS implementation.
- **Integration artifact**: `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` (16 KB, 10 sections) pulls all UAS-ACS surfaces into one register.

### 3. Kuramoto coupling — IMPLEMENTED

- **File**: `agent_core/src/research/acs/kuramoto.rs` (20,947 bytes ≈ 600+ LOC)
- **Status**: J5 #1 doctrine-substantiation per Terminal C's audit pulses. Includes `critical_coupling_kc` + `run_until_sync` + bimodality_score-substantiated pattern-formation diagnostics.
- **Doctrine**: MASTER_FUSION §3.8 row notes "red-team prefers discrete-time Kuramoto + gossip" — that's the active production path.

### 4. Ternary core (BitNet-class) — J1 PORTFOLIO COMPLETE

- **Crate**: `agent_core/src/research/ternary/` (3,385 LOC, 11 files)
- **Components**: pack (allocation-free helpers) · gemv (GemvBlock diagnostics) · residual_island (sparsity diagnostics) · fused_rmsnorm (RMS diagnostics) · kv_fingerprint (routing-layer diagnostics) · activation_tap (query helpers) · steering (steering-stack diagnostics) · trit · backend · kernel_kind
- **Plus B.6.17**: cross-backend agreement checker (substrate independence)

### 5. Unified Active Substrate (UAS) — INTEGRATION DOC

- **Doc**: `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` (16 KB, 10 sections):
  1. One-paragraph definition
  2. The 6 canonical surfaces (Rust ACS substrate · 5-plane formalism · KV-Direct gate · MASTER_FUSION §3.8 · HELIOS V6.1 substrate · V6.2 falsifier order)
  3. Naming-drift disambiguation (mandatory PR-discipline)
  4. No-loss cross-link map
  5. V1/V1.x/V2/never-ships sort (13 facets)
  6. Status-transition log (append-only)
  7. 5 UAS-ACS-specific PR-discipline rules
  8. 4 open user-decision-gated questions
  9. Cross-references
  10. Anti-scope-creep guardrail

### 6. Capability lattice (Macaroon-based)

- **File**: `agent_core/src/cognitive_dag/macaroons.rs` — 930 LOC SHIPPED. HMAC-chained Macaroon + 4 Caveat variants (ScopePrefix · ExpiryAfter · ToolNameEq · AdditionalContext) + issue/restrict/delegate/revoke. Phase 8.B resonance-revocation cascade integration.
- **Forward-staged**: `Caveat::OneShot` variant for B2-H20 ephemeral capability tokens (NOT-STARTED).

### 7. Recursive audit register

- **PASS-2 §9 audit-of-audit register**: **55 cycles** (up from 8 at start of this session).
- **Pattern**: every ~10 loop iters, a parallel audit verifies recent commits via independent grep + code-citation checks.
- **Lessons banked**: 7 trust-but-verify lessons including "re-grep at audit time, don't trust the doctrine's own grep claim" (lesson #6 from iter-74) and "row-count-only verification is insufficient — read hit context" (lesson #7 from iter-80).
- **Drift catch (real)**: Terminal C's iter-74 AoA #8 caught `agent_core/src/heal/` directory EXISTS (3 files, 463 LOC) despite B2-L1 doctrine claiming ABSENT. Also `CircuitBreaker` SHIPPED at 306 LOC despite B2-M9 claiming NOT-STARTED. **These are documented but not yet reconciled in doctrine.**

### 8. Backlog state

- **`MASTER_FUSION_NO_COMPROMISE_2026_05_13.md §3.x` Atlas rows**: **43** doctrine rows covering every named concept (Pillars · Six-tier memory · KV-Direct · SCOPE-Rex · Resonance/Sovereign Gates · Variant ladder · ACS · Halo/Shadow/Eidos · Cognitive DAG · GenUI · Live File Compiler · Honest Handle FFI · Helios kernels · AnswerPacket · Provenance ledger · XPC Mastery · NeMoCLAW · Ternary · Continual learning · Skill/procedural memory · NightBrain · A2UI · KV implantation · Simulation · Hermes positioning · Quick Capture · Vault doctrine · UI/UX/Brand · Code-side hardening · Artifact Identity · Instant Recall · Golden-ratio scheduling · SAE Cognition Observatory · N1 Prompt Tree · Graph Engine · Adaptation+Compute Steering · Nano Training Recipe · DP on Auto-Research · Run Ledger · `epistemos-code-index` · Plus 3.40 anomaly)
- **`MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md §8 Implementation Log**: **302 dated rows** from 2026-05-14 through 2026-05-16.

### 9. Per-feature decision research (E's deliverable)

13 user-decision research docs at `docs/audits/user-decisions/`:
1. `B-1-live-files.md` — Wave 7 Live Files substrate primitive
2. `B-2-obscura-browser.md` — Obscura browser engine (Pro-tier deno_core sandbox)
3. `B-3-undo-backbone.md` — V1.1 Reversal/Undo scope
4. `B-4-nousresearch-svg-art.md` — Hermes brand art (licensing-gated)
5. `B2-H16-chatterbox-tts.md` — Chatterbox conversational TTS (Pro-tier)
6. `B2-M5-hardware-budget.md` — HardwareProfile budget (9.6 vs 10.5 GB)
7. `H-1-startup-hang-time-profiler.md` — ISSUE-2026-05-12-011 startup hang
8. `H-2-idle-memory-allocations.md` — ISSUE-2026-04-21-004 idle memory regression
9. `H-3-B2-H6-editpage-macaroon.md` — Local Engineering Agent edit_note_block capability
10. `L-2-v6-2-per-bubble-vrm-binding.md` — V6.2 per-bubble VRMLabelView FULL binding
11. `L-3-graph-toolbar-cursor-shape.md` — Graph Toolbar Cursor Force + Shape Bound buttons
12. `RCA13-P0-001-vault-smoke.md` — Vault lifecycle smoke test design
13. `orphan-hermes-salvage-001-disposition.md` — 3 orphan Hermes salvage modules (wire/scaffold/delete)

**Status**: each doc carries options A/B/C/etc. with tradeoffs + recommendation. **Awaiting user signoff to advance any of them.** Cannot auto-implement.

### 10. Integration artifacts (the 3-artifact trio)

Per the 4-advisor synthesis earlier in the session:

1. **`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md`** — UAS-ACS coherence layer (no-loss register)
2. **`docs/fusion/V1_SHIP_LEDGER_2026_05_16.md`** — flat-view classification: every feature → v1/v1.1/v2/never. ~85 feature rows.
3. **`docs/fusion/DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md`** — concrete user scenario walking through every V1-shipped surface in narrative form.

### 11. Acceptance proofs (B's final-task)

- **`docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md`** — wave-by-wave acceptance evidence with claimed acceptance bar + asserting test + cargo invocation + primary source citation per shipped wave.

### 12. Terminal handoff snapshot (C's final-task)

- **`docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md`** — merge-readiness verdict per terminal, expected conflict surface, recommended merge order.

### 13. Ambient Frequencies feature (NEW user feature)

User-implemented + Claude-expanded substantial new feature:

- **`Epistemos/Engine/AmbientFrequencyAudioGenerator.swift`** (2,443 LOC) — offline 32-bit float WAV synthesis
- **`Epistemos/Engine/AmbientFrequencyLivePlayer.swift`** (384 LOC) — real-time AVAudioEngine + AVAudioSourceNode synthesis
- **`Epistemos/Views/Settings/AmbientFrequencySettingsView.swift`** (495 LOC) — Settings UI
- **39 presets** across 5 categories (Focus · Sleep · Nature · Retro · Meditative)
- **15 synthesis primitives** including 9 stateless DSP techniques + bit-crush + sample-rate-reduce + OPL2 FM
- **25 stackable sound modules** (noise color · nature · rhythmic · texture · drone · retro)
- **W3C equal-power stereo pan** + per-layer panning via indirect `.panned` wrapper
- **Pixel Crunch UI** with PixelCrunchBadge (Canvas-rendered 8×8 sprite)
- **8 retro-era presets**: Atari 2600 · NES Classic · C64 Commando Loader · Game Boy DMG · Amiga Tracker · AdLib OPL2 · MS-DOS PC Speaker · Sega Genesis YM2612

### 14. F-VaultRecall-50 fix (the advisor-named load-bearing bug)

- **Diagnosis**: `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` — bug isolated at `agent_core/src/storage/vault.rs:495-548`. Three converging defects: implicit-OR conjunction + no stop-word filter + score clamp.
- **Fix B SHIPPED**: stop-word filter + AND-for-short-queries + `QUERY_CHATTER_WORDS` const + `strip_query_chatter` helper. Cargo 1190 → 1194 (+4 new tests).
- **Defect 3 deferred**: score clamp `[0,1]` left as V1.x — floor system degraded but functional.

### 15. Autonomy hardening (the 6-terminal infrastructure)

- **4 critical fixes** to terminal prompts A/B/D/E (C+F already GREEN per audit):
  - Terminal A Phase E.1 explicit pass-counter state machine
  - Terminal B B.0.4 retry budget + degraded-mode fallback
  - Terminal B/D SCHEMA_GATE_STATUS handoff file (canonical state-string)
  - Terminal E eternal-self-audit guard with WAITING-FOR-USER signal
- **Supporting docs**:
  - `docs/SCHEMA_GATE_STATUS_2026_05_16.md` — canonical B↔D handoff state file
  - `docs/LOCAL_MODEL_STACK_RESEARCH_2026_05_16.md` — comprehensive local-LLM stack recommendation (Qwen3.5-9B primary + 4 specialist branches, Apache 2.0 throughout)

### 16. Pro-gated channel workers (F's deliverable)

NEW binaries under `agent_core/src/bin/`:
- `epistemos_channel_worker_discord.rs`
- `epistemos_channel_worker_email.rs`
- `epistemos_channel_worker_signal.rs`
- `epistemos_channel_worker_slack.rs`
- `epistemos_channel_worker_telegram.rs`
- `epistemos_channel_worker_whatsapp.rs`

Plus `agent_core/src/channels/` module (worker.rs 741 LOC + mod.rs). All `#[cfg(feature = "pro-build")]`-gated. MAS build excludes them at compile time.

### 17. MCP hardening (D's deliverable)

- **D.1.1**: authenticated URL MCP servers — `agent_core/src/providers/claude.rs` patched for proper Authorization header forwarding
- **D.1.2**: stdio MCP request wait bound at 30s — prevents indefinite hang
- **Plus**: Anthropic MCP connector beta flag wiring
- **Plus**: Git MCP hardening samples in self-audit log

---

## What the multi-terminal effort accomplished (big picture)

Over multiple days the 7 parallel terminals delivered:

- **+477 new cargo lib tests** on main (1194 → 1671)
- **+264 feature-gated tests** (1671 → 1935 with `--all-features`)
- **~30,000+ LOC of new research substrate** under `agent_core/src/research/`
- **39 ambient-frequency presets** + real-time live player + pixel-crunch UI
- **3 integration artifacts** that connect scattered substrate into coherent layers
- **13 user-decision research docs** with options + tradeoffs + recommendations
- **55 audit-of-audit cycles** in PASS-2 §9 register catching real drift
- **302 §8 Implementation Log rows** documenting every change with full trace
- **F-VaultRecall-50 fix** — the advisor-named load-bearing bug, patched + tested
- **Pro-gated channel workers** for 6 messaging platforms (compile-time excluded from MAS)
- **MCP hardening** for both URL + stdio transports

---

## Open user-decisions (you must answer to advance)

Read each research doc at `docs/audits/user-decisions/` and pick:

1. **B-1 Live Files** — V1 stub vs V1.1 defer (recommended) vs V1.1+V2 split
2. **B-2 Obscura browser** — V1 placeholder vs V1.1 defer (recommended) vs V2 Pro-only
3. **B-3 Confidence Meter** — V1 SIMPLE + V1.1 FULL (recommended) vs V1 full vs V1.1 defer
4. **B-3 Undo backbone** — Confidence-Meter re-learn (a) vs per-edit Undo (b) vs both (c)
5. **B-4 Pixel/Tactical** — V1.1 defer (recommended) vs V1 full toggle
6. **B-4 NousResearch SVG** — licensing-gated; commission alt vs license vs skip
7. **B2-H16 Chatterbox TTS** — V1 Pro vs V1.x Pro vs post-V1 Pro
8. **B2-M5 HardwareProfile** — V1 keep 9.6 GB divergence vs V1.x align to 10.5 GB
9. **H-3/B2-H6 EditPage macaroon** — V1.1 defer (recommended) vs V1 read-only attach
10. **H-1 Startup hang** — Instruments profiling needed from your machine
11. **H-2 Idle memory regression** — Instruments profiling needed
12. **L-2 V6.2 per-bubble binding** — Option A side-table sink vs Option B `packetId` through `AgentStreamEvent` (recommended)
13. **L-3 Graph Toolbar** — 1 PR vs 2 PR + hexagon/star approved vs deferred
14. **RCA13-P0-001 vault smoke** — design pending direction
15. **ORPHAN-HERMES-SALVAGE-001** — wire vs scaffold vs delete the 3 salvage modules

---

## Open product bugs / concerns

1. **F-VaultRecall-50 defect 3 (score clamp)** — V1.x scope; doesn't break Fix B but means floor system is degraded
2. **Drift findings from C's audit** — `agent_core/src/heal/` (3 files, 463 LOC) shipped but doctrine claims NOT-STARTED; `CircuitBreaker` shipped (306 LOC) but B2-M9 doctrine claims NOT-STARTED. **Doctrine needs reconciliation.**
3. **Helios kernels target-only** — PageGather · SemiseparableBlockScan · LocalRecallIsland · ControllerKernelPack · PacketRouter1bit remain `KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here"` per V6.1
4. **B.0 F-ULP-Oracle** — 412k log-sampled fixture not yet gated against ≤2 ULP fp16 tolerance (separate slice)
5. **Lane-A in-flight edit** discarded — its `startedAt` countdown fix is already solved better on main via `TimelineView` + `approval.issuedAt` anchor

---

## Recommended next steps (in priority order)

1. **Run final `xcodebuild test` on merged main** (Swift side hasn't been fully verified after all merges)
2. **Read the 3 integration artifacts** (UAS-ACS Canon · V1 Ship Ledger · Day-in-the-Life) to orient
3. **Read C's TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md** for full per-terminal verdict
4. **Read B's ACCEPTANCE_PROOFS_V6_1_2026_05_16.md** for wave-by-wave proof of what shipped
5. **Pick 2-3 of the 13 open user-decisions to answer** so V1.x work can start
6. **Address the heal/CircuitBreaker doctrine drift** (3 files in main + doctrine claims absent — fix the doctrine, not the code)
7. **Manual MAS submission** if V1 ship gates are met (see V1_SHIP_LEDGER §0 ship criteria)

---

## Cross-references

- **Doctrine spine**: `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` (43 §3.x rows)
- **Ship plan**: `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` (302 §8 rows · §10 Compromises Recorded)
- **Gap audits**: `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md` (PASS-1) · `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` (PASS-2 + §9 audit-of-audit register with 55 cycles)
- **Session handoff**: `docs/NEW_SESSION_HANDOFF_2026_05_15.md`
- **Integration artifacts**: `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` + `V1_SHIP_LEDGER_2026_05_16.md` + `DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md`
- **Terminal handoff snapshot**: `docs/TERMINAL_HANDOFF_SNAPSHOT_2026_05_16.md` (C's final-task)
- **Acceptance proofs**: `docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md` (B's final-task)
- **User-decision research**: `docs/audits/user-decisions/` (13 docs from E)
- **Codex stop prompts** (historical): `docs/CODEX_STOP_PROMPTS_2026_05_16.md`

---

## Branch state at hand-off

| Branch | Status | Action |
|---|---|---|
| **main** | `988de854f` (all 6 terminal branches merged) — **canonical** | Use for new work |
| `codex/research-snapshot-2026-05-08` | User's build worktree at `f6e7f5c37` — UNTOUCHED throughout merges | Stays as build branch; user can `git pull` to bring main's new state in when ready |
| `run-b-post-v1-research` | Merged | Safe to archive or delete |
| `run-c-audit` | Merged | Safe to archive or delete |
| `run-d-providers` | Merged | Safe to archive or delete |
| `run-e-decisions` | Merged | Safe to archive or delete |
| `run-f-integrations` | Merged | Safe to archive or delete |
| `lane-A` | 3-week-old stale — content already on main via "Final salvage" commit | **Archive only; never merge** |

---

## File-system layout (for orientation)

```
/Users/jojo/Downloads/Epistemos/                   ← USER's build worktree (codex/research-snapshot-2026-05-08)
/Users/jojo/Downloads/Epistemos-main-merge/        ← Scratch worktree used for merges (can delete)
/Users/jojo/Downloads/Epistemos-laneA/             ← lane-A worktree (stale, archive-only)
/Users/jojo/Downloads/Epistemos-runB/              ← B's worktree (merged; safe to remove)
/Users/jojo/Downloads/Epistemos-runC/              ← C's worktree (merged; safe to remove)
/Users/jojo/Downloads/Epistemos-runD/              ← D's worktree (merged; safe to remove)
/Users/jojo/Downloads/Epistemos-runE/              ← E's worktree (merged; safe to remove)
/Users/jojo/Downloads/Epistemos-runF/              ← F's worktree (merged; safe to remove)
```

---

## When picking this up (Codex or any agent)

1. `git -C /Users/jojo/Downloads/Epistemos-main-merge fetch origin main && git merge --ff-only origin/main` — get latest main
2. `cargo test --manifest-path agent_core/Cargo.toml --lib` — verify 1671 passes
3. `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` — verify Swift builds
4. Read this doc + the 3 integration artifacts
5. Pick a user-decision row from §11 and either (a) ask user to answer or (b) implement an unblocked V1.x slice

---

*— End of CODEX_HANDOFF. Multi-day 7-terminal effort closed cleanly. main has +477 tests and ~30K LOC of new research substrate. User's build worktree at `codex/research-snapshot-2026-05-08` was untouched throughout merge orchestration. All 13 user-decisions await your answers.*
