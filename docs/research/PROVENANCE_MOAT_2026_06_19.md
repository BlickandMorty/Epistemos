# PROVENANCE / HONESTY MOAT (S19, 2026-06-19)

Read-only research (subagent), code-grounded. Feeds DEEP_PLAN_AUDIT_HUB + MASTER_SYNTHESIS.
Per S5 this is the **#1 non-copyable differentiator**. Verdict: **the substrate is real, deep,
well-tested — but the last-mile wiring is the SAME built-then-not-wired keystone**, and the
visible chips are partly SYNTHETIC (a no-fake concern in the moat surface itself).

## ⚠️ HONESTY FLAG (owner's no-fake doctrine)
**AnswerPacket "verified"/VRMLabel chips are SYNTHETIC.** `produce_turn_completion_packet`
(`scope_rex/produce.rs:114-183`) synthesizes ≤3 claims from `(stop_reason, output_tokens,
attention_mode)` + a neutral residency placeholder — it **never queries the ClaimLedger**. So a
chat bubble can read "Plausible/Verified" with ZERO genuine claim provenance behind it. This is the
most load-bearing honesty gap in the moat surface (parallel to S13's "CloudKnowledgeDistillation"
misnomer). Also `EidosRetrievedSection` shows metrics-only (counts/latency), no sources, empty in
default builds; Swift `MutationOpLogReplayBundle` is NOT the Rust `.epbundle` (name collision).

## Inventory (EXISTS vs WIRED)
- **ClaimLedger** (retraction-propagating, cycle-detecting, snapshot-export) — EXISTS, fully tested, **PERMANENTLY EMPTY in production** (no live writer; `provenance_ledger()` read at 3 FFI sites, never written — writes flow to the DAG instead). `ledger.rs`.
- **Cognitive DAG** (10 NodeKind/10 EdgeKind, BLAKE3 content-address, merkle) — EXISTS, **live-populated into a process-global IN-MEMORY store** (from ledger/skills/procedural writes via `dispatch.rs:46`); **durable `RedbDagStore` UNWIRED** (feature-gated off "until Phase 8.H"). 
- **Eidos closed-citation** (the strongest primitive — inverse-closure: may cite ONLY IDs Eidos returned, else `FabricatedSourceId` reject; 472 tests) — substrate+FFI EXIST, **flag `EPISTEMOS_EIDOS_V0` OFF, vault index opened but NOTHING crawls notes into it (zero hits), and the closed-citation gate is NOT enforced on answers (W-47 open, `ChatCoordinator.swift:4500`).**
- **ReplayBundle/.epbundle** (the exportable proof — v1/v2/v3, MutationEnvelopes+LedgerSnapshot+DagSnapshot+BLAKE3 integrity; verify-CLI `epistemos_trace verify-replay` exit 4=tamper/5=merkle-mismatch, in CI) — complete Rust+CLI+CI, **NO in-app export** ("Prove it button" doctrine unmet). 
- **AnswerPacket** (per-turn chip, VRMLabel) — EXISTS, emits per CLOUD turn, **claims SYNTHETIC** (above); local lane stamps none.
- **RunEventLog** (append-only BLAKE3-rooted run witness) — two impls, **neither on the live chat path** (Rust mode-Disabled in MAS; Swift driven by one Settings button only).
- **WRV witness chips** (`VerifiedFloorChipStrip`: Flag/Substrate/Witness, orange=wired-but-unproven, green=productionWired&&falsifierPassed, CI-audited against false-green) — REAL, **Settings-only**; falsifier verdict author-asserted per row.
- **VaultRecallProvenanceCard** — the ONE real per-answer provenance surface (backend, candidates, ladder tier, 3 sources w/ title+path+reason), in `MessageBubble:454`. Fed by VaultRecall, NOT the Eidos closed-citation stack.
- **Honest-gating canon** (T4 = compiled/reachable/visible/verified/logged/rollback/AnswerPacket-visible/audit-honest) — governing doctrine.

## Surfaced vs missing
Surfaced: all in ONE place (chat `MessageBubble`) — AnswerPacketChipRow/Badge + VaultRecallProvenanceCard; EidosRetrievedSection (brain side-panel, metrics-only); ProvenanceConsoleView (Settings tab); VerifiedFloorChipStrip (Settings diagnostics).
**MISSING (moat gaps):** (1) **local answers get NO provenance chip** — only the cloud/Rust-agent path threads `answerPacketId`; the local-MLX + local-agent completion paths (`ChatCoordinator.swift:579/1327`) emit none → the local-first "no cloud required" thesis ships provenance ONLY on cloud answers; (2) **no Act/Work provenance surface** (3-engine toggle isn't a primitive; Work throws engineNotWired); (3) **closed-citation never reaches an answer** (W-47) — the strongest moat claim unenforced; (4) **no in-app .epbundle export**; (5) **claims synthetic**.

## The moat target + ordered plan (each follows §3.7 harden→add→re-harden→inspect)
Target: a uniform per-answer footer across Chat/Act/Work = **WHY** (VRMLabel + real ClaimLedger claims) + **WHAT** (Eidos closed-citation sources + VaultRecall, unified) + **PROVE IT** (export a `.epbundle`, verifiable offline by `epistemos-trace verify-replay`).
1. **Universalize emission** — thread `answerPacketId` through the local-MLX + local-agent completion paths (`:579/1327`) so EVERY answer (local+cloud) carries a packet. *Pure wire; precondition for all.* `[MAS]`
2. **Make claims REAL** — replace `produce.rs` synthetic claims with a live ClaimLedger query; wire a live writer so the global ledger is populated by retrieval/tool/verification events (the DAG mirror `migration.rs:518` already exists). `[MAS]` — *fixes the honesty flag.*
3. **Enforce closed-citation (W-47)** — route chat context through `EidosContextPacket::validate_citations`; **populate the Eidos index** (wire `insertVaultNote` into the vault crawl — `EidosVaultBootstrapper.swift:6`); flip `EPISTEMOS_EIDOS_V0` + FLIP+VERIFY. `[MAS]` — *highest-leverage moat win.*
4. **Unify the per-answer footer** — fold VaultRecallProvenanceCard + Eidos closed-citation + AnswerPacket into ONE component reused across Chat/Act/Work (not per-engine copies). `[MAS]`
5. **In-app `.epbundle` export** — FFI `export_replay_bundle_json(run_id)` → `ReplayBundle::build_with_dag`+`to_epbundle_bytes`; a "Prove it / Export proof" button on the answer footer + session menu. `[Pro]` — *highest-visibility enterprise win; currently zero in-app path.*
6. **Bind WRV chips to real falsifiers** — replace author-asserted `falsifierPassed` literals with live falsifier-artifact reads (green earned, per the canon). `[MAS]`

## Composition with engine-isolation (S17)
Provenance is **process-shared by design** — ClaimLedger/DAG/Eidos are `agent_core` process-global singletons, so all engines write/read the SAME substrate while sharing NO logic. This is exactly right: isolation prevents cross-engine logic coupling; provenance is a shared CAPABILITY (MASTER_SYNTHESIS §2f). The unified footer (#4) reads this shared substrate tagged by engine — don't re-implement per engine; guard with the `epistemos_doctrine_lint` gate so no engine smuggles provenance into ChatCoordinator/InferenceState.

## Enterprise-trust angle
`.epbundle` + `verify-replay` already gives offline, deterministic, tamper-evident verification (BLAKE3 + DAG-merkle, exit 4/5, CI-gated) — a genuinely demoable enterprise asset; it just needs in-app export (#5). Surface a per-answer "this answer used NO cloud / NO silent fallback" claim backed by the run's RunEventLog, so the no-cloud promise is shown+provable per answer, not just asserted in Settings.

**Net:** the deepest honest-provenance substrate of any PKM/agent app exists on the Rust side — closed-citation + retraction-propagating ledger + content-addressed DAG + tamper-evident replayable `.epbundle`. It's ONE wiring phase from being the visible moat: emit on every answer (local+cloud), populate ledger+Eidos with REAL claims/citations, enforce W-47, unify one why/what/prove-it footer over the shared seam, ship the in-app `.epbundle` export. Until then the visible provenance is partly **synthetic** (AnswerPacket claims), **cloud-only** (no local chip), and **Settings-bound**. Strong bones, unshipped muscle.

Key files: `agent_core/src/provenance/{ledger.rs,replay.rs}` · `agent_core/src/cognitive_dag/{dispatch.rs:46,migration.rs:518,redb_store.rs}` · `agent_core/src/eidos/{types.rs,validator.rs,provenance_verified.rs}` + `Epistemos/Eidos/EidosWiring.swift:66` + `EidosVaultBootstrapper.swift` · `agent_core/src/scope_rex/produce.rs:114-183` · `agent_core/src/bin/epistemos_trace.rs` · `Models/AnswerPacket.swift` + `Bridge/StreamingDelegate.swift:611` + `AnswerPacketEmitter.swift` · `Views/Chat/{VaultRecallProvenanceCard,EidosRetrievedSection,MessageBubble:396-471}.swift` · `Views/Settings/{ProvenanceConsoleView,SettingsSurfaceComponents:297}.swift` · `ChatCoordinator.swift:579/1327/4500`. Canon: ARCHITECTURE_TIER_PROMOTION_CANON_2026_06_06.md + eidos/STATUS.md (W-47).
