# SS-2S — Two-surface coexistence + cross-surface fidelity (Prose/TK2 ↔ Epdoc-MD), no data loss (2026-06-20)

Owner: *"The Prose editor (TextKit2) can be a deviation from the Epdoc. If Epdoc MD-v2 is the main markdown editor it
could or could not be — but there are two surfaces and I want to respect both; they both have use cases. With quick
capture I want an option to choose which surface. We should have GRANULAR but MINIMAL choices — balance usefulness +
availability with minimalism + UX. I don't want everything muddy / cloned / left to rot — deeply hardened + integrated.
ONE important thing: when I edit a note in the Prose editor then switch to the markdown (Epdoc) surface and switch
between them, I don't want things to disappear and reappear. If I have images embedded in a markdown file I can't view
it on the Prose/TextKit2 editor but I can on Epdoc — that adds ambiguity and may confuse the user ('why have this other
surface?'). I want a caveat / robust UX engineering to navigate that WITHOUT destroying data or regressing any surface.
If you can, upgrade the Prose editor; if not, leave it or minimally upgrade — whatever works best."* **CONFIRMED in code
(Explore agent, file:line-grounded). REAL, not truncated.** NON-INVASIVE intent; respects "NEVER damage TK2/Prose."

## Ground truth (verified file:line)
- **Prose/TK2 is ALREADY markdown-backed.** `SDPage` (`Models/SDPage.swift:15`) body lives in a managed `.md` sidecar
  via `NoteFileStorage` (`SDPage.swift:233,371-374`), `format` defaults `"markdown"` (`:36-37`). The editor persists
  `textView.string` = literal markdown (`ProseEditorRepresentable2.swift:595,836`); the Rust `markdown_parse_structure`
  FFI styles that md source (`MarkdownContentStorage.swift:101-117`). The `ArtifactKind.proseNote` "ProseMirror JSON"
  doc-comment is ASPIRATIONAL — the on-disk body is plain md.
- **Epdoc is currently JSON-first (the thing EPDOC_MD_V2 inverts).** `.epdoc` package canonical = `content.pm.json`
  (`Models/EpdocPackage.swift:55-96`); `projections/shadow.md` is LOSSY-by-design (`ProseMirrorMarkdownProjector.swift:9-22`).
- **No surface-switch / conversion exists.** `NoteDetailWorkspaceView.noteEditorSurface` (`:1237-1277`) routes only
  Code vs Prose within the SDPage world — Epdoc is NEVER mounted there. Epdoc opens via a separate `NSDocument` flow
  (`EpistemosDocumentController.createUntitledEpdocDocument:242`) keyed by manifest-ID, not SDPage-id. The bridging
  `ArtifactHostView` (proseNote/document hosts) is DEFERRED to placeholders (`ArtifactHostView.swift:52-84`).
- **Image asymmetry is STRUCTURAL.** The Rust parser driving Prose (`graph-engine/src/markdown.rs`) has NO image token
  (no `Tag::Image` arm; `StyleKind`/`ParaType` lists omit images) → md images `![](...)` / `![[...]]` are silently
  ignored in Prose. `MarkdownContentStorage.inlineStyleKinds:39-53` has no image kind. Epdoc fully renders images
  (`js-editor` `parseMarkdownImageLine` + `EpdocImageNode` + `assets/` pipeline).
- **TWO real data-loss bugs:** (1) Prose `insertImageAttachment` (`ProseTextView2.swift:1786-1808`) adds an in-memory
  `NSTextAttachment` that is DROPPED on save (no md serialization of the `EpistemosImagePath` attr). (2) Epdoc `shadow.md`
  loses block-IDs/custom-marks/extensions (canonical `content.pm.json` stays byte-exact, so loss only bites if shadow.md
  is treated as authoritative).
- **Quick Capture hardcoded to Prose** (`QuickCaptureView.submitCapture:548-559` → `TextCapturePipeline` makes an SDPage;
  no surface picker). Matches SS-QC.

## The resolving insight (Obsidian's model — web-validated)
Obsidian's Source / Live-Preview / Reading modes are all **VIEWS over ONE markdown file** — "the same markdown file is
handled differently across views for UX optimization rather than fundamental differences in how the underlying data is
stored." Source mode can't show images either (Obsidian ships a "Source Mode Image Renderer" plugin). So the owner's
worry is a KNOWN, SOLVED class of problem: **unify the source of truth (md), differentiate only the rendering.** Because
Prose is already md and Epdoc-MD-v2 becomes md-first, both surfaces can be honest views over the same `.md` → switching
cannot "lose" content; only the RENDER richness differs, which we make explicit, not silent.

## Plan (hardened, no data loss, respects both surfaces)
### A. Kill the silent data loss (MUST — these are bugs, do regardless of the bigger plan) [S→M]
1. **Prose inserted-image persistence:** when an image is inserted in Prose, serialize it to `![](assets/<name>)` md +
   store the asset (mirror Epdoc's `storeImageAsset` / `assets/` pipeline) so it survives save. No more dropped images.
2. **Prose renders md images (the "upgrade the Prose editor" path the owner offered):** add an image token to
   `graph-engine/src/markdown.rs` + an inline-attachment render in `MarkdownContentStorage` (NSTextAttachment from the
   resolved asset/url), so `![](...)` / `![[...]]` show in Prose too. This DIRECTLY removes the confusing asymmetry. Keep
   it minimal + lazy (don't regress Prose's speed; load attachments async, placeholder until ready). If image rendering in
   TK2 proves risky, fall back to **(B) the honest caveat** rather than forcing it.
### B. The honest cross-surface caveat (UX, in case any feature can't reach parity) [S]
Where a surface genuinely can't render something the md contains, show a NON-destructive inline affordance (e.g. a subtle
pixel-art chip "🖼 image — open in Epdoc to view/edit") instead of hiding it silently. The md text is ALWAYS preserved;
the user is told *why* a view differs and how to see it richer. This is the "caveat / robust UX" the owner asked for —
ambiguity becomes an explicit, trustable signal, never silent disappearance.
### C. Optional explicit surface switch over one md [M] (only after EPDOC_MD_V2 flips Epdoc to md-first)
Once Epdoc is md-canonical, a note's single `.md` can be opened in either view; "Open in Epdoc / Open in Prose" becomes a
VIEW switch, not a lossy conversion (one source of truth). Until then, keep them separate but both honest md views; do
NOT build a lossy JSON↔md converter (that would be the muddiness the owner fears). Gate on EPDOC_MD_V2 Phase 3.
### D. Quick-capture surface choice — granular BUT minimal [S] (extends SS-QC)
Add a single destination control to QuickCapture: default = Prose (current behavior, zero-friction), with a minimal
toggle/segment to send to Epdoc (or a saved preset). One control, not a config maze — "balance usefulness with
minimalism." Wire `TextCapturePipeline` to accept a `destination:` (Prose SDPage | Epdoc package) param (SS-QC already
flags the hardcoded Prose path). Remember last choice.

## Respect-both-surfaces contract (anti-muddiness, SS-CLEAN)
- **Prose/TK2** = the FAST, minimal, plain-md long-form writer (Obsidian source/live feel). Stays non-invasive; we only
  ADD md-image rendering + image-save (no behavior regression).
- **Epdoc MD-v2** = the RICH block editor (Notion/reading feel; SS-EDGE). Both are md-first VIEWS — one truth, two renders.
- **One serializer, one asset pipeline, one wikilink/backlink seam** shared across both (no cloned/divergent cores — the
  exact "don't let it rot / get muddy" rule). Cross-ref SS-EDGE (editor takeover), EPDOC_MD_V2 (build order), SS-QC
  (capture), SS-WL (wikilinks/images-as-links), SS-CLEAN (muddiness gate).
Every item test-backed: round-trip md fidelity (insert image → save → reload → still there in BOTH surfaces), no-regression
on Prose speed, capture-destination honored. Sequenced: (A) data-loss fixes first (independent, high-value), (B) caveat UX,
(D) capture choice, (C) view-switch after EPDOC_MD_V2 Phase 3.

Sources: Explore agent code map (file:line above); Obsidian source/live/reading-view + Source Mode Image Renderer docs;
EPDOC_MD_V2 / SS-EDGE / SS-QC / SS-WL / SS-CLEAN.
