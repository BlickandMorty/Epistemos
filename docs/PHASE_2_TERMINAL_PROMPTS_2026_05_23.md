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

## Cross-terminal coordination

- All terminals must read `docs/SANITIZATION_LOOP_TRACKER_2026_05_23.md` first.
- Per-PR gate: every PR's body MUST cite which W-row(s) it advances + which falsifier(s) it unblocks.
- WRV chip-strip status updates: every terminal updating a HealthRow MUST flip the chip from orange/red to green ONLY when the substrate is truly production-wired, NOT when the stub is replaced with another stub.
- If two terminals touch the same file (likely just `AppBootstrap.swift`), the second to land rebases.

## Expected outcome

After all 6 terminals close:
- W-row backlog: ~6/53 → ~25/53 (~50% wired)
- Falsifiers PASS: 0/15 → 5/15
- Substrate-total: ~70% → ~85%
- All HealthRow chip strips: orange/red → green where production-wired (honest signal, not cosmetic)
- Phase 2 substantially closed; Phase 3 = research-tier + Pro-build work
