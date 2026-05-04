# Epistemos — Hybrid Cognitive Artifact System
## Implementation Plan & Product Requirements Document (Extension of EPISTEMOS_MASTER_BUILD_SPEC)

**Author target:** Jordan "Jojo" — solo developer, native macOS, Swift 6 / Rust-via-UniFFI / Metal / MLX-Swift / GRDB, M2 Pro baseline.
**Scope:** Extension of the existing Epistemos master build spec, Phase I implementation guide, hardening spec, and ZERO_CORRUPTION_SPEC. Not a greenfield rebuild.
**Disposition:** Truth-first. Every API referenced in this document has been verified against current vendor documentation (as of April 2026). Anything speculative is explicitly flagged.

---

## 0. Executive Summary

Epistemos models cognition as a **pipeline of typed artifacts**, not a pile of files. The extension described here introduces a unified artifact taxonomy — Prose Notes, Documents, Raw Thoughts, Research Sources, Code, Runs, Outputs — linked by a typed knowledge-graph ontology and rendered by **file-type-driven editor surfaces** inside a single vault. There are no sidebar silos; the open artifact's type chooses the surface.

The architectural spine is four decisions:

1. **ProseMirror JSON is the canonical Document format**, stored inside a versioned container called `.epdoc`. Tiptap v3 is the authoring runtime inside a hardened WKWebView. This is chosen over Lexical, BlockNote, Slate/Plate, Portable Text, and Pandoc AST after technical comparison ([Tiptap v3 launch notes](https://tiptap.dev/docs/resources/whats-new), [Liveblocks editor comparison 2025](https://liveblocks.io/blog/which-rich-text-editor-framework-should-you-choose-in-2025), [Lexical serialization constraints](https://github.com/facebook/lexical/discussions/5512)).

2. **A "universal reading language" is a projection architecture, not a new format.** Epistemos treats ProseMirror JSON as the canonical IR and maintains **live, deterministic projections** to Markdown (GFM+wiki), HTML, DOCX, PDF, YAML-front-matter+Markdown, plain text, and a "structured JSON" view optimized for LLM traversal. Each projection is a *writer* over the IR — the Pandoc pattern ([Pandoc AST docs](https://pandoc.org/using-the-pandoc-api.html), [Pandoc DeepWiki](https://deepwiki.com/jgm/pandoc/3.1-document-representation)) — with invariants documented per-format. A small, stable subset ("Epistemos Core Block Set") is guaranteed lossless across all projections; extensions degrade predictably.

3. **Raw Thoughts capture only provider-exposed reasoning surfaces**: Anthropic extended-thinking blocks (preserved verbatim with `signature` fields; [Anthropic extended-thinking docs](https://platform.claude.com/docs/en/build-with-claude/extended-thinking)), OpenAI `reasoning` items and summaries (optionally `reasoning.encrypted_content` for ZDR; [OpenAI reasoning guide](https://developers.openai.com/api/docs/guides/reasoning)), MLX-Swift `<think>…</think>` spans for Qwen3/Qwen3.5 ([Qwen3 MLX docs](https://huggingface.co/Qwen/Qwen3-4B-MLX-4bit)), plus tool traces, plans, and explicit planner summaries. No attempt to reconstruct hidden CoT.

4. **Metal-accelerated hybrid rendering is a compositing strategy, not a replacement editor.** Tiptap runs inside a properly tuned WKWebView; the WKWebView's layer is composited alongside the Metal graph renderer through the shared CoreAnimation layer tree, backed by `IOSurface` for zero-copy snapshots when needed ([WebKit IOSurface.mm](https://github.com/WebKit/webkit/blob/main/Source/WebCore/platform/graphics/cocoa/IOSurface.mm), [Russ Bishop on cross-process rendering](http://www.russbishop.net/cross-process-rendering)). "Native feel" comes from the well-documented Craft/Linear/Lotus toolkit ([DEV — native Electron on Mac](https://dev.to/vadimdemedes/making-electron-apps-feel-native-on-mac-52e8)): pre-warmed processes, custom `WKURLSchemeHandler`, layer-backed hosting, system menu/IME/services plumbing, not pretending WebKit is UIKit.

The rest of this document expands those four spines into executable engineering.

---

## 1. Product Thesis & Cognitive Workspace Model

### 1.1 The thesis in one paragraph

Humans and agents **think** in prose notes and raw thoughts; they **produce** in documents; everything is **linked** through typed graph relationships inside one vault. The surface you see is determined by the artifact's type, not by which panel of the UI you clicked. This is the inversion of the Obsidian/Notion/Roam pattern: instead of "everything is a Markdown file" or "everything is a block-document," Epistemos has multiple *kinds* of cognitive object, each with a purpose-built editor, all sharing a graph-native substrate and a projection-able canonical form.

### 1.2 Why this is different

Notion unifies everything into blocks stored as custom JSON and exposes pagination-friendly APIs because "Markdown is not expressive enough" for their block types ([Creating the Notion API](https://www.notion.com/blog/creating-the-notion-api), [Exploring Notion's Data Model](https://www.notion.com/blog/data-model-behind-notion)). Roam/Logseq treat every bullet as an addressable block with block-ref windows ([Logseq block references](https://discuss.logseq.com/t/the-basics-of-logseq-block-references/8458)). Obsidian trades expressiveness for Markdown purity and uses `[[wikilinks]]` + a metadata cache for graph/backlinks ([Obsidian internal links](https://deepwiki.com/obsidianmd/obsidian-help/4.2-internal-links-and-graph-view)). Epistemos borrows from all three: **block-granular addressing like Roam/Logseq, Markdown-first readability like Obsidian, rich typed blocks like Notion — but with explicit artifact typing on top**, so that a "Document" is *not* the same kind of object as a "Prose Note," and a "Raw Thought" run log is *not* the same kind of object as a "Source PDF." Typed artifacts give agents a vocabulary for what they're reading and writing.

### 1.3 Three-layer linking model (honoring the user's spec)

- **Layer 1 — Explicit links.** Author-authored `[[wikilinks]]`, alias pipes (`[[Target|display]]`), heading refs (`[[Note#heading]]`), block refs (`[[Note^blockId]]`), modeled after Obsidian semantics but stored in the graph as typed edges (`links_to`) rather than resolved at query time from a text scan ([Obsidian linking model](https://deepwiki.com/obsidianmd/obsidian-help/4.2-internal-links-and-graph-view)).
- **Layer 2 — Structural links (auto-generated).** When an agent produces a Document from a Prose Note, the system writes `derived_from`; when a Run consumes a Source, it writes `references`; when a Run emits a Document, it writes `generated_by` and `produced_during`. The graph edges are materialized by the Rust substrate during the artifact mutation transaction, not by a post-hoc index job.
- **Layer 3 — Semantic suggestions (deferred).** Vector-cluster-driven suggested edges ("Related"). Not MVP. Sits on top of the existing sqlite-vec embedding store.

---

## 2. Artifact Taxonomy — Data Model

All artifacts share a common header (`ArtifactHeader`) and a type-specific body. Artifacts are stored as files in the vault (per the existing "model vaults with per-model file trees" structure) and mirrored as nodes in the Rust-owned entity graph with slotmap generational keys. The filesystem is the durable source of truth; the graph is a derived, rebuildable index.

### 2.1 Common header (all artifacts)

```
ArtifactHeader {
  id:            ULID,              // sortable, time-prefixed
  kind:          ArtifactKind,
  schema_version: u32,
  created_at:    TAI64N,
  updated_at:    TAI64N,
  title:         String,
  vault_path:    RelativePath,
  tags:          Vec<Tag>,
  provenance:    ProvenanceBlock,   // who/what produced this, and from what
  content_hash:  Blake3,
  graph_key:     SlotmapKey,        // ephemeral, rebuilt on load
}
```

`ProvenanceBlock` is required and minimal:
```
ProvenanceBlock {
  producer: Producer,              // Human { user_id } | Agent { model, run_id } | System
  derived_from: Vec<ArtifactRef>,  // feeds Layer-2 structural linking
  tool: Option<ToolId>,            // which agent/tool emitted this
}
```

### 2.2 Kinds

**2.2.1 ProseNote** — Native Markdown (djot-flavored CommonMark + wiki extensions). This is the existing TextKit 2 surface. Intended for raw thinking, brainstorming, journaling. Files: `*.md` with YAML front-matter. Djot is preferred over CommonMark for *new* notes (unambiguous nested emphasis, attributes on every element, native divs/spans, native highlight/insert/delete) while CommonMark remains fully readable ([Djot overview](https://djot.net), [Djot vs Markdown](https://php-collective.github.io/djot-php/guide/why-djot), [John MacFarlane's tools](https://johnmacfarlane.net/tools.html)). We accept both and round-trip to djot when parsing is unambiguous.

**2.2.2 Document** — The rich structured artifact. File: `*.epdoc` (see §6). Body is ProseMirror JSON in the Epistemos schema. Intended for polished output, tables, images, structured work. Surface is a Metal-composited WKWebView hosting Tiptap v3.

**2.2.3 RawThought** — A captured reasoning surface. File: directory `runs/<run-id>/` containing `events.jsonl` (append-only), `summary.md`, `final.json`, `thoughts/<turn>.thinking.json` (vendor-verbatim), `tools/<tool-call-id>.json`, `links.json`. Never an editor; always a *viewer* (timeline).

**2.2.4 Source** — Research input: web page, PDF, paper. File: `sources/<hash>.<ext>` + sidecar `sources/<hash>.meta.json` with citation metadata in CSL-JSON (so Pandoc's citeproc can consume them directly; [Pandoc index](https://pandoc.org/)).

**2.2.5 Code** — Code block/file captured as an artifact. File: arbitrary `.rs`, `.py`, `.swift`. Sidecar provenance.

**2.2.6 Run / Session** — Agent execution container. A Run is *the* RawThought structure; the distinction is that a Run also carries the invocation context (agent config, tools enabled, inputs, environment, success/failure) and a linked `Output` artifact.

**2.2.7 Output** — A final artifact produced during a Run. It is *always also* one of the other kinds (Document, ProseNote, Code, …) but additionally carries `produced_during: run_id` in its header. Output is a *role*, not a separate kind.

**2.2.8 Block** — A first-class sub-artifact for block-granular addressing. A Block has a stable `block_id` (ULID), lives inside a parent artifact, and is independently resolvable by `[[parent^block_id]]`. Blocks are materialized as graph nodes only when they are referenced from somewhere else, to prevent O(N blocks × N documents) explosion (see §4.5).

**2.2.9 Concept / Person / Project** — Lightweight typed index nodes. Not stored as files; live only in the graph. Created by author action ("promote this wikilink target to a Concept node") or auto-promoted after N backlinks cross a threshold.

### 2.3 Storage contract

Every artifact with a file-system presence is written via the `ZERO_CORRUPTION_SPEC` atomic-write protocol: temp file in same directory, fsync + `fcntl(F_FULLFSYNC)` (macOS-specific, not handled by plain `fsync` on APFS — see [Apple SSD + F_FULLSYNC discussion](https://mjtsai.com/blog/2022/02/17/apple-ssd-benchmarks-and-f_fullsync/), [SQLite fullfsync behavior](https://sqlite-users.sqlite.narkive.com/0SRI1yWZ/sqlite-database-corruption-and-pragma-fullfsync-on-macos), [Call F_FULLFSYNC in os.fsync discussion](https://discuss.python.org/t/call-f-fullfsync-in-os-fsync-for-macos/79332)), then `rename(2)`. For hot paths (keystroke coalescing) we use `F_BARRIERFSYNC` which is materially cheaper while still providing ordering. GRDB is configured with `PRAGMA synchronous=FULL`, `PRAGMA journal_mode=WAL`, `PRAGMA checkpoint_fullfsync=1`, `PRAGMA fullfsync=1`.

---

## 3. Typed Knowledge Graph Ontology

### 3.1 Model choice: labeled property graph, not RDF

The existing Epistemos graph substrate is a Rust slotmap-backed labeled property graph. This is the correct choice for a single-user cognitive workspace and should *not* be replaced with an RDF triple store. Property graphs offer index-free adjacency and attributes on both nodes and edges, which matches the 95% traversal use case ([Neo4j RDF vs Property Graphs](https://neo4j.com/blog/knowledge-graph/rdf-vs-property-graphs-knowledge-graphs/), [Wisecube comparison](https://www.wisecube.ai/blog/knowledge-graphs-rdf-or-property-graphs-which-one-should-you-pick/), [Bloor on graph DBs](https://www.bloorresearch.com/technologies/graph-databases/)). Triple stores earn their keep only when federation with external Linked Data / W3C-ecosystem knowledge is required — not Epistemos's primary use case. If that requirement ever arises, the property graph can be exported to RDF (RDF-Star handles the edge-attribute gap; [Ontotext on RDF triplestores](https://www.ontotext.com/knowledgehub/fundamentals/what-is-rdf-triplestore/)) without losing fidelity.

### 3.2 Node types

```
NodeType = ProseNote | Document | RawThought | Run | Source | Code
         | Output                       // role marker, not a distinct node
         | Block                         // sub-artifact, materialized on-demand
         | Model                         // a specific LLM configuration
         | Vault                         // folder/project-level grouping
         | Person | Concept | Project    // lightweight index nodes
```

Each node carries `kind`, `title`, `ulid`, `updated_at`, `path?`, `hash?`, plus kind-specific properties.

### 3.3 Edge types (all directed, typed, timestamped)

```
derived_from      // Document derived_from ProseNote
generated_by      // Document generated_by Run
thought_about     // RawThought thought_about Source | Concept | Document
references        // Document references Source
cites             // Document cites Source (with locator)
supports          // Source supports Claim-block-in-Document
produced_during   // Output produced_during Run
linked_to         // generic explicit [[wikilink]]
converted_to      // ProseNote converted_to Document (snapshot relation)
summarizes        // ProseNote summarizes Run | Document
answers           // Document answers Question-block
contradicts       // Claim contradicts Claim
elaborates        // Document elaborates Concept
prompted_by       // Run prompted_by ProseNote | User-input
```

Every edge carries `{ kind, source, target, created_at, source_layer: explicit|structural|semantic, confidence: f32, evidence?: Span }`. The `source_layer` field is the handle for the three-layer linking model.

### 3.4 Visual distinctions in the Metal graph renderer

The existing 10k-node force-directed renderer already distinguishes nodes by color. The extension must handle the taxonomy:

- **Shape** encodes *kind*: ProseNote = soft square, Document = hard-edge rectangle, RawThought = hexagon, Source = diamond, Code = monospaced glyph, Concept = circle, Run = ring (implies internal complexity), Block = small dot.
- **Hue** encodes *model/producer* for Runs and Outputs (Claude family in Anthropic orange, OpenAI green, Qwen local blue, human magenta).
- **Saturation** encodes *freshness*: newer artifacts saturated, older desaturated.
- **Size** encodes *degree* (PageRank-ish), smoothly animated.
- **Edge dash/solidity** encodes *source_layer*: solid = explicit, dashed = structural, dotted = semantic.

### 3.5 Level-of-detail strategy for block explosion

Materializing every paragraph as a graph node would produce millions of nodes in a mature vault, defeating the 10k-node target. The strategy:

- Blocks are **not nodes by default**. They are stored as a JSON column on the parent artifact.
- A block is **promoted to a node** when any of: (a) something else references it via `[[parent^block]]`, (b) the user pins it, (c) an agent writes a `cites`/`supports` edge into it, (d) it's selected for semantic embedding as a unit.
- Zoom-level LOD collapses promoted blocks back into their parent node at low zoom (≥ 1x world scale), fans them out at high zoom (≤ 0.5x world scale). The Metal renderer already owns camera state; we add a per-frame `lodBudget` uniform and skip sub-node draw calls above it.
- This keeps the common-case graph ≤ ~15k addressable nodes for a 1000-artifact vault; promoted-block count scales with *reference density*, which is naturally bounded.

---

## 4. Universal Reading Language — Multi-Format Projection

### 4.1 The question restated

Can one canonical representation project *losslessly or near-losslessly* into Markdown, JSON, YAML, HTML, PDF, DOCX, plain text, and agent-queryable structured JSON, such that every artifact is simultaneously searchable/readable by human, LLM, grep, and vector index?

### 4.2 Honest answer

**A single fully lossless universal format does not exist and is not practical.** Every serious attempt — Pandoc AST, ProseMirror schemas, Lexical editor state, Portable Text, Djot, MDX, CommonMark — has the same core property: **there is a tradeoff surface between format expressiveness and cross-format fidelity, and every projection involves decisions the source format leaves unspecified.** Pandoc explicitly documents this: its AST "is less expressive than many of the formats it converts between" and conversions "may be lossy" — its design goal is preserving *structure*, not *formatting details* ([Pandoc MANUAL](https://pandoc.org/MANUAL.html), [DeepWiki: Pandoc document representation](https://deepwiki.com/jgm/pandoc/3.1-document-representation)). Portable Text similarly is "an agnostic abstraction" that "should be parsed by software" and isn't designed for human authoring ([Sanity Portable Text intro](https://www.sanity.io/guides/introduction-to-portable-text)). Notion explicitly chose custom JSON over Markdown because "Markdown is simply not expressive enough" for their block palette ([Creating the Notion API](https://www.notion.com/blog/creating-the-notion-api)).

What you *can* do — and what Epistemos will do — is define a **canonical IR with a precisely-documented lossless subset** and deterministic, versioned *writers* (projections) for every target format.

### 4.3 Candidate IRs evaluated

| Candidate | Block vocabulary | Agent ergonomics | Projection maturity | Verdict |
|---|---|---|---|---|
| **ProseMirror JSON** | Author-defined schema, tree with marks. Clean separation of block vs inline. | Good: editor-native, deeply typed, `editor.getJSON()` / `editor.commands` ([Tiptap concepts](https://tiptap.dev/docs/editor/core-concepts/introduction)). | Excellent round-trips to HTML; `prosemirror-markdown` handles CommonMark subset; `prosemirror-docx` wraps docx.js for DOCX ([prosemirror-markdown](https://github.com/ProseMirror/prosemirror-markdown), [remark-prosemirror](https://github.com/handlewithcarecollective/remark-prosemirror), [prosemirror-docx](https://github.com/curvenote/prosemirror-docx)); Pandoc bridge exists as a community exporter ([Fidus Writer pandoc export](https://discuss.prosemirror.net/t/pandoc-export/6452)). | **Chosen.** |
| Pandoc AST | `[Block]` + `[Inline]` with enforced block/inline separation. Extremely well-tested across ~40 formats. | OK via JSON filters; schema is rigid Haskell ADT; the AST is less rich than ProseMirror for live editing (no marks vs nodes; no attributes on most inlines pre-`Span`). | Unmatched — Pandoc is the reference projection engine. | **Used as a backend projector**, not as IR. ProseMirror → Pandoc AST → anything. |
| Lexical EditorState | Meta's framework, immutable tree, framework-agnostic core ([Lexical intro](https://lexical.dev/docs/intro), [serialization](https://lexical.dev/docs/concepts/serialization)). | Good TS types; but "by requiring the Lexical state to be the source of state means the content stored in the database must necessarily be tightly coupled with Lexical" ([Lexical db coupling discussion](https://github.com/facebook/lexical/discussions/5512)). | Good for JSON/HTML; lacks pure decorations (collaborative cursors require DOM overlays; [Liveblocks editor comparison](https://liveblocks.io/blog/which-rich-text-editor-framework-should-you-choose-in-2025)); Lexical collaboration hardcodes root node name, blocking >1 editor per Yjs doc. | Rejected. Node mutation vs. decoration split is a Tiptap/ProseMirror advantage; schema inflexibility is a problem for a cognitive workspace. |
| Portable Text | JSON array of blocks, spans, markDefs, custom `_type`. Explicitly serializable to anything. | Good for server-side transformation; less good for live editing at scale; editor implementation is less mature than ProseMirror. | Good (markdown, HTML, React). Spec is stable. | Rejected as IR (editing ergonomics, ecosystem), but the **design pattern — `markDefs` as out-of-line annotations, `_type` on every block, `_key` on every node for real-time collab** — is borrowed directly into the Epistemos ProseMirror schema (see §4.5). |
| Djot | Syntax, not IR. Strict, unambiguous, block-level. | Excellent for humans/LLMs (no ambiguity). | Pandoc reads and writes it ([Quarto djot discussion](https://github.com/quarto-dev/quarto-cli/discussions/3514)). | **Chosen as the preferred Markdown flavor** for the ProseNote kind and for the Markdown projection of Documents. |
| MDX | Markdown + JSX embed. Developer-docs oriented. | Requires JS runtime to render components; not a storage format; brittle outside the MDX toolchain ([MDX site](https://mdxjs.com/)). | N/A as storage. | Rejected as canonical. Optionally supported as an *import* source. |
| Lisp / Pollen / Scribble | Tree-structured documents where code and prose interleave. | Powerful for programmable docs; ecosystem too narrow for Epistemos. | N/A. | Rejected; but the philosophy (prose is code is data) informs the choice to keep the IR a tree of typed nodes. |

**Decision:** Canonical IR is **the Epistemos ProseMirror Schema (EPM-Schema v1)** — a ProseMirror schema with explicit Portable-Text-style `_key`/`_type` stability, a conservative block vocabulary we guarantee across all projections, and extension nodes that degrade predictably.

### 4.4 The EPM-Schema v1 (condensed spec)

Block nodes (stable, v1 guarantees lossless projection to all targets):
`doc, paragraph, heading(level=1..6), blockquote, code_block(lang?), horizontal_rule, bullet_list, ordered_list, list_item, table, table_row, table_cell(header?), image, math_block, hard_break, thematic_break, callout(kind), figure(caption?), note(kind=foot|side|end), embed(kind=source|run|document, ref)`.

Inline nodes: `text, inline_math, inline_code, emoji`.

Marks: `em, strong, s (strike), underline, code, link(href, title?), highlight(color?), wiki_link(target, alias?, kind=page|heading|block), cite(key, locator?), agent_ref(run_id, turn?), annotation(ref_id)`.

Every node carries `attrs._key: ULID` (Portable-Text style, preserves identity across edits for real-time collab and block-level graph addressing — [Portable Text `_key`](https://www.sanity.io/guides/introduction-to-portable-text)). Every node carries `attrs._epid: ULID` (the Epistemos block id; equals `_key` unless the block has been "promoted" to a graph node, in which case `_epid` is pinned across splits/merges).

Extension nodes beyond v1 (degraded projection documented per format):
- `excalidraw_drawing(data)` — projects to SVG in HTML/PDF, image in DOCX, `![](embedded-drawing.svg)` in Markdown.
- `code_cell(kernel, code, outputs[])` — projects to fenced code block + output in Markdown, iframe in HTML, separate appendix section in DOCX/PDF (Jupyter-style).
- `raw_thought_embed(run_id, turn_range)` — projects to a collapsed quote in Markdown, a styled box in HTML, an appendix in print formats.

### 4.5 Projection matrix

| Target | Writer | Lossless for v1 core? | Notes |
|---|---|---|---|
| **Markdown (djot)** | Rust writer over EPM-Schema JSON, based on `prosemirror-markdown` semantics but reimplemented in Rust to avoid JS round-trip. | Yes for v1 core. Wiki links preserved via djot attribute syntax `[[Note]]{.wiki}`; callouts via `:::{.callout .note}` divs; annotations via `[text]{#anchor}`. | Primary consumer: agents, git, grep, ripgrep, `fzf`. Deterministic: same input → same output bytes. |
| **Markdown (CommonMark+GFM)** | Same writer, lossier mode. | No (no div/span/callout/wiki-link in plain GFM). | Falls back to HTML comments (`<!-- :::callout.note -->`) to preserve structure without visual rendering. |
| **HTML** | Tiptap `generateHTML()` (SSR-capable in v3 — [Tiptap v3](https://tiptap.dev/docs/resources/whats-new)) run in a headless JS context on indexing, *or* a mirror Rust writer for zero-JS projection. | Yes. | Used for search result previews, PDF, print. |
| **DOCX** | `prosemirror-docx` (thin docx.js wrapper) invoked in the JS context ([prosemirror-docx](https://github.com/curvenote/prosemirror-docx)). Alternatively Pandoc via the AST bridge for higher table fidelity. | Core-lossless for a small core; complex tables/footnotes gain from Pandoc. | Two-path: `prosemirror-docx` for fast in-WebView export; Pandoc binary (bundled) for high-fidelity. |
| **PDF** | WKWebView `createPDF(configuration:)` over the styled HTML, OR Pandoc → LaTeX → PDF for print-perfect output. | Visual fidelity yes; structure tagging varies. | Default fast path is WebKit PDF; publication path is Pandoc. |
| **YAML front-matter + Markdown body** | Writer reads header metadata + emits djot. | Yes. | For external Markdown tools (Jekyll, Quarto). |
| **Plain text** | Writer strips marks, flattens. | Lossy by design. | For embeddings. |
| **Structured JSON (agent view)** | Writer emits a *denormalized* tree where block IDs, headings, links, citations are first-class top-level arrays alongside the nested tree (similar shape to Notion's breadth-first paginated blocks — [Creating the Notion API](https://www.notion.com/blog/creating-the-notion-api)). | Yes. | Consumed by agent tool-calls. |
| **Pandoc AST JSON** | ProseMirror → Pandoc AST adapter (Rust). | Yes for v1 core; extension nodes wrap in Pandoc `Div` with class attributes. | Enables using Pandoc's full writer set (LaTeX, EPUB, ODT, JATS, OPML, …) as a free bonus. |

### 4.6 Determinism and round-trip contracts

The **Markdown shadow** (see §6) is the hot path: every save writes a fresh djot file next to the `.epdoc`. The writer is deterministic (stable key ordering, no dates, no random IDs in output text — IDs go into footnote-style anchor blocks). Round-trip **is not perfect** from djot back to EPM-Schema JSON; we explicitly **do not attempt round-trip from Markdown into JSON** as the canonical path. Markdown is a *projection*, not a source. If the user edits the Markdown shadow externally, we detect it (content_hash mismatch), import it into a *new* artifact version, and mark the relation as `converted_to`, preserving history. This follows the Notion choice of JSON over Markdown for precisely the round-trip reason ([Notion API blog](https://www.notion.com/blog/creating-the-notion-api)) and is what `prosemirror-markdown` warns about ("you will have trouble reading back" custom markdown — [prosemirror-markdown](https://github.com/ProseMirror/prosemirror-markdown)).

### 4.7 Per-block addressability across projections

Because every node carries `_key` / `_epid`, every projection can embed anchors:
- djot: `[para text]{#ep-01HE...}`
- HTML: `<p id="ep-01HE...">`
- DOCX: bookmarks
- PDF: named destinations via WebKit
- Plain text / embeddings: prepend `[ep:01HE...]` sentinel to the chunk

This means **a vector search hit on a plain-text chunk resolves to the exact block in the canonical IR, which resolves to the exact block in every other projection.** This is the technical core of the "universal reading language" promise.

---

## 5. Editor Stack — Recommendation & Justification

### 5.1 Final call: Tiptap v3 + ProseMirror + Yjs (deferred)

**Tiptap v3** ([launch notes](https://tiptap.dev/docs/resources/whats-new), [YC Tiptap 3.0 announcement](https://www.ycombinator.com/launches/NR5-tiptap-3-0-beta-the-next-gen-open-source-editor)) on top of **ProseMirror core** ([ProseMirror guide](https://prosemirror.net/docs/guide/)). Rationale:

- **Schema control.** ProseMirror's schema is the IR — not an editor feature layered on top ([ProseMirror schema example](https://prosemirror.net/examples/schema/), [Schema API design thread](https://discuss.prosemirror.net/t/schema-api-design/47)). We own it.
- **v3 improvements relevant to us.** Server-side rendering without a DOM (important for indexing/headless export), JSX node views, consolidated TableKit, Floating UI for menus, and — especially — the planned **Content Migrations API** for schema evolution and **Markdown Support** rounding out the story. Tiptap's 2026 roadmap is explicitly "document layer around the database" with AI Toolkit + Server AI Toolkit, which aligns with our agent-writes-documents use case ([Tiptap roadmap 2026](https://tiptap.dev/blog/release-notes/our-roadmap-for-2026)).
- **Programmatic API for agents.** `editor.commands.streamContent({from, to}, async ({write}) => …)` ([Tiptap stream content docs](https://tiptap.dev/docs/content-ai/capabilities/text-generation/stream)) provides a precise primitive for agents to insert/replace ranges with streaming content. `editor.chain()` composes commands transactionally ([Tiptap commands docs](https://tiptap.dev/docs/editor/api/commands)). `tr.mapping.map()` keeps positions correct across chained steps.
- **Pure decorations and plugin system.** ProseMirror has pure decorations; Lexical doesn't, which forces DOM-hack overlays for collab cursors ([Liveblocks comparison](https://liveblocks.io/blog/which-rich-text-editor-framework-should-you-choose-in-2025)).
- **Collaborative editing path.** When we add collab, **Loro** over Yjs is the recommendation. Loro's Fugue-based text CRDT minimizes interleaving anomalies ([Loro text docs](https://loro.dev/docs/tutorial/text)), ships an official `loro-prosemirror` binding with cursor awareness and undo/redo ([Loro ProseMirror integration](https://loro.dev/docs/tutorial/text)), and has demonstrated competitive perf against Yjs ([Yjs vs Loro thread](https://discuss.yjs.dev/t/yjs-vs-loro-new-crdt-lib/2567)). Yjs+`y-tiptap` remains the safe fallback ([y-tiptap binding](https://github.com/ueberdosis/y-tiptap)). Single-user shipping today, CRDT-ready tomorrow — choose a schema whose attrs use stable `_key` from day one so Loro/Yjs can land later without rewriting stored docs.

**Rejected:**
- **BlockNote** is Tiptap + opinionated React UI ([BlockNote vs Tiptap](https://tiptap.dev/alternatives/blocknote-vs-tiptap)). An abstraction atop an abstraction; gives up schema control without giving us enough in return for a schema-heavy product.
- **Lexical** has nice ergonomics and Meta's engineering, but: tight DB coupling, missing pure decorations, hardcoded Yjs root (incompatible with multi-editor per doc).
- **Plate (Slate)** has a smaller plugin ecosystem for our specific needs and Slate's selection/normalization model has historically been brittle.
- **Milkdown** is viable but smaller community; Tiptap's commercial + OSS tension is healthier for our time horizon.

### 5.2 ProseMirror schema best practices (applied)

Following the ProseMirror documentation's philosophy ([ProseMirror guide](https://prosemirror.net/docs/guide/)): every content type is a node or a mark; nodes are immutable values; the schema enforces invariants so the editor can auto-fix partial states. Our rules:

1. **No semantic meaning in class names.** If something means "highlight to remember," it gets a node type, not `class="important"`.
2. **`_key`/`_epid` on every node** (attrs). Stable across edits.
3. **Versioned schema (`schema_version` integer).** Stored in every `.epdoc`. The Tiptap v3 Content Migrations API is the migration path; we additionally keep a hand-written Rust migration table for offline/CI.
4. **Content expressions are conservative.** Block children use `block+`, paragraph uses `inline*`; we reject ambiguity.
5. **Schema is code-generated** from a single TOML ontology so the Swift side (for validation in the Rust substrate) and the JS side (for the editor) agree.

---

## 6. The `.epdoc` Serialization Pipeline

### 6.1 File format

`.epdoc` is a directory (Apple-package style, looks like a file in Finder via `Info.plist` UTI declaration):

```
NoteTitle.epdoc/
├── manifest.json          # ArtifactHeader + schema_version + projection manifest
├── canonical.json         # ProseMirror JSON (the truth)
├── shadow.md              # djot Markdown projection (regenerated on save)
├── snapshot.html          # HTML projection (regenerated on save)
├── plain.txt              # plain text projection (for embedding pipeline)
├── assets/                # images, attached files, referenced by content-hash
│   └── <blake3>.<ext>
├── crdt/                  # Loro/Yjs update log (when enabled)
│   └── updates.bin
└── history/
    ├── 0001-<timestamp>.patch   # ProseMirror-step format, signed
    └── ...
```

Rationale: package directories are native to macOS; each projection is an independent file for `mtime`-based incremental reindexing; history is append-only (immutable patches + periodic snapshots). Failure during any single write corrupts at most one file; `manifest.json` is always the last thing written, so a missing/stale manifest is the signal to recover from the previous patch.

### 6.2 Atomic-write protocol per file (inherits ZERO_CORRUPTION_SPEC)

1. Write to `.tmp` sibling in the same directory.
2. `write(2)` → `fsync(2)` → `fcntl(fd, F_FULLFSYNC)` ([F_FULLFSYNC necessity](https://mjtsai.com/blog/2022/02/17/apple-ssd-benchmarks-and-f_fullsync/), [Python discussion on macOS F_FULLFSYNC](https://discuss.python.org/t/call-f-fullfsync-in-os-fsync-for-macos/79332)). For hot paths (autosave on every idle tick), use `F_BARRIERFSYNC` which preserves ordering at far lower cost.
3. `rename(2)` to final name (POSIX atomic on same filesystem).
4. `fsync` the containing directory.

### 6.3 Save pipeline (hot path)

```
JS side (Tiptap):           emits JSON + step-list on every transaction
IPC → Swift:                WKScriptMessageHandler (WKContentWorld.defaultClient isolation)
Swift:                      debounce 250ms, enqueue to actor
Actor → Rust (UniFFI):      ep_document_save(canonical_json, steps)
Rust:                       validate against schema → write canonical.json (atomic) →
                            invoke md_writer → write shadow.md (atomic) →
                            invoke html_writer → write snapshot.html (atomic) →
                            emit plain.txt  →
                            update GRDB row (artifact.updated_at, hash) →
                            update graph edges (incremental) →
                            enqueue reindex job (tantivy + sqlite-vec) →
                            write new patch to history/ →
                            atomically replace manifest.json (last)
```

The projection writers are pure Rust (no JS required for save-path correctness). The *initial* HTML/DOCX rendering for publication/export can optionally go through the Tiptap JS SSR path for fidelity with the live editor; that's an export-time concern, not a save-time concern.

### 6.4 Markdown shadow: regenerate, not patch

We **regenerate** the shadow on every save rather than incrementally patch it. Reasons: incremental patching requires a position-perfect diff from the ProseMirror step-list to byte positions in the Markdown — ProseMirror steps are not defined over Markdown. Regeneration is O(N) in document size; an 80-page document regenerates in <2ms in Rust. There is no race if writes are serialized through the actor.

### 6.5 Export pipelines

- **DOCX (fast).** Headless Tiptap in an off-screen WKWebView, `prosemirror-docx` writer, `writeDocx(...)`. Under ~200ms for typical documents.
- **DOCX (high-fidelity).** Canonical JSON → Rust adapter → Pandoc AST JSON → bundled `pandoc` binary (shipped as a helper tool via XPC, sandboxed). Handles complex tables, footnotes, citations via CSL-JSON.
- **PDF (fast).** WKWebView `createPDF(configuration:)` over `snapshot.html` styled with print CSS.
- **PDF (publication).** Pandoc → LaTeX → Tectonic (bundled). Produces camera-ready output with proper typography.
- **HTML.** `snapshot.html` is already current at save time.

### 6.6 Corruption recovery protocol

On open, if `manifest.json` is missing or schema-invalid:
1. Read latest `history/*.patch`.
2. Apply patches in order against the previous snapshot to rebuild `canonical.json`.
3. Rebuild all projections.
4. Surface a user-visible notice: "This document was recovered from version N."
5. Stash the corrupted files in `.epdoc/.quarantine/` for forensics.

On canonical.json schema-validation failure, the same path runs but the last patch is isolated as the prime suspect and flagged.

---

## 7. Raw Thoughts System

### 7.1 What we capture (exhaustive list)

| Provider | What is exposed | How we capture |
|---|---|---|
| **Anthropic Claude** (extended thinking) | `thinking` content blocks with `thinking: string` and `signature: string` fields; under interleaved thinking (`interleaved-thinking-2025-05-14` beta) blocks appear between tool calls; Opus 4.5 preserves them across turns automatically ([Anthropic extended thinking docs](https://platform.claude.com/docs/en/build-with-claude/extended-thinking)). Thinking text must be sent back to the API **verbatim** or signature validation fails ([signature bug discussion](https://github.com/openclaw/openclaw/issues/24612), [opencode issue #16748](https://github.com/anomalyco/opencode/issues/16748)). | Store the block exactly as received (including `signature` and `type:"redacted_thinking"` blocks where present — the API can return blocks with data but empty text; these must also be round-tripped — [PR #1744 discussion](https://github.com/openai/openai-agents-python/pull/1744)). Never sanitize, trim, or reorder thinking blocks. |
| **Anthropic Claude Managed Agents** | Session event stream with `agent.message`, `agent.tool_use`, `session.status_*` events, plus durable session log ([Managed Agents overview](https://platform.claude.com/docs/en/managed-agents/overview), [Managed Agents quickstart](https://platform.claude.com/docs/en/managed-agents/quickstart), [Anthropic engineering blog](https://www.anthropic.com/engineering/managed-agents)). Beta header: `managed-agents-2026-04-01`. | Stream events directly into `events.jsonl`. The session itself is the run. |
| **OpenAI o3 / o4-mini / GPT-5 series** (Responses API) | `reasoning` output items. `reasoning.summary` with setting `auto` / `concise` / `detailed` (GPT-5 series doesn't support `concise`). Raw reasoning tokens not exposed; `reasoning.encrypted_content` is available as opaque payload for ZDR multi-turn continuation ([OpenAI reasoning guide](https://developers.openai.com/api/docs/guides/reasoning), [Responses API cookbook](https://cookbook.openai.com/examples/responses_api/reasoning_items)). | Capture `summary` text when present; capture `encrypted_content` opaquely for replay; note that summary is often omitted even when requested ([community thread](https://community.openai.com/t/o3-model-in-api-often-omits-reasoning-summary-despite-reasoning-summary-detailed/1307301)). |
| **MLX-Swift local (Qwen3, Qwen3.5, Qwen3.6)** | Models emit `<think>…</think>` spans in the output stream when `enable_thinking=True` (default for Qwen3) ([Qwen3 MLX model card](https://huggingface.co/Qwen/Qwen3-4B-MLX-4bit)). Thinking budgets can be enforced via tokenizer-level hooks ([MLX-VLM thinking budget PR](https://github.com/Blaizzy/mlx-vlm/pull/637)). Qwen3.6 adds thinking-preservation across history ([Qwen3.6 release](https://github.com/QwenLM/Qwen3.6)). | Split the stream on `<think>` / `</think>` during generation, route thinking to a separate buffer, stream answer to the user surface. |
| **Agent tool traces** (all providers) | Tool-call input, tool-call output, duration, success/failure. | Captured by the Rust agent runtime (rig-based; [rig crate docs](https://docs.rs/rig-core/latest/rig/)) as structured events. |
| **Explicit planner output** | Plan documents, checklists, "I'm going to do X then Y" text when agents produce them as first-class output. | Captured when the agent uses the designated `plan` or `summary` tool. |

We **do not** attempt to reconstruct hidden CoT for models that don't expose it, and we **do not** infer reasoning from output. Reasoning we don't see is reasoning we don't claim.

### 7.2 Run folder layout

```
runs/<run-ulid>/
├── manifest.json           # Run metadata: agent_id, model, config, inputs, outputs, status
├── events.jsonl            # append-only, one event per line; content-addressed by line number
├── summary.md              # human/LLM-readable summary, written at Run end
├── thoughts/
│   ├── <turn-n>.thinking.json   # vendor-verbatim thinking block (Anthropic) or <think> span (Qwen)
│   └── <turn-n>.summary.json    # reasoning summary (OpenAI)
├── tools/
│   └── <call-ulid>.json    # {tool, input, output, duration_ms, status}
├── plans/
│   └── <plan-ulid>.md      # explicit planner artifacts
├── outputs/                # links to Output artifacts produced by this run
│   └── <artifact-ulid>.ref.json
└── links.json              # typed edges produced/consumed: references, generated_by, ...
```

`events.jsonl` is the definitive log. All other files are views over events. Format:

```json
{"seq":0,"t":"2026-04-24T15:02:01.234Z","kind":"user.message","content":{...}}
{"seq":1,"t":"...","kind":"agent.thinking","turn":0,"provider":"anthropic","payload":{"type":"thinking","thinking":"...","signature":"..."}}
{"seq":2,"t":"...","kind":"agent.tool_use","call_id":"...","tool":"fs.read","input":{...}}
{"seq":3,"t":"...","kind":"tool.result","call_id":"...","output":{...},"duration_ms":23}
{"seq":4,"t":"...","kind":"agent.message","content":[...]}
{"seq":5,"t":"...","kind":"run.complete","status":"success","outputs":["..."]}
```

Per-model subdirectories (`runs/claude/*`, `runs/gpt/*`, `runs/qwen/*`) are **not** introduced — the `model` field in the manifest is sufficient and keeps ULIDs globally sortable. Filtering by model is a query, not a layout.

### 7.3 Timeline viewer UX

Present a Run as a **git-commit-style DAG**: root node is the initial prompt; child nodes are turns; each turn fans out to tool calls (parallel) and thinking blocks (serial). Branches occur when the agent retries a tool or the user sends a mid-run `user.message` ([Managed Agents send events mid-execution](https://platform.claude.com/docs/en/managed-agents/overview)). Implementation: reuse the existing Metal force-directed graph renderer at low scale — a Run's DAG is tiny (<100 nodes), so we can draw it with the same pipeline in a dedicated viewport. Clicking a thinking block opens the full verbatim text in a side pane. Clicking an Output jumps to the Document.

### 7.4 Graph linkage

A Run produces two kinds of edges:
- **Per-run edges.** `Run --generated_by--> Output`, `Run --prompted_by--> ProseNote | User`, `Run --references--> Source`. These are always on the Run node.
- **Per-turn edges (optional, promoted).** When a specific thinking block cites a specific source, we materialize a `Block(thinking) --thought_about--> Source` edge. Same promotion rule as §3.5: materialize only when referenced; keep cost bounded.

Hierarchical, not flat.

---

## 8. Metal-Accelerated Hybrid Rendering

### 8.1 Truth: WKWebView is already Metal-backed

WKWebView on Apple Silicon already composites through CoreAnimation and renders into Metal-backed `IOSurface`s managed by WebKit's `IOSurface::create` path ([WebKit IOSurface.mm](https://github.com/WebKit/webkit/blob/main/Source/WebCore/platform/graphics/cocoa/IOSurface.mm)). We do not need to "make it Metal." We need to make the WKWebView feel native and compose it into the rest of our Metal scene cleanly.

### 8.2 Making WKWebView feel native — the verified playbook

1. **Pre-warm a shared `WKProcessPool`.** First-view creation costs 100+ms ([Apple dev forum thread](https://developer.apple.com/forums/thread/733774), [WebViewWarmUper](https://github.com/bernikovich/WebViewWarmUper)). Create it at app launch. Reuse web views aggressively — never create one per document ([Embrace on WKWebView leaks](https://embrace.io/blog/wkwebview-memory-leaks/)).
2. **Serve assets via `WKURLSchemeHandler`.** Use a custom scheme (`epistemos://`) to load the editor bundle and documents from the app bundle + vault ([Custom schemes guide](https://dev.to/gualtierofr/custom-url-schemes-in-a-wkwebview-oak), [Apple WKWebView forums](https://developer.apple.com/forums/thread/125224)). Avoids file:// cross-origin hassles, enables deterministic caching, and sidesteps the startup latency of loading HTML via `loadHTMLString` with a changing baseURL ([inessential WKWebView latency note](https://inessential.com/2019/04/04/wkwebview_rendering_latency_in_10_14_4.html)). Set `limitsNavigationsToAppBoundDomains = YES` and register `epistemos` in Info.plist.
3. **Load editor bundle once, reuse across documents.** The editor is a singleton; switching documents is `editor.setContent(newJson)`, not reload.
4. **Disable everything we don't need.** `configuration.defaultWebpagePreferences.allowsContentJavaScript = true` (required), but disable link preview, 3D Touch menus, unused URL schemes, `isInspectable = false` in release.
5. **Layer-backed hosting NSView** with `wantsLayer = true`, `layerUsesCoreImageFilters = false`, explicit corner masking by the native view, not CSS.
6. **Bundle size.** The editor bundle (Tiptap v3 + our extensions) ships via `esbuild --bundle --minify --tree-shake --format=esm` targeting Safari 18. Budget: ≤ 400 KB gzipped. No framework (no React, no Vue) — Tiptap has vanilla bindings; we write minimal custom UI in vanilla TS + `lit-html` for templating.
7. **Font fidelity.** Inject SF Pro at the CSS layer via `@font-face` pointing to `epistemos://fonts/sf-pro.woff2` (assets embedded in the app bundle). Use system font-features (`font-feature-settings`) to match native kerning. Cocoa's "Look Up" / "Share" / "Speech" services require plumbing: observe `NSServicesMenuRequestor` on the host view and forward the selection fetched via JS back to the system.
8. **IME (CJK, accents, emoji) and spellcheck.** WKWebView uses macOS's native IME and spellcheck for `contenteditable` content out of the box. We *must not* intercept keystrokes in JS before the IME completes composition (listen on `compositionstart/end`, not `keydown`). Spellcheck uses the system dictionary automatically when `spellcheck="true"`.
9. **Undo/redo integration.** The native macOS undo stack lives on `NSUndoManager` of the host view. Bridge: register coalesced undo groups on every ProseMirror transaction via `WKScriptMessageHandler`; `undo`/`redo` on the native side calls back into JS to invoke `editor.commands.undo()`. This gives ⌘Z behavior matching every other Cocoa app.

### 8.3 Compositing with Metal graph renderer

**Four options evaluated:**

A. **Side-by-side (two CALayers, sibling).** The WKWebView renders into its own layer; the Metal `CAMetalLayer` renders into another. They share a parent view. Compositing is done by the window server. Zero cost. Works perfectly when doc-editor and graph-viewer live in separate panes. **This is the default.**

B. **Metal layer overlay over WKWebView.** For features like "graph mini-map overlay over document," render the Metal layer above the WKWebView layer, transparent background, letting editor content show through. Trivial via sublayer ordering. Well-supported.

C. **IOSurface snapshot into Metal texture.** For "a graph node that is a live document preview," we need the document's pixels inside the Metal scene. WKWebView exposes `takeSnapshot(with:completionHandler:)` which returns an `NSImage`. For live previews we want zero-copy. The practical path:
 - Render the doc into an off-screen WKWebView.
 - Use `WKWebView.underlyingSurfaceFromSnapshot` (internal API, SPI — do *not* ship) *or* create our own offscreen HTML renderer on the side using `NSView.bitmapImageRepForCachingDisplay` + an `IOSurface` backing store, then bind that surface to a `MTLTexture` via `device.newTexture(descriptor:iosurface:plane:)` ([Apple iosurface docs](https://developer.apple.com/documentation/metal/mtltexture/1516104-iosurface), [Russ Bishop cross-process rendering](http://www.russbishop.net/cross-process-rendering)). For Epistemos, the pragmatic approach: render static thumbnails via `takeSnapshot` (millisecond-scale), cache them per content-hash, and animate between cached snapshots on zoom transitions. Live-streaming pixels from an editable web view into a Metal scene is technically possible via SPI but fragile and not worth the maintenance cost.

D. **Replace the editor with native Metal text rendering.** Rejected. The work to replicate Tiptap's block model, IME, selection, accessibility, system services on top of Metal glyph rendering is 6+ engineer-years. We already have a native TextKit 2 markdown editor for Prose Notes; Document editing is where WebKit earns its keep.

**Decision:** (A) + (B) + (C-thumbnail-cache). Shared process pool and IOSurface-backed editor snapshots give a native feel; the graph renderer stays pure Metal; live doc previews inside graph nodes use cached thumbnails regenerated on artifact save.

### 8.4 Keystroke latency targets

Target: **p95 keystroke-to-glyph ≤ 16ms** (one 120Hz ProMotion frame). Measurement: inject `performance.now()` timestamps at `keydown` and at the following `requestAnimationFrame` after DOM flush; log to the telemetry table. Known mitigations:

- Do not debounce the JS→Swift bridge for keystroke events. Debounce only the *save* pipeline.
- Do not call `editor.getJSON()` on every keystroke; diff on commit boundaries.
- Disable expensive decorations (spellcheck-red-underline animations, prosemirror-history snapshots) during typing bursts and re-enable on idle.
- Pin the WKWebView content process to performance cores via QoS hint (`configuration.processPool` + `NSQualityOfService.userInteractive`).

### 8.5 Accessibility

WKWebView exposes its DOM to VoiceOver via WebKit's `AX` bridge automatically; our editor is pure `contenteditable`, so accessibility is inherited. The explicit work:
- All custom node views must set `role=`, `aria-label=`, and `tabindex=` appropriately.
- Focus trapping: when the editor has focus, arrow keys, Home/End, and reader-rotor commands must reach the native layer — do not capture them in the JS frame.
- Expose structural navigation (by heading) by emitting `<nav>` landmarks in the rendered DOM.

---

## 9. Agent Integration

### 9.1 How agents *read* documents

Three modes, chosen by the agent client:

- **Markdown projection (default).** Agents read `shadow.md` because it's cheap to embed in a prompt and high-recall for LLM pattern-matching. This is the Notion-like choice inverted: their reasoning that "we chose custom JSON because Markdown loses block identity" applies when *producing* rich content; for *reading*, Markdown wins on token efficiency ([Notion API blog](https://www.notion.com/blog/creating-the-notion-api)). We preserve block IDs via djot attributes so the agent can cite them back.
- **Structured JSON projection.** For agents that need to traverse (e.g., "find all headings under section X"), the structured JSON view is a denormalized tree with top-level `headings[]`, `blocks[]`, `links[]`, `citations[]` arrays.
- **Direct ProseMirror commands.** When an agent wants to *edit*, it does not regenerate Markdown and hand back. It calls our tool `edit_document(doc_id, ops)` where `ops` is a list of Tiptap commands (insertContentAt, setNode, deleteRange, chain). This survives concurrent user edits via ProseMirror's position-mapping.

### 9.2 How agents *write* documents

Two patterns:

- **Full-document replace (simple tasks).** Agent produces djot-flavored Markdown; Rust converts to ProseMirror JSON via the djot → EPM-Schema importer; stored as a new version. Fast path for short notes. Position semantics lost — appropriate for "write me a one-page summary," not for "edit paragraph 3."
- **Structured streaming edits (precise tasks).** Agent calls a typed tool that invokes `editor.commands.streamContent({from, to}, async callback)` ([Tiptap stream content API](https://tiptap.dev/docs/content-ai/capabilities/text-generation/stream)). The tool exposes position mapping, `chain().insertContentAt(pos, node).run()`, and returns structured-diff results for user accept/reject (the Liveblocks/Distribute pattern — [Liveblocks AI copilot blog](https://liveblocks.io/blog/building-an-ai-copilot-inside-your-tiptap-text-editor)).

Distribute's lesson ([Liveblocks/Tiptap case study](https://liveblocks.io/blog/building-an-ai-copilot-inside-your-tiptap-text-editor)) is critical: asking an LLM to emit low-level step operations referencing node IDs is unstable. Their fix, and ours, is to have the model emit a *complete edited document* in a constrained schema, then diff it against the original to produce the actual edit operations. The ProseMirror-level diff is stable; the LLM's job is just "write the new version."

### 9.3 Streaming without flicker/cursor-loss

ProseMirror's `streamContent` command holds a range and accumulates writes into one transaction per partial update, re-rendering only the affected subtree. Cursor stability: the tool claims the selection range, writes into it, and restores the previous selection at end. Under CRDTs (future) this is already handled by Loro's cursor API with `side: -1/0/1` semantics ([Loro cursor docs](https://loro.dev/docs/tutorial/text)).

### 9.4 Rig + Claude Managed Agents wiring

The agent runtime is pure Rust using the `rig` crate ([rig on crates.io](https://crates.io/crates/rig-core), [rig core docs](https://docs.rs/rig-core/latest/rig/)). `rig::agent::Agent` holds a model + preamble + tools + (optional) dynamic context via a `VectorStoreIndex`. Tools are Rust functions registered via `.tool()`. Claude Managed Agents is accessed via a separate provider client (using the `managed-agents-2026-04-01` beta header — [Claude Managed Agents quickstart](https://platform.claude.com/docs/en/managed-agents/quickstart)); its event stream maps 1:1 onto our `events.jsonl` schema.

Concrete agent ↔ artifact tools:
- `read_artifact(id, mode=md|json)` — returns projection.
- `list_artifacts(filter)` — graph query.
- `edit_document(id, ops)` — invokes Tiptap via the JS bridge.
- `create_document(title, initial_content)` — creates `.epdoc` and writes `derived_from` if called inside a Run with a source ProseNote.
- `cite(block_epid, source_id, locator)` — materializes a `Block --cites--> Source` edge and inserts a `cite` mark in the document.
- `run_tool(tool_spec)` — re-entry point for Claude Managed Agent sub-agents via `callable_agents`.

Every tool invocation is logged to `events.jsonl` as `kind: tool.result`. Every artifact mutation adds a `provenance` entry with `producer: Agent{ run_id }`.

### 9.5 Anthropic thinking preservation — non-negotiable rules

The single largest footgun in shipping Anthropic-based agents is quietly modifying thinking blocks during session persistence, which invalidates signatures and causes 400 errors after ~15 turns ([opencode issue #16748](https://github.com/anomalyco/opencode/issues/16748), [openclaw issue #24612](https://github.com/openclaw/openclaw/issues/24612), [Step Codex writeup](https://www.stepcodex.com/en/issue/anthropic-thinking-block-signature-field-lost-during-session)). Our Rust agent runtime enforces:

1. Thinking blocks are stored as opaque byte-identical JSON values; no Unicode normalization, no whitespace trimming, no surrogate cleaning, no key reordering.
2. The serialization layer is unit-tested with a fixture containing unpaired surrogate halves (the exact opencode bug) and round-trips byte-for-byte.
3. For every turn we re-hash the thinking blocks before replaying; a mismatch aborts the request with a clear error.
4. `redacted_thinking` blocks (empty text, encrypted payload) are preserved and placed first in the assistant message, as required.

---

## 10. Search & Universal Readability Extension

### 10.1 The stack (existing)

- **tantivy** for BM25 full-text over the Markdown projection ([tantivy GitHub](https://github.com/quickwit-oss/tantivy), [tantivy architecture](https://github.com/quickwit-oss/tantivy/blob/main/ARCHITECTURE.md)).
- **sqlite-vec** inside GRDB for dense-vector search ([sqlite-vec hybrid search writeup](https://alexgarcia.xyz/blog/2024/sqlite-vec-hybrid-search/index.html)).
- **SQLite FTS5** as a structural/fallback full-text index on artifact metadata and CSL bibliography fields.
- **RRF (Reciprocal Rank Fusion)** to combine lexical + semantic results ([sqlite-vec hybrid search](https://alexgarcia.xyz/blog/2024/sqlite-vec-hybrid-search/index.html), [liamca/sqlite-hybrid-search](https://github.com/liamca/sqlite-hybrid-search)).

### 10.2 Per-block indexing

Indexing unit is the **block**, not the document. Every block of every projection gets an entry with:
`{ artifact_id, block_epid, block_path, projection_kind, text, structural_path (h1>h2>p), tags, updated_at }`.

Tantivy gets the plain-text + structural-path tokens for BM25; sqlite-vec gets an embedding of the plain-text + a prepended structural header (2–3 parent headings, to recover section context cheaply — the "HyDE-lite" pattern for chunk embeddings).

### 10.3 Which projection to embed

**Embed the Markdown projection, not the JSON.** Markdown-trained LLMs and embedding models (text-embedding-3-large, BGE, E5, Qwen-embedding) all perform substantially better on Markdown text than on structured-JSON character sequences. The structural JSON is indexed *separately* for filter-only queries ("all headings containing X"), not for similarity.

### 10.4 Cross-format search

Because every block has a stable `_epid` and appears in every projection, a lexical hit on the Markdown projection immediately points to the HTML, JSON, PDF, DOCX renderings of the same block. Search-result UX: snippet from Markdown, "Open in → Document / Agent view / Plain text" actions.

### 10.5 Incremental indexing pipeline

Trigger: the save pipeline (§6.3) emits a `reindex` event after the manifest is committed. The indexer subscribes.

- Tantivy: deletions are by term (`term:"artifact_id:ULID"`), then re-add all blocks of the artifact. Tantivy's small-segment + merge model handles this cheaply ([tantivy arch](https://github.com/quickwit-oss/tantivy/blob/main/ARCHITECTURE.md), [Paul Masurel on indexing](https://fulmicoton.com/posts/behold-tantivy-part2/)). Commit batches every 2s.
- sqlite-vec: a reverse index (`artifact_id → block_rowids[]`) lets us delete+insert in one transaction.
- Graph edges: the Rust write path emits incremental `{add, remove}` edge events; we apply them directly, no full rebuild.

Race-freedom: the GRDB actor model + a single writer-thread invariant ensure no concurrent writes. Reads are free to run against the previous consistent snapshot.

### 10.6 Fine-grained reactivity

SolidJS-style signal propagation is not something we need on the JS side (we're not building a large reactive UI; the editor owns its own reactivity). Inside Rust, we use a simple pub-sub over slotmap keys: save → version bump → subscribers (tantivy writer, sqlite-vec writer, graph materializer, UI layer) wake up. This is sufficient for a 10-items/sec peak save rate.

---

## 11. Phased Implementation Roadmap

This roadmap extends, not replaces, the existing phased plan. Each phase lists deliverables, acceptance criteria, risks, dependencies, and rough scope.

### Phase 0 — Product decisions (done by this document)

**Deliverables.** Signed-off artifact taxonomy, graph ontology, IR (EPM-Schema v1), projection matrix, editor choice (Tiptap v3). **Acceptance.** This PRD merged into the master build spec; schema TOML checked in; licensing audit (Tiptap v3 is MIT core; some Pro extensions are commercial — we ship with Pro disabled). **Risk.** Decisions mutate during implementation. **Mitigation.** Every decision has a named "escape hatch" in the doc.

### Phase 1 — Artifact + typed graph substrate (foundational)

**Deliverables.** Rust `ArtifactHeader` + kind-specific structs; UniFFI bindings for Swift; GRDB tables + migrations for artifacts and edges; on-disk `vault/<kind>/<ulid>/` layout; the three-layer linking model in code (explicit, structural, semantic-stub); full-vault scan and incremental reindex; existing graph renderer extended with new node shapes and edge styles. **Acceptance.** Can create ProseNote (existing), create a "Document stub" (empty `.epdoc`), establish `derived_from` edge, view both in the graph with distinct shapes. **Risk.** Edge-type explosion. **Mitigation.** All edges emitted through a single `GraphWriter::add_edge(source, target, kind, layer)` API with runtime invariant checks.

**Scope:** ~3 weeks solo dev.

### Phase 2 — Raw Thoughts capture + timeline viewer

**Deliverables.** `runs/<ulid>/` layout; Rust RunRecorder with JSONL append + barrier-fsync; Anthropic thinking-block verbatim preservation (with round-trip test suite that includes unpaired-surrogate fixtures); OpenAI Responses API integration with `reasoning.encrypted_content` pass-through; MLX-Swift `<think>` splitter for Qwen3/Qwen3.5/Qwen3.6; Claude Managed Agents event-stream adapter; timeline viewer (read-only Metal DAG). **Acceptance.** Run an agent that uses Anthropic extended thinking with tools across 30 turns without a single signature error; run a Qwen local model and see thoughts separated from answers; inspect a Run in the timeline viewer and click through to the final Output. **Risk.** Thinking-block corruption; provider API churn. **Mitigation.** Verbatim storage tests; the `rig` crate isolates us from most churn; the adapter layer is small (<1k LoC).

**Scope:** ~4 weeks.

### Phase 3 — Document file type: `.epdoc` and EPM-Schema v1

**Deliverables.** `.epdoc` package UTI registered; EPM-Schema TOML + code-generated Rust + TS; schema validator; canonical JSON ↔ djot writer (Rust); HTML writer (Rust, mirror of Tiptap SSR); plain-text writer; patch history + snapshot rebuild; corruption recovery; manifest-last atomic-write ordering; F_FULLFSYNC / F_BARRIERFSYNC wrappers with benchmarks. **Acceptance.** Create a Document, save, kill the app mid-write 100 times, open — document either at N or N+1, never corrupt; the djot projection re-generates deterministically (byte-identical) across runs. **Risk.** Writer divergence. **Mitigation.** Property-based tests: `roundtrip(parse(write(doc))) ≈ doc` on a 100k-doc corpus.

**Scope:** ~5 weeks.

### Phase 4 — Hybrid document editor (Tiptap-in-WKWebView + Metal compositing)

**Deliverables.** Pre-warmed process pool; `epistemos://` URL scheme handler; editor bundle (Tiptap v3 + EPM-Schema + custom node-views for callout/figure/wiki-link/cite/annotation); JS ↔ Swift bridge (WKScriptMessageHandler, WKContentWorld isolation); IME/spellcheck/services/undo plumbing; IOSurface-cached thumbnails for graph previews; p95 keystroke latency instrument; accessibility audit (VoiceOver, keyboard-only navigation). **Acceptance.** Keystroke latency p95 ≤ 16ms on M2 Pro; editor opens in <80ms after pre-warm; VoiceOver can read and navigate a document by headings; Look Up / Share / Speech menus work; graph viewer shows live document thumbnails updated on save. **Risk.** WKWebView is a dynamic system; Safari updates change behavior. **Mitigation.** Pin `WKWebViewConfiguration` settings explicitly; nightly CI run on three macOS versions; keep a native TextKit 2 fallback path for power users who want Markdown-only.

**Scope:** ~6 weeks.

### Phase 5 — Serialization pipeline (export + import)

**Deliverables.** `prosemirror-docx` integration for fast DOCX; bundled Pandoc + Tectonic helper XPC for high-fidelity DOCX/PDF; ProseMirror ↔ Pandoc AST adapter; DOCX import → djot → EPM-Schema; PDF → text extraction via `PDFKit` (for Source artifacts); CSL-JSON citations; export manifest (which projections are current); auto-re-export on schema bump. **Acceptance.** Round-trip a 50-page test document (tables, footnotes, citations, code blocks) ProseMirror → DOCX → ProseMirror with structural fidelity ≥ 95% on a manual rubric; PDF export is camera-ready via Pandoc path. **Risk.** DOCX table hell. **Mitigation.** Two paths (fast + high-fidelity) so the user can pick.

**Scope:** ~4 weeks.

### Phase 6 — Agent integration

**Deliverables.** `rig`-based agent runtime wired to the artifact graph; tools (`read_artifact`, `edit_document`, `cite`, `create_document`, `list_artifacts`, `run_tool`); Claude Managed Agents provider (`managed-agents-2026-04-01`) with session-event streaming into `events.jsonl`; structured streaming edits via `editor.commands.streamContent`; LLM-emits-full-doc + server-side-diff pattern for multi-paragraph edits; agent view of a document = Markdown projection + block IDs as djot attributes; streaming generation writes to the active document without flicker. **Acceptance.** Agent produces a Document from a ProseNote, edges populated, thinking captured, no signature errors; streaming generation maintains cursor stability for the user; all agent mutations traceable back through `provenance` chain to the Run. **Risk.** Provider API churn (beta headers shift). **Mitigation.** Adapter layer; feature flags for each beta.

**Scope:** ~5 weeks.

### Phase 7 — Search, universal-readability polish, final UX

**Deliverables.** Per-block indexing across tantivy + sqlite-vec; RRF hybrid search; cross-projection result navigation; structural-path faceting; LOD tuning for promoted blocks in the graph; timeline viewer polish; settings for thinking-budget, reasoning-summary level, export profiles; key combos; onboarding flow that creates a starter vault. **Acceptance.** Hybrid search p95 < 150ms on a 100k-block vault; search result for a heading opens the right block in the doc view; promoted-block graph at high zoom stays at ≥ 90 FPS. **Risk.** Polish scope-creep. **Mitigation.** Hard-cut acceptance list; everything else goes post-v1.

**Scope:** ~4 weeks.

**Total solo-dev estimate: ~30 weeks.** No launch pressure; adjust as reality asserts itself.

---

## 12. Specific Technical Choices (pinned)

| Concern | Choice | Version / identifier |
|---|---|---|
| Rich editor framework | Tiptap v3 | `@tiptap/core` 3.x, `@tiptap/pm` 3.x, `@tiptap/extensions` 3.x |
| Editor runtime base | ProseMirror | via `@tiptap/pm` to guarantee version match |
| Canonical format | EPM-Schema v1 (ProseMirror JSON) | schema in `/schema/epm-v1.toml`, codegen checked in |
| Markdown flavor | Djot (preferred), CommonMark+GFM (compatible) | `jgm/djot-js` reference; mirrored Rust writer |
| Universal bridge | Pandoc + Pandoc AST JSON | Pandoc ≥ 3.2 bundled; `pandoc-types` JSON schema pinned to 1.23 |
| DOCX export (fast) | `prosemirror-docx` + `docx.js` | MIT |
| DOCX/PDF export (high-fidelity) | Pandoc → LaTeX → Tectonic | both bundled |
| CRDT (future) | Loro via `loro-prosemirror` (primary), Y.js `y-tiptap` fallback | Loro 1.x stable |
| Full-text index | tantivy | 0.22+ via Rust |
| Vector index | sqlite-vec inside GRDB | latest sqlite-vec |
| Hybrid fusion | Reciprocal Rank Fusion (k=60) | |
| Local inference | MLX-Swift | Qwen3.5-35B-A3B, Qwen3.5 4B |
| Cloud agent harness | Claude Managed Agents | beta header `managed-agents-2026-04-01` |
| Cloud reasoning | Anthropic extended thinking (verbatim), OpenAI Responses API with `reasoning.encrypted_content` | feature flags per model |
| Agent runtime (Rust) | `rig-core` | ≥ 0.10 |
| Persistence | GRDB + SQLite with WAL + fullfsync | `synchronous=FULL`, `journal_mode=WAL`, `fullfsync=1`, `checkpoint_fullfsync=1` |
| Atomic writes | temp + fsync + F_FULLFSYNC + rename + dir-fsync; F_BARRIERFSYNC on hot paths | |
| Graph substrate | Rust slotmap generational keys (existing) | unchanged |
| Graph renderer | Metal force-directed (existing) | extended with LOD + shapes/dashes |
| Bridge isolation | WKContentWorld.defaultClient | |
| URL scheme | `epistemos://` via WKURLSchemeHandler | |
| Process reuse | Single shared WKProcessPool, pre-warmed at launch | |
| Bundler | esbuild | ESM, tree-shaken, target Safari 18+ |

---

## 13. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Anthropic thinking-block corruption causing 400s mid-Run | High if careless | Critical | Byte-verbatim storage, round-trip fuzzer with surrogate fixtures, pre-replay hash check. |
| Tiptap v3 API churn or Pro-extension licensing change | Medium | Medium | Pin to exact versions; all Pro features are optional; open-core features only in v1. |
| ProseMirror ↔ djot round-trip drift | Medium | Medium | Projections are one-way canonical; external-edit import creates new version. Property-based tests on the 100k-doc corpus. |
| WKWebView startup/compositing regressions on macOS updates | Medium | Medium | CI matrix across OS versions; TextKit 2 fallback for Prose Notes; ability to export + open externally. |
| Bundle size growth | Medium | Low | Budget enforced in CI (400KB gzip); no React/Vue; tree-shake on every extension. |
| Graph explosion from block-level nodes | Medium | High (perf) | Block promotion only on reference; LOD in renderer; 15k-node soft cap with warnings. |
| Loro/Yjs migration later breaks stored docs | Low | Medium | `_key` on every node from day one; attrs are stable across versions. |
| Pandoc binary bundle size | Known | Low | Pandoc is ~60MB; Tectonic is ~100MB; acceptable for a pro app. XPC service, so they don't load unless export runs. |
| F_FULLFSYNC cost on save latency | Medium | Low | F_BARRIERFSYNC on hot path, F_FULLFSYNC only on commit boundaries and explicit save; benchmarks per write. |
| Custom URL scheme breaks service workers / modern web APIs | Low | Low | Scheme only serves assets + document payload; no service-worker dependency. |
| OpenAI reasoning summaries absent despite `summary:detailed` | Known | Low | Treat summaries as best-effort; encrypted_content is the reliable path for continuity; community reports confirm omission is normal ([community thread](https://community.openai.com/t/o3-model-in-api-often-omits-reasoning-summary-despite-reasoning-summary-detailed/1307301)). |
| DOCX fidelity gaps (complex tables, footnotes) | Medium | Low–Medium | Two-path export; Pandoc path closes most gaps. |
| Claude Managed Agents vendor lock-in | Medium | Medium | The runtime uses `rig` abstractions; Managed Agents is one provider among many; a local `rig` agent loop is always available. |

---

## 14. Open Questions (for future research)

1. **Live Metal compositing of editor content.** If WebKit ever ships a public API to expose WKWebView's backing IOSurface, we can move from cached thumbnails to live graph-node previews. Until then, cached snapshots are the pragmatic ceiling. Worth re-checking every 6 months.
2. **Loro vs Yjs once we need collab.** Benchmarks keep shifting ([Yjs vs Loro thread](https://discuss.yjs.dev/t/yjs-vs-loro-new-crdt-lib/2567)). Decide at the moment we add a second client; both bindings to ProseMirror exist.
3. **Pandoc AST as primary IR (instead of ProseMirror).** If Pandoc ever adds a first-class editable, attribute-bearing AST (Pandoc's `Span`/`Div` are close), the story becomes cleaner. Revisit when Pandoc ≥ 4.0 ships.
4. **Djot adoption trajectory.** If djot matures (Quarto-native, Obsidian-plugin, etc.), making it the *default* Markdown flavor (instead of CommonMark+GFM fallback) becomes safer.
5. **On-device reasoning summary for MLX models.** Our Qwen `<think>` extraction is lexical. When MLX exposes semantic APIs for separating reasoning (e.g., a typed event stream), migrate.
6. **Managed Agents multi-agent coordination (research preview).** Not GA. Once GA, revisit whether the cross-run graph should model `callable_agents` as explicit edges.
7. **Document-as-queryable-data APIs for agents.** Notion's breadth-first paginated JSON API ([Notion API blog](https://www.notion.com/blog/creating-the-notion-api)) is a good model. Worth formalizing a full query DSL (GraphQL? GROQ?) over the structured JSON projection when agent usage patterns stabilize.
8. **Semantic edge suggestion (Layer 3 linking).** The UX for "the system suggests this document elaborates on that concept, accept?" is not yet designed; defer until we have real vault traffic to train on.
9. **A unified query language across graph + FTS + vector + blocks.** Right now we have three indexes with three query surfaces. Long-term, a unified query language (inspired by Datalog over the graph, like Datomic/Logseq's approach) might unify them. Significant design work; deferred.
10. **Voice-first input for raw thoughts.** With Whisper/MLX voice models, ProseNotes could be dictated in real-time and streamed through the same pipeline. Natural extension, not MVP.

---

## 15. Closing note to Jojo

This plan has one invariant worth naming: **every "clever" capability is an additive projection over a boring, explicit, correct IR**. The ProseMirror JSON is not clever. The djot shadow is not clever. The per-block `_epid` is not clever. The labeled property graph is not clever. What's clever is that because each of those is boring and explicit, the projections — lossless cross-format readability, per-block graph addressing, agent structured-edit tools, universal search, Metal compositing — compose without lying to any consumer.

The parts that *are* hard — Anthropic signature preservation, keystroke latency inside a WebView, deterministic djot round-trips, graph node explosion under block-level addressing, atomic writes on APFS — have been faced in the open-source world already, and the working answers exist and are cited above. None of this is unprecedented. What's *new* is combining them with explicit typed artifacts and a typed graph ontology in a native macOS app, for cognition specifically.

Build Phase 1 first. Everything else is downstream.