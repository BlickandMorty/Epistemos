# Canonical Chronicle - 2026-05-23

Purpose: preserve the local canon as a chronological control document and stop
future agents from flattening it into slogans, branch folklore, or "file exists"
ship claims.

Core phrase:

> Epistemos is converging on a typed, addressable, witnessed substrate. Notes,
> claims, citations, graph nodes, agent events, tool calls, model outputs,
> patches, memory pages, and future model components should become substrate
> objects with stable identity, authority, provenance, and witness evidence.
> This does not mean every object is literally an EML tree.

Compressed canon phrase for future docs:

> Everything becomes a typed, addressable, witnessed substrate object when it
> enters the governed substrate. Not everything is literally EML.

EML is the arithmetic/symbolic lowering and certificate lane. It is one witness
and operator layer inside the substrate. The whole ontology is broader:
UAS/UASA addresses identity and residency, Eidos addresses canonical object
forms and closed citations, System G addresses governed execution, ACS addresses
admission/composition, lattice/WBO addresses error accounting, and WRV addresses
ship proof.

## Canonical Sources Read

Canonical product/research docs:

- [S1] `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- [S2] `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md`
- [S3] `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md`
- [S4] `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md`
- [S5] `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md`
- [S6] `docs/MAY16_ARCHEOLOGY_2026_05_23.md`
- [S7] `docs/T5_BLOCKER_LEDGER.md`

Audit inputs read for this chronicle:

- [A1] `/tmp/audit/01_canon_2026_05_20.md`
- [A2] `/tmp/audit/02_may16_cycle.md`
- [A3] `/tmp/audit/03_may18_cycle.md`
- [A4] `/tmp/audit/04_donors.md`

Drift rule: `/tmp/audit/*` files are evidence inputs, not durable canon. If a
future agent wants to rely on them after this cycle, promote the relevant audit
content into `docs/audits/**` or re-run the audit.

## Status Vocabulary

Use the product ledger taxonomy from [S4] and [A1]:

- `current-wired`: production caller chain exists and is exercised.
- `visible-working`: user can reach it and proof exists.
- `visible-broken`: user can reach it, but behavior fails.
- `implemented-not-wired`: code exists without production caller chain.
- `feature-gated`: code exists behind a real flag, build profile, or runtime
  gate with fallback.
- `scaffold-only`: shape exists without behavior.
- `not-implemented`: no durable implementation.
- `excluded-speculative`: explicitly preserved but out of scope.

Do not use `done` unless WRV is satisfied: Wired, Reachable, Visible, Verified.
Per [S2] and [S5], a doc row, file, fixture, or branch is not a ship claim.

Production-vs-fixture guard:

- Production caller chain means the current app/runtime can reach the code
  through its real entry point, not a test helper or branch-only harness.
- Fixture/stub/status-only means the row may be useful evidence, but it is not
  proof of product behavior.
- A branch-local implementation remains branch-local until current main is
  checked after merge/rebase.
- A docs-only control artifact can be `visible-working` as documentation while
  still making no product runtime claim.

## Lanes

These lanes are product/safety lanes, not memory tiers. Keep them separate from
L0/L1/L2/L3/L4/L5/L_SE/L7 residency language.

| Lane | Meaning | Chronicle discipline |
|---|---|---|
| Product / MAS | Current app surface inside App Store constraints. | Build narrow, default local, no hidden cloud/subprocess fallback. |
| Pro | Developer-ID/direct distribution features such as bounded CLI/MCP/browser/tool execution. | Preserve geometry, but require real entitlement/capability gates before calling anything shipped. |
| Research / Omega | Falsifiable substrate computer: UAS-ACS, five planes, EML/IR, KV-Direct, Metal kernels, 70B cocktail. | Research claims need falsifiers, hardware pin, and artifacts. |
| Vault | Memory, retrieval, closed citations, Eidos, Halo, provenance over user knowledge. | Highest product credibility lane because recall failure invalidates the substrate story. |
| Infrastructure | Ledgers, handoffs, branch salvage, falsifier handbooks, CI/build gates. | Must prevent drift; docs-only loops must not block code-bearing spine work. |

## Chronicle

### 2026-05-02 - Master Research Index

[S1] locked the early substrate invariants:

- Apple Silicon zero-copy/unified memory, one in-process substrate, Rust
  ownership as a Markov boundary, logged/hashed state transitions, and canonical
  state as the source of truth.
- Core/Pro/Research ship separation: Core/App Store, Pro/Developer-ID, and
  Research/private-framework or experimental lanes.
- SCOPE-Rex naming: product is Epistemos, Rust kernel is Rex, SCOPE-Rex is the
  full sparse-feature/claim/ontology/proof/execution/state-witness runtime.
- ACS lineage: the recursive/autopoietic doctrine came from the Kimi research
  corpus and later split into process-view and structure-view naming.
- Eidos and Vault were already framed as in-process attention/retrieval organs,
  with Pro deliberation and browser work deferred.
- MAS-first doctrine says Pro stays in the plan but not on the critical path.

Status: canon-index foundation, not a current implementation claim by itself.

Missing proof:

- A source-index document does not prove caller chains or UI surfaces.
- The Pro lane has design geometry, but Pro-tier capability gating remains a
  separate proof obligation.

What would falsify this:

- A future doc collapses Core/Pro/Research into one lane.
- A production path uses hidden subprocess/cloud behavior while claiming
  in-process/local substrate.
- A UI projection becomes the source of truth instead of projecting canonical
  state.

### 2026-05-13 - Master Fusion No-Compromise Backlog

[S2] exists to prevent cross-corpus drift. Its key controls:

- No drift via compression: named concepts must retain source docs, status,
  code anchors, and next moves.
- WRV is the ship test: Wired, Reachable, Visible, Verified.
- Capability lattice, not architecture fork: one codebase with MAS/Pro/Research
  gates.
- The memory/residency table and KV-Direct gate are substrate claims, but many
  rows are explicitly not started or partial.
- ACS (Autopoietic Cognitive Stack / Anchored Cognitive Substrate) is not one
  feature. It includes recursion, VSM/homeostasis, admission/control, and a
  research-only Rust substrate. First mention must disambiguate the expansion.
- Cognitive DAG and provenance ledger surfaces have real shipped pieces, but
  future docs must distinguish schema/code from user-visible proof.
- V6.2 falsifier order and M2 Pro hardware pin make research claims measurable.

Status: canon-candidate / atlas. Strong doctrine, mixed implementation.

Missing proof:

- Several tables use `MATCHES`, `PARTIAL`, or `NOT-STARTED`, but the doc itself
  is not a fresh caller-chain audit.
- KV-Direct, major Metal kernels, and many research gates are target-only in
  this source.
- WRV requires a visible surface plus verification, not just an atlas row.

What would falsify this:

- A PR changes a concept in [S2] without updating the atlas/status row.
- A future agent claims a `PARTIAL` or `NOT-STARTED` target as shipped.
- ACS is mentioned bare or treated as a hot-path kernel without admission and
  governance context.

### 2026-05-16 - UAS-ACS Canon and May-16 Branch Cycle

[S3] is the coherence register for UAS-ACS. Its one-paragraph definition says
the memory, compute, and governance fabric should behave as a single
addressable, recursively governed system. It also distinguishes UAS as the
address-space view and ACS as the governance/regulation view.

[S3] names six canonical surfaces:

- research-only ACS substrate types;
- five-plane runtime formalism;
- KV-Direct gate;
- [S2] ACS doctrine row;
- HELIOS V6.1 substrate targets;
- V6.2 falsifier order.

[A2] and [S6] clarify what the nine May-16 terminal branches actually produced:

- T1 Tri-Fusion: real Rust/Swift document mutation substrate and tests, salvage.
- T2 Agent/Blueprint: Swift blueprint and diagnostics layer, complementary to
  T11 System G, salvage after reconciliation.
- T3 UAS/ACS: UAS, active assembly, and page-gather primitives, salvage subset.
- T4 Vault recall: real retrieval contract, but superseded by T21 production
  path in current main audit context.
- T5 EML-IR: large six-IR substrate; split per IR, do not merge as one PR.
- T6 UI/UX: mostly modifications and polish; defer until UI refactor cycle.
- T7 Deep EML: runtime integration, tests, and CLI, salvage.
- T8 Biometric: doctrine-only, donor/salvage doc, do not start code.
- T9 Coordinator: docs-only, archive/salvage selected coordination docs.

[S5] is the bridge between branch-scoped work and product reality. It records
that scope locks deferred cross-terminal wiring and user-facing surfacing. Its
W-rows are the critical path from substrate to app behavior.

Status:

- UAS-ACS doctrine: current canonical register.
- May-16 code: branch-local and not automatically current-wired.
- Wiring backlog: current control document for post-merge visibility.

Missing proof:

- T-branch code is not current-wired until merged, caller-chain audited, and
  user-visible where applicable.
- [S5] W-rows W-01 through W-45 are mostly `NOT-STARTED` or `PARTIAL`; `PARTIAL`
  can mean branch-local or substrate-only.
- T5 has `lake build` evidence but still has `EML-LEAN-VENDOR` unresolved in
  [S7].

What would falsify this:

- A future agent treats a May-16 branch artifact as shipped on main without
  re-checking main.
- The product still cannot surface vault provenance, agent runtime status,
  EML/UAS health, or AnswerPacket badges after claimed wiring.
- T5 is merged monolithically despite [S6] and [A2] requiring per-IR split.

### 2026-05-18 - Endgame Prompt Deck and May-18 Spine

[S4] reframes the product class:

- Epistemos should become a native macOS verifiable cognition substrate, not
  just a notes app.
- Builder-facing discipline: one spine, typed events, governed actions, visible
  proof.
- Current product spine: `TypedArtifact -> MutationEnvelope -> RunEventLog /
  AgentEvent / GraphEvent -> UI projection`.
- The five product lanes are MAS/current app, Pro/direct, Research,
  Infrastructure/reserved, and Vault.
- UAS/UASA starts boring: stable addresses, content hashes, residency leases,
  byte ranges, and provenance IDs before model components and KV pages.
- ACS (Autopoietic Cognitive Stack / Anchored Cognitive Substrate) is
  composition/admission above SCOPE-Rex and before durable mutation.
- Eidos V0 and the Vault Context Contract outrank ceiling research because
  retrieval failure undermines all higher claims.
- System G / Invader Agent is the canonical user-facing agent naming. `Aegis`
  is rejected; `agent_runtime_v2` is the code namespace.

[A3] audits the May-18 tracks:

- T10 Eidos V0: real Rust crate and tests, Swift bridge proof still a gate.
- T11 System G: real runtime code, but lattice/WBO dependency and Swift bridge
  proof remain.
- T12 F-ULP: real research code, but duplicate `eml_ir`/`fulp_oracle` paths and
  Metal/doc alignment must be resolved.
- T17B Lattice/WBO: canonical `lattice_wbo` substance, but one huge module
  needs decomposition.
- T18B ACS Admission: real admission code, but depends on T17B and also needs
  decomposition/reviewability.
- T21 Vault Recall: real retrieval runner/fixture, but some visible surfaces
  and FFI/diagnostic proof remain.
- T09 and T23B: docs-only loops with useful canon but too many refresh commits;
  squash and prevent cron-like updates.

Status:

- May-18 spine is buildable in a specific merge order, not uniformly wired.
- Code-bearing tracks are mostly Phase 1 hardening.
- T22, T22B, T27, T14 full wiring, and full T22 Substrate Health are Phase 2
  wiring because they consume merged substrates.

Missing proof:

- Swift bridges and visible surfaces are missing for several Rust substrates.
- Falsifier handbook rows are not pass evidence unless commands/artifacts exist.
- T09 status categories are useful, but not code.

What would falsify this:

- Any future merge order lands T11/T18B over the wrong lattice/WBO base.
- Eidos permits citations not returned in an `EidosContextPacket`.
- System G reintroduces Hermes subprocess behavior or the rejected Aegis name.
- Falsifier rows claim PASS without M2 Pro artifacts.

### 2026-05-20 through 2026-05-23 - Audits, Donors, and Salvage

[A1] turns the previous docs into a spine map:

`Vault/Eidos retrieval -> System G runtime -> UAS addressing / ACS admission ->
lattice/WBO accounting -> EML/EML-IR witness/cert layer ->
falsifier/health gates -> visible product`

[A1] also clarifies phase language:

- Phase 1 hardening means additive, mostly isolated work that can land without
  May-16 branch merges: product ledger, vault contract, Eidos, Eidos Form Layer,
  Brain Panel citations, System G, lattice/WBO, ACS admission, falsifier docs
  and gates where self-contained.
- Phase 2 wiring means post-merge work that makes substrates call each other
  and become visible: T14 five-plane UAS wiring, T18 residency governor, T22
  full Substrate Health Panel, and T27 WRV surfacing.

[A4] classifies non-T donors:

- Simulation is donor-only except possible future mining of AgentEvent
  normalization and Applier sandbox/audit infrastructure.
- Quick Capture has already contributed some code, but `route/`, `heal/`,
  `format/`, `effect/`, `undo/`, and branch `nightbrain` remain locked until
  T11-style dispatch reconciliation.
- Hermes parity is legacy/dead because the Hermes subprocess was purged.
- Several session worktrees are redundant and should be archived, not mined.

[S6] produces the actionable May-16 salvage table and confirms T4/T6 skip/defer
decisions where parallel or conflict-heavy work would create drift.

Status: audit-control layer. It ranks and classifies work; it does not itself
wire the product.

Missing proof:

- Phase definitions need a durable canonical doc, which is D2.
- Next actions need a ranked durable ledger, which is D3.
- Donor mining is not authorized unless it supports the spine and has a clear
  production caller path.

What would falsify this:

- A future agent starts donor visual or renderer work before the product
  substrate surface is decided.
- A future agent revives Hermes subprocess paths.
- Phase 2 begins before required substrates are merged or before Jojo explicitly
  authorizes merges that the canon says are gated.

## Major Claims, Status, Missing Proof, Falsifiers

| Major claim | Source(s) | Status | Missing proof | What would falsify this |
|---|---|---|---|---|
| Epistemos is aiming at a native macOS verifiable cognition substrate. | [S4] | `implemented-not-wired` as an endgame, not a shipped product class | WRV surfaces across Vault, agent, citations, health, provenance | User-visible app remains a notes/search UI with no reachable substrate proof |
| Everything meaningful should become typed, addressable, and witnessed. | [S1], [S2], [S3], [S4] | `implemented-not-wired` across many surfaces | UAS IDs, Eidos forms, RunEventLog/AnswerPacket/ClaimLedger caller chains | Notes, graph nodes, agent events, or citations remain string blobs without stable IDs/provenance |
| Not everything is EML. EML is the arithmetic/symbolic witness lane. | [S2], [S4], [S7] | `feature-gated` / Research-first | T5 per-IR split, F-ULP proof, Lean/vendor closure | A doc or code path says the whole ontology is literally EML trees |
| Vault recall and Eidos outrank ceiling research. | [S4], [S5], [A1], [A3] | `implemented-not-wired` to `visible-broken` depending surface | ChatCoordinator/Brain Panel closed-citation wire and diagnostics | `LIMIT N` style context, irrelevant first notes, or fake citations reach a user |
| System G is the governed executor; Aegis is rejected. | [S4], [A3] | `implemented-not-wired` | Swift bridge, production caller chain, capability/budget proof | User-facing or doc text revives Aegis, or runtime falls back to purged Hermes subprocess |
| UAS/UASA starts with boring metadata before model/KV pages. | [S3], [S4], [A1] | `not-implemented` to `implemented-not-wired` | T14 stable `UasAddress`/`UasKind`/lease/register tests in product paths | Work jumps to KV/model addressing before notes/events/tools/retrieval hits have stable addresses |
| ACS is admission/composition above SCOPE-Rex, not a monolithic kernel. | [S2], [S3], [S4], [A3] | `implemented-not-wired` for T18B; research-only for older ACS substrate | No durable write bypasses admission; audit records visible/replayable | Durable mutation path exists that bypasses ACS admission after a claim of ACS wiring |
| Lattice/WBO is the error-accounting lane, not a speed claim. | [S4], [A3] | `implemented-not-wired` | T17B decomposition, tests, consumers in T11/T18B | Approximate/compressed representations ship without WBO/error terms |
| Falsifier gates are M2 Pro artifact gates. | [S2], [S3], [S4], [A3] | `scaffold-only` or `implemented-not-wired` per gate | Commands, fixtures, artifacts, thresholds, failure fallback | Any F-* gate is marked PASS without repo-local command output/artifact |
| WRV is the ship test. | [S2], [S4], [S5] | current control rule | Screenshot/visible proof for user surfaces; narrow tests for caller chain | A feature is called done because code or docs exist but the user cannot reach it |
| Preserve wide, build narrow. | [S4], [A1], [A4] | current operating rule | Lane/status labels in every action ledger | Donor/research material is promoted to product without gates, caller chain, or visible proof |

## Lane Chronicle

### Product / MAS

| Item | Status | Missing proof |
|---|---|---|
| Vault Context Contract / F-VaultRecall-50 | `implemented-not-wired` to partial visible, depending branch | All retrieval entry points enforce contract; diagnostics row; no first-N fallback |
| Eidos V0 | `implemented-not-wired` | Swift FFI bridge, ChatCoordinator/Brain Panel callers, fake-citation rejection at product seam |
| Eidos Form Layer / T10B | `not-implemented` or branch-local pending audit | Stable form mapping for at least one real object and caller-chain proof |
| System G / Agent Runtime v2 | `implemented-not-wired` | Swift bridge, MAS-bounded behavior, RunEventLog and AnswerPacket visible path |
| AnswerPacket / provenance surfaces | mixed `current-wired` substrate and `implemented-not-wired` UI | Per-row chat badge, provenance cards in multiple surfaces, closed citations |
| T27 WRV surfacing | `not-implemented` until P0 W-rows get code/UI/tests | First three P0 W-rows wired, reachable, visible, verified |

### Pro

| Item | Status | Missing proof |
|---|---|---|
| CLI/MCP/browser/tool execution | design-preserved, not product-shipped by default | Real entitlement/capability gate, MAS symbol cleanliness, no unconditional dispatcher |
| Obscura/deno_core/Eidos Plus | `excluded-speculative` or Pro-deferred | Bounded in-process capability model and explicit user-facing gate |
| Pro tier labels in ledgers | design intent unless gates exist | StoreKit/receipt/capability integration or labels downgraded |

### Research / Omega

| Item | Status | Missing proof |
|---|---|---|
| EML/IR and T5 | large branch-local implementation, split required | Per-IR PRs, `EML-LEAN-VENDOR`, current-main verification |
| F-ULP Oracle / T12 | `implemented-not-wired` research gate | Single canonical path, M2 Pro timing/artifact, Metal/doc alignment |
| KV-Direct / T13 | `not-implemented` or branch-local pending audit | Reference vs residual/mmap/NF4 comparison and artifact |
| Five Metal kernels / V6.2 falsifiers | mostly `not-implemented` target-only | CPU references, Metal kernels, correctness/perf artifacts |
| 70B local cocktail | `excluded-speculative` / harness-only | Research harness artifacts before any execution claim |

### Vault

| Item | Status | Missing proof |
|---|---|---|
| RRF/Halo/Shadow search base | mixed current substrate and feature-flagged surfaces | Exact current-main caller-chain audit and visible provenance consistency |
| Eidos closed citations | `implemented-not-wired` | Source IDs shown to user; fake IDs rejected before commit |
| Brain Panel closed citations / T22B | `not-implemented` | "Retrieved by Eidos" source display, offline proof, missing-source rejection |
| Vault recall health row | `not-implemented` | Diagnostics surface populated by real metrics |

### Infrastructure

| Item | Status | Missing proof |
|---|---|---|
| Product architecture ledger / T09 | useful docs-only loop | Squash, cadence rule, durable updates only on real status change |
| Falsifier handbook / T23B | useful docs-only loop | Replace stale stubs with canonical cross-links; commands/artifacts for each gate |
| Phase definitions | missing durable D2 doc | D2 canonical definitions and gates |
| Next-action map | missing durable D3 doc | D3 ranked ledger by spine criticality, user value, dependency |
| Donor mining | donor-only | Explicit spine caller chain and no hidden cloud/subprocess behavior |

## WRV Checklist for Future Readers

Before changing a status to `current-wired` or `visible-working`, record:

1. Wired: the real production caller chain, not a fixture-only path.
2. Reachable: how the user or runtime reaches it without private setup.
3. Visible: the UI, log, artifact, or documented proof surface.
4. Verified: the exact test, command, screenshot, or artifact path.
5. Fallback: behavior when feature flag is off, input is empty, IDs are stale,
   unicode appears, no result exists, or a repeated call happens.
6. Boundary: MAS/Pro/Research/Vault/Infrastructure lane and build gate.
7. No hidden behavior: no silent cloud fallback, hidden subprocess, or
   aspirational caller chain.

## Unstarted Spine-Critical Tracks to Spec First

These are tempting because they unlock visible value. Do not implement them
from this chronicle alone. They need D2/D3 control docs or their own PR-sized
specs first.

| Track | Why spine-critical | Current classification | First proof needed |
|---|---|---|---|
| T14 UAS addressing | Gives notes, events, graph nodes, retrieval hits stable substrate identity | `not-implemented` / merge-gated | `UasAddress` and plane tags in a real consumer |
| T22 Substrate Health | Makes architecture inspectable to users | `not-implemented` / Phase 2 | Read-only panel with missing-subsystem fallback |
| T22B Brain Panel citations | Makes retrieval/citation honesty visible | `not-implemented` | Fake citation rejected; loaded Eidos sources shown |
| T27 WRV surfacing | Converts P0 W-rows from substrate to product | `not-implemented` | First three P0 rows get code, UI, tests |
| T10B Eidos Form Layer | Canonical object identity/schema layer | `not-implemented` or branch-local | Stable form for one current object and status label |
| T13 KV-Direct | Research memory-floor falsifier | `not-implemented` | Reference-vs-test path artifact on M2 Pro |

## Do Not Start Yet

Do not start these from this terminal:

- Donor simulation visuals, sprite/rendering work, or companion theater.
- Quick Capture `route/`, `heal/`, `format/`, `effect/`, `undo/`, or branch
  `nightbrain` merges before T11 dispatch reconciliation.
- Biometric lock code. T8 remains doctrine-only until prerequisites land.
- 70B execution, model surgery, active rank-one runtime, PCF runtime
  acceleration, or major Metal kernel claims before falsifier gates pass.
- Pro-tier CLI/MCP/browser/iMessage execution without real entitlement and
  capability gates.
- Any new EML ontology rewrite. EML is not the whole ontology.
- Any ACS rename or bare "ACS" wording. Preserve both expansions:
  ACS (Autopoietic Cognitive Stack) for process/governance lineage, and
  ACS (Anchored Cognitive Substrate) for structure/code lineage.
- Any branch merge that the canon says requires Jojo authorization.

## Drift Guards

- A future doc that says "everything is EML" contradicts this chronicle.
- A future doc that says "everything becomes typed/addressable/witnessed" is
  aligned only if it also names UAS, Eidos, System G, ACS, WBO, EML, falsifiers,
  and WRV as distinct roles.
- A future status ledger must include missing proof and falsification criteria.
- A `PARTIAL` branch claim must be revalidated against current main.
- A docs-only loop must not block code-bearing spine work.
- A code-bearing substrate must not claim product value until a user-reachable
  surface or documented proof exists.

## Chronicle Classification

Product-runtime classification: not applicable. This document has no runtime
caller chain and intentionally makes no code ship claim.

Docs/canon classification: `visible-working`. The file exists at the canonical
D1 path, cites the local source set, separates lanes/status/missing proof, and
is readable by other terminals. It is not yet index-wired unless a future docs
index PR links it.

Self-audit loop result:

- What exists: one canonical chronicle under `docs/**`.
- Fixture/stub/status-only: all branch and audit claims remain status evidence
  unless merged and caller-chain verified.
- Real production caller chain: none for this document; that is expected for a
  docs/canon control artifact.
- Missing WRV: runtime WRV remains on the product W-rows, not this doc. Doc
  proof is path reachability, source citations, required drift guards, and
  whitespace/search verification.
- Hardened paths: empty input, no-result/nil path, unicode, stale or invalid
  IDs, rapid toggle/repeated call, feature-flag-off fallback,
  fixture-vs-production confusion, and no hidden cloud/subprocess behavior are
  captured as future WRV checklist obligations.

Verified in this PR-sized unit:

- Source set read.
- `docs/CANONICAL_CHRONICLE_2026_05_23.md` created under `docs/**`.
- No code files touched.
