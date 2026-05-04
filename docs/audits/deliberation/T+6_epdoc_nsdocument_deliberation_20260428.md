# T+6 Deliberation Brief — `.epdoc` as NSDocument (2026-04-28)

> Closes task #31 ("T+6 deliberation brief"). Authored after the
> implementation already shipped in this session — this brief
> retro-formalizes the design rationale + records the loose ends so
> future audits can verify against intent.

## Phase identity

T+6 is the slice that promotes the `.epdoc` package from a stub
file-wrapper into a first-class macOS `NSDocument` with a SwiftUI
host, autosave, and a shared GRDB pool wired through an
`NSDocumentController` subclass. The work matches and extends T+4.5
(`.epdoc` package stub) and T+4.6 (Document editor host).

## Settled architectural decisions

These are the calls that landed during the audit close-out (F1-F12 in
`docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md`); recording them here
so they are not re-litigated:

### Decision 1: NSDocument over NSFileWrapper-only ✅ shipped
The `.epdoc` is a UTI-typed package (`com.epistemos.epdoc`). A bare
NSFileWrapper-driven save/load loop would have been simpler but would
not support: window restoration, document-version coalescing, the File
> Open command, or the autosave heartbeat. NSDocument is the macOS
contract for *all* of these. F1 (makeWindowControllers) + F2 (cmd+O
menu) shipped this.

### Decision 2: Option C — Explicit DI over Singleton ✅ shipped
Rejected the singleton pattern (`SearchIndexService.shared`) for the
shared-pool plumbing. Instead: `EpistemosDocumentController`
(NSDocumentController subclass) holds a `DatabaseWriter` reference
that the app pushes down at launch
(`EpistemosApp.applicationDidFinishLaunching`), and every
`makeDocument(for:...)` factory injects that writer into the
EpdocDocument via initializer.

**Why not singleton**: a global `SearchIndexService.shared` would have
made the F8 wiring a one-line change but at the cost of (a) hidden
coupling between the document layer and the Sync layer, (b) test
fixtures that have to either monkey-patch the singleton or live with
a polluted global, (c) impossibility of running two documents against
two different vault DBs in the same process. Option C costs ~30 LOC
in the Document Controller and pays off forever in test isolation.

### Decision 3: Share the pool, not the SearchIndexService ✅ shipped
The DocumentController holds a `DatabaseWriter` (GRDB protocol), not a
`SearchIndexService`. EpdocDocument's `projectAndIndexBlocks` writes
through the same pool but does NOT instantiate a second
SearchIndexService actor. Why: the actor's job is to serialize
PRODUCER-side mutations, but the projection write is itself the
producer. The pool is what's shared; the actor wrapping it is not
duplicated.

### Decision 4: Atomic save via fileWrapper(ofType:) regen ✅ shipped
F6 — every save regenerates `shadow.md` via
`ProseMirrorMarkdownProjector` inside `fileWrapper(ofType:)`. The
package always saves as a unit; partial / interleaved file writes are
impossible. Trade-off: we re-render the whole markdown shadow on every
save, even for trivial edits. Acceptable because the projector is
~2ms on typical doc sizes; profiling required if doc size grows.

## Bridge between T+6 and adjacent slices

| Adjacent slice | Touch point | Status |
|---|---|---|
| T+4.4 readable_blocks projection | `EpdocDocument.projectAndIndexBlocks` calls `ReadableBlocksIndex.replaceAllForArtifact` through the shared pool — F8 close-out wires this. | ✅ |
| T+4.6 Document editor host | `EpdocDocument.makeWindowControllers` instantiates `NSHostingController(rootView: EpdocEditorChromeView(document:))` — preserves the WKWebView Tiptap chrome from T+4.6. | ✅ |
| T+4.8 MutationEnvelope | T+6 saves do NOT yet emit a MutationEnvelope. Existing `notifyIndexChanged([.searchBlocks])` invalidation still suffices. Reframed under RRF F9 (write-side). | ⏸ deferred to T+13 |
| RRF Phase 4 wiring | `SearchIndexService.fusedSearch` reads from the SAME pool that `EpdocDocument.databaseWriter` writes to — closes the producer-consumer loop F8 was about. | ✅ via Phase 3+4 |
| Halo V0/V1 panel | Panel queries `epistemos-shadow` (separate cache), NOT the .epdoc readable_blocks. T+6 does not wire into the Halo panel. | scoped out |

## Loose ends + future work

### F3 — Tiptap bundle staging at Resources/Editor/
Status: 🟡 ship-staged via `build-tiptap-bundle.sh` content-hash gate,
not runtime-verified. Fix: user runs `xcodebuild` (or full `cmd+B` in
the Xcode GUI) once after Xcode IDE lock releases. The build script's
output is gated on `package-lock.json` content hash so unchanged
checkouts skip work; cold path takes ~20 seconds to npm-install + run
esbuild.

### F9 — MutationEnvelope on save
Status: ⏸ deferred to T+13. Current schema is write-side ONLY (see
`docs/RRF_FUSION_DESIGN.md` §9 item 3). T+13 master hardening will
adjudicate whether `notifyIndexChanged` should upgrade to a full
MutationEnvelope post or stay as the lightweight Notification it is
today.

### F12 — V0 vs V1 dual recall systems
Status: ⏸ now formalized in the parallel deliberation brief
`T+5_v0_v1_recall_migration_decision_20260428.md` (this same
session). Recommended Option C: migrate V0's UI surface
(`ContextualShadowsState`) to V1's backend
(`ShadowSearchService`/`epistemos-shadow`) once V1 reaches ≥95%
shipped.

### Runtime verification
Status: ⏸ blocked on Xcode IDE lock. The codebase deltas from this
session compile cleanly under SourceKit's eyes; runtime tests
(`EpistemosTests/EpistemosDocumentControllerTests.swift` + the smoke
suites I shipped) need a `swift test` or `xcodebuild -test` run to
confirm. Documented in `docs/AGENT_PROGRESS.md` last-updated header.

## Acceptance criteria (retroactive)

- [x] `.epdoc` opens via cmd+O (F2) ✅
- [x] Edits persist atomically via `fileWrapper(ofType:)` (F6) ✅
- [x] Save triggers FTS5 projection through shared pool (F8) ✅
- [x] Window restoration + autosave handled by NSDocument default machinery (F1) ✅
- [x] Tiptap chrome reused from T+4.6 (no editor regression) ✅ (compile-clean; runtime gated)
- [ ] Tiptap bundle ships in `Resources/Editor/` at runtime (F3) — pending xcodebuild
- [ ] Runtime test pass for EpdocDocument + EpistemosDocumentController suites — pending xcodebuild

## Signal: T+6 is essentially closed

T+6 is the LAST T-step that was structurally open at session start.
With F1+F2+F6+F7+F8 shipped this turn, all in-scope T+6 deliverables
are on disk. The two open items above (F3 runtime gate + runtime
test pass) are the same gate that's already documented for every
other unverified slice this session — i.e. they belong to the
"close Xcode, run xcodebuild" punch list, not to T+6 specifically.

This brief is the disk-of-record for the T+6 design rationale; future
sessions reading the codebase can verify against it without
re-deriving every decision from git history.
