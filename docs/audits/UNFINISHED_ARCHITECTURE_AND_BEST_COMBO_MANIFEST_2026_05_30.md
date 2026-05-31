# Unfinished Architecture And Best-Combo Manifest - 2026-05-30

Status: canon reconciliation after the worktree salvage checkpoint
`b37c24041b2f`, updated by the route-policy diagnostics and Paperclip
heartbeat checkpoints.

Purpose: preserve the full Phase 1 / Phase 2 architecture without confusing
old branch-local promises, stale audit rows, generated fixtures, or research
ambition with shipped product behavior. This document is the anti-loss ledger
for the "best combo" Epistemos architecture: local models as engines, Epistemos
as the verifiable cognition substrate.

Drift-control companion: read
`docs/audits/AGENT_MANAGEABLE_ARCHITECTURE_CANON_2026_05_30.md` before naming a
new search, memory, citation, route, proof, or model-substrate surface. That
register defines the stable organ names and adapter rules so future agents do
not invent parallel authorities such as detached AgentSearch, AgentMemory, or
AgentCitation.

Namespace companion: read
`docs/audits/ACS_NAMESPACE_RECONCILIATION_2026_05_30.md`. From this point
forward, Active Cold Storage is named ColdStore or Cold Residency Layer, not
ACS. Existing `AcsAnchor` source remains the anchored coordinate/provenance
lineage, legacy ACS/Kuramoto wording is renamed forward to KuramotoSync/ResonanceSync,
and admission/verdict behavior is SCOPE-Rex Admission, SovereignGate, or
AdmissionGate. Existing source paths containing `acs_admission` are
transitional naming debt, not permission to reuse ACS for admission in new docs
or UI.

Helios companion rule: Helios is the substrate-runtime research lineage, not a
product-spine step. When older docs say "Helios does X", translate it into the
actual organ before editing: UAS/OAS, ColdStore/ResidencyGovernor, WBO,
RuntimeRouter, System G, Eidos/VaultRecall, SCOPE-Rex, SovereignGate,
RunEventLog, or AnswerPacket.

## Non-Negotiables

1. WRV remains the floor: Wired, Reachable, Visible, Verified.
2. A file, fixture, branch, doc row, or health row is not a product ship claim.
3. No stale worktree or donor branch is a merge source. Mine one hunk or one
   file at a time from current HEAD.
4. No 70B, 128K, full Metal witness, GGUF/MLX heavy probe, mmap stress, or SSD
   residency stress runs until crash-safe harnesses are implemented and
   explicitly approved.
5. Lattice/WBO, ternary/Sherry research, KV-Direct, self-evolving adapters, and
   the autogenous-kernel idea are retained, but they live behind falsifier and
   residency gates. They do not replace UAS, ColdStore, VaultRecall,
   Eidos, or provenance.
6. A scheduler heartbeat is not proof of architecture progress. It is only a
   liveness hook for future loop runners. A heartbeat-backed run may advance a
   row only when it leaves code, tests, artifact evidence, and an updated WRV
   claim trail.

## Heartbeat Scheduler Covenant

`PaperclipHeartbeatClock` now provides a two-minute persisted liveness pulse in
the Paperclip WAL store. Future automation may use that pulse as a scheduling
signal, but every scheduled run must obey this covenant:

1. Start from this manifest plus `ARCHITECTURE_NO_GAP_BUILD_ORDER_2026_05_28`.
2. Pick one row, not an entire architecture region.
3. Prove current source truth before editing: code path, caller, flag, UI
   surface, tests, and falsifier/artifact state.
4. If the row touches Phase 2+ local inference, UAS/OAS/ColdStore/AcsAnchor,
   ActiveAssembly,
   KV-Direct, 70B, lattice/WBO, EML/F-ULP, Lean, or autogenous-kernel work, run
   the relevant No-Orphan check: addressed unit, UAS address, plane, residency,
   WBO/error policy, witness, falsifier, tier, rollback.
5. Leave a durable result: commit, focused verification, and either a green
   WRV row or an explicit skip reason.

The heartbeat must never launch 70B, 128K, full Metal, GGUF/MLX heavy probes,
mmap/SSD stress, or memory-pressure experiments. The safe 70B sequence remains:
WeightBlockManifest range guard -> ResidencyPlan -> non-executing witnesses ->
crash-safe harness -> measured probe -> product claim.

## Track Namespaces

The old ledgers mix several namespaces. They must stay separate.

| Namespace | Meaning | Canon anchor |
|---|---|---|
| Broad substrate tracks `T0`-`T18` | Original product/research feature map: Sovereign, Hermes, Simulation, Local Model, Halo, Graph, UX, Multi-Agent, Ternary/Research, ANE, Live File Compiler, Cognitive Weight, Variant Ladder. | `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md` |
| Helios lineage | Umbrella research/runtime substrate lineage. It preserves vocabulary and mechanisms, but product claims must translate it into concrete organs before shipping. | `docs/audits/AGENT_MANAGEABLE_ARCHITECTURE_CANON_2026_05_30.md` |
| Phase-1 May-16 branches `T1`-`T9` | Salvage branches from the May-16 archeology pass. Some were cherry-picked; some remain donor-only. | Phase C / salvage docs |
| Phase-2 terminal workcards `T09`-`T27` | The no-compromise workcard set: Eidos, System G, UAS/OAS, Lattice/WBO, ColdStore, AcsAnchor, VaultRecall, F-70B, Lean, WRV surfacing. Older decks may say ACS; inspect context: AcsAnchor/Anchored Cognitive Substrate, legacy ACS/Kuramoto research now named KuramotoSync/ResonanceSync, or stale admission naming. | `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` |
| W-rows | Cross-terminal production wires. These decide whether substrate is actually used by app behavior. | `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` |
| Deferred codewords `D-*` | Long-horizon architecture that is preserved but intentionally not on the hot path yet. | `docs/DEFERRED_WORK_GUARANTEE_2026_05_23.md` |

## Best-Combo Architecture

The strongest architecture is not "lattice instead of the original plan" and
not "70B first." It is a layered substrate where every ambitious component pays
through identity, permission, provenance, and falsifier gates.

### 1. Product spine

Typed artifacts, mutation envelopes, graph events, run events, answer packets,
and UI projections are the first spine. Anything that changes user state should
have an event, address, provenance, and visible recovery path. This is why
RunEventLog, AnswerPacket, GraphEventProjection, ClaimLedger, and the chat
provenance badge are architectural primitives rather than UI garnish.

### 2. Retrieval organ

Vault retrieval, Eidos V0, PageGather, and SearchFusion collapse into one honest
retrieval contract over time. T21 VaultRecall is the umbrella API, but T4 must
still be checked for unique scoring/trace pieces before final unification.

Target shape:

- `QueryRuntime.fullText` can use Eidos when `EPISTEMOS_EIDOS_V0` is on.
- `SearchIndexService` and vault sync emit real VaultRecall traces.
- PageGather escalation becomes a read path for vault retrieval, not a detached
  research demo.
- Retrieved chunks carry UAS addresses and closed citation IDs.
- The Brain/source panel shows exactly what was retrieved and rejects fake
  source IDs.

### 3. Runtime mouth and agent loop

RuntimeRouter, LocalAgentLoop, System G / `agent_runtime_v2`, and the
Hyperdynamic Loop decide how model output becomes action. The model is the
mouth; Epistemos owns routing, schema, permission, evidence, and replay.

Target shape:

- RuntimeRouter exposes production route profiles from policy tables, not
  placeholder rows.
- System G run events replay deterministically into visible timelines and
  AnswerPacket output.
- Per-model badges show honest capability state: `HONEST`, `EXPERIMENTAL`, or
  `OFF`.
- Tool actions and durable mutations carry SCOPE-Rex/SovereignGate admission
  proof before commit.

### 4. Address and residency layer

UAS/UASA is the identity spine. ResidencyPlan and WeightBlockManifest are the
safe route into the 70B/SSD-resident ambition. `UasAddress` must cover notes,
blocks, graph events, claims, agent traces, answer packets, tool results,
retrieval chunks, KV pages, model components, and later adapter/kernel assets.

Target shape:

- Address is independent of residency.
- `AcsAnchor` and plane projection stay stricter than donor branches.
- Compressed/NF4/lattice/model-component rows must point back to dense
  rollback references with model-component addresses.
- No live SSD/Metal/mmap stress path is allowed until dry-run planners and
  crash-safe witnesses are green.

### 5. Permission and witness layer

SCOPE-Rex Admission, SovereignGate, CapabilityBridge, ClaimKind, and Provenance
Console are the permission/witness layer. Do not call this layer ACS. Existing
`acs_admission` source paths are transitional naming debt until migrated.

Target shape:

- Every mutation/tool/kernel-promotion path calls SCOPE-Rex/SovereignGate
  admission before commit.
- Rejections are visible as records, not silent fallbacks.
- Proof IDs resolve back to audit records.
- The UI can show why a claim/action was allowed, denied, or escalated.

### 6. Lattice/WBO accounting layer

The lattice work is retained as accounting and falsification infrastructure. It
tracks compression, residuals, drift, quantization, semantic error, and numeric
cost. It does not replace UAS, AcsAnchor, or ColdStore.

Best-combo placement:

- WBO terms `T_W`, `T_K`, `T_R`, `T_Q`, `T_S`, `T_SE`, and `T_num` remain the
  accounting vocabulary.
- Sherry/ternary/E8/Leech/NF4/ShadowKV/Residual/Adapter claims must each carry
  falsifier obligations.
- The current oplog accounting hook is present, so the next work is proof,
  UI, and per-mutation semantics, not a raw reimplementation.

### 7. Formal/proof layer

EML, EML-IR, F-ULP, Lean, and ClaimLedger schema authority form the proof lane.
Lean is not the hot path yet. It becomes schema authority and proof-bearing
claim custody once the toolchain is vendored and a first Lean PR is green.

Target shape:

- EML certificate emission witnesses through F-ULP.
- ClaimLedger schema invariants get Lean authority under T24/D-10.
- `eml_ir/` and `fulp_oracle/` are not collapsed until ownership is proven.

### 8. Visible truth layer

Diagnostics and UI surfaces must make the substrate visible without overstating
it. Health rows are useful only when their orange/green states honestly mirror
WRV.

Target shape:

- Settings Diagnostics shows current flags, last backend, falsifier status, and
  honest stub/production distinctions.
- Chat shows AnswerPacket badges and retrieved evidence.
- Agent settings and run views show live route/timeline/replay state.
- Falsifier and provenance drill-downs are reachable from product surfaces.

### 9. Capability ceiling layer

KV-Direct, 128K, 70B local cocktail, SSD-resident model components, ANE/Metal
kernels, active assembly, research construction, self-evolving adapters, and
the autogenous-kernel direction remain core ambition. They are last-mile
capability ceiling, not the starting point.

Safe order:

1. Dry-run falsifiers and manifests.
2. ResidencyPlan over WeightBlockManifest.
3. Guarded witnesses that do not launch heavy inference.
4. Crash-safe harnesses.
5. Measured runtime probes.
6. Only then 70B/128K/KV-direct/Metal/SSD stress.

## Current Truth At This Checkpoint

These items have live source anchors in the current worktree and should not be
restarted from stale donor branches:

| Surface | Current truth |
|---|---|
| T10 Eidos -> QueryRuntime | `RetrievalRuntime.fullText` checks `EidosFlags.isEnabled`, prefers `EidosBridge.retrieve` when the vault index is open, falls back to fixture search, then falls through to RRF/legacy when unmapped. `QueryRuntimeTests` cover the production-vault route. Remaining work is product-depth and contract unification, not "not wired at all." |
| T21 VaultRecall | Swift wiring, metrics, health row, and production trace recording exist. Some paths still report stub or fixture backends honestly. Final work is unification and typed retrieval, not raw substrate creation. |
| T17B Lattice/WBO -> oplog | `agent_core/src/oplog.rs` calls `oplog_lattice_wbo::account_append` after successful in-memory append. The stale "0 entries because nothing writes" claim is no longer globally true. Remaining work is semantics, proof, tests, and visibility. |
| T18B SCOPE-Rex/SovereignGate admission | Transitional source paths still include `agent_core/src/acs_admission/`, `SCOPERexAdmissionProof`, `ACSRunEventLogSink`, and System G tool-call admission surfaces. Full pre-commit coverage of every mutation/tool/kernel-promotion path remains high-risk follow-up. New docs must not call this ACS. |
| T14 terminal UAS bridge | `UasAddress`, `UasKind`, `AcsAnchor`, `AcsAnchorPlaneProjection`, anchor registry, vault-note addresses, claim addresses, and agent-trace addresses exist. More consumer wiring remains. |
| T22 Substrate Health | `SubstrateHealthPanel`, `EidosHealthRow`, `VaultRecallHealthRow`, `SystemGHealthRow`, `UasAcsHealthRow`, `ACSAdmissionHealthRow`, `FUlpHealthRow`, and falsifier rows exist with tests. Falsifier drill-down/product panel depth remains follow-up. |
| T2 Agent/UI substrate | `AgentBlueprintSettingsView`, `AgentRunTimelineView`, and `AnswerPacketBadge` exist. End-to-end replay and real run-flow insertion remain unfinished. |
| Runtime Router | `LocalPolicy`, `localPolicyTable`, and `modelPreferenceTable` exist in `RuntimeRouter`; `ConfidenceRouter.routeProfiles()` now adapts those profiles for LocalAgentDiagnostics and ActiveConstellation. Remaining work is live route decisions, replay, per-model behavior proof, and ActiveAssembly falsifier witness. |
| T4 retrieval | `agent_core/src/retrieval/mod.rs` and vault trace/search code exist in current source. T4 donor still needs unique-value diffing before being declared fully absorbed. |
| Paperclip heartbeat scheduler | `PaperclipHeartbeatClock` records an immediate heartbeat and then sleeps for 120 seconds between ticks. It is wired from `AppBootstrap` outside XCTest. This is a liveness/scheduling hook only, not a WRV proof for unfinished architecture rows. |

## Checkpoint Evidence

- `Tools/audits/epistemos_worktree_inventory.sh` was re-run on 2026-05-30. It
  reported 40 Epistemos-like candidates, 34 sibling worktrees, and 25 dirty
  candidates. The only inventory-file diff was volatile current-repo HEAD,
  dirty count, and timestamp from this in-flight patch, so it was inspected and
  not retained as canon.
- Source/doc dirty filtering with generated-output exclusions found real
  source/doc deltas in `Epistemos-terminal-d-r2`,
  `Epistemos-terminal-d-r3`, `Epistemos-terminal-e`, and
  `Epistemos-wrv-docs`. No cleanup or merge was performed.
- Route-profile diagnostics were verified with a focused red/green test loop:
  the old placeholder assertions failed first, then 14 selected Swift tests
  passed after wiring `ConfidenceRouter.routeProfiles()` to
  `RuntimeRouter.defaultRouteProfiles()`.

## Phase 1 Leftovers

These rows preserve the user's older ledger but normalize it against current
source truth.

| Item | Status now | Next action |
|---|---|---|
| T4 Vault retrieval donor | Partially absorbed. Current source has retrieval/vault trace material and newer T21/Eidos paths, but the May-16 donor may still contain unique scoring, tests, or trace policy. | Non-mutating diff against `codex/t4-vault-2026-05-16`; port only novel additive hunks. |
| T6 UI/UX donor | Preservation-only donor. Current source has newer chat, landing, graph, syntax, artifact, settings, and AgentBlueprint surfaces. | Mine only small accessibility/audio/Halo/provenance-console polish. Do not restore old shells. |
| T5 Lean custody | EML/IR substrate and docs are partially present. Lean toolchain and first proof PR remain deferred. | Vendor/verify Lean toolchain, then land one minimal schema-proof PR. |
| T2 production route profiles | Closed for diagnostics/visibility in this checkpoint: LocalAgentDiagnostics and ActiveConstellation read the RuntimeRouter policy profiles instead of placeholder rows. | Continue into live route decisions, per-model policy badges, replay, and ActiveAssembly witness. |
| T2 AppBootstrap refresh deletion | Not a ship candidate. Current behavior preserved. | Keep skipped unless a separate bug proves need. |
| T2 ToolCallingPlan fields | Breaking initializer change was correctly skipped. | Only pursue as additive variant with tests. |
| T23B duplicate docs | Falsifier docs landed, with likely duplicates after T10/T12/T17B/T21 canon. | Mechanical dedupe once no citations depend on duplicate paths. |
| T12 `eml_ir/` vs `fulp_oracle/` | Both exist because ownership is not proven. | Collapse only after F-ULP witness path and Lean authority are clear. |

## Phase 2 Wiring Ledger

The highest-value remaining wires are no longer exactly the same as the older
ledger. Current next work should follow this order.

| Priority | Wire | Current state | Build requirement |
|---|---|---|---|
| 1 | T4 unique-value check | Still unresolved donor question. | Prove absorbed or port one additive retrieval hunk/test. |
| 2 | T21 retrieval contract unification | Eidos and VaultRecall both exist; PageGather trace metadata exists; flags are still separate in product shape. | Collapse Eidos/VaultRecall/PageGather behind the T21 contract after T4 check. |
| 3 | Agent replay path | Timeline view exists; replay and run-flow insertion are incomplete. | Deterministic RunEventLog replay into visible AnswerPacket output. |
| 4 | Per-model badges | Some badge surfaces exist and route profiles are policy-backed for diagnostics; behavior-level proof remains incomplete. | Bind `HONEST`/`EXPERIMENTAL`/`OFF` badges to runtime policy decisions and replay records. |
| 5 | Runtime route policy behavior | Policy tables are visible; production dispatch proof still needs focused tests. | Prove `RuntimeRouter.route(_:)` consumes the same policy table under lane enable/disable and confidence gates. |
| 6 | W-01/W-04/W-22 typed vault retrieval | Rust has UAS addresses and vault trace methods, but every retrieval consumer is not yet typed end-to-end. | `hybrid_search` consumers use/return typed `Vec<UasAddress>` where appropriate; PageGather escalates through vault retrieval. |
| 7 | W-06 Tri-Fusion typed mutations | Not closed. | Graph/vault/agent mutations emit typed mutation envelopes and UAS-backed graph events. |
| 8 | W-25/W-26 provenance and Cognitive DAG | Partial provenance source exists, UI depth remains. | Clickable SCOPE-Rex/SovereignGate provenance records and Cognitive DAG visualizer. |
| 9 | T12 F-ULP -> EML witness | Substrate exists, production witness path incomplete. | EML certificates call F-ULP witness and carry result into ClaimLedger/provenance. |
| 10 | T18B full admission gate | Tool-call/System G slices exist, but all durable paths are not proven gated. | Gate every mutation/tool/kernel-promotion path. Do this last with broad tests. |

## Terminal Workcards Still Deferred Or Partially Open

| Workcard | What it means now |
|---|---|
| T09 Product Architecture Ledger | Present in several ledgers; this manifest supersedes the partial memory ledger for future planning. |
| T10 Eidos V0 | Wired into `QueryRuntime.fullText`; further work is unification, source-panel depth, and falsifier visibility. |
| T10B Eidos Form Layer | Still deferred as canonical object identity/schema layer. Build after retrieval contract stabilizes. |
| T11 System G | Rust and local-agent seams exist; more Swift bridge/runtime migration and replay UI remains. |
| T12 F-ULP | Substrate present; witness emission path remains. |
| T13 F-KV-Direct Gate | Deferred capability-ceiling gate. Do not run heavy KV probes. |
| T14 Five-plane UAS / AcsAnchor / ColdStore | Core bridge exists; typed consumer closure remains. |
| T15 Executor Trait | Deferred. Fold into System G execution once route policy and SCOPE-Rex/SovereignGate admission are stable. |
| T16 Live File Compiler | Deferred production compiler. Keep typed seams separate from hot path. |
| T17 Cognitive Weight Class Enforcement | Deferred/partial. Connect to ResidencyPlan/WeightBlockManifest before runtime claims. |
| T17B Lattice/WBO | Oplog hook exists; semantic accounting, falsifier proof, and UI remain. |
| T18 ResidencyGovernor | Dry-run/planner surfaces exist; live residency governor remains deferred. |
| T18B SCOPE-Rex/SovereignGate Admission | Substrate and System G/tool-call slices exist; full gate remains high-risk. |
| T19 Halo V1 plus Eidos control vectors | Deferred product/research surface. |
| T20 Variant Ladder | Deferred D-05. |
| T21 Vault Recall Contract | Present but not final umbrella over all retrieval. |
| T22 Substrate Health Panel | Present; drill-down truth and falsifier panel depth remain. |
| T22B Brain Panel Closed Citations | Partially present via Eidos/chat citation surfaces; make retrieved-source panel complete. |
| T23 F-70B Local Cocktail | Deferred D-09; do not run heavy probes. |
| T23B M2 Pro Falsifier Handbook | Present; dedupe and wiring into UI remain. |
| T24 Lean ClaimLedger Schema Authority | Deferred D-10. |
| T25 ACS Naming and Plane Reconciliation | Reopened by `ACS_NAMESPACE_RECONCILIATION_2026_05_30.md`: ColdStore names Active Cold Storage; ACS remains context-bound to AcsAnchor/Anchored Cognitive Substrate or legacy ACS/Kuramoto research now named KuramotoSync/ResonanceSync; admission names must migrate to SCOPE-Rex Admission / SovereignGate / AdmissionGate. |
| T26 Self-Evolving Adapter Lane | Deferred D-06; candidate home for autogenous-kernel research. |
| T27 WRV Product Surfacing | Still the capstone: make the first P0 W-rows visible and verified. |

## Broad Substrate Tracks To Preserve

These are not all "not started"; they are broader than the May-18 terminal
workcards and should be treated as architecture lanes.

| Broad track | Best-combo placement |
|---|---|
| T14 Ternary/Research | Preserve Sherry, ternary, WBO-6, KV-direct, and lattice research as falsifier-backed research lanes. Do not let them override retrieval/permission/product spine. |
| T15 ANE | Capability-ceiling optimization after correctness and crash safety. |
| T16 Live File Compiler | Build after typed mutation/event contracts are stable. |
| T17 Cognitive Weight | Bind to UAS/ResidencyPlan/WeightBlockManifest, then enforce. |
| T18 Variant Ladder | Build as model/runtime policy generalization, not as one-off provider preference. |
| Simulation / Farm | Use for safe sandbox/applier work only after product-surface decision. |
| Quick Capture | Keep as future pro-tool ingestion lane; gate on System G/live routing and typed receipts. |
| Autogenous kernel | Treat as Research Construction plus L_SE/self-evolving adapter lane. It must have UAS identity, ColdStore residency, SCOPE-Rex/SovereignGate admission, WBO accounting, rollback, and falsifier proof before it can become product behavior. |

## Auxiliary Branches To Audit, Not Merge

These branches exist and remain preservation/donor references until a focused
non-mutating audit proves a small current-head patch is useful:

| Branch | Default decision |
|---|---|
| `codex/release-stabilization-and-runtime-hardening` | Audit for already-superseded runtime guards; do not raw merge. |
| `codex/research-snapshot-2026-05-08` | Preserve as research snapshot. |
| `codex/runtime-input-audit` | Audit against current SCOPE-Rex/SovereignGate runtime input code plus ColdStore/ACS naming debt. |
| `codex/runtime-memory-hardening` | Audit against current residency/runtime-hardening code. |
| `feature/knowledge-fusion-v1` | Deep-dive only; likely massive. |
| `feature/landing-liquid-wave` | Superseded by newer landing/pixel surface; preserve only. |
| `run-b-post-v1-research` | Audit for docs/canon only. |
| `run-c-audit` | Audit for canon provenance. |
| `run-d-providers` | Audit for provider matrix ideas after route policy table. |
| `run-e-decisions` | Audit for decision/governance docs. |
| `run-f-integrations` | Audit for integration ideas after runtime gates. |

## Build Order

This order keeps the original architecture, the later lattice/research insight,
and the current product truth in one executable path.

1. Keep the repo/build green. If build is broken, fix it before new
   architecture work.
2. T4 unique-value check against `codex/t4-vault-2026-05-16`.
3. T21 retrieval contract unification over Eidos/VaultRecall/PageGather.
4. Runtime route policy behavior under lane enable/disable and confidence gates.
5. Agent replay path: RunEventLog -> AgentRunTimelineView -> AnswerPacket.
6. Per-model runtime badges backed by policy decisions and replay records.
7. Typed vault retrieval and PageGather escalation with UAS addresses.
8. Tri-Fusion typed mutations and graph event contracts.
9. Provenance/admission drill-down and Cognitive DAG visualizer.
10. F-ULP -> EML witness emission.
11. Lean ClaimLedger schema authority.
12. Residency governor over WeightBlockManifest and ResidencyPlan dry-runs.
13. Full SCOPE-Rex/SovereignGate admission gate across every durable mutation/tool/kernel path.
14. Only then capability ceiling: KV-Direct, 128K, 70B, Metal/ANE kernels,
    L_SE/autogenous kernel, active assembly, and measured runtime probes.

Before any row can be marked "done," apply the end-to-end gate:

- **Wired:** production caller uses the substrate, not just a scaffold.
- **Reachable:** a real app path, CLI, falsifier, or test can invoke it.
- **Visible:** the user/operator can see the status, provenance, or result.
- **Verified:** focused tests or schema-valid artifacts prove the behavior.
- **Rollback:** stricter current truth-floor fields remain intact.

## Resume Prompts

Use these exact short prompts to continue without losing the architecture:

```text
Resume T4 unique-value check from UNFINISHED_ARCHITECTURE_AND_BEST_COMBO_MANIFEST_2026_05_30.
```

```text
Resume T21 retrieval contract unification from UNFINISHED_ARCHITECTURE_AND_BEST_COMBO_MANIFEST_2026_05_30.
```

```text
Resume runtime route policy behavior from UNFINISHED_ARCHITECTURE_AND_BEST_COMBO_MANIFEST_2026_05_30.
```

```text
Resume Agent replay path and model badges from UNFINISHED_ARCHITECTURE_AND_BEST_COMBO_MANIFEST_2026_05_30.
```

```text
Resume capability ceiling only after ResidencyPlan, crash-safe harnesses, and falsifier dry-runs are green.
```

## Bottom Line

The comprehensive canon is not one branch and not one explainer. It is the
combination of:

- Product spine: typed events, artifacts, graph, runs, claims, answer packets.
- Retrieval organ: T4 + T10 + T21 + PageGather under one contract.
- Runtime mouth: RuntimeRouter + System G + Hyperdynamic Loop.
- Address/residency: UAS/UASA + ResidencyPlan + WeightBlockManifest.
- Permission/witness: SCOPE-Rex/SovereignGate + provenance + ClaimKind.
- Accounting: lattice/WBO/Sherry/ternary as falsifier-backed cost truth.
- Proof: EML/F-ULP/Lean as schema and certificate authority.
- Visible truth: diagnostics, source panels, badges, timelines, DAGs.
- Capability ceiling: KV-Direct/128K/70B/ANE/Metal/L_SE/autogenous kernels only
  after safety and falsifier gates.

Nothing in the original Phase 1/Phase 2 ambition is dropped. The build path is
to make each piece WRV, one small current-head patch at a time.
