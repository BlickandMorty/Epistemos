# MD-V2 inversion — grounded design (2026-06-21)

North-star pillar (§343/§389): **Markdown is the robust SOURCE OF TRUTH; HTML/JSON are dynamic PROJECTIONS.**
This note grounds the inversion in the REAL code so the dedicated execution context doesn't build the wrong
thing. It is RESEARCH-FIRST groundwork (the progress map's "#12 needs dedicated grounding"), not the flip.

## Today's reality (verified by code-read, not assumption)
- **`EpdocPackage`** (`Epistemos/Models/EpdocPackage.swift`): `contentJSON: Data` is REQUIRED + canonical
  (`content.pm.json`, ProseMirror JSON); `shadowMarkdown: Data?` is OPTIONAL + derived (`projections/shadow.md`).
- **PM → md projection** is native Swift: `ProseMirrorMarkdownProjector.project(jsonData:)`, called on every
  save in `EpdocDocument.fileWrapper` (`:236-238`) to regenerate `shadow.md` from the canonical JSON. It is
  **LOSSY by design** (block IDs / custom marks don't survive) — fine for FTS/grep/export, NOT a source format.
- **md → PM is DELIBERATELY NOT in Swift.** The projector header (`ProseMirrorMarkdownProjector.swift:30-32`)
  states verbatim: *"Round-trip Markdown→ProseMirror is NOT in scope here (handled by Tiptap's importer in
  Wave 7.2)."* External `shadow.md` edits are *"imported as a reviewable conversion / new version … handled by
  the editor"* (`:17-19`). So **md→PM lives in the Tiptap (JS) editor**, by design.

## The key correction (prevents wasted effort)
A NATIVE Swift `MarkdownProseMirrorImporter` (the naive "inverse of the projector") would be a **PARALLEL
md→PM implementation competing with Tiptap's existing JS importer** — exactly the "a parallel MdV2 type would
not integrate" anti-pattern the progress map warns against. **Do not build a Swift md→PM parser.** The md→PM
direction the inversion needs ALREADY EXISTS in Tiptap/JS (`js-editor/`).

## What the inversion actually is (scoped)
Not a new parser — a **subsystem flip** of which artifact is canonical + which is the projection:
1. **Storage**: promote `shadowMarkdown` (md) to the REQUIRED source-of-truth entry; demote `contentJSON`
   (PM JSON) to a derived projection (or a fast-load cache) under `projections/`.
2. **Load path**: on open, (re)derive `contentJSON` FROM the md source via the **Tiptap importer** (md→PM,
   JS) so the editor's live ProseMirror doc is a projection of the md — the inverse of today's save path.
3. **Save path**: the editor still edits ProseMirror; on save, project PM→md (the EXISTING Swift projector)
   and persist the **md as canonical** (today it's persisted as a shadow). The lossy-projector gap must be
   closed first (md must round-trip faithfully enough to be the source — block IDs/marks fidelity), OR the
   canonical md must carry the fidelity the projector currently drops.
4. **Readers**: update every `contentJSON`-canonical reader (`EpistemosDocumentController`,
   `projectAndIndexBlocks(contentJSON:)`, the graph projector, the HTML workspace) to treat md as source.

## Why this is NOT a 2-minute loop increment
It spans the Tiptap/JS editor (md→PM fidelity), the Swift PM→md projector (close the lossy gap so md can be
source), `EpdocPackage` (required-entry flip + migration of existing packages), `EpdocDocument` save/load
inversion, and every canonical reader — with a no-regress bar on the 120fps Prose editor + a data migration
for existing `.epdoc` packages. It needs a focused, app-buildable context (not a disk-constrained ~15-min-
per-xcodebuild loop tick), staged so main never goes red mid-flip. It is CERTAIN, sequenced for that context.

## Concrete first step FOR that context (when taken)
Close the projector's lossy gap so md is faithful enough to be canonical — i.e. make PM→md→PM round-trip
preserve block IDs + the mark/node set the editor uses — BEFORE flipping which entry is required. Until that
fidelity holds, md cannot honestly be the source of truth (it would silently drop structure on every save).
