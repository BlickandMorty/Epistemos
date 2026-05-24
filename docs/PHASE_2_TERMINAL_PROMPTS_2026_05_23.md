# Phase 2 — 6 Terminal Prompts (2026-05-23)

Six parallel Codex/Claude terminals to drive the W-row backlog (currently ~6/53 wired, ~11%) up toward 50%+ Phase-2 closure. Each terminal is self-contained — minimal cross-surface conflict between them.

**Authority bar (every terminal):** No fake successes. No hidden cloud fallback. WRV (Wired/Reachable/Visible/Verified) discipline. Universal Loop Block: Audit → Build → Verify → Harden → Report. Use chip-strip + honest language pattern from PR #57. Reference `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` + `docs/CANONICAL_CHRONICLE_2026_05_23.md` before any code.

---

## Terminal A — Eidos Real Vault Binding (P1 + W-46/W-47)

**Goal:** Land `Epistemos/Eidos/EidosBridge.swift` so Brain Panel + ChatCoordinator can call `Eidos.retrieve(query)` without bypassing the closed-citation contract. Eidos retrieves from REAL vault, not fixture.

**Substrate already in main:**
- `agent_core/src/eidos/*` — 217 Rust tests green
- `Epistemos/Eidos/Eidos.swift` — Swift mirror types declared
- Cross-language parity JSON fixture pinned

**To wire:**
1. `Epistemos/Eidos/EidosBridge.swift` (NEW) — `@_silgen_name` bindings to `eidos_retrieve_json` + `eidos_validate_citation_json` + `eidos_free_string`
2. `agent_core/src/bridge.rs` — add the 3 FFI entries
3. `Epistemos/App/ChatCoordinator.swift` — run every emitted source_id list through `eidosValidateCitations(...)` before commit (W-47)
4. Replace `EidosHealthRow`'s "fixture path active" chip with "production vault binding active" when bridge succeeds
5. Update `docs/audits/EIDOS_PRODUCTION_BINDING_<date>.md` audit doc per WRV discipline

**Acceptance:**
- `cargo test --lib eidos::` still green (217 tests)
- `swift test` covers a real-vault round-trip (insert note → retrieve → validate citation → expect ok; insert forged citation → reject)
- `EidosHealthRow` chip strip flips orange→green when bridge active
- `docs/falsifiers/F-Eidos-Bridge-RoundTrip_<date>.md` PASS

**Loop discipline:** This terminal MUST also pull T4's `F_VaultRecall_50_*` Swift tests from `codex/t4-vault-2026-05-16` since they exercise the same retrieval path.

---

## Terminal B — Vault Recall Real Backend Trace + Chat Citation Surface (P2 + P3 + W-19/20/21/27)

**Goal:** Every chat answer surfaces WHY the vault notes were chosen + the per-row claim_kind + confidence badge.

**Substrate already in main:**
- `Epistemos/Sync/RRFFusionQuery.swift` — full RRF impl
- `Epistemos/Sync/SearchIndexService.swift` — fusedSearch API
- `EventStore.swift` — RunEventLog event store
- `AnswerPacketEmitter` — emits per-message AnswerPackets

**To wire:**
1. `ChatCoordinator.swift` — emit `RunEventLog.append(VaultRecallTrace{...})` for every retrieval; surface trace in chat row UI
2. `Epistemos/Views/Notes/NoteChatSidebar.swift` already has provenance cards — extend pattern to `ChatInputBar` autocomplete + `HaloShadowPanel` (W-20)
3. New `Epistemos/Views/Chat/AnswerPacketBadge.swift` — per-row badge: claim_kind (synthesis/empirical/mathematical/causal/speculative) + confidence (verified/plausible/speculative/blocked) — W-27
4. `VaultRecallHealthRow` chip-strip update: 4 metrics (top-1 exact-title %, top-5 paraphrase %, synthesis 2-note citation %, adversarial reject %) per W-21
5. Audit doc `docs/audits/VAULT_RECALL_VISIBILITY_<date>.md`

**Acceptance:**
- F-VaultRecall-50 ≥ 95% top-1 exact-title hit rate measured on M2 Pro
- 0 chat answers ship without a visible provenance card
- AnswerPacketBadge renders on every chat row
- ChatCoordinator never builds context with `LIMIT N` from index order (rg gate enforced)

---

## Terminal C — System G Full Path (P5)

**Goal:** Replace `StubSystemGRunSeam` (currently throws `notWired`) with `RealSystemGRunSeam` that round-trips `MissionPacket → AgentEvent → RunEventLog → AnswerPacket` through Rust.

**Substrate already in main:**
- `Epistemos/SystemG/SystemGRunSeam.swift` — protocol + stub + Swift types (PR #42 + PR #43)
- `Epistemos/SystemG/SystemGWiring.swift` — capability gates
- `Epistemos/App/AppBootstrap.swift` — `agentAuthorityStore`

**To wire:**
1. `agent_core/src/bridge.rs` — add `system_g_start_run_json(mission_json) -> String` + `system_g_drain_events_json(run_id) -> String` per the SystemGRunSeam header spec
2. `agent_core/src/agent_runtime_v2/mission_run.rs` (NEW) — production MissionPacket runner that emits SystemGAgentEvents
3. `Epistemos/SystemG/RealSystemGRunSeam.swift` (NEW) — implements SystemGRunSeam by polling `system_g_drain_events_json` until terminal event
4. `Epistemos/App/AppBootstrap.swift` — `SystemGRunSeamRegistry.shared.register(RealSystemGRunSeam())` at bootstrap
5. `SystemGHealthRow` chip-strip update: "status-only" → "production dispatch live"
6. Add 10 unit tests + 1 integration test (one full Mission round-trip)
7. Audit doc `docs/audits/SYSTEM_G_FULL_PATH_<date>.md`

**Acceptance:**
- `SystemGRunSeamRegistry.shared.current().run(mission:)` no longer throws notWired in DEBUG builds
- One real Mission runs end-to-end through the seam
- Replay UI reconstructs the run from RunEventLog alone (deterministic)

---

## Terminal D — Substrate Health WRV Panel Unification (P6 + T22 + W-29)

**Goal:** One Settings panel showing ALL substrate health (currently 9 separate rows scattered across Diagnostics; many are visually-misleading per chronicle audit).

**Substrate already in main:**
- 9 HealthRow widgets: ACSAdmission, ActiveConstellation, Eidos, FUlp, LocalAgentDiagnostics, SystemG, VaultRecall + 2 from earlier
- `Epistemos/Views/Settings/SubstrateHealthPanel.swift` skeleton (PR #40)
- `VerifiedFloorChipStrip` component (PR #57)

**To wire:**
1. Promote `SubstrateHealthPanel` from skeleton to full panel
2. Add 4 missing health rows: AnswerPacketHealthRow, EmlObservatoryHealthRow (W-07), UasAcsHealthRow (W-10), CognitiveDagCountsHealthRow
3. Each row reads via FFI on 1 Hz refresh; gracefully degrades if subsystem unavailable
4. Cross-link each row to its falsifier doc in `docs/falsifiers/`
5. Replace the scattered Diagnostics → Settings rows with one tab navigation to SubstrateHealthPanel
6. Audit doc `docs/audits/SUBSTRATE_HEALTH_UNIFICATION_<date>.md`

**Acceptance:**
- `SubstrateHealthPanel` shows 9+ rows with chip strips
- 0 visually-misleading green-X surfaces (every chip honestly reflects production posture)
- Live verification screenshot: user opens Settings → "Substrate Health" tab → sees full panel

---

## Terminal E — ACS Admission Production Gate (P4 + P7 + W-46/W-47/W-25)

**Goal:** ACS Admission becomes a REAL gate (currently `CSISafeguard` is orphan + chip strip says "substrate-only").

**Substrate already in main:**
- `agent_core/src/acs_admission/audit_sink.rs` — `ACSAuditSink` trait + `InMemoryACSAuditSink`
- `agent_core/src/agent_runtime_v2/` — OpLog substrate
- `ACSAdmissionHealthRow` chip strip ("substrate-only" + "gate not installed")

**To wire:**
1. `agent_core/src/agent_runtime_v2/acs_run_event_log_sink.rs` (NEW) — `ACSRunEventLogSink: ACSAuditSink` fanning every verdict into RunEventLog (W-46)
2. `agent_core/src/scope_rex/admission_proof.rs` (NEW) — `SCOPERexAdmissionProof { verdict, record_id, capability_signature }` (W-47)
3. T11 cross-lane handoffs MUST carry `SCOPERexAdmissionProof`; signature mutation rejected at proof boundary (property test)
4. `Provenance Console` (`Epistemos/Views/Console/ProvenanceConsoleView.swift`) — render ACS verdict column inline with claims (W-25)
5. `ACSAdmissionHealthRow` chip strip update: "substrate-only" → "production gate active"
6. Audit doc `docs/audits/ACS_ADMISSION_PRODUCTION_GATE_<date>.md`

**Acceptance:**
- Every tool invocation passes through `ACSRunEventLogSink::admit_and_record`
- Forged-signature property test rejects mutation at proof boundary
- Provenance Console UI shows ACS verdict for every entry
- Falsifier `F-ACS-Anchor-Addressing` PASS on M2 Pro

---

## Terminal F — Falsifiers Run on M2 Pro Hardware (P8 + T23)

**Goal:** Get ≥ 5 falsifiers from doctrine targets to actual PASS on M2 Pro 16 GB. Currently **0/15 measured**.

**Substrate already in main:**
- `docs/falsifiers/*` — 12+ falsifier specs + 1 baseline (F-VaultRecall-50_baseline)
- `agent_core/src/research/` — substrate kernels (target-only)
- `epistemos_doctrine_lint` CLI

**To wire (pick 5 to target):**
1. **F-VaultRecall-50** — already has baseline; run vs new Eidos binding (depends on Terminal A)
2. **F-PageGather-M2Pro** — sketch→residual→exact escalation; run on real vault
3. **F-UAS-ZeroCopy-Spine** — 5 paths (embedding/logits/KV-metadata/graph-search/provenance)
4. **F-ULP-Oracle** — `max ULP ≤ 2 fp16 in [0.5, 2.0]` over 412k+2k points in ≤ 90 s
5. **F-ControllerKernelPack** — control kernel correctness vs CPU ref

**Procedure for each:**
- Build harness binary in `agent_core/src/bin/falsify_<name>.rs`
- Run on M2 Pro 16 GB; persist artifact to `artifacts/falsifiers/<name>/result.json`
- Validate via the artifact schema (T23B doctrine) — note that `epistemos-shadow-validator` Rust binary is still TBD (W-46)
- Mark PASS in `docs/falsifiers/<name>.md`'s status line
- Wire to a Substrate Health row (Terminal D consumer)

**Acceptance:**
- ≥ 5 falsifiers show PASS in their doc + matching artifact JSON
- All measurements on the user's M2 Pro 16 GB rig (per V6_2_HARDWARE_LOCK)
- Audit doc `docs/audits/FALSIFIER_M2PRO_5_PASS_<date>.md`

---

## Side tasks (small enough to fit alongside any terminal)

- **T25 ACS Naming Reconciliation:** Add a lint to `epistemos_doctrine_lint` that fails CI if "ACS" appears without parenthetical expansion on first mention in a modified doc. Small.
- **W-13 Power-user mode UI toggle:** Replace `defaults write` with a SwiftUI Toggle in Settings → Inference. ISSUE-2026-05-16-015 has the spec.
- **W-32 Experimental Features panel:** Unified Settings panel for all UserDefaults flags (EPISTEMOS_RRF_FUSION_V1, EPISTEMOS_GRAPH_INDEX_CHATS, epistemos.localAgent.powerUserMode).

---

## Terminal G — T14 Five-Plane UAS Wiring + No-Orphan-Data Invariant + 2 new falsifiers (NEW; the bridge piece)

**Goal:** Make the canonical "everything is one substrate object" doctrine REAL by enforcing that EVERY data class carries UAS address + plane placement + residency tier + WBO (if approximate) + WRV status (if product-facing). Plus add `F-UAS-CopyCount` + `F-ACS-AnchorLookup` to the falsifier suite.

**Why this is now the critical terminal:** Per Codex's read of [docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md](docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md), T14 is "the exact bridge from the lattice ontology into the working app." Without it, the substrate doctrine drifts to "everything is only an EML tree" — which is wrong. EML is ONE primitive; the substrate fabric is wider (pixels = vectors = notes = graph nodes = KV pages = model components = AnswerPackets, all typed projections of one address space).

**Substrate already in main:**
- `epistemos-research/src/five_planes.rs` (308 LOC — `RuntimePlane::{State, Episodic, Assembly, Controller, Verification}` enum)
- `epistemos-research/src/acs.rs` (190 LOC — `AcsAnchor` + `CmsXField` + `ACS_CANONICAL_PLANE = RuntimePlane::Episodic`)
- `agent_core/src/uas/` (UasAddress + UasKind)
- `agent_core/src/lattice_wbo/` (305 tests passing; LatticeBudget + WboLedgerEntry types)
- `agent_core/src/cognitive_dag/node.rs` (10 NodeKind + 10 EdgeKind)
- `agent_core/src/scope_rex/` (MutationEnvelope + WitnessedState + ClaimGraph + RunEventLog)

**To wire:**
1. **Plane + UAS + residency fields on cognitive_dag NodeKind:** add `uas: Option<UasAddress>` + `plane: RuntimePlane` + `residency: ResidencyTier` to every NodeKind variant in `cognitive_dag/node.rs`
2. **`agent_core` re-export of five_planes types:** add a `pub use` so MAS-build code can address `RuntimePlane` + `ResidencyTier` without depending on `epistemos-research` directly (research crate stays Lane-3-only)
3. **LatticeBudget field on approximate representations:** add `lattice_budget: Option<LatticeBudget>` to types that compress / approximate (KV pages, embeddings, scan-IR blocks) per Lattice-Error Law §1.4
4. **`agent_core/src/bin/uas_copy_count.rs` (NEW):** harness counting tensor copies on the UAS hot path (Swift / Rust / Metal / MLX / KV / HNSW). PASS = 0 copies. Produces `artifacts/falsifiers/uas_copy_count/result.json`.
5. **`agent_core/src/bin/acs_anchor_lookup.rs` (NEW):** harness measuring `anchor_registry.rs` lookup latency over 10,000 claims. PASS = < 1 μs avg.
6. **`docs/falsifiers/F-UAS-CopyCount_<date>.md`** + **`docs/falsifiers/F-ACS-AnchorLookup_<date>.md`** (NEW spec docs)
7. **`Epistemos/Views/Settings/PlanePlacementHealthRow.swift` (NEW):** surfaces per-class plane placement count + per-plane node count (Witness Law §1.7). Wired into Terminal D's Substrate Health panel.
8. **CI lint:** every new `struct` / `enum` / `class` declaration in code MUST have `// UAS: <address-pattern>` + `// Plane: <RuntimePlane>` + `// Residency: <ResidencyTier>` comments OR an explicit `// UAS-EXEMPT: <reason>` waiver. Implement as a `clippy::custom_lint` rule + a Swift source-guard test mirror.
9. **Audit doc `docs/audits/T14_FIVE_PLANE_NO_ORPHAN_<date>.md`** — enumerate every existing data class against the 5-field checklist; flag every orphan; pin remediations.

**Acceptance:**
- Every existing NodeKind variant has UAS address + plane + residency (round-trip serde test)
- F-UAS-CopyCount PASS on M2 Pro (≥ 1 measured run with 0 tensor copies between languages on the hot path)
- F-ACS-AnchorLookup PASS on M2 Pro (< 1 μs avg over 10k anchors)
- `PlanePlacementHealthRow` renders in Substrate Health panel with per-plane counts
- CI lint catches a deliberately-added orphan class in a probe PR
- T-track register §2 line for T14 flips from 🔴 to ✅

**No-Orphan Invariant — also enforced by every other terminal:** every Phase 2+ PR description (including A-F above) MUST include a §No-Orphan check listing which data classes the PR touches + which 5 invariants are satisfied (UAS address, plane placement, residency tier, WBO/error policy if approximate, WRV status if product-facing) OR explicitly waived with a reason.

---

## Cross-terminal coordination

- All terminals must read `docs/SANITIZATION_LOOP_TRACKER_2026_05_23.md` first.
- Per-PR gate: every PR's body MUST cite which W-row(s) it advances + which falsifier(s) it unblocks.
- WRV chip-strip status updates: every terminal updating a HealthRow MUST flip the chip from orange/red to green ONLY when the substrate is truly production-wired, NOT when the stub is replaced with another stub.
- If two terminals touch the same file (likely just `AppBootstrap.swift`), the second to land rebases.

## Expected outcome

After all 7 terminals close (A-G):
- W-row backlog: ~6/53 → ~30/53 (~57% wired)
- Falsifiers PASS: 0/15+ → 7/17+ (incl. new F-UAS-CopyCount + F-ACS-AnchorLookup)
- Substrate-total: ~70% → ~90%
- T14 five-plane wiring LIVE — the bridge piece from lattice ontology to working app
- No-Orphan-Data invariant enforced via CI lint (catches orphan classes at PR time)
- All 7 Laws cited in every PR description
- All HealthRow chip strips: orange/red → green where production-wired (honest signal)
- Phase 2 substantially closed; Phase 3 = research-tier (Pro + V6.1 kernels + Lean proofs)

## Doctrinal preservation (Pro + Research tiers)

Per `project_mas_first_focus_2026_05_03` + `project_app_store_first_sequencing`, terminals must:
- **Build for MAS:** any feature that ships in MAS today
- **Stub for Pro:** every Pro-only path gets `#[cfg(feature = "pro-build")]` / `#if PRO_BUILD` — preserve geometry, don't develop. DO NOT delete Pro hooks.
- **Preserve for Research:** Lane-3 substrate stays in `epistemos-research/` crate. NEVER ships in MAS. Doctrine targets only. Read-only from MAS code via crate boundary.
- **Vault:** preserved-speculation only (Hermes namespace in `simulation` worktree — assets-only extraction allowed; Swift Hermes files contradict 2026-05-05 purge).
