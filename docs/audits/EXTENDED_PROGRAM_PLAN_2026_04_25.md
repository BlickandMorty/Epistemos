# Epistemos Extended Program Plan — 2026-04-25

This extends `MASTER_HARDENING_WIRING_AUDIT.md` and `PATCH_QUEUE.md` to fold in the full 3-program scope from `/Users/jojo/Downloads/workspace/` and `/Users/jojo/Downloads/opt/`.

**Sequencing rule (your call)**: hardening + stability + performance foundations BEFORE features and views.

**Authority cascade** (highest → lowest):
1. PLAN_V2.md §22 (BoltFFI carve-out, no mass-migration)
2. CLAUDE.md non-negotiables (preserve thinking blocks, stream everything, no silent backend rerouting)
3. AGENTS.md golden rules (zero copy-paste, direct communication, performance is architecture, minimal fixes)
4. This extended plan
5. Per-wave patch queue entries

## Status anchor

| Tag | Date | What's locked in |
|---|---|---|
| `v0-audit-checkpoint-2026-04-25` | today | 13 audit docs |
| `v0-implementation-checkpoint-2026-04-25` | today | 12 patches + 3 V1 product moments |
| `v0-mas-hardened-checkpoint-2026-04-25` | **current HEAD** | omega-mcp PTY/osascript stripped from MAS dylib |

## The three programs (re-grouped)

- **Program A** — V1 hardening + wiring + product expression. **DONE this session.**
- **Program B** — Cognitive Workspace (Documents `.epdoc` + Tiptap, Code-editor syntax-core wiring, ACC full surface). PARTIAL (Raw Thoughts substrate landed; Documents + Patch 6a NOT built).
- **Program C** — Deterministic Performance Plan (6 sprints / 12 weeks per `EPISTEMOS_DETERMINISTIC_PERF_PLAN.md`). 0% started.

## Extended plan (hardening-first, 6 waves)

Each wave finishes before the next starts. Each wave produces a restorable tag.

### Wave 1 — Finish V1 hardening (1 week)
**Goal**: close the last V1 ship-gate items so the app is ready for TestFlight.

| # | Item | Source | Effort |
|---|---|---|---|
| W1.1 | Reliability gate **full 5-gate run** (baseline ✅ + ASAN + UBSAN + TSAN + soak_repeat) — record fresh evidence | `PHASE_S_AUDIT.md` | 2 hrs |
| W1.2 | TestFlight submission prep: App Store Connect metadata, screenshots, App Privacy form, JIT entitlement notes (already drafted at `docs/release/MAS_APP_REVIEW_NOTES.md`) | `V1_SHIP_GATE_DECISION.md` | 4 hrs |
| W1.3 | CI bundle-size gate (Patch 9) verified in actual GitHub Actions run | already wired | 1 hr |
| W1.4 | Manual smoke-test plan execution per `BUILD_TEST_VERIFICATION_AUDIT.md` §"Smoke test plan" — 15 user flows | audit doc | 2 hrs |
| W1.5 | Empty-state/error polish second pass (Patch 13 already covered Notes; chat/graph empty states minor polish) | `STABILITY_ERROR_HANDLING_AUDIT.md` | 2 hrs |

**Exit criteria**: green reliability gate (5/5), TestFlight build uploaded + reviewer notes attached, smoke test passed, CI green.
**Tag**: `v1-ship-ready-2026-XX-XX`

### Wave 2 — Sprint 0 cheap deterministic wins (1 week)
**Goal**: instrument + tune SQLite + tighten release profile. No architecture changes. Pure config + signposts. Ships shippable on its own per `EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` §1.4 (stabilization checkpoint).

| # | Item | Source | Effort |
|---|---|---|---|
| W2.1 | Wire `OSSignposter` into hot paths: render frame, MCP tool invoke, GRDB query, every UniFFI call site, MLX inference (`Sources/Telemetry/Sig.swift`) | dpp §1.1 Task 0.1 | 1 day |
| W2.2 | Build `Tools/Performance.instrpkg` (custom Instruments package with subsystem `io.epistemos.core` + categories render/mcp/graph/ffi/storage/inference) | dpp §1.1 Task 0.2 | 2 hrs |
| W2.3 | Apply canonical GRDB pragma block: WAL + synchronous=NORMAL + mmap_size=1GB + cache_size=-65536 + page_size=4096 + temp_store=MEMORY + fullfsync=0. Convert all hot queries to `cachedStatement(sql:)`. | dpp §1.1 Task 0.3 | 1 day |
| W2.4 | Tighten release profile in workspace-root Cargo.toml: `lto="fat"`, `codegen-units=1`, `panic="abort"`, `strip="symbols"`, `opt-level=3`, `overflow-checks=false`. Measure dylib size before/after (target ≥30% reduction). | dpp §1.1 Task 0.4 | 30 min |
| W2.5 | Define `docs/perf-budgets.toml` (cold_start_ms_p99=800, frame_ms_p99=8.3, mcp_invoke_ms_p99=2.0, ffi_hot_path_us_p99=5.0, binary_size_mb_max=12). Add CI step parsing budgets + asserting them. | dpp §1.1 Task 0.5 | 2 hrs |
| W2.6 | Synthesize `bench/morning-session.swift`: scripted typical session (cold start → open vault → scroll graph 60s → 100 notes → 10 MCP tools → 5 raw thoughts → 20 searches → close). Replay-able for PGO + CI regression. | dpp §1.1 Task 0.6 | 1 day |

**Exit criteria**: signposts visible in Instruments for all 6 categories. SQLite returns `journal_mode=wal`, `mmap_size=1073741824`. Release dylib ≥30% smaller. perf-budgets.toml CI step active. `bench/morning-session` runs to completion.
**Tag**: `v-perf-0`

### Wave 3 — Sprint 1 + 2: deterministic substrate (4 weeks)
**Goal**: replace string-keyed / pointer-chasing patterns with compile-time deterministic dispatch. Foundation for everything else.

#### Wave 3.A — Sprint 1: slotmap + SoA migration (2 weeks)

| # | Item | Source | Effort |
|---|---|---|---|
| W3A.1 | Introduce `crates/substrate-core` with `slotmap::SlotMap<ArtifactKey, ArtifactCore>` + `SecondaryMap<ArtifactKey, T>` columns for titles/bodies/embeddings | dpp §2.1 | 3 days |
| W3A.2 | Expose `EpiArtifactRef(u64)` via C ABI; integer handles cross FFI, never pointers | dpp §2.3 | 1 day |
| W3A.3 | Differential dual-write: keep old store + new store; `cargo test --features differential` continuously | dpp §2.4 | 1 day |
| W3A.4 | Migrate read paths first, then writes, then components, then edges; each step ships independently | dpp §2.5 | 1 week |
| W3A.5 | Swift `ArtifactRef` newtype wrapping `UInt64`; codemod existing `ArtifactID: String` call sites | dpp §2.6 | 2 days |

**Tag**: `v-perf-1` (or `v-perf-1-partial` per dpp stabilization §2.4)

#### Wave 3.B — Sprint 2: phf registries + Swift macro routing (2 weeks)

| # | Item | Source | Effort |
|---|---|---|---|
| W3B.1 | Add phf to substrate-core; add phf_codegen build-dep | dpp §3.1 | 30 min |
| W3B.2 | `build.rs` compiles MCP tool registry + edge-kind enum + slash commands into static `phf::Map<&'static str, &'static Tool>` | dpp §3.2 | 1 day |
| W3B.3 | `@ArtifactView` Swift macro (Sources/EpistemosMacros) — synthesizes exhaustive `static func make(for ref: ArtifactRef) -> some View` switch | dpp §3.3 | 3 days |
| W3B.4 | `@MCPSchema` Rust proc macro — emits static `&'static SchemaNode` trees, eliminates runtime JSON-schema parse | dpp §3.4 | 2 days |
| W3B.5 | Audit + migrate `[String: Any]` and `as? AnyView` in render hot paths; cold paths keep dynamic dispatch | dpp §3.5 | 1 week |

**Tag**: `v-perf-2`

### Wave 4 — Sprint 3: Metal binary archive + Tree-sitter SoA (2 weeks)
**Goal**: eliminate runtime Metal pipeline compilation; Tree-sitter SoA highlight cache.

| # | Item | Source | Effort |
|---|---|---|---|
| W4.1 | Move Metal shader compilation offline: `xcrun metal -O3 -ffast-math` → `.metallib` shipped in bundle | dpp §4.1 | 2 days |
| W4.2 | Generate `MTLBinaryArchive` (`metal-tt --pipelines pipelines.mtlp`); use it at runtime via `MTLRenderPipelineDescriptor.binaryArchives` | dpp §4.2 | 2 days |
| W4.3 | Convert graph render path to argument buffers + `MTLStorageMode.shared` (UMA zero-copy) | dpp §4.3 | 3 days |
| W4.4 | Tree-sitter SoA highlight cache (Rust): `Vec<HighlightSpan>` sorted by start_byte; viewport-scoped FFI returns `&[HighlightSpan]` | dpp §4.4 | 1 week |
| ~~W4.5~~ | ~~**Patch 6a** (the BLOCKED item from V1): wire `SyntaxCoreService` into CodeEditSourceEditor's highlight pipeline~~ — **SUPERSEDED 2026-04-26 by W9.6 canonical** (`Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift`). Per `epistemos_code_verdict.md` §1, live syntax stays in Swift via SwiftTreeSitter direct C bindings, NOT through CodeEditSourceEditor's HighlightProviding protocol. The Rust-FFI bridge route W4.5 attempted is the slower, less-correct path the verdict explicitly rejected. Audit agent confirmed: upstream CodeEditSourceEditor 0.15.2 → main has no Sendable changes (last touched 2025-04-08); W4.5 stays blocked indefinitely while W9.6 already ships the right architecture. `SyntaxCoreHighlightProvider.swift` + its test deleted as dead code. | superseded | n/a |

**Tag**: `v-perf-3`

### Wave 5 — Sprint 4: zero-copy FFI carve-out (3 weeks, highest variance)
**Goal**: substrate-rt crate with `repr(C)` SPSC ring buffer for hot-path events. Keep UniFFI for cold/control plane.

| # | Item | Source | Effort |
|---|---|---|---|
| W5.1 | Create `crates/substrate-rt` (staticlib + cdylib) | dpp §5.1 | 1 day |
| W5.2 | Implement SPSC ring buffer (`EventRing` with cache-line padding for `head`/`tail` atomics, 16384 slots, 64-byte `GraphEvent` POD) | dpp §5.2 | 3 days |
| W5.3 | Swift module map (`Sources/EpistemosRT/include/`) + `EventDrain` actor draining at frame boundaries | dpp §5.3 | 2 days |
| W5.4 | Identify 5–10 highest-frequency UniFFI events from Sprint 0 signpost data (cursor moves, edit deltas, layout updates, MCP token chunks, agent frame ticks) | dpp §5.4 | 1 day |
| W5.5 | Migrate one event per day with differential testing; remove UniFFI fallback only after 7 consecutive green days | dpp §5.5 | 2 weeks |
| W5.6 | mmap'd raw-thoughts log (already partially landed via Patch 4 Rust emitter; finalize wait-free reader pattern per Cloudflare `mmap-sync`) | dpp §5.6 | 3 days |

**Tag**: `v-perf-4` (or `v-perf-4-partial` per dpp §5.4 stabilization)

### Wave 6 — Sprint 5 + 6: PGO + bumpalo + polish (2 weeks)

| # | Item | Source | Effort |
|---|---|---|---|
| W6.1 | `cargo install cargo-pgo`; instrumented build → run `bench/morning-session` → `cargo pgo optimize build`. Expect ≥5% wall-clock improvement. | dpp §6.1-6.2 | 2 days |
| W6.2 | Bumpalo per-frame arenas in render + MCP invoke (`Bump::with_capacity(16MB)`, reset per frame) | dpp §6.3 | 3 days |
| W6.3 | Final perf polish + `xcrun xctrace` reports per `EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` §8 acceptance | dpp §6 | 3 days |

**Tag**: `v-perf-1.0` (full Program C complete)

### Wave 7 — Program B: Documents + ACC + remaining product surfaces (4–6 weeks)
**Goal**: NOW the deferred feature work, on top of the deterministic perf substrate that makes them safe to add.

| # | Item | Source | Effort |
|---|---|---|---|
| W7.1 | **Documents `.epdoc` MVP**: package format (manifest.json + content.json canonical ProseMirror JSON + shadow.md + search_blocks.jsonl + assets/) | `gpt work 2.md` §"V1 .epdoc package", `raw thoughts.md` | 1 week |
| W7.2 | **Tiptap + WKWebView document editor**: locally-bundled assets via app-bound, `WKScriptMessageHandler` bridge, prewarm/reuse single WebView, debounced canonical JSON save, block IDs preserved via `UniqueID` extension | `gpt work.md` §"Recommended stack", `raw thoughts.md` §"Document editor stack" | 2 weeks |
| W7.3 | Markdown shadow projection (GFM via Tiptap; lossy by design; never canonical) + DOCX export-only via Pandoc with `reference.docx` styling | `gpt work 2.md` §"Universal artifact envelope" | 1 week |
| W7.4 | **Agent Command Center full surface** (PLAN_V2 §4.1): slash commands, at-mentions, capability pills, brain selector, right-side inspector, global shortcut | `PLAN_V2.md` §4.1 | 1 week |
| W7.5 | Memory diff card + embedded terminal (Pro) + iMessage inbound (Pro) — V1.5+ | `MASTER_PLAN_2026-04-19.md` §GG | 1 week each, Pro-only |
| W7.6 | **EpdocManifest free-form `metadata`**: optional `[String: String]` field for theme / icon / display-mode / color-hex without bumping schema_version. Forward-compat decode (older readers ignore unknown keys) | Alexandrie scan (2026-04-26) — `nodes.metadata JSON` column equivalent | 1 day |
| W7.7 | **Math (KaTeX) Tiptap node**: register `math_inline` (`$x=1$`) + `math_display` (`$$…$$`) Tiptap node; client-side KaTeX 0.16.45 render; mhchem extension for chemistry equations; ProseMirrorMarkdownProjector round-trips both syntaxes; Pandoc reads `$…$` natively so DOCX/PDF needs no writer change | Alexandrie `frontend/app/helpers/markdown/katex.ts`; verdict line on Tiptap math extensions | 3 days |
| W7.8 | **Markdown plugin Tiptap nodes** (4): `footnote` (`[^id]` ref + def), `highlight` mark (`==text==`), `task_item` (`- [ ] / - [x]`), `callout` container node (`:::tip / :::warning / :::danger / :::info / :::details`). Each round-trips through ProseMirrorMarkdownProjector and reads back via markdown-it on the JS side | Alexandrie `helpers/markdown/{container,colors,other,checkbox}.ts` (decorative `cards/panels/frames` explicitly skipped) | 1 week |
| W7.9 | **Mermaid diagram Tiptap node**: register `mermaid` node (extends fenced code-block-with-language); bundle `mermaid.min.js` (~2 MB) under `Resources/Editor/`; ProseMirrorMarkdownProjector emits ` ```mermaid\n…\n``` ` so the projection round-trips through any markdown reader. Alexandrie does NOT ship Mermaid; we add it because it's the most-requested diagram format in 2026 docs tooling | New (Alexandrie scan delta) | 3 days |
| W7.10 | **KaTeX slash-menu snippets**: port Alexandrie's `katex-snippets.ts` autocomplete dictionary (hundreds of macros) to a Swift `KaTeXSnippets` data source; surface from the editor's slash-menu so `/sqrt`, `/sum`, `/integral`, `/matrix` etc. expand to the right LaTeX. Pure data file, no logic | Alexandrie `frontend/app/components/MarkdownEditor/katex-snippets.ts` | 1 day |
| W7.11 | **Image upload paste/drop handler**: paste/drop image events into the Tiptap WKWebView trigger an upload that writes the bytes to the `.epdoc` package's `assets/` directory and inserts a relative-path `![alt](assets/<filename>)` node. Mirrors Alexandrie's `editorUploads.ts` pattern but writes into the package bundle (not S3) per the `.epdoc` offline-first contract | Alexandrie `frontend/app/components/MarkdownEditor/modules/editorUploads.ts` | 3 days |

**Tag**: `v1.5-cognitive-workspace`

> **W7.6–W7.11 provenance** — Borrowed from a 2026-04-26 scan of
> [Smaug6739/Alexandrie](https://github.com/Smaug6739/Alexandrie) (Nuxt 4 + Go + MySQL self-hosted wiki). The
> agent's full report + line-cited recommendations live in the session's
> chapter "Grounding pass — verify state vs canonical truth". Decorative
> features intentionally skipped: the `card`/`panel`/`frame` academic
> blocks (Tiptap blockquote covers the use case), the entire CodeMirror
> split-pane editor (we're committed to Tiptap WYSIWYG), the OIDC/SSO
> stack (single-user macOS), and MySQL FULLTEXT search (Halo Shadow is
> generations ahead).

#### Wave 7 — Notion × Obsidian × Craft tier (W7.12–W7.16)

> **Why this tier exists.** The 2026-04-26 user direction:
> > "I want it to be like I have a whole Notion as one of the text
> > editors in my app — so the document mode literally has a whole
> > multi-database thing where it also shows up in the graph where
> > nest things are weighted with a particular complexity scale, then
> > the graph reflects the complexity of the documents, and then the
> > documents are attached to all thoughts in the pro system… literally
> > like Notion times Obsidian times Craft."
>
> W7.6–W7.11 close the editor-feature gap (math, callouts, footnotes,
> Mermaid). W7.12–W7.16 close the **systems-integration** gap: every
> `.epdoc` becomes a first-class node in the graph engine, carries
> typed properties / database queries (Notion), backlinks bi-directionally
> with thoughts and other docs (Obsidian), and renders with a complexity-
> aware visual weight in the Metal graph view (Craft).

| # | Item | Source | Effort |
|---|---|---|---|
| W7.12 | **DocComplexityMetric**: scalar 0.0–1.0 computed per `.epdoc` from word count, heading depth, code-block count, link-out count, math-block count, mermaid-block count, embed/transclusion count. Cached in `manifest.metadata["complexity"]` on every save (W7.6 substrate). Drives graph node radius + edge weight in W7.14. Includes `EpdocComplexityCalculator.swift` + `ComplexityWeights.swift` config struct + a Swift Testing source-guard with 12 fixtures spanning min/max/typical | New (user direction 2026-04-26) | 3 days |
| W7.13 | **DocPropertiesDB (Notion-like)**: typed property schema on top of `manifest.metadata` — `properties: [PropertyDef]` where each `PropertyDef` is `{ id, name, kind: select/multiSelect/date/number/checkbox/relation/url/email/file/formula/rollup, options?, formula? }`. New `EpdocProperty.swift` model + `EpdocDatabase.swift` query engine that reads + writes typed values to `manifest.metadata["properties.<id>"]`. The query engine reuses the existing structured-query AST from `Epistemos/Engine/QueryAST.swift` | New (Notion-like multi-database) | 1 week |
| W7.13.a | **Logseq query-DSL grammar (Swift port)**: borrow Logseq's s-expression query language verbatim — `(and …)`, `(or …)`, `(not …)`, `(property <id> <value>)`, `(between <field> <start> <end>)` time-window helper. Ship `EpdocQuery.swift` with `QueryAST` enum + `EpdocQueryEvaluator` that lowers the AST to `EpdocDatabase.filtered(where:)` against the W7.13 actor. `EpdocQueryParser` that reads the s-exp surface lands in W7.13.b. **Borrow the LANGUAGE, not the ENGINE** — Datascript is AGPL-v3 + Electron-coupled, both blockers for the MAS build (per the 2026-04-26 Logseq-source scan at `/Users/jojo/Downloads/logseq-source/`). | New (Logseq scan 2026-04-26) | 3 days |
| W7.13.b | **Logseq query-DSL parser**: hand-written recursive-descent parser for the s-expression surface that produces `QueryAST`. Time-ref micro-language: `today`, `-7d`, `+30d`, ISO-8601. Hooks into the W7.13 evaluator + a SwiftUI editable-query field on the database view. | New (W7.13.a follow-up) | 2 days |
| W7.13.c | **PropertyOption with stable id**: change `PropertyDef.options: [String]?` → `[PropertyOption]` where `PropertyOption = { id: String, value: String }`, mirroring Logseq's `:closed-values` pattern (`deps/db/src/logseq/db/frontend/property.cljs:301-307`). Prevents rename-corrupts-data when an option's display value changes. Migration code reads any pre-W7.13.c `[String]` and minted ULID-based ids. | New (Logseq scan 2026-04-26) | 1 day |
| W7.13.d | **Named-rule registry**: a `BuiltInRules` Swift enum cataloguing reusable query predicates — `.parent(of:)`, `.classExtends`, `.between`, `.hasProperty(id:)`, `.scalarPropertyWithDefault(id:default:)`. Logseq groups these in `rules.cljc:1-366`; we surface them as `QueryAST.rule(<name>, [args])`. Cheap V1 surface; gives W7.14 graph queries somewhere to grow. | New (Logseq scan 2026-04-26) | 2 days |
| W7.17 | **Block + toolbar UX (Alexandrie-parity)**: ship the parity surface. Top toolbar with formatting / extended / insert / structure groups, every Alexandrie shortcut (`⌘B/I/U`, `⌘1-6`, `⌘⇧.`, `⌘⇧7/8/9`, `⌘K/M/E/P/S`, etc.), word/char/line stats badge, KaTeX `\…` autocomplete inside `$…$` (sources W7.10), paste/drop image into `.epdoc/assets/` (W7.11). Surface inventory borrowed verbatim from `Alexandrie/frontend/app/components/MarkdownEditor/Toolbar.vue:2-117` + `editorKeymaps.ts:1-228` (2026-04-26 scan). | New (user direction 2026-04-26) | 1 week |
| W7.17.a | **SwiftUI / WKWebView hybrid render decision (NATIVE chrome, in-WebView caret-glued tools)**: per the user's 2026-04-26 direction "if there is a way to put SwiftUI over the UI then we can do that." Verdict: HYBRID. The chrome (top toolbar, right inspector pane, left outliner, command palette, complexity meter, thought-attached badge) is **SwiftUI** — Material 3 + flat aesthetic, opulent polish, free dark mode + accessibility. The caret-glued surfaces (slash menu, formatting bubble, KaTeX live preview, drag handle gutter) stay **inside the Tiptap WKWebView** because positioning a SwiftUI popover above the WebView's caret across the bridge stutters; Tiptap's BubbleMenu / FloatingMenu / Suggestion plugins are first-class for these. Bridge: `WKScriptMessageHandler` channel emits caret rect + selection state on every change → SwiftUI re-positions docked-panels next to the relevant document area. | New (user direction 2026-04-26) | 3 days |
| W7.17.b | **EXCEED Alexandrie — features Alexandrie's editor literally cannot do** (the agent verdict 2026-04-26: Alexandrie's editor is CodeMirror over markdown text; it has NO slash menu, NO block-action gutter, NO bubble menu, NO right-click menu, NO block-conversion picker, NO live KaTeX preview, NO image toolbar, NO table-tools popover). Each item below is 1–2 days because the backend already exists: <br/>• **Slash menu** (Tiptap Suggestion) — `/heading 1…6 / bullet / numbered / task / quote / code / math / mermaid / callout(tip|warn|danger|info|details) / table 3×3 / divider / image / file / link to doc / link to thought / embed / template`<br/>• **Block-action gutter** (drag-handle + ＋ + ⋯ menu: Duplicate / Move / Convert to / Wrap in callout / Delete)<br/>• **Bubble menu on selection** (bold / italic / link / highlight / color + **"Ask agent"** + **"Capture as RawThought"** — both alien to Alexandrie)<br/>• **Live KaTeX preview popover** when caret enters `$…$` / `$$…$$` (Alexandrie makes you toggle the whole-doc preview pane)<br/>• **Graph-aware "Insert link to" picker** that hits the W8.4 Halo backend so 3 chars surface semantically-related docs/thoughts/people; insert as `[[wikilink]]` so W7.14 graph projector immediately picks up the edge<br/>• **Complexity-budget meter** (W7.12 scalar) in the toolbar's right cluster, color-graded green→amber→red, tooltip with breakdown ("Words 1.2k • Headings 4 deep • 3 mermaid • 7 wikilinks"). >0.7 surfaces "Consider splitting?" chip<br/>• **Thought-attached badge** (W7.15) — "⚡ N thoughts" pip next to the title; click expands every RawThought run touching the doc with re-open-in-agent action<br/>• **Paste-as-block intelligence**: YouTube URL → embed; markdown table → real Tiptap table; mermaid fence → live diagram; code → language-detected code block<br/>• **Right-click block context menu**: Convert to / Duplicate / Move / Wrap in callout / Comment / Ask agent / Cite as source<br/>• **Block templates** (per-vault `.epdoc` packages surfaced in slash menu under `/template`) — Alexandrie has user snippets but no shareable templates | New (user direction 2026-04-26 + Alexandrie inventory agent) | 2 weeks |
| W7.14 | **EpdocGraphProjector**: extends [GraphBuilder.swift](Epistemos/Graph/GraphBuilder.swift) so every `.epdoc` package emits one graph `SDGraphNode` (kind=`.document`, weight = W7.12 complexity scalar, label = manifest.title, id = manifest.id) on first index pass + on every save. Edge emission: every `EpdocProvenance.derivedFrom`/`sourceArtifacts`/`outputArtifacts` becomes a directed `SDGraphEdge` with `kind = .derivation` and `weight = 1.0`; every Tiptap `[[wikilink]]` becomes a `kind = .reference` edge | New (Obsidian-style backlinks + the user's "documents in the graph" ask) | 1 week |
| W7.15 | **ThoughtAttachmentBridge**: bidirectional binding between `RawThought` (Wave 3.1) and `.epdoc` packages. (a) When an agent run produces a doc, the doc's `EpdocProvenance.generatedByRun` already records the run id; W7.15 ADDS the reverse: when a thought references a doc id, write a `RawThought.attachedDocs: [String]` field that the indexer cross-references. (b) `Epistemos/Models/SDPage.swift` gets an `attachedThoughts: [String]` mirror so the doc inspector shows "this doc was generated by N thoughts" + click-through. Migrations + foreign-key validation tests included | New (user direction: "documents are attached to all thoughts in the pro system") | 1 week |
| W7.16 | **Complexity-weighted Metal graph rendering**: extend [graph-engine](graph-engine/src/renderer.rs) so node radius scales by `weight ∈ [0,1]` (the W7.12 complexity scalar), edge thickness scales by `kind`-typed weight, and the SDF label atlas font size also scales modestly with complexity. Visually: simple notes are small clean nodes; complex docs are large luminous nodes with thicker derivation edges. Performance budget: rendering 10K nodes at 60Hz must not regress (existing `bench_tests.rs` budget ceiling) | New (user direction: "graph reflects the complexity of the documents") | 1 week |

**Cross-cutting tests added with W7.12–W7.16:**
- `EpdocComplexityCalculatorTests` — 12 fixtures
- `EpdocDatabaseQueryEngineTests` — 8+ scenarios across each PropertyKind
- `EpdocGraphProjectorTests` — 6+ doc-to-graph projection round-trips
- `ThoughtAttachmentBridgeTests` — bidirectional binding + dangling-reference detection
- `graph-engine` benchmark gate — 10K-node render p99 budget unchanged

**Tag (after W7.16)**: `v2-cognitive-substrate-cosmic`

> **W7.12–W7.16 provenance + ambition** — The user's framing on
> 2026-04-26: "literally like Notion times Obsidian times Craft… a
> really interesting complex and very, very, very useful note-taking
> but not just note-taking — thought analysis and thought ontology
> system." This tier is what makes the `.epdoc` system the **thought
> ontology surface** the user wants: every doc is a graph node, every
> graph node carries semantic + structural complexity, every thought
> binds to the docs it touched, and queries cross from typed properties
> through the unified graph back to source thoughts. Audit gate before
> the `v2-cognitive-substrate-cosmic` tag drops: 7-layer audit per the
> stabilization pattern (build / test / unsafe-grep / drift-check /
> dead-code / runtime perf / cross-tier review).

### Wave 8 — Contextual Shadows + Halo (V1 differentiator, 4 weeks)
**Goal**: ship the V1 decision's defining feature per `ambient/EPISTEMOS_V1_DECISION.md`. "Type a sentence, see a related thought appear, can't remember a time before it worked that way."

| # | Item | Source | Effort |
|---|---|---|---|
| W8.1 | `epistemos-shadow` Rust crate scaffold + UniFFI surface | `ambient/epistemos_shadow.rs` | 2 days |
| W8.2 | Swift `HaloState` + `HaloController` 6-state machine | `ambient/HaloController.swift` §HaloController | 2 days |
| W8.3 | `ShadowSearchService` + `ShadowIndexingService` actors | `ambient/HaloController.swift` §services | 2 days |
| W8.4 | Real backend: Model2Vec + usearch HNSW + tantivy BM25 + RRF fusion + `@_silgen_name` FFI binding | V1 decision §"Retrieval" | 1 week |
| W8.5 | NSPanel non-activating + SwiftUI ShadowPanelContent + HaloButton overlay | `ambient/HaloController.swift` §UI | 3 days |
| W8.6 | NSTextView delegate → controller wiring + Sig.storage signposts | V1 decision §"What gets measured" | 2 days |
| W8.7 | Vault bootstrap indexing on first launch + progress UI | V1 decision §"Week 3" | 3 days |

**Tag**: `v1-shadows-halo`

### Wave 9 — Code Editor v2 + unified provenance (Slice 4-6 from epistemos_code_verdict)
**Goal**: per `epistemos_code_verdict.md`: live syntax stays in Swift via SwiftTreeSitter; Rust handles project-wide indexing + AI semantic embeddings. Code artifacts integrate with the unified provenance graph so when an AI creates / mentions code in raw thoughts, that code links automatically into the substrate.

| # | Item | Source | Effort |
|---|---|---|---|
| W9.1 | `CodeArtifactKind` file-extension catalog (Swift / Rust / TS / JS / Python / HTML / CSS / Go / Markdown / shell / etc.) + new-code-file template scaffolds | brain dump 2026-04-26 | 2 days |
| W9.2 | `CodeProvenance` model mirroring EpdocProvenance for code files (producedBy run / derivedFrom raw thoughts / sourceArtifacts) | brain dump 2026-04-26 | 1 day |
| W9.3 | `CodeArtifactSidecar` schema + `.epcache/code/<blake3>.epcode.json` path resolver (sidecar — NEVER embed in source files) | brain dump 2026-04-26 | 2 days |
| W9.4 | `ChatCodeExtractor` — markdown fence parser that turns agent-mentioned code blocks into candidate CodeArtifacts linked to the originating Run + RawThought | brain dump 2026-04-26 | 2 days |
| W9.5 | Tool-result hook for `write_file` / `edit_file` / `multi_edit` that auto-creates the CodeArtifact + writes its sidecar | brain dump 2026-04-26 | 3 days |
| W9.6 | Swift+SwiftTreeSitter live editor surface (per `epistemos_code_verdict.md` §1: keep syntax in Swift, NOT Rust syntax-core) — line gutter, code-folding, bracket matching, viewport-scoped highlight | `epistemos_code_verdict.md` §3 | 2 weeks |
| W9.7 | Rust workspace indexer (RAG chunking + embeddings → usearch sidecar at `.epcache/code/index.usearch`) | `epistemos_code_verdict.md` §3 | 1 week |
| W9.8 | SourceKit-LSP integration for Swift files (completion + go-to-def + diagnostics) | `epistemos_code_verdict.md` §3 | 2 weeks |
| W9.9 | Agent-grep API: "find code matching X with full provenance" — surfaces the file + run/thought refs + cross-cited artifacts | brain dump 2026-04-26 | 1 week |

**Tag**: `v1-code-editor-v2`

## Total horizon

- **Wave 1**: 1 week (finish V1 ship)
- **Waves 2–6**: 12 weeks (Program C, parallel-compatible per dpp §0.6)
- **Wave 7**: 4–6 weeks (Program B Documents + ACC + Pro features)
- **Total**: **17–19 weeks** for the full multi-program plan, sequenced hardening-first.

Per `EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` §0.6: "If at any point you are >2 weeks behind on a sprint, invoke the Stabilization Path (§7) and ship what's done. Every sprint produces a shippable improvement on its own."

## Stabilization paths (skip-eligible)

If scope gets messy, the dpp defines three stabilization paths:
- **Path A** (Wave 2 only) — Sprint 0 + Sprint 1 read paths only + `.metallib` only. ~3 weeks for 25–35% perf win.
- **Path B** — Skip Sprint 4 (zero-copy FFI carve-out) entirely if it turns into a swamp.
- **Path C** — Defer the Swift macro work; keep hand-maintained `switch` with `precondition(false, "missing case")` guards.

## Codex-style discipline (what continues working)

Every wave runs the same recursive audit pattern this session proved:
1. Master auditor dispatches focused sub-agents per patch
2. Sub-agent returns diff + tests + build evidence
3. Master auditor INDEPENDENTLY verifies (`xcodebuild build`, `cargo test`, `nm`, etc.)
4. Reverts out-of-scope drift (xcodeproj edits, etc.) before commit
5. Commits with full audit trail in message
6. Tags stabilization checkpoints

Protected surfaces remain absolute: ProseEditor, graph engine internals, Anthropic thinking-block byte preservation, agent_core control-plane sovereignty.

## Decision needed from user

Pick one to start:

- **(a) Wave 1** — finish V1 ship hardening (5 items, ~1 week) — most conservative; gets you to TestFlight.
- **(b) Wave 2 (Sprint 0)** — cheap deterministic wins (signposts + GRDB pragmas + LTO) — 1 week; safest perf foundation.
- **(c) Wave 1 + Wave 2 combined** — finish V1 hardening AND lay perf foundation — 2 weeks; shippable + measurable.
- **(d) Direct to Wave 7 (Documents)** — skip perf foundation, ship Documents on current substrate — fastest user-visible feature, but no perf headroom.

Recommended: **(c)** — the user explicitly said "finish hardening before features" and Wave 2 IS hardening (instrumentation + tuning). Then proceed to Wave 3 (substrate) before Wave 7 (features).
