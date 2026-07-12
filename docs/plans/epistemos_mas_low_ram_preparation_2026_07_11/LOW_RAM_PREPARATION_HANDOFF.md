# Low-RAM Preparation Handoff — 2026-07-11

PREPARATION ONLY — subordinate to the July 8 MAS master canon. This document does not change the active execution key or prove implementation.

Active execution key (unchanged): `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` — INCOMPLETE, awaiting a safe resource window for the one-serial-archive + runtime-matrix evidence chain.

This file is updated after each preparation cycle.

---

## Cycle 1 — Canonical dependency graph and shared-contract map (COMPLETE)

Files inspected (read-only):
- Canon 00–10 (all), `manifest`-level listing of canon dir.
- `docs/plans/keelstone/HANDOFF_OWNER_STEERS_CLOSEOUT_2026_07_10.md`,
  `KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`.
- Repo layout (`Epistemos/` modules, test targets, `scripts/`).
- `project.yml` (targets/macros/prebuild), `Epistemos-AppStore.entitlements`,
  `Resources/PrivacyInfo.xcprivacy` (head).
- June seam: all 20 `Epistemos/JuneAgent/*` file names + interfaces of
  `JuneSessionStore`, `JuneMASToolPolicy`, `JuneAgentApprovalRegistry`,
  `JuneEpdocAssist`, `JuneCloudEngine`; `Epistemos/Goose/GooseMASAgentCoreRunner.swift` head.
- Contracts: `AtomicVaultWriter` callers, provenance owners
  (`agent_core/src/provenance/*`, incl. `suggestion_schema.rs` interface),
  `agent_core/src/tools/registry.rs` MAS gating, allowlist plumbing
  (`bridge.rs`), routing owners, Keychain/consent owners, reconcile owners,
  `NoteSessionStateMachine` shape, `MutationOpLogReplay` shape.

Requirements traced: the nine shared contracts each have a named current
source owner (see `CANONICAL_DEPENDENCY_AND_SEAM_MAP.md` §2); stable-ID layer
classified MISSING [CORRECTED 2026-07-11 → PARTIALLY IMPLEMENTED; see
`PREPARATION_PACKET_CORRECTION_LOG.md` §2]; everything else EXISTING or
PARTIALLY IMPLEMENTED at text level.

Contradictions found (carried to CONTRADICTION_AND_PROVENANCE_MAP.md):
1. Active MAS June runner lives in parked-named files
   (`Epistemos/Goose/GooseMASAgentCoreRunner.swift`,
   `GooseInProcessACPServer.swift`) while canon 04/08 archive leak scans grep
   case-insensitively for "goose". Symbol names will trip string scans.
2. `agent_core/src/tools/` still compiles parked-lane tool sources
   (terminal/stdio_mcp/browser*/computer_use/cli_passthrough); MAS safety is
   allowlist + runtime preflight, not build exclusion.
3. Three message stores exist (JuneSessionStore App-Support JSON, SDChat GRDB,
   vault `chats/*.json`); canon demands one June transcript authority.
4. Privacy manifest declares 2 collected-data types while the retained-archive
   gate flagged 2 collected-data findings — needs reconciliation at next gate
   run (log at /tmp may be gone).

Unresolved questions: StoreKit/proxy monetization shape; ResearchHub provider
subset for v1; local-model ship-or-defer for v1 [CORRECTED 2026-07-11 —
resolved by a later explicit owner steer and removed from the open list; see
correction log §3]; salvage of `files (5).zip` storage code.

Next cycle: June/MiniChat requirements, source ownership, tests, missing seams.

---

## Cycle 2 — June/MiniChat (COMPLETE)

Files inspected: `JuneAgentBridge.swift` (command surface),
`JuneAgentGateway.swift` (literal-send + `prompt.forge_preview` rejection at
101–108, agent_core stream plumbing), `JuneWebAssets.swift` (full),
`build-june-web.sh` (head: service-worker refusal, unlicensed-font exclusion,
June-identity string validation), `.june-web-stage/` listing,
`JuneToolEventBounds.swift`, `EpdocCopilotDockView.swift` (submit path),
`JuneEpdocAssist.swift` interface, `GooseMASAgentCoreRunner.swift` head, test
inventories: `AppStoreJuneSubstrateHardeningTests` (17 tests),
`JuneWorkspaceAgentSourceGuardTests` (14 tests), `EpdocCopilotSurfaceTests`
(9 tests), `AppStoreJuneSourceGuard`.

Requirements traced: R1–R11 in `JUNE_MINICHAT_IMPLEMENTATION_PACKET.md` §1–2.
Headline: "MiniChat" does not exist as a symbol; the seam is
`EpdocCopilotDockView` + `JuneEpdocAssist`; the phase is close-gaps +
prove-it, not green-field.

Contradictions found: (1) active-lane `Goose*` symbols vs. "goose" archive
scans; (2) `hermes_bridge_*` wire tokens are June-fork protocol names — keep +
document; (3) `tauri-internals-shim.js` filename vs. "tauri" scan tokens —
gate-policy or rename decision; (4) StoreKit/monetization branch undefined
(owner decision), receipt proxy correctly parked behind
`EPISTEMOS_LEGACY_RECEIPT_PROXY`.

Unresolved questions: child-session ledger-linkage fields (batch J1); approval
affordance inside the dock (batch J2); consent UX on first assist cloud turn
(runtime).

Next cycle: LumenLens/Reckoner requirements, workspace contracts, tests, seams.

---

## Cycle 3 — LumenLens/Reckoner (COMPLETE)

Files inspected: `js-editor/src/bridge/document-load-state.ts` + `inbound.ts`
(named), `js-editor/src/markdown/tiers.ts` (tier catalog),
`js-editor/src/suggestions/SuggestionAdapter.ts` (named),
`Epistemos/Engine/QuarantineArchive.swift`, `EpdocMarkdownWriteThrough.swift`,
`EpdocAIDiffReview.swift`, `Epistemos/Views/Notes/EditorProvenanceStore.swift`
(+ its 12 test names), `LensFidelityDisclosure.swift`,
`EpdocNotebookManifest.swift`, `NoteSessionStateMachine.swift`; vendoring
probes (`LocalPackages/`, `Epistemos/Vendor/` empty, `project.yml`); conflict
owners; `import Charts` sweep (zero hits).

Requirements traced: full LUMENLENS obligation table + full RECKONER
obligation table in `LUMENLENS_RECKONER_IMPLEMENTATION_PACKET.md` §1–2.
Headline: LUMENLENS = verify-and-harden (all obligations have source);
RECKONER = build phase (grid/calc/charts/dataset-writer all MISSING; only
seam hooks exist).

Contradictions found: C-LL-1 — two suggestion/provenance representations
(`EditorProvenanceStore.swift` vs `suggestion_schema.rs`) vs canon F5
"no parallel schemas" — unification batch LL-2 required before RECKONER
staging; Plan 9's "in-tab agent chat" and "GRDB truth" REJECTED by canon 06.

Unresolved questions: `EpdocNotebookTabKind` dataset case existence; IronCalc/
Univer licensing + bundling facts (official-source validation queued §6).

Next cycle: Capability Ring requirements, provider legality, storage
dependencies, tests, missing seams.

---

## Cycle 4 — Capability Ring (COMPLETE)

Files inspected: `JuneMASToolPolicy.swift` (full — exact 10-tool allowlist +
forbidden fragments + obfuscated "docker" matcher), `Arxiv/ArxivClient.swift`
(host allowlist, rate limiter, canonical-ID checks), `ArxivPullGateStatus.swift`,
`Views/Capture/QuickCaptureView.swift` + `QuickCaptureReadBack.swift` +
`Engine/TextCapturePipeline.swift` (write route), STT/Vision/PDF owners
(`EpistemosSpeechAnalyzer`, `LiveVoiceInputService`, `LiveTextImageView`,
`NoteImageProcessor`, `LiteParse/SourcePDFViewer`), browser surfaces
(`BrowserCapabilityStatus`, `BrowserTrackerContentBlocker`),
`Sync/iCloudMaterializer.swift` (placeholder handling), skills machinery
(`agent_core/src/skill_discovery/`, `nightbrain/live.rs`,
`Vault/SkillVaultFileIO.swift`, `SkillDiscoveryCatalog.swift`).

Requirements traced: full tables in `CAPABILITY_RING_IMPLEMENTATION_PACKET.md`
§1. Headline: PDF/Vision/STT/sync-placeholder/skills machinery EXISTING or
PARTIAL; ResearchHub multi-source + RSS lane MISSING; arXiv adapter
PARTIALLY IMPLEMENTED (needs the six-part adapter record).

Contradictions found: Quick Capture persists via `NoteFileStorage`/`SDPage`
(TextCapturePipeline comment line 15), not `AtomicVaultWriter` — CONTRADICTED
vs canon 07 until KEELSTONE's body-truth collapse (canon 04 migration step 3)
lands [WITHDRAWN 2026-07-11 — that header comment is stale; current source
persists via `vaultSync.createPage` (`TextCapturePipeline.swift:779`);
reclassified EXISTING VAULT-BACKED ROUTE AT SOURCE LEVEL + runtime evidence
pending; see correction log §1]; browser tools stay allowlist-forbidden while
`browser*.rs` sources still compile (same pattern as Cycle 1 finding 2).

Unresolved questions: v1 ResearchHub provider subset (owner decision);
X/Reddit BYO terms volatility; visible-recording indicator runtime proof.

Next cycle: cross-phase contradiction sweep and integration-order audit.

---

## Cycle 5 — Cross-phase contradiction sweep and integration-order audit (COMPLETE)

Files inspected: `docs/prompts/` listing, `MASTER_PLAN_INDEX_2026_07_03.md`
(superseded banner verified), `MAS_EXECUTION_STATUS_2026_07_10.md` (five-key
table + strict order verified). All cross-cycle contradictions consolidated
into `CONTRADICTION_AND_PROVENANCE_MAP.md` (register C1–C12); all proposed
tests consolidated into `TEST_FIXTURE_AND_ACCEPTANCE_MATRIX.md` (5 shared
fixtures; T-J0..J3, T-LL-1..6, T-RK-1..7, T-CR-1..7).

Requirements traced: every canonical requirement across the three future IDs
now has a source owner (or explicit MISSING classification), a dependency, a
proposed verification method, and a status classification — the task's
stop-searching condition is met.

Contradictions found this cycle: none new; key-set consistency confirmed
(program-director key complete-for-alignment; four task IDs = active + three
future, in status-doc order).

Unresolved questions: the four canon-09 owner decisions plus the two small
June-phase naming decisions (C1 rename-vs-allowlist, C4 shim filename).

---

# FINAL HANDOFF SUMMARY

## What exists now

Eight preparation files in
`/Users/jojo/Downloads/epistemos_mas_low_ram_preparation_2026_07_11/`,
produced read-only (zero modifications under `/Users/jojo/Downloads/Epistemos`;
no builds, tests, archives, launches, model loads, provider requests, or
parallel agents were run).

## Dependency findings (one paragraph each)

1. **KEELSTONE (active, incomplete):** the only open work is the exact
   evidence chain (one serial archive → artifact gates → finite runtime
   matrix), blocked 2026-07-10 by swap preflight. Resume KEELSTONE through
   its existing exact evidence chain first. A preparation finding may become
   implementation work only when a current focused test, artifact gate, or
   runtime check proves the corresponding canonical defect. (The two items
   previously framed here as "additive design items" were corrected on
   2026-07-11: C5 withdrawn, C10 narrowed — see the correction log.)
2. **June/MiniChat:** mostly built. `EpdocCopilotDockView` + `JuneEpdocAssist`
   + gateway→`agent_coreFFI` + one allowlist + approval registry + App-Support
   session store all exist with substantial test coverage (17+14+9 named
   tests). The phase is close-gaps (child-session linkage, applied-hash +
   undo, consent inheritance) + evidence-first scan adjudication for C1/C4
   (rename only identifiers the current artifact gate fails on) + the
   canon-05 runtime evidence list.
3. **LUMENLENS/RECKONER:** sharply asymmetric. LUMENLENS = verify-and-harden
   (epoch guard, serializer tiers, quarantine, minimal-diff writeback,
   disclosure, notebook manifests all present); RECKONER = build (no grid,
   no calc engine, no charts, no dataset writer). The Rust suggestion schema
   already models tabular ranges — the C6 unification (LL-2) is the critical
   pre-RECKONER step.
4. **Capability Ring:** PDF/Vision/STT/sync-placeholder/skills substrate
   largely exists; ResearchHub beyond arXiv and the RSS lane are missing;
   the arXiv adapter needs only its six-part adapter record. The one tool
   surface to extend is `JuneMASToolPolicy` + `agent_core/src/tools/`.

## Parallelization analysis — NOT AUTHORIZED (historical planning information only)

Owner correction 2026-07-11: the owner selected one-agent sequential work.
The analysis below is retained solely as historical planning information and
grants no authorization to parallelize.

- Inside June/MiniChat: J0 symbol rename ∥ J1 session linkage ∥ JuneWeb asset
  refresh — disjoint files.
- Inside LUMENLENS/RECKONER: LL-1 test backfill ∥ RK-1 dataset artifact truth
  (after LL-2 schema unification lands); LL batches touch `Views/Notes` +
  `Engine/Epdoc*`, RK batches touch new files.
- Inside Capability Ring: CR-1 arXiv record ∥ CR-3 sync tests ∥ CR-6 browser
  guard ∥ CR-7 skills surface — mutually disjoint; CR-2 is a runtime-evidence
  pass on the existing capture route (corrected 2026-07-11, no flip); CR-4
  waits on the owner provider decision.
- NOT parallelizable: anything vs. the KEELSTONE evidence chain (serial,
  resource-capped, one archive at a time); LL-2 vs. RK-5 (schema authority
  must land first); any two `xcodebuild` invocations (hard rule).

## Boundaries honored

KEELSTONE was not completed or attempted; no execution key changed; nothing
was implemented; review here is preparation, not hardening proof. Every
classification is text-level and inherits REQUIRES RUNTIME EVIDENCE until the
owning phase runs its evidence chain.

---

## Codex audit corrections applied — 2026-07-11

An owner adjudication pass corrected this packet after delivery. Full detail,
verbatim original claims, and evidence: `PREPARATION_PACKET_CORRECTION_LOG.md`
(authoritative where older text conflicts). Summary:

1. **Quick Capture** — CONTRADICTED/route-flip claim WITHDRAWN (stale header
   comment); reclassified EXISTING VAULT-BACKED ROUTE AT SOURCE LEVEL
   (`vaultSync.createPage`, `TextCapturePipeline.swift:779`) + runtime
   crash/restore/provenance evidence pending; tests retained, no rewrite
   prescribed.
2. **Stable IDs** — MISSING → PARTIALLY IMPLEMENTED (`SDPage.id`, frontmatter
   `id` restoration + collision handling, `_epdoc_id`, manifest IDs, capture
   `traceID`/`mutationID`/`noteID`); remaining work is survival proofs +
   per-phase ID definitions; no new global framework unless tests fail.
3. **Local GGUF** — removed from open owner decisions; later owner steer is
   settled (preserve selected June-owned GGUF models + cloud choices; prove
   linkage/admission/cancellation/teardown/output; don't broaden catalog).
4. **Symbol/shim hygiene** — broad Goose→June rename demoted from default
   batch; evidence-first rule installed (scan → rename only gate-failing
   identifiers → document narrow exceptions), same for
   `tauri-internals-shim.js`.
5. **KEELSTONE boundary** — standing rule embedded: resume KEELSTONE through
   its existing exact evidence chain first; a preparation finding becomes
   implementation work only when a current focused test, artifact gate, or
   runtime check proves the corresponding canonical defect.
6. **Parallelism** — all parallelization analysis relabeled NOT AUTHORIZED
   (historical planning information only); owner selected one-agent
   sequential work.

Files updated in this pass: seam map, all three implementation packets, test
matrix, contradiction map, READ_FIRST index, this handoff; correction log
created. Repo untouched (two adjudication `rg` probes only).
