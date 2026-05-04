# T+8 Deliberation Brief: Workspace Dual-Editor / Code Editor / .epdoc Completion

**Date**: 2026-04-27
**Phase**: T+8 — workspace dual-editor (Tiptap+WKWebView Document side already at T+4.6; this phase covers the **Code editor side**: Swift+TextKit2 + SwiftTreeSitter + SourceKit-LSP + Rust background brain + Metal viz overlays)
**Authority**: BINDING per chronological queue T+8 entry. Per user direction (2026-04-27), execute T+8 BEFORE T+6 (CLI integration).
**Author**: Claude builder
**Auditor**: deferred (Codex unavailable; user adjudicating)

---

## §A — Disk research synthesis

### A.1 — BINDING five-component architecture

Per `workspace_epistemos_code_verdict.md` §1-3:

1. **Swift + TextKit 2** owns the surface — NSTextView renders, IME, cursor physics, scroll
2. **SwiftTreeSitter on the SwiftUI thread** for live syntax — direct C bindings to tree-sitter (NOT Rust FFI for the hot path)
3. **Rust background brain** (`syntax-core` crate) — project-wide symbols + RAG chunking + incremental parsing
4. **SourceKit-LSP** — completion + diagnostics + go-to-definition
5. **Metal viz** — minimap / heatmap / diff overlays only (not on critical typing path)

The fundamental design issue (resolved in canon): "Range Mapping over an FFI boundary" killed Rust-driven syntax. UTF-8↔UTF-16 cross-FFI conversion cost was immense per keystroke. **Solution: keep live UI syntax in Swift via SwiftTreeSitter direct C bindings. Rust owns the parser + ropey buffer + capture mapping; highlight query runs on the same actor as the editor (one FFI call per recompute, NOT per keystroke).**

### A.2 — Performance budgets (per `perf_editor_120fps_v3.md`)

- **Frame budget**: 8.33 ms @ 120 fps (6.25 ms @ 60 fps display fallback)
- **Parse budget**: < 5 ms keystroke-to-highlight on files < 100 KB
- **Paint budget**: < 3 ms glyph layout + render
- **Viewport-scoped highlighting**: tokenize visible range + 50-line margin only
- **Metal overlays (minimap)**: deferred; never on critical path
- **Concurrency invariant**: hot, fixed-size events go through SPSC ring buffer (`repr(C)` POD); variable-size control-flow uses `rkyv` archive; GPU buffers `.storageModeShared`

### A.3 — Invalidation strategy (per `perf_invalidation_strategy.md`)

- **Per-keystroke**: update `Binding<String>` only on 300 ms debounce, NOT every keystroke
- **Tree-sitter incremental**: `tree.edit(start_byte, old_end_byte, new_end_byte)` then `parser.parse(text, &old_tree)` — reuses unchanged subtrees
- **Syntax-core viewport scoping**: `tokensForViewport(byteStart:byteEnd:)` returns only visible tokens
- **Outline cache + diff**: hash-based; only diff-merge on miss

### A.4 — TOC + folding (per `FEATURE_SPEC_TOC_AND_FOLDING.md`)

**Symbol TOC** (right-edge strip):
- Rust FFI: `CodeSymbol` struct (20 bytes — line, col, name_start, name_end, kind, depth, _pad)
- Swift: `SymbolTOCView` (NSView) with `CATextLayer` pool
- Click → jump; active section highlighted

**Code Folding** (gutter):
- Rust FFI: `CodeFoldRange` struct (12 bytes — start_line, end_line, kind, _pad)
- Swift: `▼/▶` chevron in line-number gutter
- Phase 1 (now): show chevrons + log toggles
- Phase 2 (deferred): NSLayoutManager glyph hiding

### A.5 — Polish scope (per `CODE_EDITOR_POLISH_SCOPE.md`)

**Phase S (App Store, ~2 days):**
1. Theme-aware line gutter (6 hrs) — CATextLayer overlay, 48 pt width
2. `Binding<String>` 300 ms debounce (2 hrs)
3. Outline cache + diff (4 hrs) — hash-keyed
4. Viewport-scoped syntax highlighting (1 day) — parallel tokenizer via `tree-sitter QueryCursor.set_byte_range()`

**Pro / Phase K+ (deferred):**
5. Inspector panel (4 hrs)
6. Minimap via Metal overlay (1 day)
7. Incremental parsing via syntax-core full integration (3 days — unblocks Patch 6)
8. Semantic sidebar with vault grounding (1 day)

**DO NOT** (per BINDING):
- Re-enable `semanticSidebarEnabled` (Pro-only)
- Override `CodeEditSourceEditor`'s `MultiStorageDelegate`
- Build Rust syntax-core crate for App Store (it's already built — but defer enabling on the App Store path)
- Hardcode gutter colors

### A.6 — Current shipped state (per code survey)

**Shipped (foundation):**
- `Epistemos/Views/Notes/CodeEditorView.swift` (3,992 LOC) — full SwiftUI editor via `CodeEditSourceEditor` 0.15.2
- `Epistemos/Engine/SyntaxCoreService.swift` (130 LOC) — production-wired but opt-in via `EPISTEMOS_USE_SYNTAX_CORE` env flag
- `LiveCodeEditorController` + `SyntaxCoreLiveHighlighter` — 143 + 227 LOC of tests passing
- SwiftTreeSitter 0.25.0 SPM dep registered
- `LSPMessage.swift` (61 LOC) — LSP JSON-RPC 2.0 codec ready, no subprocess yet
- 20+ language mappings (line 1700-1770)
- 3 `os_signpost` intervals (selection, textDidChange begin/end)

**Not yet shipped (the polish gap):**
- Theme-aware line gutter rendering (state exists; no `CATextLayer` pool)
- `Binding<String>` 300 ms debouncing (spec'd; not implemented)
- Outline cache + diff (deferred)
- Viewport-scoped highlighting (Patch 6 BLOCKED — primary path still uses `CodeEditSourceEditor` internal pipeline)
- Code folding UI + Rust FFI (spec exists, no code)
- Symbol TOC strip (spec exists, no code)
- SourceKit-LSP subprocess (codec only, no spawn)

**Architecture verdict**: LOCKED + WORKING. T+8 ship readiness ~40% — gap is feature polish, not architecture.

---

## §B — Web research findings

T+8 is heavily code-locked (CodeEditSourceEditor 0.15.2 production-tested, SwiftTreeSitter 0.25.0 stable). Spot-check primary sources:

- **TextKit 2 NSTextStorage delegate** (developer.apple.com): mature in macOS 14+; doc-edited delegate methods stable.
- **SwiftTreeSitter 0.25.0** (github.com/ChimeHQ/SwiftTreeSitter): direct C bindings; production-ready.
- **tree-sitter UTF-8 NSRange UTF-16 trap** (github.com/tree-sitter): well-known; canonical solution is byte-offset everywhere internally + boundary translation only at NSRange<->byte-range edges.
- **SourceKit-LSP** (github.com/swiftlang/sourcekit-lsp): macOS distribution via `xcrun sourcekit-lsp`; documented JSON-RPC stdio surface.
- **Metal MSDF font atlas**: deferred (minimap is Pro-phase).
- **CADisplayLink ProMotion triple-buffer**: macOS 14+ stable; standard pattern.
- **CodeEditSourceEditor 0.15.2 production readiness** (github.com/CodeEditApp/CodeEditSourceEditor): MIT-licensed, used in CodeEdit IDE; production-tested on multi-MB files.

No 2026 deltas affect the locked stack.

---

## §C — Conjugation (disk × web × code)

**Q1: Should we ship Phase S polish (4 items, ~2 days) before T+6 CLI?**
- Disk: `CODE_EDITOR_POLISH_SCOPE.md` lists Phase S as ship-critical for App Store.
- Code: foundation works; gaps are user-facing polish.
- Doctrine: per BINDING, Phase S items are V1.5 ship-blocking for the code editor surface.
- **Synthesis**: yes — Phase S polish ships before CLI work because it's V1.5 ship-blocking.

**Q2: Should we attempt to unblock Patch 6 (SyntaxCoreService → primary editor)?**
- Disk: per session-summary §51, Patch 6 BLOCKED because "CodeEditSourceEditor does NOT consume SyntaxCoreService in main editor (only at graph inspector :2286)."
- Code: `EPISTEMOS_USE_SYNTAX_CORE=1` env flag enables opt-in. Production default OFF.
- Phase S item 4 = viewport-scoped highlighting via parallel tokenizer = unblocks Patch 6.
- **Synthesis**: Phase S item 4 is the unblock. Defer SyntaxCoreService rewrite of CodeEditSourceEditor (multi-day re-architect).

**Q3: SourceKit-LSP — Phase S or Pro-defer?**
- Disk: not in `CODE_EDITOR_POLISH_SCOPE.md` Phase S list.
- Code: codec ready, subprocess missing.
- Doctrine: completion + diagnostics are nice-to-have for V1.5; not ship-blocking.
- **Synthesis**: defer to Pro / Phase K+. Only the LSP transport layer ships in T+8.

**Q4: Code folding UI + Rust FFI — Phase S or defer?**
- Disk: spec written at `FEATURE_SPEC_TOC_AND_FOLDING.md`; estimated 2 days.
- Doctrine: not in Phase S list per `CODE_EDITOR_POLISH_SCOPE.md`. Deferred.
- **Synthesis**: defer. Pure UX polish.

**Q5: Sequencing — what ships in T+8 before T+6?**
- Phase S 4 items (~2 days) cover most ROI.
- Smoke harness for the .epdoc save path (audit Tier 1) is shorter.
- Wire fixes for F4/F5/F7/F8 (audit Tier 1) take precedence over T+8 polish.
- **Synthesis**: order is **audit Tier 1 fixes → T+8 Phase S → T+6 CLI**.

---

## §D — Trade-off matrix

### D.1 — Phase S item priority

| Item | Effort | ROI | Risk | Recommendation |
|---|---|---|---|---|
| Theme-aware line gutter | 6 hrs | medium-high (immediate visual polish) | low (overlay only, doesn't touch CodeEditSourceEditor internals) | Ship in T+8 |
| `Binding<String>` 300 ms debounce | 2 hrs | high (typing perf win on large files) | low (additive Combine debouncer) | Ship in T+8 |
| Outline cache + diff | 4 hrs | medium (cuts re-tokenize work on small edits) | low | Ship in T+8 |
| Viewport-scoped highlighting | 1 day | very high (unblocks Patch 6 + 100KB+ file perf) | medium (touches the parallel-tokenizer integration with CodeEditSourceEditor) | Ship in T+8 if time |

### D.2 — Code folding scope

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| A: Phase 1 only (chevrons + log) | small; visible affordance | doesn't actually fold | Recommended for T+8 polish |
| B: Phase 1 + Phase 2 (NSLayoutManager glyph hiding) | full feature | 2 days; risk of regressing scroll perf | Defer to V1.5 follow-up |
| C: Defer entirely | no risk | feature missing | reject — visible deficit |

### D.3 — SourceKit-LSP

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| A: Defer all integration | safe; LSP transport already ships | no completion / diagnostics | **Chosen** for T+8 |
| B: Wire stdio subprocess + initialize handshake (1 day) | unblocks completion path | 2-3 days to make production-ready; sandbox interaction with subprocess | Defer to Pro |

### D.4 — V0/V1 recall migration (carry-over from T+5)

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| A: Defer to T+13 hardening (current default) | safe; T+5 fixes in place ready for migration | V1 doctrine surface unwired | **Chosen** |
| B: Migrate now in T+8 | doctrine cleanup | scope explosion; not workspace-related | reject |

---

## §E — Decision

**Chosen path** (T+8 execution plan):

1. **Tier 1 audit fixes (this session)**:
   - F4 + F5 fix in `EpdocEditorChromeView.swift` (close the Tiptap → save data drop) — ✅ shipped in this session
   - Smoke harness `EpistemosTests/EpdocEndToEndSmokeTests.swift` exercising .epdoc round-trip + readable_blocks integration — ✅ shipped in this session
   - F7 (`ProseMirror → ReadableBlock` projector helper inside the smoke harness) — ✅ included in smoke harness as `extractReadableBlocks(from:)` (production projector lifts this verbatim)

2. **Tier 2 — Phase S polish (next session)**:
   - Theme-aware line gutter (6 hrs)
   - `Binding<String>` 300 ms debounce (2 hrs)
   - Outline cache + diff (4 hrs)
   - Viewport-scoped highlighting (1 day) — unblocks Patch 6

3. **Tier 3 — defer to Pro / V1.5 / T+13**:
   - Code folding (Phase 1 + 2)
   - Symbol TOC strip
   - SourceKit-LSP subprocess
   - V0 → V1 recall migration
   - Drift Q2 / Q3 / Q4 close-out
   - F1 (NSDocument `makeWindowControllers`) + F2 (File > Open menu) — UX-load-bearing, surface for user review before edit

**Rationale**: T+8 architecture is LOCKED + working at 40% spec coverage. Phase S polish (4 items, ~2 days) closes the V1.5 ship gap on the code editor side. Tier 3 items are post-V1 polish or architectural decisions beyond T+8 scope. The audit Tier 1 fixes shipping in this session unblock the Document editor save path that was blocking actual end-to-end use of T+4 work.

**Risks accepted:**
- Code folding deferred — visible UI gap until V1.5
- SourceKit-LSP deferred — no native completion / diagnostics in T+8 ship
- V0 → V1 recall migration deferred to T+13 (existing user-facing recall keeps working via V0 path)
- F1/F2 NSDocument window + menu deferred for user review (cannot open .epdoc from Finder until those land)

**Risks deferred:**
- Patch 6 full unblock (SyntaxCoreService rewrite of CodeEditSourceEditor) → architectural; Pro-phase
- Metal minimap / heatmap / diff overlays → Pro-phase
- Inspector panel → Pro-phase

**Success metrics:**
- Phase S 4 items ship; `os_signpost` intervals show typing latency < 16 ms p99 on M-series
- Smoke harness 5 tests pass on user's xcodebuild test
- Audit Tier 1 fixes (F4/F5/F7/F8 — F7+F8 covered by smoke harness; F4+F5 by EpdocEditorChromeController changes) verified by user's smoke run

**Reversal triggers:**
- Phase S item 4 (viewport-scoped highlighting) regresses any test → revert
- Patch 6 BLOCKED state proves more entrenched than expected (CodeEditSourceEditor's MultiStorageDelegate footgun reasserts) → defer item 4 to V1.5
- F4/F5 fix breaks an existing test → revert and reassess

**Citations (disk):**
- `/Users/jojo/Downloads/Epistemos/docs/_consolidated/70_design_implementation/workspace_epistemos_code_verdict.md` (architecture binding §1-3)
- `/Users/jojo/Downloads/Epistemos/docs/perf_editor_120fps_v1.md`, `_v2.md`, `_v3.md` (frame budgets)
- `/Users/jojo/Downloads/Epistemos/docs/perf_invalidation_strategy.md`
- `/Users/jojo/Downloads/Epistemos/docs/FEATURE_SPEC_TOC_AND_FOLDING.md` (TOC + folding spec)
- `/Users/jojo/Downloads/Epistemos/docs/CODE_EDITOR_POLISH_SCOPE.md` (Phase S vs Pro list)
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift` (current 3992 LOC code editor)
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/SyntaxCoreService.swift` (Rust integration boundary)
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LSPMessage.swift` (LSP transport, no subprocess yet)
- `/Users/jojo/Downloads/Epistemos/docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md` (audit Tier 1 items)

**Citations (web, accessed 2026-04-27):**
- https://developer.apple.com/documentation/appkit/nstextview (TextKit 2)
- https://github.com/ChimeHQ/SwiftTreeSitter (0.25.0)
- https://github.com/tree-sitter/tree-sitter (utf-8/utf-16 trap discussion)
- https://github.com/swiftlang/sourcekit-lsp (LSP server)
- https://github.com/CodeEditApp/CodeEditSourceEditor (0.15.2 production-tested)
