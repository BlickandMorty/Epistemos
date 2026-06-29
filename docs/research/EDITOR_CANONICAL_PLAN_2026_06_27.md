# Epistemos Editor — CANONICAL PLAN (2026-06-27)

> **★ THE single source of truth for the editor work.** Consolidates the Tolaria-supersede research loop
> (passes 1–10 + the 2026-06-27 finalization audit) into one contradiction-free plan. Where any other editor
> doc disagrees, **this wins.** Code detail lives in the code packs (linked per section). Research provenance:
> `TOLARIA_SUPERSEDE_RESEARCH_2026_06_27.md`. **Finalization audit (contradictions/supersede/completeness):
> see §12 — it is current as of pass 10 and supersedes any stale phrasing elsewhere in this doc.**
>
> **Doc status map:** CANONICAL → this doc + the 7 codepacks (`TOLARIA_ONTOLOGY_UPGRADE_CODEPACK`,
> `MARKEDIT_EMBED_CODEPACK`, `NATIVE_CONTROLS_CODEPACK`, `GOOSE_MINICHAT_CODEPACK`, `COMMAND_REGISTRY_CODEPACK`,
> `MD_SOURCE_OF_TRUTH_CODEPACK`, `AI_INSTRUCTIONS_AND_GRAMMAR_CODEPACK`) + `EPDOC_MD_V2_BUILD_SEQUENCE`
> (note-editor build content) + `SS-P_TOLARIA_V2_MD_EDITOR` (note-editor patterns/license) + `SURFACE...§16`
> (markdown-as-truth). HISTORICAL → `SS-CM_CODEMIRROR_MD_SOURCE_SURFACE` + `CODEMIRROR_MD_V2_BUILD_AND_POLISH`
> (CodeMirror-as-note-editor was reversed; their CM6/MarkEdit research now applies to the CODE lane only).

---

## ⚛️ HARDENING & THERMONUCLEAR REVIEW DOCTRINE (how this plan stays strict + safe)
Binding for any implementing agent (the build prompt `docs/prompts/PROMPT_PLAN_2_EDITOR.md` carries it too) — same
strictness as the Goose plan's R-CODEREVIEW:
- **Thermonuclear review (recurring):** run `[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)`
  over the touched code AT EACH build stage + a full-app pass periodically. Honest findings only — correctness, dead/
  stale code, honesty-constraint violations, perf, arch drift, contradictions.
- **Harden-before → build → re-harden-after** per feature, with its own regression tests + a "HARDENED <item>" note.
- **Deletion guardrail:** harden/dedupe over delete; NEVER delete new/in-progress/owner-requested code; KEEP+flag when
  unsure; commit deletions separately. (Per L3 REVISED 2026-06-29 the old code-editor files are NO LONGER deleted — they are KEPT as a v1-legacy fallback. There is no sanctioned deletion in this plan.)
- **No-contradictions gate:** before a stage is done, grep this plan + codepacks for any contradicting claim; fix the SOURCE.
  (The 2026-06-28 audit caught `vendor/`→`LocalPackages/` + triple width-px this way — keep doing it.)
- **PROVEN-DONE bar (5 criteria for any ✅):** real-state · live in-app · migrates existing data · end-to-end · witnessed.
  Build-green ≠ done (and per memory, headless app-hosted test runs crash-loop → push logic into pure helpers + mirror-witness).
- **Full-clone law:** MarkEdit embedded in FULL — settings and all, nothing lost (see §14). No silent capability drop.
- **CLAUDE.md NON-NEGOTIABLES** (xcodegen only, no model commits, no nonexistent SDKs; never BREAK existing TK2/Prose behavior — TK2 is unfrozen 2026-06-29 only to ADD the Prose lens, L4).
  **No-collision** with Plan 1 (Goose) / Plan 3 (capabilities) — see §13.7 + the build prompt boundaries.

---

## 0. OWNER DECISIONS — status
### ✅ LOCKED by the owner (2026-06-27)
- **L1. Source of truth = MARKDOWN-ON-DISK.** Vault `.md` + frontmatter is durable truth; `.epdoc` ProseMirror
  JSON demotes to a derived cache. Staged, reversible, falsifier-gated flip per `MD_SOURCE_OF_TRUTH_CODEPACK`
  (`EPISTEMOS_MD_SOURCE_OF_TRUTH`: jsonOnly → dualWrite → markdownCanonical), serializer-first, HTML-in-markdown
  fallback for rich-only blocks (charts/mermaid/math/callouts). Goose's real write seam is **`edit_note`** (NOT
  the nonexistent `update_note`); pre-flip it writes JSON-into-package, post-flip it writes `.md`.
- **L2. Note-width = BINARY toggle AND a SLIDER, both shipped.** Binary preset (normal **720px** / wide
  `max-width:none`) PLUS a continuous slider (stores a custom px in `_width`, same "never create frontmatter
  just for UI state" guard). ⚠️ **Ground truth:** the live `js-editor/src/editor.css:80` default is **820px** — the build
  changes it to 720px (the owner's readable-column target). ⚠️ **The codepacks are binary-only** — `NoteWidthResolver`
  (`enum {normal,wide}`), the `NATIVE_CONTROLS` setter, and `CommandRegistry.setContentWidth(wide:)` MUST each gain a
  `custom(px:)` path to satisfy the slider half of L2 (an explicit ADD, not yet in the codepacks).
- **L3. CODE editor = MarkEdit (Source) engine; KEEP the old code editor as a "v1 legacy" fallback (do NOT delete).**
  ⚠️ **SUPERSEDES the earlier "delete the 3 old code-editor files" rule** — owner 2026-06-29 wants v1 PRESERVED.
  Plan 2 makes the MarkEdit CoreEditor engine the DEFAULT code surface (replacing `WebKitCodeEditorView` the
  disabled-highlighting textarea + the dormant `CodeEditSourceEditor` wiring + the `LiveCodeEditorController`/
  `SwiftTreeSitterLiveHighlighter` scaffold AS THE DEFAULT), but RETAINS the old editor as **"v1 legacy"**:
  reachable from **Settings** + a **toggle inside the MarkEdit surface** so the owner can fall back. **NO deletion.**
  **SCOPE: code editor ONLY** — the Note (Epdoc) and Prose/TK2 surfaces are not broken by this swap.
  - **L3-CHROME (owner 2026-06-29, REVISED twice): MarkEdit ENGINE + POLISH for both; MD = MarkEdit chrome
    VERBATIM; CODE = the old v1 minimal look REIMPLEMENTED on the MarkEdit engine.** The owner keeps MarkEdit's
    innate polish, but the CODE surface should LOOK like the old minimal code editor — **NOT MarkEdit's full
    standalone toolbar, and NOT a restore of v1's code** (reimplement the look fresh on MarkEdit). CODE reproduces:
    the **nested-box container** (inset rounded-card editor panel, exactly like v1), the **title styling** (filename
    + "Swift · N lines" subtitle), **real per-language file-type LOGOS** (the Swift bird, Rust gear, etc. — NOT a
    generic `</>`), and **Epistemos THEME-AWARENESS** (today it only takes MarkEdit's theme — make the code chrome +
    CoreEditor follow the app's light/dark/custom/accent theme). **Preserve-list (GRAFT into the code chrome):**
    Live-Preview/HTML preview (`HTMLWorkspacePreviewView`), LSP hover (`CodeEditorSemanticLSP`), Outline, + the
    other critical v1 buttons. **Sizing:** MD = MarkEdit's full default size; CODE a few ticks SMALLER but roomier
    than today's editor. Canonical detail = `MARKEDIT_EMBED_CODEPACK §3 + §3a`.
- **L4. THE LENS MODEL (owner 2026-06-29): markdown-on-disk is the ONE truth; THREE editors are three LENSES on it,
  cross-synced on the same file.** Lenses: **Prose** (TK2 native focus/long-form) · **Source** (MarkEdit CoreEditor —
  raw markdown + live preview + native chrome) · **Note** (Epdoc/TipTap WYSIWYG — a STANDALONE, isolated module).
  A markdown document toggles across all three (the Option-A per-document toggle); a CODE file = **Source only**.
  - **Truth rule:** all three read/write the same `.md` (L1) — NO separate lock-in format is treated as truth.
    Epdoc/Note is engineered standalone, but its ONLY writer is the full-fidelity JS `getMarkdown()` bridge (never
    the lossy Swift projector).
  - **Where data loss can happen + how it's contained:** Source + Prose edit raw text → near-zero loss. The ONLY
    loss boundary is **Note/Epdoc serializing back to markdown** — constructs Epdoc's schema doesn't model (raw
    HTML, footnotes, exotic/nested tables, custom callouts, frontmatter edge cases) can be dropped/normalized on
    SAVE. FOUR guardrails make cross-sync safe: (1) Epdoc writes ONLY via the full-fidelity `getMarkdown()` bridge;
    (2) preserve-unknown PASSTHROUGH (Epdoc holds unrenderable constructs as raw md/HTML nodes so they round-trip
    untouched); (3) write ONLY on a real edit (viewing in Note then switching away must NOT rewrite the file);
    (4) a round-trip test that FAILS LOUD on the edge constructs (open→save must be byte-identical).
  - **Sequence:** ship the **Source ↔ Note** toggle FIRST (both built). Add **Prose** as the third lens LATER. ⚠️
    TK2/Prose is **unfrozen by owner approval (2026-06-29)** for this purpose only (this relaxes the "Prose/TK2
    frozen hard-gate" elsewhere in the canon — reconcile those mentions to "don't BREAK existing Prose behavior").
    As a lens, Prose edits markdown AS TEXT — it does NOT re-serialize a rich model and does NOT render rich blocks
    like Epdoc.

### ⏳ RECOMMENDED — audit-verified best, pending the owner's final nod (not blocking)
- **R1. Grammar = Obsidian/GFM** (`> [!KIND]` callouts · ` ```chart ` · `[[wikilink]]`). Follows directly from
  L1 (on-disk truth should be the format the rest of the world reads); already has a working reader; the graph
  already indexes `[[wikilinks]]`. Align `ProseMirrorMarkdownProjector.swift` to it (Pass 9b).
- **R2. Minichat = native SwiftUI over the Goose ACP bridge + an "Open in Goose" webview escape hatch.**
  Maximizes nativeness (the owner's through-line) + inline per-edit approval; the webview button still gives
  "full web Goose." Honestly diverges from the owner's "native webview shell" phrasing — surfaced, not assumed.
- **R3. Code-engine = MarkEdit (Source); MarkEdit native chrome for BOTH code AND markdown (L3-CHROME REVISED).**
  Preserve-list grafted in (preview button, LSP-hover, Outline, critical v1 buttons); code sizing a few ticks
  smaller than MD. The old code editor is KEPT as "v1 legacy" (Settings + MarkEdit toggle) — NOT deleted (L3).
  See L4 for the full Prose/Source/Note lens model.
- **R4. `@codemirror/merge`** = the code-lane diff engine (it was only wrong for the *note* editor). Settled.
- **R5. Edit-provenance = the existing Swift `AgentNoteEditProvenance` → EventStore spine**, enriched with an
  `EditClaim` metadata struct. The Rust `ClaimLedger` FFI is read-only today and Phase 8.E moved live provenance
  to the Cognitive DAG, so the "EditClaim → Rust ledger" phrasing in older passes is NOT buildable as written;
  a `record_edit_claim_json` FFI would be net-new (defer). See §6 + §12.

---

## 1. The surface model — THE LENS MODEL (markdown-on-disk = ONE truth; three lenses on it, L4)
A markdown document opens in any of three **lenses** (cross-synced on the same `.md`); a CODE file = **Source only**.
| Lens / surface | Engine | Role | Status |
|---|---|---|---|
| **Note** (= Epdoc) | TipTap/ProseMirror in WKWebView | WYSIWYG rich lens — **STANDALONE, isolated module**; `getMarkdown()`-only writer; the one fragile round-trip (4 guardrails, L4) | LIVE; revamp + isolate |
| **Source** (= MarkEdit CoreEditor) | CodeMirror 6 in WKWebView (vendored from MarkEdit) | raw markdown + live preview + **MarkEdit native chrome**; the DEFAULT **code** surface AND a markdown lens (L3-CHROME) | BUILD (default) |
| **Prose** (= TK2) | TextKit 2 / `ProseTextView2` (native) | native focus/long-form lens; edits markdown AS TEXT (no rich re-serialize) | UNFROZEN (owner 2026-06-29); wire LAST |
| **(legacy) code editor v1** | `WebKitCodeEditorView` + dormant impls | KEPT as a **v1 legacy fallback** — Settings + a toggle inside the MarkEdit surface (NOT deleted, L3) | RETAIN as legacy |
| **(embedded) Full MarkEdit app** | MarkEdit Swift modules | full settings + native chrome; "another feature later" | EMBED, inert behind a flag |
| **HTML Workspace** | `HTMLWorkspaceDocument`/`HTMLWorkspaceEditorView` | AI-artifact surface; hand-edit routes to the Source (MarkEdit code) surface | LIVE; Plan 2 owns it (§13.5) |

Why: same markdown underneath, three ways to see it — **Note** = WYSIWYG (rich, Tolaria/Notion feel), **Source** =
raw markdown + preview + native MarkEdit chrome (also the only sensible lens for real code), **Prose** = native
distraction-free long-form. Loss can only occur at the Note→markdown serialize boundary; the L4 guardrails contain it.

---

## 2. Locked decisions (consolidated from passes 1–5)
1. **Note editor = TipTap on the existing Epdoc.** NOT BlockNote (React-only, 8.8× bundle, primitives-only
   props hostile to the ontology, `xl-ai` is GPL). NOT CodeMirror (that decision was reversed). "Look like
   Tolaria" = a CSS/chrome polish task on Epdoc, not an engine swap.
2. **Code surface = MarkEdit (Source); the old code editor is KEPT as v1 legacy, NOT deleted (L3 REVISED).**
   Make MarkEdit CoreEditor the DEFAULT at `CodeEditorView.codeEditorSurface`; retain `WebKitCodeEditorView` as a
   v1-legacy fallback (Settings + a toggle inside the MarkEdit surface). MarkEdit engine+polish for both; MD =
   MarkEdit chrome verbatim, CODE = the v1 minimal look reimplemented on MarkEdit (L3-CHROME REVISED). Epdoc stays
   the Note lens; the three lenses cross-sync on the same `.md` (L4).
   **★ SOURCE OF TRUTH = MARKDOWN-ON-DISK (L1).** Vault `.md` + frontmatter is durable truth; `.epdoc` JSON is a
   derived cache. **Canonical grammar = Obsidian/GFM (R1).** **Note-width = binary toggle + slider (L2).**
3. **MarkEdit = FULL app embedded** (Route D): vendor `MarkEditCore` + `MarkEditKit` + `MarkEditMac/Modules`
   (11 libs incl. SettingsUI/FontPicker/Statistics) + `Sources/{Editor,Panels,Settings}` + `CoreEditor`;
   DROP its `@main`/`AppDocumentController`/`.xcodeproj`/`Info.entitlements`/both `.appex`; re-host
   `EditorViewController` via `NSViewControllerRepresentable` against the EXISTING `EpistemosDocumentController`
   (Epistemos is already a document app). Full Settings present-but-inert behind `#if EPISTEMOS_MARKEDIT_EMBED`.
4. **Prose/TK2 = the third lens (L4).** Unfrozen 2026-06-29 ONLY to wire it as the Prose lens (lowest priority, last); never BREAK its existing long-form behavior. It edits markdown AS TEXT (no rich re-serialize).
5. **Note AI-diff = `prosemirror-changeset` (MIT) + `@handlewithcare/prosemirror-suggest-changes` (MIT).**
   NOT `@codemirror/merge` (that's the code-lane diff), NOT TipTap AI Toolkit (paid), NOT BlockNote xl-ai (GPL).
   Diff per settled chunk, never per token (Zed #58037 lesson).
6. **Markdown round-trip = official `@tiptap/markdown` pinned `3.24.0` (MIT)** to match the TipTap stack
   (`@tiptap/pm@3.24.0`) — 3.27.x against a 3.24.0 pm is a duplicate-ProseMirror/schema-mismatch hazard.
   ⚠️ **P0: confirm `@tiptap/markdown@3.24.0` actually resolves on npm before committing the lock** (it's an
   "early release" with sparse versions; if absent, pin the lowest published `3.2x` peering `@tiptap/core@^3.24`).
   Register per-node serializer/parser hooks (NOT `marked` tokenizers — the bundle is webpack 5 and `@tiptap/
   markdown` vendors its own parser) for callouts/wikilinks/frontmatter. (NOT the deprecated community
   `tiptap-markdown`; NOT the nonexistent `@tiptap/extension-markdown`.) Source-of-truth = markdown (L1).
7. **AI = Goose** (engine), grafting Tolaria's editing doctrine; minichat note-aware, Phase-0 gated.
8. **Ontology = Tolaria clean-room on SDPage + frontmatter + the unified graph.** Tolaria is AGPL-3.0 →
   clone-forbidden, ZERO code, behavioral reimplementation only.
9. **Review model = hybrid** (git-diff/file-level spine + opt-in in-editor diff for small edits).

---

## 3. Note editor (Epdoc / TipTap) — the Tolaria revamp
- **Look like Tolaria:** CSS/chrome polish on Epdoc (it already has slash menu, drag handles, bubble menu).
- **Markdown:** add `@tiptap/markdown` + tokenizers; resolve the JSON-fork (open Q1).
- **AI-diff trail (yellow=add/red=delete):** `prosemirror-changeset` two-doc diff (snapshot original → stream
  into staging, batched per chunk → `ChangeSet.addSteps` → decorations: insertions yellow `mark`, deletions
  red strikethrough `widget`) → per-chunk accept/reject via `EpdocCopilotDockView`. Carry a `claimId` in each
  span's `data` (→ provenance, §6).
- **Live-preview note:** TipTap is already WYSIWYG (tables/code/etc. render + edit in place, no syntax shown,
  no shift) — this is the "edit-on-preview" feel the owner wanted; no CodeMirror reveal-at-cursor needed.

## 4. Code editor (MarkEdit Source) — `MARKEDIT_EMBED_CODEPACK_2026_06_27.md §3/§3a`
- **★ MarkEdit ENGINE + POLISH for both; chrome differs (L3-CHROME REVISED 2026-06-29).** MarkEdit's CoreEditor
  (CM6) is the ONE engine. An `isMarkdownDocument` branch picks the chrome: **`.markdownChrome` = MarkEdit's chrome
  VERBATIM**; **`.codeChrome` = the old v1 minimal look REIMPLEMENTED on MarkEdit** (nested-box container, title
  styling, **real per-language file-type logos** not `</>`, **Epistemos theme-aware**) — NOT MarkEdit's full
  toolbar, NOT a restore of v1's code. **PRESERVE-LIST — graft into the code chrome (never lose):** the
  Live-Preview/HTML preview button (`HTMLWorkspacePreviewView`), LSP hover (`CodeEditorSemanticLSP`), the Outline
  navigator, + the other critical v1 buttons. (For MD, MarkEdit natively supplies Find/GoToLine/FontPicker/Statistics.)
- **Sizing (§3a):** MD = MarkEdit's full default size; CODE = a few ticks smaller but roomier than today's editor.
  Inherit MarkEdit's `FontPicker.defaultFontSize` + `AppPreferences.Editor.lineHeight` (don't substitute/​hardcode).
- **v1 legacy (L3):** KEEP the old `WebKitCodeEditorView` reachable from Settings + a toggle inside the MarkEdit
  surface. NOT deleted.
- **Lens model (L4):** for `.md` this Source surface is one of three cross-synced lenses (Note/Source/Prose); for
  code it is the only surface. Wire the orphaned `.markdownChrome` route (today `CodeEditorView.swift:706` sends
  markdown to Prose — fix it so `.md` can open in Source).
- **LSP:** keep the one-shot Swift `CodeEditorSemanticLSP` over `RustLSPTransport` (engine-agnostic); a CM6
  LSP-client extension bridged to `lspSendMessageJson`/`lspPollResponseJson` is a later slice.
- **Code-lane diff:** `@codemirror/merge` (open Q5).

## 5. MarkEdit full embed (Route D) — `MARKEDIT_EMBED_CODEPACK_2026_06_27.md`
Vendor/drop/re-host map + build plan in the codepack. Build (`build-coreeditor-bundle.sh` cloned from
`build-tiptap-bundle.sh`, vite+yarn, lock-hash gate); keep `chunk-loader://` first (brotli-unify later);
adopt Epistemos entitlements (reject MarkEdit's MAS-hostile keys); xcodegen `project.yml`. Coexistence: two
scheme handlers, shared (no-op-on-12+) process pool routed through the memory-pressure handler.

## 6. AI / minichat (Goose) — `GOOSE_MINICHAT_CODEPACK_2026_06_27.md`
- **Shape (open Q2):** native SwiftUI over `GooseACPEventBridge` + "Open in Goose" webview escape hatch.
- **Auto-init on note open:** `ActiveEpdocTracker` (frontmost note) + `NoteContextProvider` (bounded head/tail
  body via existing `ProseMirrorMarkdownProjector`) → `WorkNativeMCPHost.updateContext`. One shared Goose
  session re-scoped per note (cwd=vault constant).
- **Graft Tolaria's doctrine onto Goose:** vault-root `AGENTS.md` guidance, per-turn context snapshot (MCP-pull
  via `epistemos.context.snapshot` + a thin "current note" preamble), honest head/tail truncation, UI-steering
  MCP tools (`open_note`/`highlight_editor`), convention-frontmatter. Goose BEATS Tolaria's CLI-shell:
  in-process, real per-edit approval (`session/request_permission`), provenance, no port sprawl.
- **Goose-boundary gaps to close:** `GooseACPClient.newSession` drops `mcpServers` (1-line), NO cancel method
  (add `session/cancel`), NO Epdoc UI-steering affordances (add to `GooseWebNativeAffordanceBridge`).
- **Phase-0 GATED:** scaffold + note-context plumbing now (zero Goose dep, testable); flip live after the Goose
  §7 sign-off; mirror the `#if EPISTEMOS_APP_STORE` Pro gate on the minichat surface.
- **Provenance (supersede Tolaria's git-only) — R5, corrected:** per accepted edit → an `EditClaim` metadata
  struct (agent/model/runtimeKind/capability_tier/confidence/approver/generatedAt vs acceptedAt) carried on the
  EXISTING Swift `AgentNoteEditProvenance` → EventStore spine (wired through `VaultNoteEditor.applyEdits(_:to:
  provenance:)`); `claimId` ties the inline hunk ↔ git commit ↔ provenance record. ⚠️ The earlier "EditClaim →
  Rust `ClaimLedger`" phrasing is **NOT buildable today** — that ledger's FFI is read-only and Phase 8.E moved
  live provenance to the Cognitive DAG. Retraction-propagation-beats-`git revert` lives in that Rust ledger and
  is therefore NOT delivered by the shippable Swift path; a `record_edit_claim_json` FFI (→ `commit_claim` or DAG
  dispatch) would be net-new work, deferred. Ship the honest Swift-spine version; don't overclaim the ledger one.

## 7. Native controls — `NATIVE_CONTROLS_CODEPACK_2026_06_27.md`
Epdoc is ALREADY MarkEdit-shaped (native SwiftUI chrome → `EpdocEditorCommand` → `window.epistemos.*`). Gaps:
- **Unified `CommandRegistry`** (one registry → menu bar + shortcuts + a NEW **Cmd+K palette**; Cmd+K is free) —
  highest-leverage, build first.
- **Find/Replace** (native panel → ProseMirror search for notes / CM6 search for code).
- **Note-width toggle** (native button → CSS var `--epdoc-content-max-width`, already exists; persist `_width`
  only if frontmatter exists — see ontology §8).
- **Panel-toggle segmented control** (Properties/ToC/Backlinks/AI) with focus-scoped Cmd-shortcuts.
- **MUST stay in WebView:** the 4 caret-anchored TRIGGERS (slash/bubble/drag-handle/KaTeX) — but their PANELS
  are already native SwiftUI positioned from a bridged anchor rect.

## 8. Ontology — `TOLARIA_ONTOLOGY_UPGRADE_CODEPACK_2026_06_27.md`
7 clean-room Swift/Rust snippets, each on a real Epistemos type: `NoteOntologyParser` (typed parse over the
existing flat parser), `FrontmatterRelationshipReconciler` (persist forward+inverse typed edges into the graph),
`SystemKeys` (`_`-convention enforced across FTS+HNSW+graph), `ViewDefinition`/`ViewCompiler`/`ViewEvaluator`
(all/any tree → indexed GRDB SQL + a `semantic:` op RRF-fused with HNSW), `NoteWidthResolver`, `TypeRegistry`
(in-memory over SDPage + advisory schema-light validation), `incrementalCrawl` (per-note content-hash deltas).
SUPERSEDE: persisted typed relationship graph, schema-light validation, semantic+structured hybrid views,
provenance-aware incremental reindex, real trash+undo (Tolaria deletes permanently).

## 9. Minimal-but-best toggle curation (owner: "minimal but the best things")
KEEP (top): note-width toggle · Cmd+K unified command registry · rich↔(future)source on one `.md` · files-first
truth · `[[wikilink]]` autocomplete+rename+backlinks · round-trip-only slash menu · layout presets · Inspector
(Properties/Relationships/Backlinks/Git-history) · git first-class (AutoGit opt-in) · Inbox+mark-organized ·
Types as light lenses · saved Views (visual builder) · ToC · Light/Dark/System no-flash · global RRF search ·
math+code(fix the fence bug) · Mermaid · keyboard-first+surface-aware shortcuts · drag-handle blocks ·
open-in-new-window focus. DROP/DEFER: whiteboards, spreadsheets, bundled multi-agent CLIs, Pulse/Neighborhood,
multi-vault graph, hand-YAML views, telemetry. ADD (beat Tolaria): real focus/typewriter mode, width slider,
real trash+undo, semantic search, mobile.

---

## 10. Build sequence (dependency-ordered)
Stage gates; each is independently shippable where possible. Goose-dependent items wait for Phase-0 sign-off.
1. **[S] Ontology core** (codepack 4a): `NoteOntologyParser` + `SystemKeys` + `NoteWidthResolver` + the
   frontmatter→graph reconciler. Pure Swift, testable, no UI risk.
2. **[S] Native CommandRegistry + Cmd+K palette** (codepack 4c) — unifies menu/shortcuts; wire existing Epdoc
   dispatch into it.
3. **[M] Note-editor revamp** (Epdoc): Tolaria CSS/chrome polish + note-width **toggle AND slider (L2)** +
   Find/Replace + panel segmented control. Add `@tiptap/markdown` (3.24.0, P0 npm check) + execute the L1
   markdown-as-truth flip (serializer-first; dualWrite → markdownCanonical, falsifier-gated).
4. **[M] Note AI-diff** (`prosemirror-changeset` + suggest-changes) via `EpdocCopilotDockView`.
5. **[M] MarkEdit embed + Source code surface** (codepack 4b/§3/§3a): vendor MarkEdit under `LocalPackages/MarkEdit/`
   (NOT `vendor/`), `build-coreeditor-bundle.sh`, make MarkEdit CoreEditor the DEFAULT surface at
   `CodeEditorView.codeEditorSurface`. **Chrome = MarkEdit native for BOTH code + markdown (L3-CHROME REVISED):**
   graft-preserve the v1 critical buttons (Live-Preview/`HTMLWorkspacePreviewView`, LSP-hover, Outline); MarkEdit
   supplies Find/FontPicker/Statistics/GoToLine. Visual fidelity (§3a): inherit MarkEdit font size + line-height;
   code a few ticks smaller than MD. **Wire the orphaned `.markdownChrome` route** so `.md` opens in Source (today
   `:706` routes markdown to Prose). **KEEP the old code editor as v1 legacy** (Settings + MarkEdit toggle) — NOT
   deleted. NOTE editor (Epdoc) + existing Prose/TK2 behavior untouched (TK2 unfrozen only to ADD the Prose lens, L4).
6. **[M] Views + Type registry + incremental crawl** (codepack 4a) over GRDB/graph/shadow.
7. **[L, Phase-0 gated] Goose minichat** (codepack 4d): build the note-context plumbing now; flip the live
   agent surface after Goose §7 sign-off. Close the 3 Goose-boundary gaps. Provenance EditClaim wiring.
8. **[L] Supersede polish:** real trash+undo (P0-design first — see §12), focus/typewriter mode, semantic view
   op, saved-Views visual builder + backlinks panel (model-layer only today — need UI). (Width slider ships in
   step 3 per L2, NOT here.)

## 11. License ledger (all live-verified)
SHIP-CLOSED: MarkEdit (MIT), CodeMirror 6 + `@codemirror/*` (MIT), TipTap core + `@tiptap/markdown` (MIT),
`prosemirror-changeset` (MIT), `@handlewithcare/prosemirror-suggest-changes` (MIT), `@codemirror/merge` (MIT,
code-lane). FORBIDDEN closed: Tolaria (AGPL — clean-room only, ZERO code), BlockNote `xl-*` (GPL), Vrite
(AGPL), TipTap Pro AI Toolkit (paid). CAUTION: `prosemirror-suggestion-mode` (MIT per npm only, no LICENSE file).
Every lift → `F-ProprietaryCompression-ProvenanceGate` (MIT/Apache=clean-import; AGPL/GPL=research_only).

---

## 12. FINALIZATION AUDIT (2026-06-27, pass 10) — honest state before building
Three independent audits (contradiction / supersede-Tolaria / completeness) ran over the full corpus. Net:
**the research is deep, honest, and self-correcting; the backend genuinely supersedes Tolaria on search,
relationships, provenance-architecture, and AI-architecture. But "supersedes on every axis" is NOT yet true,
and several headline features are model-only.** What's recorded here supersedes stale phrasing above.

### 12.1 Where Epistemos truly BEATS Tolaria (real + buildable)
- **Global search:** RRF (BM25+HNSW) vs Tolaria's no-index walkdir-at-query-time. Real, shipping today.
- **Relationships:** persisted forward+inverse typed graph vs renderer-recompute — *conditional* on the 3 Pass-7b
  C2 fixes (the `firstNode(matchingTitle:)` resolver, the `addEdge` silent-drop ordering, the `fmrel:inv:` reuse).
- **Hybrid semantic+structured Views** (`semantic:` op RRF-fused with all/any GRDB predicates) — no files-first PKM
  can express this. Buildable on the existing RRF stack. **The single most differentiated capability.**
- **AI: in-process Goose** (real per-edit approval `session/request_permission`, cancellation, honest gating)
  vs subprocess CLIs + loopback WS ports. Architecturally superior; **operationally Phase-0-gated (Phase 0 is
  currently FAIL/PARTIAL)** — superior-in-design, not-yet-proven-at-runtime.

### 12.2 Where Epistemos is BEHIND or DIVERGES (own these honestly)
- **Markdown-as-truth (L1):** Tolaria *ships* it; Epistemos reaches it only *after* the unbuilt `@tiptap/markdown`
  serializer + the staged flip. Behind until Phase B.
- **Dual rich↔raw editor on one note — ACHIEVABLE, now a PLANNED feature (owner-corrected 2026-06-27).** Earlier
  framing called this a "gap"; too conservative. TipTap WYSIWYG is *enough* — and richer — for the primary editing
  feel (Tolaria's own editor is BlockNote = TipTap-family, so notes look/feel like Tolaria). The only extra Tolaria
  has is a "view this note as raw markdown" toggle. **With L1 (every note IS a `.md` file) + the embedded MarkEdit
  CoreEditor, that toggle is nearly free: same `.md`, two views — Epdoc renders it rich, CoreEditor renders it raw,
  a button swaps which editor is mounted (suppress the save-echo on swap).** So Epistemos MATCHES Tolaria's rich↔raw
  AND the rich side is better. ⟹ Add **"open note as raw markdown"** to the build sequence (small; gated on L1 +
  code-editor v2). NOT behind — on par + richer.
- **Provenance retraction-beats-revert:** claimed, but lives in the read-only Rust ledger; the shippable Swift
  spine doesn't have it (R5). Don't demo what isn't wired.
- **"Full MarkEdit app embedded":** the literal "two apps in one" is impossible (one `@main`/`NSDocumentController`);
  what ships is a curated module graft with Settings inert. Honest internally; the headline oversells.

### 12.3 GAPS — named/loved but model-only or unspecced (don't call v1 "done" without these)
- **Real trash + undo** — the most-repeated "we beat Tolaria" claim, with ZERO design/code. Design it before
  claiming the supersede.
- **Saved-Views visual builder UI** — compiler/evaluator exist; the "not hand-YAML" builder UI is unspecced.
  (And we DROP Tolaria's hand-YAML authoring — until the builder ships, that's a regression for YAML power-users.)
- **Backlinks panel** — graph edges exist; panel rendering unspecced.
- **Note AI-diff lane** (`prosemirror-changeset` yellow-add/red-delete trail) — an [M] core lane with **no
  falsifier/verification spec** (the biggest verification hole; needs the "diff per settled chunk not per token"
  Zed-#58037 guard tested).
- **Git history / AutoGit / per-note history** — asserted "first-class," no seam/code. Status-bar+history for v1;
  AutoGit can defer.
- **Pulse/activity-feed** dropped — but the AI-review story leans on "review via activity feed." Reconcile.

### 12.4 P0 checks to run BEFORE building (cheap, high-leverage)
1. **`@tiptap/markdown@3.24.0` resolves on npm** — one 30-second check that silently gates the entire L1
   markdown-as-truth lock. Do this FIRST.
2. **Patch the codepacks with the Pass-7/8/9/10 ground-truth corrections** so an implementer reading one in
   isolation doesn't hit a landmine: `vendor/`→`LocalPackages/`; `update_note`→`edit_note`; the
   `firstNode(matchingTitle:)` compile-blocker (spec the resolver); the read-only-ledger provenance fork (R5);
   `@tiptap/markdown` 3.27.x→3.24.0; the three width-pixel specs → one (720px / `max-width:none`).
3. **Verify the 5 [INFERRED] integration assumptions** (MarkEdit ts-gyb bridge selectors; Goose HTTP-MCP
   descriptor key shape; `session/cancel` wire string; the 8 `vault.*` tool arg schemas) before their lanes.

### 12.5 The correct FIRST buildable slice (lowest risk, visible value)
**CommandRegistry + Cmd+K palette + the `caretChanged.marks` read-back** (build sequence step 2, codepack 4c +
`COMMAND_REGISTRY_CODEPACK`). Why: pure Swift/SwiftUI, zero web-bundle/Goose/markdown-flip risk; ~80% of commands
already dispatch through existing `EpdocEditorCommand` cases; Cmd+K is verified free; and the one shared
dependency (`caretChanged.marks`, a contained 3-file change) ALSO unblocks the toolbar active-state (4c) and Find
active-feedback (B4) — it pays triple. Resolve the npm check (12.4.1) and the provenance fork (R5) before the
markdown-flip and minichat lanes start.

### 12.6 The "truly brilliant" lean (to be a category leap, not a faster clone)
Put the three things only Epistemos's substrate can do in the FRONT door: (1) **provenance-native editing** —
"every sentence has a verifiable lineage you can hover" with retraction-propagation as the demo (needs R5 built
honestly); (2) **hybrid semantic+structured Views as a query language** — "all `type:Project` notes `before: 30
days ago` *semantically about* runtime safety" (buildable on the shipping RRF stack — ship the visual builder);
(3) **the in-process agent that steers the view** (open_note/highlight/replaceSelection + per-edit approval +
lineage) — gated on Phase 0, highest ceiling. Backend already supersedes Tolaria; these make it a leap.

---

## 13. Editor surfaces recovered into Plan 2 (owner 2026-06-28 — these were dropped; Plan 2 owns them)
The scope-recovery sweep found these owner-confirmed editor items were homed to Plan 2 but not actually listed. Adding
them here so nothing is lost (SCOPE_RECOVERY is now retired — its content lives here + in LEDGER_CURATION).

- **13.1 Graph inline-edit of document nodes (SS-GE A).** Today note/Epdoc/HTML nodes in BOTH graphs bounce to a
  detached `NSDocument` window (`HologramSearchSidebar.swift:847` / `MetalGraphView.activateNode:1959` →
  `EpdocDocumentOpening.openDocument`). Promote `GraphInlineDocPreview` (read-only, flag `EPISTEMOS_GRAPH_INLINE_DOC_EDIT_V0`)
  to inline **edit** via the existing note-save pipeline, using the ONE md-first Epdoc editor (no in-graph clone). Scope:
  note + Epdoc + HTML + code, in `HomeGraphEmbeddedView` + the mini overlay. Honest gating; never a silent no-op.
- **13.2 Home-graph tunnel → Epdoc + HTML-workspace inline (SS-HGT).** Add `case epdoc(id:)` + `case htmlWorkspace(id:)`
  to `GraphWorkspaceRoute`; mount `EpdocEditorChromeView`/`HTMLWorkspaceEditorView` inline in `GraphWorkspaceContainer`
  (the route arm OWNS the `NSDocument` so autosave + `dismantleNSView` teardown fire); redirect open-paths to push routes
  (keep window as explicit "Open in Window"); inherit landing theme. TK2/Prose + Metal engine untouched.
- **13.3 Two-surface fidelity / fix 2 data-loss bugs (SS-2S).** (1) Prose `insertImageAttachment`
  (`ProseTextView2.swift:1786-1808`) drops the image on save (no md serialization of `EpistemosImagePath`) → serialize to
  `![](…)`/`![[…]]` on the `NoteFileStorage` atomic-write path. (2) Epdoc `shadow.md` is lossy → the L1 markdown-as-truth
  flip MUST use the JS `getMarkdown()` full-fidelity bridge as the canonical writer, never the lossy projector (locked in
  MD-source §2a — cross-referenced here as the data-loss guard). "One file, many views"; never damage frozen TK2/Prose.
- **13.4 Instant-recall / Halo popup scoped to the editors + bubble→native NSPopover (SS-IR).** Keep Surface A (Halo
  `HaloButton`+`ShadowPanel`, editor-scoped, click-gated). Stop Surface B (`ContextualShadowsPanel`, the auto-show-while-
  typing "pixel box") from showing on chat/landing/mini-chat; converge on A's native-anchored model; add a glowing bubble
  to Epdoc that opens a **native NSPopover** (not the pixel box); scope recall to Epdoc + TK2 (NOT chat); accuracy-first.

- **13.5 HTML Workspace = REPURPOSE HTML into a real AI-artifact / web-app / explainer BUILDER (Plan 2 owns it).
  ⬆ PULLED FORWARD from step 8 — owner hit it not working (2026-06-29).** ⚠️ This is an UPGRADE feature, not a
  renderer fix — the canonical spec is **`docs/research/SS-HW_HTML_WORKSPACE_STATUS_UPGRADE_2026_06_20.md`** (read
  it; Steps 0–4 + the EXPANSION). The vision (owner 2026-06-20): take the existing `HTMLWorkspaceDocument`/
  `HTMLWorkspaceEditorView` surface and repurpose it so **chat can completely rewrite the whole surface into a live
  website/webpage/explainer** (DOM, live UI, animations) — and even *"explain something"* becomes *"build a
  webpage/explainer from what the model knows"* via **JSON/HTML streaming** (research: StreamHtml/htmlstream,
  `docs/RESEARCH_HTMLSTREAM_2026_06_18.md` — port the per-chunk repair + DOMPurify via the build-time WKWebView
  bundle, MAS-safe). Plus **R-LIVE-ARTIFACTS** (OWNER_REQUESTS_LEDGER): revive `ArtifactHostView` via an
  `ArtifactRoute.htmlWorkspace(id)` + a **self-refreshing `data.json`** bound to a vault/query feed (saved
  `fusedSearch`/RRF or DAG/provenance) → patch the live WKWebView (counters Claude Artifacts). **Mini-chat is the
  primary driver** (any surface via `MiniChatTarget`); main-chat auto-link DEFERRED (no implicit global link).
  Hand-editing routes to the Source (MarkEdit) surface (no second code pane). **HONEST STATE
  (`HTMLWorkspaceCapabilityStatus.swift`): 4 LIVE** (multi-file edit · WKWebView preview · agent chat PATCH pipeline
  `HTMLWorkspacePatchRouter` · export/import/PDF/snapshot) **/ 5 DEFERRED** (app message-bridge stub · console/error
  capture behind `EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0` OFF · live-DOM = static regex · Python Pyodide/WASM unbuilt ·
  full-surface REGENERATE). BUILD ORDER per SS-HW (honesty-first; MAS-safe; reuse Epdoc WKWebView/bridge/URL-scheme +
  build-time bundle): (1) PROVE the 4 LIVE caps on a clean build (if dead = stale binary); (2) **full-surface
  `regenerate`/`replaceDocument`** patch op (atomic, versioned, reversible, AI-provenance) + streaming +
  explainer-from-knowledge — the headline "repurpose" upgrade; (3) real console+error bridge (implement the empty
  `didReceive`); (4) live-DOM inspection + chat-edit hot-reload; (5) "full web app" scaffold pipeline (multi-file/
  multi-route, relax the persistence ban per sandbox mode); (6) Python via Pyodide/WASM in-WKWebView (MAS-safe, no
  subprocess; vendor at build) = research/Pro, honest-gated. Keep the capability ledger TRUTHFUL — flip `isLive:
  true` only when it really is.
- **13.6 Web clipper (Plan 2-owned, UNSPECCED).** Capture web content → a vault `.md` note (frontmatter source-url,
  sanitized HTML→md via the canonical serializer). No code today — needs a design slice; flagged so it isn't lost.
- **13.7 PDF *viewer* (PDFKit `PDFView`) — Plan 2 owns it (was orphaned).** Plan 3 owns the PDF→md PARSE + the `source_pdf`
  storage contract; Plan 2 mounts a native `PDFView` on the resolved `source_pdf` URL (selection/search/thumbnails/outline/
  annotations) + the "View original PDF" affordance. Build the viewer here; consume Plan 3's link, don't re-invent storage.

## 14. MarkEdit full-clone completeness (owner: "literally clone it, settings and all, nothing less")
**★ Method = LITERAL FULL-SOURCE CLONE minus only the un-coexistable shell (see `MARKEDIT_EMBED_CODEPACK §0a`).**
You CANNOT drop the whole `.app` in (macOS allows ONE `@main`/`NSDocumentController` per binary — two = won't compile/
crash). So: `git clone` the ENTIRE MarkEdit source into `LocalPackages/MarkEdit/`, DELETE only its `@main`/AppDelegate
+ `AppDocumentController` + `.xcodeproj` + 2 `.appex`, mount its one `EditorViewController` in an Epistemos window. The
clone is a deterministic SCRIPT (no cherry-picking); the ONLY hand-written part is the VC-mount seam. ZERO editing/
settings capability lost.
**★ Each dropped item maps to an EPISTEMOS EQUIVALENT — harvest the hardening so it's as hardened as the standalone app
(see `MARKEDIT_EMBED_CODEPACK §0a` table):** `@main`/AppDelegate → `EpistemosApp`+`AppBootstrap` (port MarkEdit's
launch setup) · `AppDocumentController` → `EpistemosDocumentController` (register MarkEdit's doc-types with it) ·
`.xcodeproj` → `project.yml` (**harvest** MarkEdit's build settings + Info.plist doc-types/UTIs + entitlements; adopt
MAS-safe, reject MAS-hostile) · 2 `.appex` → Epistemos's own Finder/QuickLook extensions later. Then close these gaps:
- **Add the 3 missing Modules products** to the `project.yml` `dependencies:` in `MARKEDIT_EMBED_CODEPACK` §4 — currently
  9 are declared; a full clone also needs **`FileDrop`** (drag-in), **`Previewer`** (preview pane), **`TextBundle`**
  (`.textbundle` import/export). Without them those capabilities are lost.
- **Decide Scripting/Shortcuts** (`Sources/Scripting` + `Sources/Shortcuts`): vendor both for literal "settings and all",
  OR state explicitly they're dropped (arguably moot inside Epistemos's own shell) — a decision, not a silent omission.
- **Settings is embedded-but-inert** behind `#if EPISTEMOS_MARKEDIT_EMBED` (`Cmd+,` not wired) — add an explicit later
  slice "flip Settings live" so "full settings" isn't read as already user-reachable.
- **The 2 `.appex` (Finder/Preview extensions) are DROPPED** (MAS-hostile, not portable into Epistemos's bundle) — the one
  honest, justified capability loss. State it so the headline doesn't overclaim.
