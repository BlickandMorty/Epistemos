# Preparation Packet Correction Log — 2026-07-11

PREPARATION ONLY — subordinate to the July 8 MAS master canon. This document does not change the active execution key or prove implementation.

Owner correction directive (same day, adjudication-only pass): remain in
preparation mode; revise only this directory; no repo modification, builds,
tests, archives, launches, model loads, provider requests, secrets, audio,
Computer Use, or key changes. All six corrections below were applied. Where a
correction concerned a source-of-truth claim, the exact call site was
re-verified with a narrowly scoped `rg` before rewriting (adjudication
evidence, not a new research cycle). Where older text in the other packets
conflicts with this log, this log wins.

---

## 1. Quick Capture persistence route

- **Original claim (Capability packet §1.2, contradiction C5, handoff Cycle 4):**
  "Quick Capture persists via `NoteFileStorage`/`SDPage` (line 15 comment) +
  graph writes — NOT via `AtomicVaultWriter` … CONTRADICTED (vs canon 07) →
  REQUIRES KEELSTONE … capture route flips then," with batch CR-2 defined as
  a route flip.
- **Evidence contradicting it:** the claim rested on the stale header comment
  at `Epistemos/Engine/TextCapturePipeline.swift:15`. Verified current call:
  `TextCapturePipeline.swift:779` — `let pageId = await
  bootstrap.vaultSync.createPage(...)`; `VaultSyncService.createPage`
  (`Epistemos/Sync/VaultSyncService.swift:4696`, with a `frontMatter:`
  parameter) creates the `SDPage` and exports the vault-backed Markdown
  through the current vault/index write path (owner-attested; call-site
  verified).
- **Corrected classification:** EXISTING VAULT-BACKED ROUTE AT SOURCE LEVEL +
  RUNTIME CRASH/RESTORE/PROVENANCE EVIDENCE PENDING.
- **What was preserved:** proposed zero-loss, crash, enrichment-failure, and
  route-journal tests (T-CR-2/3, reworded to exercise the existing route).
  No source-route rewrite is prescribed unless a later focused test proves
  one necessary.
- **Files updated:** `CAPABILITY_RING_IMPLEMENTATION_PACKET.md` (§1.2 row,
  §3 bullets, batch CR-2), `CONTRADICTION_AND_PROVENANCE_MAP.md` (C5
  withdrawn), `TEST_FIXTURE_AND_ACCEPTANCE_MATRIX.md` (T-CR-2),
  `LOW_RAM_PREPARATION_HANDOFF.md` (Cycle 4 annotation + final summary).
- **Remaining uncertainty:** runtime crash/restore behavior, provenance/
  route-journal linkage completeness, and whether `createPage`'s export path
  covers every capture modality (voice/screenshot) — all runtime-evidence
  items, not assumed defects.

## 2. Stable-ID system

- **Original claim (seam map §2.2, contradiction C10, handoff Cycle 1):**
  "no dedicated stable-ID minting layer found … Classification: MISSING
  (additive KEELSTONE hybridize item)."
- **Evidence narrowing it:** the sweep used the wrong token (`stableID`).
  Existing carriers per owner correction, partially re-verified: `SDPage.id`;
  frontmatter `id` import restoration with duplicate-file collision handling
  (`VaultSyncService.createPage(frontMatter:)` verified at :4696; restoration/
  collision behavior owner-attested); `_epdoc_id` (verified present in
  `EpdocMarkdownWriteThrough.swift` and `VaultIndexActor.swift`);
  `EpdocNotebookManifest` IDs; capture `traceID`/`mutationID`/`noteID`
  (verified at `TextCapturePipeline.swift:140,452,465`, incl.
  `mutationID: "capture-<traceId>"`).
- **Corrected classification:** PARTIALLY IMPLEMENTED.
- **Remaining work (recorded separately, per owning phase):** prove note-ID
  survival across rename, move, export, import, cache rebuild; define dataset
  IDs when RECKONER is implemented; define ResearchHub source ID + vault ID
  when ResearchHub is implemented; ensure captures retain
  capture/mutation/note identity and route-journal linkage. No new global
  stable-ID framework unless those tests prove the current contracts
  insufficient.
- **Files updated:** `CANONICAL_DEPENDENCY_AND_SEAM_MAP.md` (§2.2),
  `CONTRADICTION_AND_PROVENANCE_MAP.md` (C10 narrowed),
  `LUMENLENS_RECKONER_IMPLEMENTATION_PACKET.md` (§3, RK-1),
  `CAPABILITY_RING_IMPLEMENTATION_PACKET.md` (§3),
  `LOW_RAM_PREPARATION_HANDOFF.md` (Cycle 1 annotation).
- **Remaining uncertainty:** survival semantics of each carrier under
  rename/move/import/export/rebuild are unproven (that is exactly the
  proposed test surface).

## 3. Local GGUF owner decision

- **Original claim (contradiction map §4 item 3, handoff Cycle 1):** "Local-
  model surface ships in v1 or deferred" listed as an open canon-09 owner
  decision.
- **Evidence superseding it:** a later explicit owner steer resolved it:
  preserve the selected local GGUF models; keep them June-owned; keep
  OpenAI/Anthropic cloud choices; prove linkage, memory admission,
  cancellation, teardown, and actual output; do not broaden the selected
  model catalog. (Consistent with the 2026-07-10 closeout steers and the
  release gate's new GGUF-linkage rejection.)
- **Corrected state:** removed from the open owner-decision list; recorded as
  a settled steer with its proof obligations.
- **Files updated:** `CONTRADICTION_AND_PROVENANCE_MAP.md` (§4),
  `LOW_RAM_PREPARATION_HANDOFF.md` (Cycle 1 annotation).
- **Remaining uncertainty:** none on the decision itself; the proof
  obligations (linkage, admission, cancellation, teardown, output) remain
  KEELSTONE/June runtime-evidence items.

## 4. Symbol and shim hygiene (C1 / C4)

- **Original claim (June packet §5.1/§5.3, batch J0, T-J0-1, seam-map
  parallelization note):** broad `Goose*`→`JuneAgentCore*` rename presented
  as the preferred default first batch; shim rename presented as a co-equal
  option.
- **Evidence narrowing it:** owner correction — evidence-first. No current
  archive scan has yet attributed a gate failure to these identifiers (the
  retained artifact's 12 findings name GGUF linkage, one parked
  account/backend marker, JuneWeb staleness, and privacy entries; exact
  offending identifiers must be enumerated from the exact current scan).
- **Corrected rule:** run the exact current archive scan; identify the exact
  offending symbols/resources; rename ONLY identifiers that make the current
  artifact gate fail; otherwise preserve internal compatibility and document
  narrowly justified exceptions. Same rule applies verbatim to
  `tauri-internals-shim.js`.
- **Files updated:** `JUNE_MINICHAT_IMPLEMENTATION_PACKET.md` (§5.1, §5.3,
  batch J0, §7), `TEST_FIXTURE_AND_ACCEPTANCE_MATRIX.md` (T-J0-1),
  `CONTRADICTION_AND_PROVENANCE_MAP.md` (C1, C4 resolutions),
  `LOW_RAM_PREPARATION_HANDOFF.md` (final summary finding 2).
- **Remaining uncertainty:** which identifiers, if any, actually fail the
  current gate — answerable only by the exact scan inside KEELSTONE's
  evidence chain.

## 5. KEELSTONE boundary

- **Original claim (handoff final summary finding 1, seam-map §2.2):**
  preparation findings framed as "additive design items surfaced for
  [KEELSTONE's] hybridize verdict," implying preparation can add KEELSTONE
  implementation scope.
- **Corrected statement (verbatim rule now embedded in the seam map, June
  packet J0, and handoff):** "Resume KEELSTONE through its existing exact
  evidence chain first. A preparation finding may become implementation work
  only when a current focused test, artifact gate, or runtime check proves
  the corresponding canonical defect."
- **Files updated:** `CANONICAL_DEPENDENCY_AND_SEAM_MAP.md` (§1),
  `JUNE_MINICHAT_IMPLEMENTATION_PACKET.md` (J0),
  `LOW_RAM_PREPARATION_HANDOFF.md` (final summary finding 1).
- **Remaining uncertainty:** none; this is a standing boundary rule.

## 6. Parallelism

- **Original claim (seam map §5, handoff "Safe parallelization" section,
  final chat summary):** identified batches "safe to parallelize" within
  phases.
- **Evidence narrowing it:** owner selected one-agent sequential work.
- **Corrected state:** both sections retitled "Parallelization analysis —
  NOT AUTHORIZED (historical planning information only)"; content retained
  solely as historical planning information.
- **Files updated:** `CANONICAL_DEPENDENCY_AND_SEAM_MAP.md` (§5),
  `LOW_RAM_PREPARATION_HANDOFF.md` (final summary section).
- **Remaining uncertainty:** none.

---

## Unchanged by this correction pass

Active execution key (`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`,
INCOMPLETE); the repo worktree (read-only; two adjudication `rg` probes only);
all other classifications, batches, tests, and contradictions (C2, C3, C6–C9,
C11, C12); the canon build order; the remaining owner decisions (StoreKit
shape, ResearchHub provider subset, `files (5).zip` salvage).
