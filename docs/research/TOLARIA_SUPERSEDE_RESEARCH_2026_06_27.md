# Tolaria-Supersede Research Loop (2026-06-27)

**Running via `/loop 2m` (cron `fc3d7bc7`).** Deliberate multi-pass research until the owner says stop.
Each pass appends findings below + ticks the checklist. When research passes are done → restructure the
editor docs into ONE canonical, contradiction-free plan, then keep deepening until told to stop.

## Locked decisions (owner, 2026-06-27)
- **Route D (confirmed, overrides D′):** FULL MarkEdit cloned and living **inside the Epistemos app** —
  settings, everything, the whole app present — AND the **Tolaria revamp built on Epdoc** in parallel.
- **Foundation = MarkEdit** (MIT). **Editor feel = Tolaria** (looks like Tolaria on edit).
- **Toggles = minimal-but-best** — curate the best Tolaria buttons/toggles (incl. the wide/normal note-width
  toggles the owner loves), not everything.
- **AI = Goose engine** + Tolaria's editing UX/instructions grafted on (study Tolaria's approach).
- **Goal = study Tolaria deeply, clean-room (AGPL — reimplement, NEVER copy code, including system prompts:
  spec the intent, don't paste verbatim), and SUPERSEDE/upgrade it through Epistemos.**
- TipTap vs BlockNote = decide via research (both ProseMirror-family; BlockNote = TipTap + Notion UI).

## Clean-room rule (legal)
Tolaria is AGPL-3.0. Research agents read its PUBLIC repo to produce BEHAVIORAL specs. The implementer
works from the spec, not the source. Reimplement intent; do not copy code or verbatim prompts.

## Pass plan + status
- [x] **Pass 1 DONE** (2026-06-27): (a) Tolaria UX/toggle teardown + minimal-best curation;
      (b) Tolaria AI-editing/agents/system-prompts/context-tracking; (c) TipTap vs BlockNote — DECIDED.
      → **NEW LOCKED DECISIONS below.** Pass 2 next.
- [x] **Pass 2 DONE** (2026-06-27): Tolaria ontology deep-study + MarkEdit Route-D embedding mechanics.
      → Big finding: **Epistemos is ALREADY a document-based app** (`EpistemosDocumentController` +
      `EpdocDocument`/`HTMLWorkspaceDocument`), so MarkEdit's shell grafts cleanly. Pass 3 next.
- [ ] **Pass 3:** Goose ↔ Tolaria AI graft + AI-edit review model (git-diff vs in-editor) + correct
      ProseMirror-era diff/change-tracking repos (the CodeMirror `@codemirror/merge` pick does NOT apply
      to a WYSIWYG editor — resolve the replacement).
- [ ] **Pass 4:** "Supersede Tolaria" brilliance layer — what to do BETTER (semantic/RRF search, provenance
      ledger, real trash+undo, keymap completeness, etc.).
- [ ] **Pass 5:** Contradiction audit across ALL editor docs + the emerging plan.
- [ ] **Pass 6:** RESTRUCTURE into one canonical plan doc (MarkEdit-in-app + Tolaria revamp on Epdoc +
      Goose AI + ontology + minimal-best toggles).
- [ ] **Pass 7+:** Deepen/polish each area until told to stop.

---

## FINDINGS

### ⭐ Decisions locked by Pass 1
1. **EDITOR = TipTap on the EXISTING Epdoc bundle. NOT BlockNote.** (Decisive.) BlockNote would hand you
   Tolaria's exact look for ~0 CSS, BUT: React-only (+React/DOM/Mantine to the WKWebView), `@blocknote/core`
   ~256KB vs `@tiptap/core` ~30KB (8.8×), **props are primitives-only → structurally hostile to our
   ontology** (relations/nested objects can't be node props), no document-level frontmatter slot, and its
   only good AI-diff (`@blocknote/xl-ai`) is **GPL-3.0** (closed-app blocker; $195/mo BlockNote Business to
   ship closed). Adopting it discards all Epdoc work (callout/chart/image/code/graph nodes, brotli scheme
   handler, theme injector, bridge, autosave, slash menu). **TipTap keeps all of it.** "Look like Tolaria"
   = a **CSS + chrome polish task on Epdoc**, not an editor swap. Tolaria's Notion feel IS TipTap-family
   underneath (BlockNote = TipTap + Notion UI), and Epdoc already has slash menu / bubble menu / block
   gutter / drag-handle built.
2. **AI-DIFF STACK (resolves the earlier contradiction): `prosemirror-changeset` (MIT) + decorations**, with
   `@manuscripts/track-changes-plugin` (Apache-2.0) as the mature data layer. **NOT `@codemirror/merge`**
   (CodeMirror-only — wrong engine now), **NOT** TipTap AI Toolkit (paid, private registry), **NOT**
   BlockNote `xl-ai` (GPL). Recipe: stream AI output as PM transactions → feed steps to
   `prosemirror-changeset` → render added/removed spans as green/strikethrough decorations → accept = clear
   decorations, reject = invert steps. 100% MIT, fits Epistemos's in-process streaming. Surface via the
   existing `EpdocCopilotDockView` bounded-command model.
3. **MARKDOWN round-trip:** add the official **`@tiptap/markdown` v3.27.x (MIT)** (NOT the deprecated
   community `tiptap-markdown`, which corrupts YAML frontmatter; NOT the nonexistent
   `@tiptap/extension-markdown`). It preserves unknown HTML as literal text + lets you register custom
   `marked` tokenizers for callouts/wikilinks/frontmatter to make round-trip lossless for OUR constructs.
   Caveat: self-labeled "early release" with open round-trip bugs (#7269 newline doubling, #7353 ol-start,
   #7731 table-cell `<br>`) — prototype the round-trip before promising lossless. Epdoc today does markdown
   via input-rules + paste only (no doc→md serializer in the bundle) — this adds the serializer.
4. **AI ENGINE = Goose** (graft Tolaria's editing *doctrine*, discard its CLI-shell *mechanism*). Goose
   beats Tolaria on: no subprocess sprawl / no external-CLI dependency, native streaming fidelity + real
   cancellation, true per-edit approval + provenance (Tolaria has NO per-edit gate — tools "execute
   immediately"; review is only git after-the-fact), typed transactional vault tools, no two-port Node
   WebSocket bridge to secure, persistent session memory, honest capability gating.

### Pass 1a — Tolaria UX/toggle teardown + MINIMAL-BEST curation
- **Layout:** 4 resizable panels — Sidebar (Inbox/All/Changes-Pulse/Views/Types/Favorites/Folders/Archive)
  · Note List (sortable, snippet; alt = Pulse / Neighborhood) · Editor (rich BlockNote ↔ raw CM6 ↔ diff) ·
  Inspector (Properties|ToC, mutually exclusive; Properties has Dynamic-props/Relationships/Backlinks/Git-
  history) · bottom status bar. Presets **Cmd+1/2/3** (Editor-only / +Notes / All).
- **★ Note-width toggle (owner favorite) — exact spec:** binary `normal` (centered ~700–760px readable) vs
  `wide` (`max-width:none`, margins/padding zeroed). Control = button in editor toolbar/breadcrumb (per-note
  override); global default in Settings (`note_width_mode`). Resolution: transient session cache → `_width`
  frontmatter → settings default. **Persists to `_width` frontmatter ONLY if the note already has a
  frontmatter block** (never creates frontmatter just for UI state — the classy detail). Raw mode ignores
  width (always full). `_width` is a hidden `_`-system property.
- **Command palette = Cmd+K** backed by ONE unified command registry that also drives the native menu bar +
  shortcuts + tooltips (build this first — it keeps the whole app coherent). Cmd+P = separate Quick Open.
- **Key shortcuts:** Cmd+\ raw toggle · Cmd+Shift+I Properties · Cmd+Shift+T ToC · Cmd+Shift+L AI panel ·
  Cmd+Shift+F vault search · Cmd+E mark-organized · Cmd+D favorite · Cmd+Shift+O open-in-new-window ·
  Cmd+Backspace delete (permanent on disk, recover via git — we should ADD real trash+undo).
- **Slash menu deliberately restricted to markdown-round-trippable blocks only** (headings/quote/lists/code/
  mermaid/whiteboard/math) — the discipline is WHY files stay clean. Keep the restraint.
- **MINIMAL-BUT-BEST keep list (ranked, curate to these):** 1) note-width toggle 2) Cmd+K unified command
  registry 3) rich↔raw dual editor on one `.md` 4) files-first `.md`+frontmatter truth 5) `[[wikilink]]`
  autocomplete+rename+backlinks 6) round-trip-only slash menu 7) layout presets Cmd+1/2/3 8) Inspector
  (Properties/Relationships/Backlinks/Git-history) 9) git first-class (status bar + per-note history;
  AutoGit OPT-IN) 10) Inbox + mark-organized 11) Types as light lenses (icon+color, no required-field
  validation) 12) saved Views (but a visual filter builder, not hand-YAML) 13) ToC panel 14) Light/Dark/
  System + no-flash startup 15) global search + quick open (native-fast) 16) math KaTeX + Shiki code (FIX
  the ``` fence bug) 17) Mermaid + lightbox 18) keyboard-first + surface-aware shortcuts 19) drag-handle
  block editing 20) open-in-new-window as the focus surface.
- **DROP/DEFER for minimal:** whiteboards (tldraw), spreadsheets (IronCalc), bundled multi-agent MCP +
  7 CLI integrations (we use Goose), Pulse/Neighborhood viz, multi-vault unified graph, hand-YAML Views,
  telemetry/analytics cluster, diff-view/PDF-export/alpha-channel/type-pluralization.
- **ADD (free differentiation Tolaria lacks):** real focus/typewriter mode, optional width SLIDER (one-up
  the headline feature), real trash+undo, semantic search (our RRF), mobile.

### Pass 1b — Tolaria AI editing (clean-room behavioral spec → graft onto Goose)
- **`AGENTS.md` doctrine:** ONE vault-root guidance file every agent reads; `CLAUDE.md`/`GEMINI.md` are
  redirect shims. App seeds/repairs/status-tracks it (managed/missing/broken/custom). Teaches: filesystem
  is truth; title = first H1 or filename; category in `type:` frontmatter (not folders); relationships =
  any `[[wikilink]]`-valued frontmatter field (auto-inverses for belongs_to/has/related_to); `_`-prefixed
  system props hidden from UI. **Graft this — single best idea; makes any agent competent with zero
  per-model wiring.**
- **Context Snapshot (per-turn JSON in the system prompt):** `activeNote{path,title,type,frontmatter,body,
  wordCount,bodyTruncated}`, `openTabs`, `noteList`(cap 100 + truncation flags + active filter), `vault`
  (types+count), `referencedNotes` (the `[[wikilinks]]` in the prompt). **Honest head-tail truncation:**
  active body 24k (16k head + 4k tail), referenced 12k (8k+2k); middle replaced with an instruction to call
  the read tool before content-sensitive edits — never silent. "Current note" = `activeTabPath`. **Graft as
  a typed context object.**
- **Editing mechanism:** AI edits real files on disk via its own file tools and/or path-validated MCP
  `create_note` (every write validated against vault root, blocks `/../`). Frontend detects the write by
  which tool ran → editor **silently reloads** (modified→reload file; created→reload+auto-open tab).
  **Review is git** (diff + Pulse feed + rollback), **NO per-edit approval dialog** (tools execute
  immediately) → Goose can do BETTER with a real per-edit approval/preview + honest provenance.
- **8 MCP tools:** search_notes, get_note, create_note, get_vault_context, list_vaults, **open_note**,
  **highlight_editor** (UI-steering!), refresh_vault. Transport = stdio to client + two loopback WS ports
  (9710 tool bridge, 9711 UI broadcast). **Graft the UI-steering tools** (agent drives the view, not just
  files) onto Goose's in-process bridge (no Node server, no ports needed).
- **Event model:** N CLI agents → one normalized stream Init/TextDelta/ThinkingDelta/ToolStart/ToolDone/
  Error/Done. Safe(default)/PowerUser per-vault modes → each CLI's native sandbox flags (Safe=no shell,
  Power=vault-scoped shell; never writes outside vault). Tolaria stores NO API keys (forwards env allowlist;
  each CLI owns auth). **Goose already owns this contract natively + better.**
- **AI sidebar:** right panel, open Cmd+Shift+L; agent chosen in Settings (no in-panel picker); edits are
  plain prompts (no separate edit mode); `[[wikilink]]` to reference notes; collapsible thinking
  (auto-expand streaming / auto-collapse done) + tool-action cards (pending/done/error); per-message
  regenerate/copy/fork. (Weak spot: no clear stop/abort button — Goose should have one.)

### Pass 1c — TipTap vs BlockNote (full rationale)
See "Decision 1" above. Net: **stay TipTap on Epdoc**; the ONLY thing given up is BlockNote's free Notion
UI, and Epdoc already has most of that chrome. Concrete next steps when building: (1) add `@tiptap/markdown`
+ custom tokenizers for callouts/wikilinks/frontmatter; (2) add `prosemirror-changeset` + inline accept/
reject decoration layer via `EpdocCopilotDockView`; (3) "look like Tolaria" = CSS/chrome polish; (4) do NOT
adopt `xl-ai` (GPL) or `@tiptap-pro/*` (paid).

---

### ⭐ Decisions locked by Pass 2
5. **ROUTE D, refined to what's actually buildable: vendor MarkEdit's Swift modules + GRAFT onto Epistemos's
   EXISTING document app — do NOT run a 2nd app lifecycle.** Big discovery: **Epistemos is already a
   document-based app** — it has `EpistemosDocumentController: NSDocumentController` + real `NSDocument`
   subclasses (`EpdocDocument`, `HTMLWorkspaceDocument`, `.epdoc` = `com.apple.package`). So MarkEdit's
   document/window/menu/settings layer is NOT foreign tissue. You CANNOT have two `@main` / two
   `NSApplicationMain` / two `NSDocumentController` singletons in one binary — so "full MarkEdit app running
   inside" (literal) is not viable. The viable path that gives you ALL of MarkEdit's chrome:
   - **Vendor:** `MarkEditCore` + `MarkEditKit` (bridge transport) + `MarkEditMac/Modules` SwiftPM +
     `MarkEditMac/Sources/{Editor,Panels,Settings}` source. (MIT — keep LICENSE.)
   - **Drop:** MarkEdit's `AppDelegate`/`Application`/`AppDocumentController`, `CoreEditor` (its CodeMirror
     JS), `chunk-loader://`, and the Finder/Preview `.appex` extensions.
   - **Re-host** `EditorViewController` inside Epistemos's SwiftUI `WindowGroup` via
     `NSViewControllerRepresentable` (exactly how Epdoc already uses `NSViewRepresentable`), wired to the
     EXISTING `EpistemosDocumentController`.
   - **Point its WebView at Epdoc immediately** (`epistemos-doc:///editor.html` + the `epdoc` handler),
     not CoreEditor.
6. **What MarkEdit actually contributes (the prize) = native chrome Epistemos lacks:** native **Find/Replace
   panels**, **Settings tabs**, window/tab management + closed-tab history, **FontPicker**, **Statistics/
   word-count**, Goto-Line, FileVersion picker, App Intents/Shortcuts/scripting. Epdoc contributes the
   already-hardened **web-editor plumbing** (scheme handler + brotli, bridge, theme, save pipeline, shared
   process pool). They're complementary; the two brotli/bridge/theme stacks are mutually exclusive → **keep
   Epdoc's, discard MarkEdit's**.
7. **Editor-swap seam = ONE place:** the `lazy var webView` block in `EditorViewController`. The bridge is
   editor-agnostic in *shape* (Swift→JS `invoke`, JS→Swift one `bridge`/`epdoc` message handler), editor-
   specific in *vocabulary*. Swap = replace MarkEdit's string-buffer methods (`getEditorText`,
   `insertText(from:to:)`, `resetEditor(text:)`) with Epdoc's ProseMirror-JSON methods
   (`contentDidChange(json:)`, `setContent(json:)`). The shell never knows the editor changed. Native Find
   must be re-bound to a ProseMirror search plugin behind the existing search bridge method names (budget
   for this — it's the prize that needs wiring).
8. **Entitlements:** adopt **Epistemos's** set (`cs.allow-jit` ✅ already present, `network.client`,
   `files.user-selected.read-write`, `files.bookmarks.app-scope`, app-sandbox). **REJECT** MarkEdit's
   MAS-hostile keys (`temporary-exception.files.home-relative-path`, `files.user-selected.executable`).
   xcodegen only (`project.yml`) — never hand-edit `.xcodeproj`. Keep `build-tiptap-bundle.sh`; drop
   CoreEditor's vite/yarn build.

### Pass 2a — Tolaria ontology (clean-room spec + Epistemos mapping)
- **Axiom:** filesystem is truth; every concept lives in markdown frontmatter or `.yml` sidecars in the
  vault, never a DB. Caches are 100% rebuildable. (Project was formerly "Laputa" — cache dir `.laputa/`.)
- **Types:** just a `type:` string (canonical; reads legacy `Is A`/`is_a`; list → first wins). No schema
  enforcement ("navigation aids, not enforcement"). A Type IS a markdown file with `type: Type` (a
  "definition doc") whose frontmatter (`_icon`/`color`/`_order`/`template`/`_sort`/`view`/`visible`/
  `_list_properties_display`) supplies instance defaults **at creation only**. Default set
  `[Event,Person,Project,Note]`; starter types cloned from a getting-started repo. Types ⟂ folders
  (retype = rewrite `type:`; move-folder = move file).
- **Relationships (the heart):** ANY frontmatter field whose values contain `[[wikilinks]]` is a
  relationship edge, keyed by the field name (no hardcoded key list). Built-ins `belongs_to`/`has`/
  `related_to` aren't privileged. **Inverses are recomputed in the renderer** (not stored): `belongs to`→
  "Children", `related to`→"Referenced by", custom `Foo`→`← Foo`. Body `[[links]]` → separate
  `outgoing_links`.
- **Frontmatter:** title = first H1 → legacy `title:` → humanized filename (no `title:` field; `untitled-*`
  auto-renames on gaining an H1). `status:` = colored chip. Property kinds: string/number/bool/null/
  scalar-array (tags are just a scalar-array, set semantics) /date(ISO). Properties panel = bidirectional
  view of non-reserved non-`_` keys.
- **System props:** any `_`-prefixed key = app-managed, hidden from Properties UI, excluded from search +
  relationship detection, editable in raw mode. Write canonical `_key`; read accepts legacy aliases
  without rewrite. (`_archived/_icon/_order/_sidebar_label/_sort/_width/_display/_organized/_favorite/
  _favorite_index/_list_properties_display`.) Trash was REMOVED (delete = permanent + confirm; git =
  recovery) — **we should ADD real trash+undo**.
- **Views:** `.yml` files in `.laputa/views/`; recursive `all`(AND)/`any`(OR) tree of
  `{field,op,value,regex?}`; ops equals/not_equals/contains/not_contains/any_of/none_of/is_empty/
  is_not_empty/before/after; NL relative dates ("3 days ago"); field resolution = struct fields →
  properties → relationships. "Collections" (ADR-0144) is the unifying model (filters/types/folders/views/
  neighborhood = collection + presentation).
- **VaultEntry / cache:** parsed per-note projection; 3-layer `Filesystem→cache(~/.laputa/cache/<hash>.json,
  CACHE_VERSION=14)→React state`, filesystem wins. **Git-aware incremental rescan:** same HEAD → `git
  status` dirty only; different HEAD → `git diff old..new`; else full `walkdir`. Search = keyword-only,
  no index, `walkdir` at query time.
- **Epistemos mapping:** frontmatter = durable truth; **SDPage + GRDB = derived cache** (mirrors "filesystem
  wins"). Types stay as `SDPage` notes with `type: Type` (no new SwiftData entity; cache a type→metadata
  registry). **Relationships → the unified GRAPH** (Epistemos's biggest win: persist forward+inverse typed
  edges vs Tolaria recomputing). `_`-convention adopted verbatim. Views = `.yml` IN the vault (git-sync),
  evaluated via GRDB/graph predicates. Incremental git-HEAD+content-hash crawler added to
  `ShadowVaultBootstrapper`. Search = RRF (BM25+HNSW) >> Tolaria's no-index walkdir.
- **5 ways to SUPERSEDE:** (1) persisted bidirectional typed relationship graph + multi-hop queries +
  centrality (vs recomputed inverses); (2) schema-LIGHT advisory validation (declare kinds/enums on the
  Type doc, gentle hints + typed editors, never reject); (3) hybrid views — add a `semantic:` op backed by
  shadow HNSW, fused with structured predicates via RRF; (4) incremental content-addressed provenance-aware
  reindex (per-note hash deltas into GRDB+shadow+graph, DAG/ledger replayable, additive migrations vs
  CACHE_VERSION full-rebuild); (5) type-aware presentations (boards/calendars/tables on typed edges +
  validated props) + honest in-process agent that proposes frontmatter edits the user confirms.
- (Full AGPL source cloned at `/tmp/tolaria-research/` by the research agent — behavior only, reimplement.)

---

