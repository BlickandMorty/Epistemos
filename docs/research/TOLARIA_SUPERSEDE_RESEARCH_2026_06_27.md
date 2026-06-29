# Tolaria-Supersede Research Loop (2026-06-27)

> ★ **CANONICAL PLAN = `EDITOR_CANONICAL_PLAN_2026_06_27.md`** (written pass 6 — the single source of truth).
> This doc is the running research LOG; that doc is the consolidated plan. Code detail = the 4 codepacks.
>
> **★ 2026-06-29 supersession:** this research log contains historical pass notes. The current Plan 2 canon
> reverses several entries below: keep the old code editor as a v1-legacy fallback; make MarkEdit settings
> user-reachable before final acceptance; build only Goose note-context plumbing from Plan 2; do not build a
> separate native chat UI; do not wait for Phase-0/§7 sign-off; verify current routes instead of trusting stale
> line numbers.

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

## OWNER DECISIONS 2026-06-27 (late-loop, supersede earlier where they conflict)
- **★ Q1 SOURCE OF TRUTH = MARKDOWN-ON-DISK (owner-locked).** Vault `.md` + frontmatter is durable truth;
  `.epdoc` package JSON demotes to a derived cache. Proceed with the Pass-8 staged flip
  (`EPISTEMOS_MD_SOURCE_OF_TRUTH`: jsonOnly → dualWrite → markdownCanonical), serializer-first, falsifier-gated.
- **Grammar / Minichat / Width / Code-swap / Cleanup / Provenance:** owner asked for recommendations
  (laid out in chat 2026-06-27). **2026-06-29 supersession:** grammar=Obsidian/GFM; Goose work in Plan 2 =
  note-context plumbing only; width=720px/`max-width:none` plus slider; code-swap=MarkEdit Source default with
  MD MarkEdit chrome and CODE v1-minimal-on-MarkEdit; cleanup=KEEP old code editor as v1 legacy; provenance=ship
  the existing Swift `AgentNoteEditProvenance` spine (defer the new Rust FFI).

## Locked decisions ADDED mid-loop (owner, 2026-06-27 — supersede where they conflict with earlier)
- **MarkEdit = FULL app embedded, full settings, completely closed-in, settings must become user-reachable.** Owner:
  "full thing full app, please do not do anything other than full thing full app." Embed everything incl.
  the full Settings; note/markdown stuff lives "under a different mode." Early inert settings were only a build
  slice, not final acceptance.
- **MarkEdit's CodeMirror = the CODE EDITOR** (replaces Epistemos's current code editor, which looks less
  polished than MarkEdit). ⟹ **UPDATES Pass-2 Decision 5: do NOT drop `CoreEditor`.** Keep MarkEdit's
  CodeMirror as the code-editing surface; Epdoc/TipTap stays the *note* editor. Each tool to its strength:
  CodeMirror for code, TipTap for rich notes. (Open sub-question for research: keep Epistemos's existing
  code-editor UI/chrome and drop just its engine, or replace the whole surface with MarkEdit's.)
- **AI chat = EXTEND Goose, not a new agent.** After Plan 1 Option 1, the live chat/agent UI remains Goose's
  reskinned WebView owned by Plan 1. Plan 2 owns only the open-note context plumbing and editor affordance routes
  that let Goose act on the active note.
- **Nativeness = maximize.** Native buttons/controls like MarkEdit has, as much as possible. The text stack
  is WebView (not native) but the *chrome* (toolbar/Find/Settings/FontPicker/panel toggles/menus/width
  toggle) should be native AppKit wherever it can. Goose-side nativeness is less critical but still wanted.
- **RESEARCH OUTPUT REQUIREMENT (from here on):** every researched subsystem must come with **code snippets
  + a concrete 1:1 upgrade mapping** (Tolaria behavior → the actual Epistemos Swift/Rust code that upgrades
  it). Clean-room for Tolaria (write NEW Epistemos code, never paste AGPL); MarkEdit is MIT (adapt freely).

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
- [x] **Pass 3 DONE** (2026-06-27): Goose↔Tolaria AI graft + review model + ProseMirror diff stack.
      → Big finding: **most of the AI-graft infra already EXISTS in Epistemos** (`WorkNativeMCPServer` +
      `WorkToolMCPCore` + `WorkAppContextSnapshot` + the full Goose ACP client). Also an HONESTY
      CORRECTION to a pass-1 claim (see below). Pass 4 next.
- [x] **Pass 4 DONE** — code-level, per owner's mid-loop directive (all 4 codepacks landed):
   - [x] 4a — `TOLARIA_ONTOLOGY_UPGRADE_CODEPACK_2026_06_27.md`
   - [x] 4b — `MARKEDIT_EMBED_CODEPACK_2026_06_27.md` (★ current code editor = textarea, highlighting DISABLED)
   - [x] 4c — `NATIVE_CONTROLS_CODEPACK_2026_06_27.md` (Epdoc already MarkEdit-shaped; gaps = Find/width/palette)
   - [x] 4d — `GOOSE_MINICHAT_CODEPACK_2026_06_27.md` (superseded 2026-06-29: Plan 2 context plumbing only; live UI is Plan-1-owned Goose WebView/reskin)
- [x] **Pass 5 DONE** (2026-06-27): CONTRADICTION AUDIT complete. 6 BLOCKERS found (all the same reversal:
      SS-CM + CODEMIRROR_MD_V2 said "CodeMirror=primary note editor, drop TipTap" — REVERSED) + planted banners
      in EPDOC_MD_V2 + SS-P. **All 4 poisoned banners FIXED this pass.** 4 codepacks + §16 clean. Open questions
      catalogued below. Pass 6 next.
- [x] **Pass 6 DONE** (2026-06-27): RESTRUCTURE complete → `EDITOR_CANONICAL_PLAN_2026_06_27.md` written
      (surface model, locked decisions, all areas, build sequence, license ledger, 6 open questions up top).
      **The core research + restructure is now COMPLETE.**
- [x] **Pass 7 DONE** (2026-06-27): PER-STAGE VERIFICATION/FALSIFIER SPECS (matches the owner's "done only
      when verification passes" doctrine). Two lanes appended below: **7a** = MarkEdit embed + code-editor swap
      (stages 5.1–5.8, each with green criteria + falsifiers + CI-PROVABLE vs RUNTIME-ONLY honesty ledger);
      **7b** = Goose minichat (A1–A6) + native controls (B1–B4) + ontology (C1–C5). **3 real implementer traps
      surfaced from source:** (1) `GraphStore.addEdge` silently drops edges to not-yet-loaded nodes (`:871-874`);
      (2) `GraphEdgeType` is a strict 12-case FFI contract — inverse edges must reuse a type + `fmrel:inv:`
      prefix, not a new case; (3) the ontology codepack's `firstNode(matchingTitle:)` doesn't exist (compile
      blocker). Plus: `vendor/` vs `LocalPackages/` path correction; `GooseACPClientTests.swift:38` currently
      asserts the mcpServers BUG. Pass 8 next.
- [x] **Pass 8 DONE** (2026-06-27): RESOLVED open-Q1 (JSON-vs-markdown source-of-truth fork) into a buildable
      two-sided code pack → `MD_SOURCE_OF_TRUTH_CODEPACK_2026_06_27.md` (8a JS serializer + 8b Swift write-through).
      6 top-level findings surfaced from source (see codepack + below). The single biggest underserved blocker
      now has a staged, reversible, falsifier-gated plan. Pass 9 next.
- [x] **Pass 9 DONE** (2026-06-27): two deepen code packs → `AI_INSTRUCTIONS_AND_GRAMMAR_CODEPACK_2026_06_27.md`.
      **9a** = the owner's "down to system prompts / AI-edit instructions" goal AS CODE (`VaultAgentsGuideManager`
      seed/repair/shims + original clean-room AGENTS.md body + thin per-turn preamble + doctrine-in-MCP-tool-
      descriptions + 4 SUPERSEDE seams). **9b** = grammar-unification (align `ProseMirrorMarkdownProjector.swift`
      to the JS/Obsidian grammar: 3 diffs + shared-fixture parity test; lands BEFORE the Pass-8b flip). Two
      load-bearing findings below. Pass 10 next.
- [x] **Pass 10 DONE** (2026-06-27): the FOUNDATIONAL native-controls stage → `COMMAND_REGISTRY_CODEPACK_2026_06_27.md`.
      ONE `@Observable CommandRegistry` (id-deduped, scope-narrowed `.global/.note/.code`, `isEnabled`-filtered)
      drives native menu bar + every shortcut (declared ONCE) + a new native Cmd+K palette. **10a** = registry
      core + palette SwiftUI + menu/shortcut binding; **10b** = curated command catalog + dispatch glue through
      the verified `EpdocEditorChromeController.dispatch`/`runCommand` seam. Findings: Cmd+K free; ~80% of Epdoc
      commands wrap EXISTING cases; the `caretChanged`-has-no-marks gap blocks honest `isEnabled` (3-file fix);
      5 shortcut collisions catalogued (⌘1/2/3, ⌘E, ⌘K, ⌘⇧I, ⌘G). Pass 11 next.
- [x] **FINALIZATION (2026-06-27, owner-requested) — loop STOPPED (cron `669316a7` deleted).** 3 independent
      audits ran (contradiction / supersede-Tolaria / completeness); findings folded into the CANONICAL PLAN
      **§12** (the now-authoritative honest-state section). Owner LOCKS applied: **L1 markdown-as-truth · L2
      width = toggle + slider · L3 keep the old code editor as v1 legacy while MarkEdit becomes default**; recommendations R1–R5 recorded (audit-verified best, pending
      final nod). Corpus contradictions fixed: provenance §6 (Swift spine not Rust ledger), `update_note`→
      `edit_note`, `@tiptap/markdown` 3.27→3.24, `vendor/`→`LocalPackages/`, width pixels → 720px/none, stage
      5.8 deletion VOIDED. P0 pre-build checks + first-slice recorded in §12. **The canonical plan §12 is the
      read-first for any build work.**

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

### ⚠️ HONESTY CORRECTION (Pass 3 overrides a Pass-1 claim)
Pass 1 / the earlier AI-edit-UX research claimed "Cursor + Zed both shipped live in-editor agent typing
and REMOVED it for reliability; users want it back." **Primary sources do NOT support this.** Both still
stream edits live today and *added a review layer on top*. The one real primary signal (Zed PR #58037,
merged 2026-05-29) shows streaming each char as its own transaction caused jank — and Zed's fix was to
**BATCH the streaming, not remove it** (61–90% latency win). Cursor's only "review UI disappeared" case was
a bug (build 2.6.19), since fixed; in May 2026 it moved the *default* review granularity to session-level
(no stated reliability reason) and users want the granular inline diffs back. **Corrected takeaway: an
in-editor live diff trail is VIABLE — the real constraint is "batch transactions per settled chunk, never
per token."** Carry this corrected version into the canonical plan.

### ⭐ Decisions locked by Pass 3
9. **AI-EDIT REVIEW MODEL = HYBRID. Git-diff/file-level review is the SPINE; in-editor diff decorations are
   an OPT-IN for small single-note edits.** Model A (agent writes `.md` → editor reloads → review via git
   diff + activity feed + rollback) is the low-risk default and the natural fit for markdown-as-truth + a
   git-backed vault (Tolaria's model). Model B (stream edits as PM transactions → green-insert/strike-delete
   decorations → per-chunk accept/reject) is added ONLY for small in-place edits the user invokes on a
   selection — and the diff is computed **once per settled chunk, never per token** (the Zed #58037 lesson).
10. **FINAL ProseMirror diff stack (all permissive, TipTap-3 compatible via `addProseMirrorPlugins()`):**
   **`prosemirror-changeset` (MIT)** = the canonical diff-data primitive (step→added/deleted spans with
   arbitrary per-span `data`; it's literally what TipTap's PAID AI-diff is built on) → render via your own
   `Decoration`s → optional command layer **`@handlewithcare/prosemirror-suggest-changes` (MIT, NYTimes/
   BlockNote pedigree)** for accept/reject. Streaming wiring = **two-doc diff**: snapshot `originalDoc`,
   stream into a staging doc (batched), on settle generate steps (`prosemirror-recreate-transform` — note:
   weakest-maintained link) → `ChangeSet.create(orig).addSteps(...)` → decorations; accept commits + writes
   `.md`, reject inverts. EXCLUDE TipTap AI Toolkit (paid), BlockNote xl-ai (GPL), @codemirror/merge (wrong
   engine), and treat `prosemirror-suggestion-mode` with caution (MIT only per npm metadata, no LICENSE file).
11. **AI graft is mostly "rename/repoint/extend," NOT build-from-scratch — the infra EXISTS:** Epistemos
    already has `WorkNativeMCPServer` (loopback HTTP MCP, per-launch bearer token, Origin allowlist,
    constant-time auth), `WorkToolMCPCore` (JSON-RPC initialize/tools-list/tools-call, already exposes
    `epistemos.context.snapshot`), and `WorkAppContextSnapshot`/`WorkAppContextStore` (typed thread-safe
    context already carrying `activeNoteTitle`/`activeNotePath` + head/tail truncation), plus the full Goose
    ACP client/supervisor/event-bridge/provider-key-bridge.
12. **CONTEXT INJECTION = MCP-pull primary + thin per-turn preamble (better than Tolaria's push).** ACP has
    no system-prompt slot, so: (a) a `vault.context_snapshot` MCP tool the agent calls on demand (no stale
    snapshot, no per-turn context burn), + (b) a 1-line "the user is currently on note X" preamble on the
    first prompt block. `AGENTS.md` instructs "call context_snapshot before content-sensitive edits."
13. **PROVENANCE that supersedes git-author-only:** per accepted edit, emit an `EditClaim` into the existing
    `ClaimLedger` (`agent_core/src/provenance/ledger.rs`) with `agent_id`/`model_id`+version/`runtimeKind`/
    `capability_tier`/`confidence`/approver/`generatedAt` vs `acceptedAt` — fields git's 2-identity model
    can't hold. Content-address each edit span in the `cognitive_dag` (`DerivesFrom`/`AttributedTo`/
    `ApprovedBy`/`Evidence` edges, Merkle tamper-evident). Carry the `claimId` in the changeset span `data`
    so an inline hunk, a git commit, and a DAG node share ONE identity. **Retraction propagation** (already
    implemented, bounded-walk) beats `git revert` (it knows which later edits *depended on* the retracted
    one). Git = bytes layer; ledger+DAG = meaning layer.

### Pass 4a + 4b — code-level upgrade packs (full code in dedicated docs)
- **4a Tolaria ontology → Epistemos** (`TOLARIA_ONTOLOGY_UPGRADE_CODEPACK_2026_06_27.md`): 7 clean-room Swift/
  Rust snippets, each mapped to a real file — `NoteOntologyParser` (typed parse over the existing flat
  `parseFrontMatter`), `FrontmatterRelationshipReconciler` (persist forward+inverse typed edges into
  `GraphStore` — beats Tolaria's recompute), `SystemKeys` (one `_`-convention table enforced across FTS+HNSW+
  graph), `ViewDefinition`/`ViewCompiler`/`ViewEvaluator` (compile all/any tree → indexed GRDB SQL + a
  `semantic:` op RRF-fused with HNSW), `NoteWidthResolver` (binary normal/wide + the "never create frontmatter
  for UI state" guard), `TypeRegistry` (in-memory projection over `SDPage`, no new entity, advisory schema-light
  validation), `incrementalCrawl` (per-note content-hash deltas into 3 engines, additive — no CACHE_VERSION wipe).
- **4b MarkEdit embed + code editor** (`MARKEDIT_EMBED_CODEPACK_2026_06_27.md`): ★ **current code editor is a
  plain textarea with highlighting DISABLED (dead `renderHighlight()`), NOT CodeMirror** → MarkEdit's CM6 is a
  strict upgrade; Epistemos's SwiftUI chrome (top bar/Find/Go-to-Line/Outline/Live-Preview/LSP-hover) is worth
  keeping. Plan: vendor `MarkEditCore`+`MarkEditKit`+`Modules`(11 libs incl. SettingsUI/FontPicker/Statistics)+
  `Sources/{Editor,Panels,Settings}`+`CoreEditor`; DROP its `@main`/AppDocumentController/.xcodeproj/entitlements/
  both `.appex`; re-host `EditorViewController` via `NSViewControllerRepresentable` against the existing
  `EpistemosDocumentController`; vendor FULL `SettingsUI` panes and wire them user-reachable before final acceptance.
  **Code-editor swap = Option A** (keep Epistemos chrome, swap engine textarea→CoreEditor at
  `CodeEditorView.codeEditorSurface`) **+ selectively graft MarkEdit's native Find/FontPicker/Statistics/
  Goto-Line** (= maximize nativeness without surrendering chrome). LSP: keep one-shot Swift `CodeEditorSemanticLSP`
  over `RustLSPTransport` (engine-agnostic); CM6 LSP-client extension deferred. Build: clone
  `build-tiptap-bundle.sh`→`build-coreeditor-bundle.sh` (vite+yarn, lock-hash gate); keep `chunk-loader://` first
  (brotli-unify later); adopt Epistemos entitlements (reject MarkEdit's MAS-hostile keys); xcodegen `project.yml`.

### Pass 5 — contradiction audit (resolved) + open questions
**One structural fault line** (predicted): `SS-CM` + `CODEMIRROR_MD_V2` declared "CodeMirror = PRIMARY note
editor, drop TipTap" (written 17:18, BEFORE the loop reversed it); their supersede banners poisoned
`EPDOC_MD_V2` + `SS-P`. 6 BLOCKERS (B-1..B-6) = the same reversal across axes: note-engine, code-engine,
MarkEdit-role, AI-diff-lib, "markdown round-trip solved". **FIXED this pass — all 4 banners rewritten:**
- `SS-CM` → hard supersede → T; re-scoped to CODE-lane research only; "decision (locked)" table marked historical.
- `CODEMIRROR_MD_V2` → hard supersede → T; CM6/MarkEdit/typography research reusable for the CODE editor only.
- `EPDOC_MD_V2` → un-demote banner: Epdoc/TipTap IS the note editor (CANONICAL); `@tiptap/markdown` name fix;
  note AI-diff = prosemirror-changeset; JSON↔md does NOT evaporate (still the open fork).
- `SS-P` → corrected: "graft onto Epdoc" was RIGHT; the 2nd surface is the CODE editor; AGPL clone-forbidden stands.
The 4 Pass-4 codepacks + `SURFACE...§16` are aligned with the truth (only minor reconciliations: width pixels,
package name, the within-T `@manuscripts`→`@handlewithcare` evolution — use the Pass-3 name).

**⚠️ OPEN QUESTIONS captured historically; current resolutions live in the canonical plan.**
1. **JSON-vs-markdown source-of-truth fork (resolved L1):** serializer-first → canonical-`.md` flip →
   HTML-in-md fallback for rich blocks; the real Goose write seam is `edit_note`, not `update_note`.
2. **Minichat shape (resolved 2026-06-29):** Plan 2 builds note-context plumbing only. Live chat/agent UI is
   Plan-1-owned Goose WebView/reskin under Option 1.
3. **Note-width pixels (resolved L2):** binary 720px/`max-width:none` plus a slider.
4. **Code-editor swap scope (resolved L3/L3-CHROME/L4):** MarkEdit Source is default; MD uses MarkEdit chrome;
   CODE reimplements the v1 minimal look on MarkEdit; the old editor stays reachable as v1 legacy.
5. **`@codemirror/merge` for the CODE editor:** excluded for notes; it's the natural diff engine for the CM6
   CODE editor — capture this positive re-scope.
6. **Cleanup fate (resolved 2026-06-29):** keep the old code editor as a v1-legacy fallback. Do not delete
   `WebKitCodeEditorView`/dormant code-editor scaffolds unless the owner later approves a separate cleanup.

### Pass 4c + 4d — code-level (full code in dedicated docs)
- **4c Native controls** (`NATIVE_CONTROLS_CODEPACK_2026_06_27.md`): ★ Epdoc is ALREADY MarkEdit-shaped
  (native SwiftUI chrome → `EpdocEditorCommand` → `window.epistemos.*`). Gaps to close: Find/Replace,
  note-width toggle (CSS var already exists), panel-toggle segmented control + focus-scoped shortcuts, and the
  big one — a **unified `CommandRegistry` powering menu bar + shortcuts + a NEW Cmd+K palette** (entirely
  missing; Cmd+K is free). Code provided for all. MUST stay in WebView = the 4 caret-anchored TRIGGERS (slash/
  bubble/drag-handle/KaTeX) — but their PANELS are already native. Code editor: mirror the enum
  (`CodeEditorCommand`). Build order: registry+palette → Find/Replace → width → panels → status bar.
- **4d Goose note-context plumbing** (`GOOSE_MINICHAT_CODEPACK_2026_06_27.md`, superseded in scope 2026-06-29):
  do not build a separate native chat UI from Plan 2. Lifecycle = ONE shared session re-scoped per note
  (cwd=vault constant). Auto-init = `ActiveEpdocTracker`
  (frontmost note) + `NoteContextProvider` (bounded head/tail body via existing `ProseMirrorMarkdownProjector`)
  → `WorkNativeMCPHost.updateContext`. **Goose-boundary gaps:** `GooseACPClient.newSession` drops `mcpServers`
  (1-line), NO cancel/stop method (add `session/cancel`), NO Epdoc UI-steering affordances (add `open_note`/
  highlight). Build the editor-side note-context plumbing now (zero Goose dep, testable); Plan 1 owns the live
  Goose WebView/reskin surface.

### Pass 3a — Goose graft architecture (concrete)
- **Goose seam:** `GooseRuntimeSupervisor` spawns `goose serve` (:3284, hardened env, Keychain keys pushed
  post-connect via `GooseProviderKeyBridge`, `#if EPISTEMOS_APP_STORE` → unavailable = Pro/Dev-ID only).
  ACP over WS: `session/new {cwd=vaultRoot, mcpServers}` → `session/prompt [text]` → `session/update`
  (`agentThoughtChunk`/`agentMessageChunk`/`toolCall`/`toolCallUpdate{kind,status}`) → **`session/
  request_permission` = REAL per-tool approval gate Tolaria lacks** → `session/fork` for branch.
- **file/page context tracking (owner's specific want):** new `@MainActor EditorContextTracker` observes
  the frontmost `.epdoc` window (active note path/title/manifestID), caret/selection (`caretChanged`),
  open tabs (`EpistemosDocumentController.documents`) → live `EpdocAIContextSnapshot` in a thread-safe
  store; the MCP `vault.context_snapshot` tool reads it → always live (pulled, not stale-pushed).
- **8 MCP tools to expose (mirror Tolaria + UI-steering trio):** `vault.context_snapshot`, `vault.search`
  (RRF — beats Tolaria's no-index walkdir), `vault.get_note` (honest head/tail truncation), `vault.create_
  note`, `edit_note`/`vault.propose_edit`, `open_note` (UI-steer via `EpdocDocumentOpening`),
  `highlight_editor` (new `EpdocEditorCommand.highlightRange`), `refresh_vault` (`ShadowVaultBootstrapper`).
- **Edit round-trip:** Path A (MCP `edit_note` writes file → reload via `setContent` + self-write
  suppression, like the HTMLWorkspace path) for bulk/create; Path B (stream → `prosemirror-changeset`
  decorations via `EpdocCopilotDockView`) for AI-authored in-place edits.
- **AI sidebar (Cmd+Shift+L):** thin SwiftUI projection of `GooseACPEventBridge` — composer with
  `[[wikilink]]` autocomplete, collapsible thinking (auto-expand streaming/auto-collapse end_turn), tool
  cards keyed by `toolCallId`, **inline per-edit approval** (allow_once/always/reject → `resolvePermission`),
  **Stop/abort** (Goose `cancelled` — Tolaria has none), per-message copy/regenerate/**fork**. Agent/model
  from Goose's provider catalog. Safe/Power → `GOOSE_MODE`. MAS build = honest "Pro only" state.
- **⚠️ SOURCE-OF-TRUTH FORK to resolve before `edit_note` is "done":** Epdoc historically stored ProseMirror
  JSON in `.epdoc` packages, NOT markdown-on-disk. Markdown-as-truth (add `@tiptap/markdown` serializer) is
  the LOCKED direction but UNBUILT. Path B (diff decorations) sidesteps it for AI-authored edits; Path A
  needs the serializer (or write JSON into the package meanwhile).
- **What's BUILD vs EXISTS:** EXISTS = full ACP stack, the loopback MCP server + JSON-RPC core + security,
  the typed context store w/ truncation, Epdoc bridge + document controller, RRF search, copilot dock,
  the clean-room Tolaria spec. BUILD = `EditorContextTracker`, repoint Work-MCP → vault/editor MCP + the 8
  tools, `EpdocEditorCommand.highlightRange`/`proposeEdit`/`reloadFromDisk`+suppression,
  `VaultAgentsGuideManager` (seed/repair/status AGENTS.md + shims), per-turn preamble builder, the sidebar
  SwiftUI view, head/tail truncation in `get_note`, Safe/Power → GOOSE_MODE.

---

### Pass 7a — Verification/falsifier specs: MarkEdit embed + code-editor swap

> **Scope:** build-sequence item 5 (`EDITOR_CANONICAL_PLAN §10.5`) — vendor MarkEdit, clone the bundle script,
> make MarkEdit Source the default engine, graft/preserve the required panels, wire full Settings live, and keep the
> old code editor as a v1-legacy fallback. Headless signals tagged `[CI-PROVABLE]`; runtime-only tagged
> `[RUNTIME-ONLY]` (needs signed `Product▸Run`).
>
> **★ Load-bearing correction to the code pack** `[VERIFIED-CODE]`: `MARKEDIT_EMBED_CODEPACK §4` shows `path: vendor/MarkEdit/...`, but the repo convention is **`LocalPackages/`** (`project.yml:479-487`: `mlx-swift`, `SwiftTerm`, `GGUFRuntimeBridge`, `CodeEditSourceEditor` all live there; nothing uses `vendor/`). Vendor under `LocalPackages/MarkEdit/` or the path assertions below correctly fail.

**5.1 — Vendor sources, drop app-lifecycle/project/entitlement/appex.** Green: `LocalPackages/MarkEdit/{MarkEditCore,MarkEditKit,MarkEditMac/Modules}` present + MIT LICENSE preserved + ProvenanceGate `clean_import` record. Falsifiers (must be absent): any `.xcodeproj`/`.appex` under the vendor dir; any `@main`/`NSApplicationMain` (collides with `EpistemosApp.swift:934` lone `@main`); `AppDocumentController.swift` present (2nd `NSDocumentController` races `EpistemosDocumentController` → non-deterministic shared singleton → open/save crash); any `Info.entitlements` reachable by the build.

**5.2 — xcodegen wires packages, lint plugin stripped.** Green: `xcodegen generate` exits 0 + `.xcodeproj` is a pure artifact; `grep 'LocalPackages/MarkEdit' project.yml`; `Main/Application/**` in `excludes:`; `! grep 'plugins:' .../Modules/Package.swift`. Falsifiers: `path: vendor/MarkEdit`; manual `.pbxproj` hunk (CLAUDE.md DO-NOT); SwiftLint plugin pollutes the build graph.

**5.3 — `build-coreeditor-bundle.sh` (clone of tiptap script), lock-hash gated, no RUNTIME npm/yarn.** Green: executable; `shasum -a 256` gate on `CoreEditor/yarn.lock`; missing-bundle sanity `exit 2`; in BOTH `preBuildScripts` (Pro `:92`+AppStore `:194`); PATH-hardening block. Falsifiers: any Swift-side `Process()`/npm/yarn spawn (`grep -rn 'Process()\|npm\|yarn' Epistemos/ --include='*.swift'` → MAS/hardened-runtime violation; build-time ≠ runtime, only Swift spawns are the falsifier); gates on `package-lock.json` not `yarn.lock`; runs after xcodebuild / absent from preBuildScripts.

**5.4 — Entitlements: adopt Epistemos's, REJECT MarkEdit's MAS-hostile keys.** Baseline confirmed clean THIS session (`temporary-exception.files.home-relative-path` + `files.user-selected.executable` absent from all 3 `.entitlements`) → **regression-prevention**, not remediation. CI gate:
```bash
for f in Epistemos/Epistemos.entitlements Epistemos/Epistemos-AppStore.entitlements Epistemos/Epistemos-Debug.entitlements; do
  ! grep -qE 'home-relative-path|user-selected\.executable|temporary-exception' "$f" || { echo "MAS-HOSTILE KEY in $f"; exit 1; }
done
```
Real risk surface is the static plist — fully catchable headlessly though signing enforcement is `[RUNTIME-ONLY]`.

**5.5 — Swap seam textarea→CoreEditor at `CodeEditorView.codeEditorSurface` (verify current line numbers).**
★ `[VERIFIED-CODE]`: the v1 code editor is a **plain textarea, highlighting DISABLED** (`WebKitCodeEditorView.swift`
`renderHighlight(){ return; }`) and is now retained as legacy, not the default. Green: new
`MarkEditCodeEditorRepresentable: NSViewControllerRepresentable` over `EditorViewController`; default surface uses
MarkEdit while `WebKitCodeEditorView` stays reachable only through the v1-legacy toggle; `bridge.core.*` selectors
exist in vendored `Generated/` (verify ts-gyb — codepack marked `[INFERRED]`); reaches CodeSign with
`CODE_SIGNING_ALLOWED=NO`. `[RUNTIME-ONLY]`: real CM6 highlighting, autosave debounce, LSP hover. Falsifiers:
default surface still silently mounts `WebKitCodeEditorView`; a `resetEditor` selector with no `Generated/` match
(compile-fail); no `lastPushed` dedupe → edit-loop/cursor-reset; any `DispatchQueue.main.sync` in a UniFFI/bridge
callback (deadlock).

**5.6 — Coexistence: CoreEditor `chunk-loader://` + Epdoc `epistemos-doc://`, routed by lens/extension; shared pressure handler.**
Green: code extensions open Source/CoreEditor; `.md` can explicitly open Source(MarkEdit) while preserving
Note/Prose lenses; each scheme on exactly one `WKWebViewConfiguration`; no two `"bridge"` handlers on one content
controller; CoreEditor WebView registered with the shared memory-pressure tracking. Falsifiers: duplicate scheme
registration (`WKWebView` traps → crash); `.md` Source lens unreachable; `.md` forced to Source only; CoreEditor
escapes memory-pressure relief (30-50 MB/editor leak).

**5.7 — Full MarkEdit Settings live/reachable.** Green: Settings panes are vendored and reachable from the Source/MD
surface or app Settings; builds WITH and WITHOUT any embed flag; flag in `project.yml` for embed config only.
Falsifiers: Settings panes hidden behind an inert flag at final acceptance; flag bleeds into AppStore scheme;
flag-unset build fails.

**5.8 — Keep the v1 legacy fallback (2026-06-29 L3 reversal).** After a MANUAL real-app verify that MarkEdit
CoreEditor types + highlights + saves, keep `WebKitCodeEditorView` reachable from Settings + a toggle inside the
MarkEdit surface. Dormant code-editor scaffolds may be flagged, but deletion requires a separate explicit owner
approval and commit. **Hard falsifier (the L3 scope guard):** old code editor deleted or unreachable; any
`Epdoc*`/`ProseTextView2`/`ProseEditorView` behavior broken by the code-editor swap.

**Honesty ledger:** all of {vendor/drop presence, no-`@main`/`.appex`, xcodegen-only, lint-strip, bundle wiring,
MAS-hostile entitlement leak (static plist), swap-seam grep, selector existence, scheme disjointness,
settings-live reachability, v1-legacy reachability + `swift test`} = `[CI-PROVABLE]`. **CM6 highlighting/typing/
LSP-hover + code-signing = `[RUNTIME-ONLY]`** (per `headless_xcodebuild_signing`: treat "reached CodeSign, 0 other
errors" as compile-OK).

### Pass 7b — Verification/falsifier specs: Goose minichat + native controls + ontology

> Tiers: `[HEADLESS]` (compile/grep/`swift test`/`cargo test`/MCP JSON-RPC round-trip over a stub) vs `[RUN-APP]`;
> live Goose UI is Plan-1-owned after the 2026-06-29 upgrade.

**A. GOOSE-MINICHAT**
- **A1 — `newSession` carries `mcpServers` (1-line gap).** `[VERIFIED-CODE]` `GooseACPClient.swift:74-83` calls `GooseACPNewSessionRequest(cwd:metadata:)` with NO `mcpServers`, though the struct supports it (`GooseACPProtocol.swift:755-771`). ⚠️ **`GooseACPClientTests.swift:38` asserts `mcpServers == .array([])` — it LOCKS IN the bug; any fix MUST update it.** Green: signature gains `mcpServers:` + body forwards it; recording-stub round-trip asserts `params.mcpServers == [descriptor]`, shape `{name,type:"http",url,headers:{Authorization}}` checked vs vendored goosed (keys `[INFERRED]`). Falsifier: populated call still encodes `[]`.
- **A2 — `session/cancel` (NEW method, coordinate with Plan 1 if live UI needs it).** `GooseACPMethod` (`:39-49`)
has NO `.cancel` (only the `cancelled` stop-reason + elicitation `.cancel()`). Green: new `case cancel`→wire string
(confirm vs goosed); `client.cancel(sessionId:)` encodes it; `stop()` no-ops when idle. Falsifier: `stop()` resolves
an elicitation `.cancel()` not the turn; invented wire string.
- **A3 — `WorkAppContextSnapshot.activeNoteBodyExcerpt` (build-now, zero Goose dep).** `:7-61` has title/path, NO body excerpt. Green: `Codable/Equatable/Sendable` field, `Self.clean(_,limit:)` bound, threaded through `init`/`isEmpty`(`:89`)/`rows`(`:106`)/`CodingKeys`/`jsonString`(`:152`); `headTail(8000,4000,1500)` ≤~5500, preserves head+tail, honest elision marker. Falsifiers: `isEmpty` ignores field; unbounded; fabricated contiguity.
- **A4 — `ActiveEpdocTracker` → live `epistemos.context.snapshot`.** Headless-testable: `WorkToolMCPCore.handle(requestJSON:)`, name at `:16`, gated on `appContextProvider != nil` (`:30-37`). Green: round-trip — provider→A then `tools/call`→A's path; flip→B→B's path AND not A's; provider nil → tool not advertised. **Headline falsifier STALE PATH**: snapshot returns A after key window→B. Also: projector nil but snapshot reports content; list/call divergence.
- **A5 — UI-steering affordances (`open_note`/`highlightEditor`/`replaceSelection`).** `[VERIFIED-CODE]` `GooseWebNativeAffordanceBridge.swift:99-238` has ~30 cases, NONE of these three; targets exist (`EpdocDocumentOpening.openDocument(withManifestID:)`, `EpdocEditorCommand` `:564-586`). Green: 3 cases; malformed args → structured error (no crash); map to real commands. Falsifiers: affordance writes OUTSIDE the vault (AGENTS.md §6 must be code-enforced); `replaceSelection` → command `js-editor/src/bridge/inbound.ts` doesn't implement (silent no-op).
- **A6 — Plan boundary / MAS honesty.** Plan 2 does not ship a separate native chat surface. Green:
`-D EPISTEMOS_APP_STORE` keeps any Goose runtime use honestly gated by the Plan-1 runtime availability path, while
Plan-2 context plumbing remains harmless/testable. **MAS-VIOLATION falsifier:** Plan 2 exposes live Goose runtime
prompting in the MAS build or bypasses Plan-1 gating.

**B. NATIVE-CONTROLS**
- **B1 — Unified `CommandRegistry`.** Green: `Set(ids).count==commands.count` (NO dup IDs — `register` appends blindly, dedup test mandatory); `matching("",scope:.code)` only code+global; `isEnabled` honored in palette AND menu; every `run` → real `EpdocEditorCommand`. Falsifiers: dup IDs; scope leak; menu/palette `isEnabled` divergence.
- **B2 — Cmd+K free.** Green: `grep keyboardShortcut("k"` exactly ONE; panel toggles don't re-bind Cmd+1/2/3 at app scope (`EpistemosApp.swift:1468`). Falsifiers: 2nd Cmd+K; toggles shadow Home/Notes/Goose nav.
- **B3 — Note-width toggle drives existing CSS var + persistence guard.** Green: `setContentWidth(wide:)` sets `--epdoc-content-max-width` (var EXISTS); `NoteWidthResolver.setWidth` nil (session-only) when NO `---` block, upserts `_width` when frontmatter exists; BOM handled; precedence session>`_width`>settings. **Falsifier frontmatter-injection**: writes `---` into a note that had none; wrong var name.
- **B4 — Find/Replace + active-mark feedback.** Green: `caretChanged` gains `marks:{bold,...}` (`:426,476`). `[RUN-APP]`: bold toggle flips toolbar state. Falsifiers: notes Find wired to CM6 (wrong engine); mark state computed heuristically in Swift not read back over bridge.

**C. ONTOLOGY-UPGRADE**
- **C1 — `NoteOntologyParser` over the real flat parser.** `[VERIFIED-CODE]` reuse `VaultIndexActor.parseFrontMatter` (`:1804`) + `WikilinkResolver` (`:14,127`); NO Yams. Green: `classify` matrix; title H1 > `title:` > humanized filename. Falsifiers: 2nd frontmatter reader; `_`-key in `properties` not `systemProps`.
- **C2 — `FrontmatterRelationshipReconciler` forward+inverse edges.** ★ **THREE traps verified in source:** (1) `GraphStore.addEdge` **silently returns if either node index absent** (`GraphStore.swift:871-874`) → inverse edges to not-yet-loaded targets silently dropped (cause of the inverse-not-persisted falsifier); (2) `GraphEdgeType` strict 12-case FFI contract (`Models/GraphTypes.swift:267`, `FFIVersionSyncTests`), NO `.backlink` — inverse REUSES an existing type + `fmrel:inv:` prefix + weight 0.5; `.quotes` dropped at ingest (`:595`), never emit; (3) wire-in calls `graphStore.firstNode(matchingTitle:)` which **does not exist** (only `firstNode(ofType:)` `:664`/`node(bySourceId:type:)` `:704`) — **compile blocker**. `GraphEdgeRecord(id:sourceNodeId:targetNodeId:type:weight:createdAt:)` real (`:586-593`). Green: BOTH nodes pre-added → `cites:[[B]]`→`fmrel:A::cites::B`(1.0)+`fmrel:inv:B::cites::A`(0.5); idempotent; diff-removal drops only `fmrel:`; dangling→0; NEGATIVE test for the silent-drop. Falsifiers: inverse absent; `firstNode(matchingTitle:)` compile-break; mutating the 12-case set; emitting `.quotes`; non-idempotent dups.
- **C3 — `SystemKeys` across FTS+HNSW+graph.** Green: `isSystemKey`/`canonicalize` alias-aware; filter at ALL 3 sites (`BlockPropertySheet`, `ShadowVaultBootstrapper.loadDocument(.notes)`, `ReadableBlocksProjector`). Falsifiers: `_`-key leaks into FTS/HNSW/Properties UI; alias swallows a legit user field (`order`/`width`).
- **C4 — `incrementalCrawl` content-hash deltas (additive).** Uses `SDPage.bodyHash` (SHA256). Green: unchanged→indexed nowhere; new→added/changed→modified/missing→removed (+`enqueueRemove`); `ScanDelta` counts match. Falsifiers: unchanged re-indexed; removed docID lingers; version bump wipes (must be additive).
- **C5 — `ViewCompiler` SQL safety.** Green: tree → parameterized GRDB SQL with `StatementArguments` (a `'; DROP` value only as bound arg); `.semantic`→`1=1` sentinel (`:196`) routed via `fusedSearchAsync` (RRF k=60); `RelativeDate.resolveISO` correct. **Falsifier SQL-injection**: any value string-interpolated into WHERE; `.semantic` silently → match-everything when HNSW unavailable.

**Cross-cutting:** CI-gate (headless today) = A1, A2-encode, A3, A4, A5, A6, B1, B2, B3, C1–C5. Requires running
app = B4, A4 window-key, and any live `session/*` behavior owned by Plan 1. Owner-confirm gates are resolved in the
current canon: Plan 2 context plumbing only, and markdown-on-disk truth with the real `edit_note` seam.

---

### Pass 8 — open-Q1 RESOLVED: JSON↔markdown source-of-truth code pack
Full code in **`MD_SOURCE_OF_TRUTH_CODEPACK_2026_06_27.md`** (8a JS serializer + 8b Swift write-through). 6 findings from source:
1. **JS bundle is webpack 5, NOT esbuild** (CLAUDE.md stale) — wire the dep into webpack; lock-hash gate already re-runs `npm ci`.
2. **TipTap pinned `3.24.0`, not 3.27.x** — pin `@tiptap/markdown` to `3.24.0` (duplicate-PM hazard otherwise; confirm it resolves on npm).
3. **Swift projector ⟂ JS paste-parser grammar disagree** on callout (`:::info` vs `> [!INFO]`), chart (` ```epdoc-chart ` vs ` ```chart `), wikilink (absent vs `[[t]]`⇄`epistemos-doc:wiki/<t>`) — they don't round-trip TODAY. **Rec: adopt the JS/Obsidian grammar as canonical** (vault-native, already has a reader, graph indexes `[[…]]`); demote `ProseMirrorMarkdownProjector.swift` to the lossy shadow/FTS job it already self-declares. ← the real open-Q1 decision.
4. **TWO persistence worlds:** World A (`.epdoc` = JSON-in-package canonical, GRDB/shadow.md already caches) + World B (Prose/TK2 = ALREADY `.md`-on-disk with atomic `F_FULLFSYNC`+content-hash+reload-suppression spine to REUSE). The flip is cheaper than docs imply.
5. **No `update_note` tool** — the real Goose seam is **`edit_note`** (`omega-mcp/src/vault.rs:509` / `VaultNoteEditor.swift:36-79`), already writing plain `.md` to the vault.
6. **`SDPage.swift:7-9,50` doc-vs-code DRIFT** — claims "SwiftData is source of truth / `.md` secondary," but `body` is cleared after save (`:29`) so disk is effectively canonical; comment is stale.
**Plan shape:** 3-state `EPISTEMOS_MD_SOURCE_OF_TRUTH` flag (jsonOnly default → dualWrite additive/reversible → markdownCanonical), HTML-in-md fallback for non-round-trippable blocks, falsifier-gated flip (round-trip must preserve callout/wikilink/chart/frontmatter/`_`-keys + self-write must suppress reload), serializer-first so Phase B unlocks only when the 8a fidelity harness is green.

---

### Pass 9 — AI-edit-instructions graft (9a) + grammar-unification (9b)
Full code in **`AI_INSTRUCTIONS_AND_GRAMMAR_CODEPACK_2026_06_27.md`**. Two load-bearing findings:
1. **⚠️ Provenance-ledger DRIFT (9a §4.2):** Decision 13 / plan §6 say "EditClaim → Rust `ClaimLedger`," but that ledger's FFI is **read-only** (`bridge.rs:3465-3499`) and Phase 8.E moved live provenance to the Cognitive DAG (`bridge.rs:3441`). The shippable path is the **already-built Swift spine** (`AgentNoteEditProvenance`→EventStore via `VaultNoteEditor.applyEdits(_:to:provenance:)` `:53-79`), enriched with an `EditClaim` metadata struct. A Rust-ledger EditClaim needs a NEW `record_edit_claim_json` FFI that **does not exist today** — owner decision queued for Pass 10.
2. **Grammar fix is a no-op for today, a prerequisite for the flip (9b):** the Swift projector's `shadowMarkdown` is write-only/never-consumed (FTS is fed by a *different* projector, `ReadableBlocksProjector` off `contentJSON`), so the `:::`/`epdoc-chart`/no-wikilink divergence causes **no current bug** — demote literally suffices today. But Pass-8b designates the projector as the degraded-`.md` fallback, so ALIGN it (3 diffs + shared-fixture parity test) and land BEFORE the `.markdownCanonical` flip.
Net: the AI-graft is ~80% wiring over verified seams (`WorkToolMCPCore`, `WorkAppContextSnapshot`, ACP `request_permission`, `VaultNoteEditor`+`AgentNoteEditProvenance`); 2 genuine new builds (`VaultAgentsGuideManager`, the `EditClaim`/preamble glue).

---

### Pass 10 — unified CommandRegistry + Cmd+K palette (foundational native-controls stage)
Full code in **`COMMAND_REGISTRY_CODEPACK_2026_06_27.md`**. ONE `@Observable CommandRegistry` = the single source for the native menu bar + every keyboard shortcut (declared once on `Command.shortcut`) + a new native Cmd+K palette; `isEnabled` is MarkEdit's `validateMenuItem` applied to all three surfaces. Findings: **Cmd+K verified free**; app shortcuts live in `EpistemosCommands` (`EpistemosApp.swift:1446`); **~80% of the Epdoc command catalog already dispatches** through the existing `EpdocEditorCommand.runCommand`/`.insertSlashChoice` cases (registry mostly wraps); real ADDs are small (`setContentWidth(wide:)` bridge case, Epdoc Find, `markOrganized`/`favorite` host closures, the whole new `CodeEditorCommand` enum). **Dependency surfaced:** the `caretChanged` payload carries no marks today, so honest mark `isEnabled`/active-state needs a `marks:{}` read-back added in 3 files (also unblocks the 4c toolbar active-state). 5 shortcut collisions catalogued + resolved (⌘1/2/3 focus-scope, inline-code→⌘⇧E, link→⌘⇧K, Properties wins ⌘⇧I, code-findNext focus-scope vs ⌘G).

---
