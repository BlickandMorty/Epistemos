---
state: candidate-canon
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source_prompt: user request for more useful math plus portable note/editor systems and repo motifs, including Tolaria-style Markdown vaults and Tauri/non-Tauri markdown apps
status: architecture doctrine and source intake; no code import without license/setup/vendor gate, local benchmarks, and rollback
---

# Math And Portable Note Systems Intake - 2026-06-01

## Thesis

The practical breakthrough for Epistemos's note surface is mathematical:

> **Treat editing, sync, search, graph, review, and AI mutation as typed deltas
> over durable files, not as whole-document UI refreshes.**

The app should source-mine modern markdown editors and local-first systems, but
the portable gold is not their shell. Epistemos is macOS Opulent: Swift,
TextKit/AppKit, Metal, Rust, UAS, Eidos, AnswerPacket. Tauri apps are useful as
reference implementations and product pattern libraries, not as a replacement
runtime for the live macOS architecture.

The math to port is:

- editor transactions compose;
- derived views update by delta;
- CRDT merges are join operations with conflict witnesses;
- backlinks and graph views are maintained incrementally;
- syntax trees reparse only touched ranges;
- review scheduling follows a memory model, not a notification vibe;
- structured model output is parsed while decoding, not repaired after trust;
- summaries, sidecars, and cache state pay a rate-distortion budget.

## Local anchor

Epistemos already has the right spine:

| Local source | Existing pattern | Canonical implication |
|---|---|---|
| `docs/windows_research_handoff/06_notes_editor_and_textkit_patterns.md` | Persistent native editor instance, storage swapping, native scroll ownership, native undo, debounced sync, AI insertion safeguards. | Keep the macOS note editor native; source-mine web/Tauri editors for data structures and UX, not shell replacement. |
| `Epistemos/Sync/ReadableBlocksProjector.swift` | Pure projection from ProseMirror JSON into flat searchable blocks with title paths and O(N) behavior under caller debounce. | Promote projection discipline: canonical state -> derived search/readable views. |
| `Epistemos/Models/ProseMirrorMarkdownProjector.swift` | `.epdoc` keeps canonical ProseMirror JSON and regenerates lossy `shadow.md`. | Markdown can be a derived view for rich documents, while plain notes remain file-first Markdown. |
| `Epistemos/Engine/EpistemosSidecar.swift` | Sidecars are additive to markdown and never replace user-readable files. | Portable vault truth stays human-readable; machine cognition rides beside it. |
| `Epistemos/Engine/PromptCache.swift` | Prompt cache is a pure helper with explicit provider semantics and visible telemetry. | Cache, projection, and editor mutation should remain pure where possible and witnessed where user-visible. |

## Source intake translated into doctrine

| Source handle | Signal | Portability status | Epistemos route |
|---|---|---|---|
| Tolaria | Files-first Markdown, YAML frontmatter, Git-first vaults, offline/no-account workflow, types as lenses, local agent setup, 10k+ note use case. | AGPL-3.0-or-later; source-mine only unless a deliberate license strategy exists. | `GitVaultLineage`, `FrontmatterTypeLens`, agent-readable vault conventions, command-palette and history UX motifs. |
| Noteriv | Tauri 2 markdown editor with graph view, plugin API, Git/WebDAV sync, AI MCP, math, Mermaid, callouts, modes, split editor. | MIT; vendor/import only after license/setup review and local benchmark. | Portable feature checklist for note math, diagrams, graph/MCP, split-view, and per-file modes. |
| Lumark | Minimal Tauri local-first Markdown app, file tree plus editor, split preview, MIT. | MIT; source-mine for simplicity and footprint discipline. | Baseline for "do less, stay fast" note app ergonomics. |
| ProseMirror | Semantic content editor with custom schemas, transactions, collaborative editing, modular packages. | MIT; already influences `.epdoc` paths. | Treat rich docs as schema-bearing state, not HTML strings. |
| Tiptap | Headless ProseMirror-based editor with extension architecture and optional collaboration backend. | MIT core; paid/pro extensions separate. | Extension registry motifs and schema/node vocabulary for `.epdoc`, not a wholesale replacement for TextKit notes. |
| Milkdown | Plugin-driven WYSIWYG Markdown editor built on ProseMirror and remark. | MIT. | Study Markdown-to-schema plugin boundaries and live Markdown UX. |
| CodeMirror 6 | Modular state/view architecture; editor state, changes, and extensions are explicit modules. | MIT. | `EditorDeltaMonoid` and transaction-first code/markdown surfaces. |
| Lexical | Immutable state model, plugins, Yjs collaboration, JSON/Markdown/HTML serialization, accessibility/performance emphasis. | MIT. | Immutable editor-state snapshots, plugin isolation, and import/export discipline. |
| Tree-sitter | Incremental parser fast enough for per-keystroke parsing and robust under syntax errors. | MIT. | `IncrementalParseForest` for code blocks, Markdown structure, command grammar, and constrained output parsing. |
| Yjs / y-crdt | Shared CRDT types for offline collaboration, undo/redo, snapshots, and rich editor integrations. | Check exact crate/package license before import. | CRDT algebra for future collaborative sidecars and conflict witnesses. |
| Automerge | Local-first CRDT with Rust core, JS/WASM bindings, compact format, sync protocol, and document URLs. | MIT. | Candidate for `DeltaSemilatticeSync` and offline multi-device vault sidecars. |
| Differential Dataflow | Rust dataflow that maintains relational computations as inputs change. | MIT. | `DifferentialKnowledgeView` for backlinks, graph reachability, tags, review queues, and search projections. |
| Datafrog | Lightweight embedded Rust Datalog engine with explicit update iteration. | MIT/Apache-2.0. | Small in-process rule engine for local relation closure, not a runtime dependency until benchmarked. |
| FSRS | Open spaced-repetition scheduler with optimizer and multi-language implementations. | MIT. | `RetentionPotentialField` for note/concept resurfacing and graph-aware review. |
| Semantic entropy | Meaning-level uncertainty can detect confabulation better than token entropy alone. | Research source; implement only as evaluation/abstain gate. | `SemanticEntropyGate` for high-risk answers and note synthesis. |
| PICARD | Incremental parsing constrains autoregressive decoding token by token. | Research/source repo; license review before code import. | `ConstrainedMutationDecode` for note edits, query ASTs, and tool arguments. |
| HNSW | Hierarchical navigable small-world graphs support efficient approximate nearest-neighbor search. | Algorithmic source; existing local vector stack already uses ANN ideas. | Keep vector recall graph-shaped and measured; combine with lexical/graph/RRF rather than raw embedding trust. |
| Information bottleneck / rate-distortion | Useful compression preserves task-relevant information while paying distortion. | Mathematical lens, not direct product claim. | `RateDistortionSidecarBudget` for summaries, projections, cache state, and lossy markdown shadows. |

## L13-Candidate: Delta Projection Law

A knowledge app stays fast and honest when every visible view is maintained as
the smallest verified delta from a durable source.

```text
Cost(view_update | edit) =
  touched_editor_delta
  + dependent_projection_delta
  + verifier_or_visibility_delta

not

  whole_document
  + whole_graph
  + whole_index
  + whole_model_context
```

Promotion condition:

- source of truth is explicit: Markdown file, ProseMirror JSON, sidecar JSON,
  Git commit, CRDT document, or UAS object;
- every derived view names its source digest and projection version;
- editor changes are represented as typed transactions with undo/redo,
  selection, and scroll implications;
- graph/search/review projections update from deltas or declare a bounded
  rebuild reason;
- lossy projections carry an error/loss budget and never silently overwrite
  canonical state;
- imported source code passes license, setup, vendor, test, and rollback gates.

## New primitive set

### `EditorDeltaMonoid`

Composable editor changes.

```text
EditorDeltaMonoid {
  identity_delta
  compose(delta_a, delta_b)
  affected_ranges
  selection_before
  selection_after
  undo_inverse_or_reason_absent
  provenance
}
```

### `ReadableProjectionFunctor`

Derived views from canonical state.

```text
ReadableProjectionFunctor {
  source_kind: markdown | prosemirror_json | sidecar_json | crdt_doc
  source_digest
  projection_kind: search_blocks | shadow_markdown | plain_text | graph_edges
  projection_version
  loss_budget
  output_digest
}
```

### `DeltaSemilatticeSync`

CRDT/local-first merge discipline.

```text
DeltaSemilatticeSync {
  document_id
  actor_id
  operation_id
  partial_order_clock
  join(delta_a, delta_b)
  conflict_witness
  resolved_state_digest
}
```

Required algebra: join must be associative, commutative, and idempotent where
the chosen CRDT claims those properties.

### `DifferentialKnowledgeView`

Incrementally maintained graph/search/review relation.

```text
DifferentialKnowledgeView {
  input_relation
  delta_batch
  maintained_query
  output_delta
  recompute_escape_hatch
  latency_budget_ms
}
```

### `IncrementalParseForest`

Reusable parse state for Markdown, code blocks, command grammar, and
structured output.

```text
IncrementalParseForest {
  document_id
  grammar_id
  previous_tree_digest
  edit_ranges
  changed_ranges
  recovered_errors
  new_tree_digest
}
```

### `RetentionPotentialField`

FSRS-style memory scheduling over notes, blocks, concepts, and graph edges.

```text
RetentionPotentialField {
  item_id
  item_kind: note | block | concept | graph_edge | source_card
  stability
  difficulty
  retrievability
  last_reviewed_at
  next_review_at
  resurfacing_reason
}
```

### `SemanticEntropyGate`

Meaning-level uncertainty gate for answers and note synthesis.

```text
SemanticEntropyGate {
  prompt_digest
  candidate_generations
  semantic_clusters
  entropy_score
  abstain_or_verify_threshold
  verifier_route
}
```

### `ConstrainedMutationDecode`

Incremental parse validation for model-authored edits.

```text
ConstrainedMutationDecode {
  target_schema
  partial_output
  incremental_parse_state
  accepted_tokens
  rejected_tokens
  final_ast_or_rejection
}
```

### `GitVaultLineage`

Git as user-auditable vault history.

```text
GitVaultLineage {
  vault_root
  note_path
  frontmatter_digest
  body_digest
  sidecar_digest
  commit_id
  author
  diff_summary
  restore_ref
}
```

### `FrontmatterTypeLens`

Tolaria-style type as navigation aid, not hard schema.

```text
FrontmatterTypeLens {
  note_id
  type_label
  optional_fields
  missing_fields_are_allowed
  navigation_affinity
  agent_hint
}
```

### `RateDistortionSidecarBudget`

Loss accounting for summaries, projections, cache units, and shadows.

```text
RateDistortionSidecarBudget {
  source_digest
  compressed_artifact
  retained_task_information
  distortion_metric
  max_allowed_distortion
  verifier_caveat
}
```

## What to literally port versus only source-mine

| Category | Portability decision |
|---|---|
| MIT editor frameworks | Can be vendored only after setup/license review, dependency audit, local benchmark, and rollback. Prefer motifs unless there is a clear gap in current native code. |
| AGPL apps such as Tolaria | Source-mine product/architecture ideas only unless Epistemos intentionally accepts AGPL obligations or isolates a separate open-source companion. |
| Tauri app shells | Do not replace macOS Opulent. Use Tauri repos as cross-platform reference and feature checklist only. |
| Markdown vault conventions | Portable and highly aligned: files-first, YAML frontmatter, Git history, sidecar JSON, agent-readable docs. |
| CRDT libraries | Future Pro Research unless conflict fixtures, privacy model, sidecar compatibility, and large-note benchmarks pass. |
| Tree-sitter grammars | Strong candidate for code/Markdown/command parse lanes, but hot-path integration needs per-keystroke latency proof. |
| FSRS | Strong candidate for note/concept resurfacing because it is algorithmic, small, local, and user-visible. |
| Differential dataflow / Datalog | Strong candidate for graph/search/review derived views if it beats simpler incremental SQL/Rust projection. |

## Engineering route

1. **Source cards.** Store Tolaria, Noteriv, Lumark, ProseMirror, Tiptap,
   Milkdown, CodeMirror, Lexical, Tree-sitter, Automerge, Yjs/y-crdt,
   Differential Dataflow, Datafrog, FSRS, semantic entropy, PICARD, HNSW, and
   information bottleneck as source cards with license/status notes.
2. **No shell swap.** Keep Swift/AppKit/TextKit as the live note-editor lane.
   Study Tauri apps for product patterns and test fixtures.
3. **Delta schema.** Define `EditorDeltaMonoid` and
   `ReadableProjectionFunctor` over current note/editor fixtures.
4. **Projection tests.** Prove Markdown/ProseMirror/sidecar projections carry
   source digests, projection versions, and loss budgets.
5. **Incremental parse gate.** Use Tree-sitter only after a fixture proves
   changed-range behavior under rapid edits and long notes.
6. **Differential view gate.** Compare differential/Datalog backlink and graph
   updates against current projection/index paths.
7. **Review field gate.** Apply FSRS-style scheduling to note blocks and graph
   concepts with visible "why resurfaced" reasons.
8. **Structured mutation gate.** Use PICARD-style incremental parsing for note
   edit JSON, query ASTs, and tool arguments before accepting model-authored
   mutations.

## New falsifier targets

Backlog bundle:
`docs/falsifiers/F-MATH-NOTE-SYSTEMS-PORTABILITY-BUNDLE_2026_06_01.md`.

| Falsifier | Purpose |
|---|---|
| `F-EditorDeltaMonoid` | Proves editor transactions compose, preserve selection/scroll metadata, and carry undo inverse or reason absent. |
| `F-ProjectionFunctor-Digest` | Proves derived Markdown/search/plain/graph views bind source digest, projection version, loss budget, and output digest. |
| `F-MarkdownSidecar-Portability` | Proves notes remain readable as Markdown with additive sidecars and no proprietary-only required data. |
| `F-IncrementalParseForest` | Proves parse updates touch only changed ranges under long-note and rapid-edit fixtures. |
| `F-DifferentialKnowledgeView` | Proves backlinks/graph/review projections update by delta and beat full rebuild under held-out changes. |
| `F-CRDTVaultConflict` | Proves concurrent edits merge or emit conflict witnesses without silent data loss. |
| `F-GitVaultLineage` | Proves file/frontmatter/body/sidecar changes bind to commit history and restore refs. |
| `F-FSRSNoteReview` | Proves note/concept resurfacing improves recall or usefulness versus recency-only and random surfacing. |
| `F-SemanticEntropyGate` | Proves high semantic uncertainty routes to abstain/verify rather than unsupported answer confidence. |
| `F-ConstrainedMutationDecode` | Proves model-authored edits/tool args are accepted only when incremental parse/schema checks pass. |
| `F-LicensePortabilityGate` | Proves repo motifs are classified as importable, source-mine-only, or rejected before any code import. |

## Hard no-overclaim rules

- Do not replace the native macOS editor with a web editor because a Tauri repo
  looks convenient.
- Do not copy AGPL code into product paths without an explicit license strategy.
- Do not let Markdown shadows overwrite canonical rich state silently.
- Do not call a CRDT conflict-free until the chosen operation model and fixtures
  prove it for Epistemos's note shapes.
- Do not add per-keystroke parsing, indexing, graph, or model work without
  latency proof and debouncing/backpressure.
- Do not treat semantic entropy as truth. It is an uncertainty gate that routes
  to verification, citation, abstention, or follow-up.

## Source links

- Tolaria: `https://github.com/refactoringhq/tolaria`, `https://tolaria.md/`
- Noteriv: `https://github.com/thejacedev/Noteriv`
- Lumark: `https://www.lumark.app/`
- ProseMirror: `https://github.com/ProseMirror/prosemirror`
- Tiptap: `https://github.com/ueberdosis/tiptap`
- Milkdown: `https://github.com/Milkdown/milkdown`
- CodeMirror 6 guide: `https://codemirror.net/docs/guide/`
- Lexical: `https://github.com/facebook/lexical`
- Tree-sitter: `https://github.com/tree-sitter/tree-sitter`
- Yjs: `https://github.com/yjs/yjs`
- Automerge: `https://github.com/automerge/automerge`
- Differential Dataflow: `https://github.com/TimelyDataflow/differential-dataflow`
- Datafrog: `https://github.com/frankmcsherry/datafrog`
- FSRS: `https://github.com/open-spaced-repetition/fsrs4anki`, `https://github.com/open-spaced-repetition/py-fsrs`
- Semantic entropy: `https://www.nature.com/articles/s41586-024-07421-0`
- PICARD: `https://arxiv.org/abs/2109.05093`, `https://github.com/ServiceNow/picard`
- HNSW: `https://arxiv.org/abs/1603.09320`
- Information bottleneck: `https://www.princeton.edu/~wbialek/our_papers/tishby+al_99.pdf`

## Agent rule

Any PR touching note editor architecture, Markdown vault portability, `.epdoc`
projection, sidecars, ProseMirror/Tiptap/Milkdown/CodeMirror/Lexical motifs,
Tree-sitter parsing, CRDT/local-first sync, Git vault history, FSRS review,
Datalog/differential graph views, semantic entropy, constrained decoding, or
repo code import must cite this source and declare: source of truth,
transaction/delta model, projection digest, loss budget, license status,
latency budget, rollback, falsifier, RunEventLog, and AnswerPacket surface.
