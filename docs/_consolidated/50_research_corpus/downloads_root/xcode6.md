# Epistemos: Native macOS Notes + Code Workspace — Full Architecture Report

> **Target stack:** Swift 6 · Rust · UniFFI · Metal · MLX · AppKit/SwiftUI
> **Goal:** Replace the dominant portion of Obsidian + VS Code + AI wrapper workflows with a single native macOS hybrid app.

***

## 1. Executive Recommendation

**The winning architecture is a TextKit 2–powered AppKit editor core in Swift, with a Rust service layer owning the rope buffer, Tree-sitter incremental parsing, search index, file watcher, and LSP process supervision — bridged via UniFFI with strict async patterns.**

This beats every alternative because:

- **TextKit 2** (`NSTextLayoutManager` + `NSTextViewportLayoutController`) already provides viewport-only layout (never lays out off-screen text), fragment-based rendering extensibility, and full access to Apple's font/script/RTL pipeline — without writing a GPU text renderer from scratch like Zed's GPUI.[^1][^2]
- **Rust owns the compute-heavy, allocation-heavy, or concurrency-heavy work** (rope, parse, index, watcher, LSP supervisor) where Swift's GC pressure and ARC overhead genuinely matter at scale.
- **UniFFI async** provides clean Swift `async/await` bridging to Rust futures without unsafe glue code, avoiding the FFI-call-in-a-tight-loop anti-pattern.[^3][^4]
- **Metal is relevant but narrow:** text rendering should stay in CoreText/TextKit 2; Metal is only justified for the minimap or a custom gutter layer, not for text itself. Zed's entire custom GPUI renderer exists because they needed GPU-accelerated multiplayer cursors and cross-platform parity — constraints Epistemos does not share.[^2][^5]
- **MLX handles local AI inference** using Apple Silicon UMA; because CPU and GPU share the same physical memory on M-series chips, zero-copy embedding generation is achievable without staging buffers.[^6]

***

## 2. Detailed Architecture: Component Ownership

### 2.1 Swift Owns (UI Layer)

| Component | Owner | Rationale |
|---|---|---|
| Window / Scene management | Swift / AppKit | `NSWindowController`, `NSDocumentController` — native state restoration |
| Editor shell (`CodeEditorViewController`) | Swift / AppKit | AppKit `NSTextView`-backed, TextKit 2 stack |
| Gutter / line-number layer | Swift / CALayer | CALayer overlay pinned left of text container |
| Syntax highlight application | Swift | Applies `NSAttributedString` rendering attributes from token stream |
| File navigator sidebar | SwiftUI | `OutlineView`-backed or SwiftUI `List` with lazy tree model |
| Command palette / quick open | SwiftUI | Overlay sheet, driven by Rust search index results |
| Toolbar, inspector, breadcrumb | SwiftUI | Language badge, file path, symbol outline |
| AI chat / attachment UI | SwiftUI | Attachment builder delegates to Rust context extractor |
| MLX inference integration | Swift | `mlx-swift` API, local model pipeline |
| Document model shell | Swift | `NSDocument` subclasses: `NoteDocument`, `CodeFileDocument` |

### 2.2 Rust Owns (Intelligence Layer)

| Component | Owner | Rationale |
|---|---|---|
| Rope text buffer (`ropey`) | Rust | O(log n) edits and point translation; SIMD newline indexing[^7][^8] |
| Tree-sitter incremental parse | Rust | `tree-sitter` crate; parser runs in Rust, tokens sent to Swift |
| Syntax token stream | Rust | `tree-sitter-highlight` produces `HighlightEvent` spans |
| Full-text search index (`tantivy`) | Rust | Sub-millisecond query for code and notes[^9][^10] |
| File system watcher (`notify` crate) | Rust | Wraps FSEvents on macOS; debounce in Rust actor[^11] |
| Workspace metadata engine | Rust | Folder scan, file tree, `.gitignore` parsing |
| Symbol cache / outline | Rust | Tree-sitter-derived symbols, updated incrementally |
| LSP process supervisor | Rust | Spawn, restart, debounce, route messages per open workspace |
| AST code chunker (AI context) | Rust | Tree-sitter–based semantic chunk extractor[^12][^13] |
| Vector embedding store | Rust | Wraps `sqlite-vec` via rusqlite for local semantic search[^14][^15] |
| Trigram / BM25 index | Rust | `tantivy` BM25 for lexical search across notes + code[^10] |

### 2.3 Subprocess Workers (Isolated Processes)

| Process | Transport | Notes |
|---|---|---|
| `sourcekit-lsp` | stdio via `Process` + `Pipe` | Managed by Rust LSP supervisor; restart on crash[^16] |
| `rust-analyzer` | stdio | Managed by supervisor; per-workspace instance |
| `pyright` / `basedpyright` | stdio | |
| `typescript-language-server` | stdio | For JS/TS/TSX |
| `vscode-css-languageserver` | stdio | CSS/SCSS |
| `vscode-html-languageserver` | stdio | HTML |
| `yaml-language-server` | stdio | YAML |
| `taplo` | stdio | TOML |

All LSP workers communicate via stdio. The Rust supervisor owns process lifecycle, writes JSON-RPC to the worker's stdin, and routes responses back to Swift via UniFFI. **No language server binary is ever imported as a library** — subprocess isolation is non-negotiable for crash safety.

***

## 3. Editor Core Comparison

### 3.1 Option Analysis

#### TextKit 1 (`NSTextStorage` + `NSLayoutManager`)

- **Architecture:** three-object MVC (storage → layout manager → text container → text view)[^1]
- **Strength:** mature, well-documented, huge community of workarounds
- **Fatal weakness:** `NSLayoutManager` lays out the entire document eagerly on first render; for files >~10,000 lines, scroll latency becomes visually unacceptable
- **Verdict:** Do not use as the primary path for code files

#### TextKit 2 (`NSTextContentStorage` + `NSTextLayoutManager` + `NSTextViewportLayoutController`)

- **Architecture:** element-based MVC with viewport-gated layout[^1]
- Key insight: `NSTextViewportLayoutController` instructs `NSTextLayoutManager` to generate `NSTextLayoutFragment` objects **only for the visible region**. A 100,000-line file costs no more to open than a 100-line file in initial layout
- Rendering attributes (syntax colors) are injected via `NSTextContentStorageDelegate.textParagraphWith(range:)` **without modifying the backing store** — syntax highlighting is a pure display transformation[^1]
- Custom gutter: pin a CALayer to the left of the text container; enumerate visible line fragments via `NSTextViewportLayoutControllerDelegate` to stamp line numbers
- **Inline diagnostics:** inject a custom `NSTextLayoutFragment` subclass for annotated lines (same pattern as Apple's "BubbleLayoutFragment" sample)[^17]
- **Verdict:** ✅ Primary path. Use this.

#### SwiftUI + `CodeEditorView` (mchakravarty)

- Open-source SwiftUI wrapper over a TextKit 2 stack with token-based regex highlighting, line numbers, and inline messages[^18][^17]
- Provides minimap (macOS only), bracket matching, and message gutter out of the box
- **Limitation:** uses a custom regex tokenizer for syntax, not Tree-sitter — means no incremental parse, no scope injection for embedded languages
- **Verdict:** ✅ Excellent study reference and starting scaffold. Replace its tokenizer with the Rust Tree-sitter bridge. Keep its TextKit 2 layout architecture.

#### Custom GPU renderer (Metal / GPUI-style)

- Zed built GPUI because they needed cross-platform GPU rendering, sub-frame multiplayer cursor updates, and a UI framework they fully control[^5][^2]
- Zed's Metal pipeline complexity is documented: ProMotion synchronization, triple-buffering, `CADisplayLink` vs `CVDisplayLink` — all problems introduced by bypassing the system compositor[^2]
- Apple Silicon TextKit 2 with `CALayer`-backed fragments renders via CoreAnimation at 120fps on ProMotion displays without custom Metal code
- **Verdict:** ❌ Do not build a custom GPU text renderer. This is a 6–12-month engineering commitment that blocks every other feature.

#### AppKit `NSTextView` + Electron / WebView / Monaco

- **Verdict:** ❌ Explicitly out of scope. Violates the native performance contract.

### 3.2 Recommended Editor Stack (Concrete)

```
╔═══════════════════════════════════════════════════════════════╗
║  SwiftUI wrapper (CodeEditorRepresentable)                    ║
║    └─ NSViewControllerRepresentable → CodeEditorViewController ║
╠═══════════════════════════════════════════════════════════════╣
║  AppKit layer                                                 ║
║    NSScrollView                                               ║
║      └─ NSTextView (TextKit 2 stack)                          ║
║           NSTextContentStorage                                ║
║           NSTextLayoutManager                                 ║
║           NSTextViewportLayoutController                      ║
║    GutterView (CALayer, left of text container)               ║
║    MiniMapView (optional, CALayer, right side)                ║
╠═══════════════════════════════════════════════════════════════╣
║  Rust bridge (UniFFI)                                         ║
║    RopeBuffer — canonical text store                          ║
║    TokenStream — syntax highlight spans (incremental)         ║
║    SymbolOutline — document symbols list                      ║
╚═══════════════════════════════════════════════════════════════╝
```

**Text ownership:** The canonical text lives in the Rust `ropey` rope. `NSTextStorage` acts as a synchronized mirror for TextKit 2's layout. On every edit, the delta is sent to Rust; Rust re-parses the affected region and returns updated token spans. Swift applies those spans as rendering attributes in a `performEditingTransaction` block.

**Why dual storage?** TextKit 2 requires `NSTextContentStorage` to drive its layout. Rewriting it to talk directly to a Rope is possible but would require implementing the full `NSTextContentManager` protocol — multi-week work. Keeping a String-backed NSTextStorage as a read-only mirror is the practical path, with all mutation authority living in the Rust rope.

***

## 4. Language System Plan

### 4.1 Syntax Layer: Tree-sitter

Tree-sitter provides incremental parsing: on every edit, only the subtrees affected by the changed character range are re-parsed. A grammar for Swift, Rust, Python, JavaScript, TypeScript, HTML, CSS, YAML, TOML, BASH, and Markdown are all available as open-source C grammar modules.[^19][^20]

**Integration architecture:**

1. Tree-sitter C runtime is compiled into the Rust crate (`tree-sitter` crate v0.22+)
2. Language grammars are compiled as C and linked into the same Rust binary
3. On edit: `(byte_range, new_text)` crosses the UniFFI boundary; Rust calls `tree.edit()` then `parser.parse_with_old_tree()`
4. Rust runs `tree-sitter-highlight` with the language's `highlights.scm` query, producing `HighlightEvent` spans: `(start_byte, end_byte, highlight_name)`
5. Swift receives the span array, maps highlight names to `NSColor` from the active theme, and applies via `performEditingTransaction`

**Key advantage:** Tree-sitter highlight queries use scope names (`@keyword`, `@function.method`, `@string`, etc.) that map cleanly to a theme token table — the same model VS Code, Neovim, and Zed use. Language injection (JavaScript inside HTML `<script>` tags, CSS inside `<style>`) is supported by the injection query system natively.[^20]

**Do not reparse the whole file on every keystroke.** Tree-sitter's incremental edit is O(change_size + re-parse_region), typically sub-millisecond for typical edits. The full-file parse on open is the only expensive operation (amortized once).

**swift-tree-sitter** (`tree-sitter/swift-tree-sitter`) provides a Swift Package Manager–compatible wrapper of the tree-sitter C runtime. This can be used directly if you prefer Swift-native binding, but running the parse in Rust avoids marshaling raw tree objects across the FFI boundary and keeps parse work off the main thread naturally.[^21][^22][^23]

### 4.2 Semantic Layer: LSP Integration

The recommended architecture:

**Rust LSP Supervisor** (`lsp_supervisor` module in the Rust crate):
- Spawns each language server binary as a child `Process` with `stdin`/`stdout` pipes
- Maintains per-workspace, per-language server state
- Implements JSON-RPC framing (Content-Length header protocol)
- Routes requests/responses by message ID
- Implements exponential-backoff restart on crashes
- Debounces `textDocument/didChange` notifications (50–200 ms typical)
- Exposes a clean UniFFI async interface to Swift: `async fn getHover(uri, position) -> HoverResult`

**Why in Rust?** Process supervision and JSON-RPC routing involve tight concurrency (multiple concurrent requests, async I/O, reconnect loops). Rust's `tokio` async runtime handles this elegantly without main-thread stalls. Swift `Process`-based supervisors require careful GCD dispatch and are harder to make crash-tolerant.[^16]

**Transport: stdio is correct.** XPC is macOS-specific and requires code-signed XPC services — adds entitlement complexity for user-installed language servers. Unix domain sockets require socket setup. stdio is universally supported by every language server.[^24][^16]

#### Per-Language Server Recommendations

| Language | Server | Notes |
|---|---|---|
| Swift | `sourcekit-lsp` | Ships with Xcode; `xcrun sourcekit-lsp` binary; requires SPM or BSP workspace for full indexing[^24][^25] |
| Rust | `rust-analyzer` | Single binary, excellent stdio support; needs `Cargo.toml` workspace[^26] |
| Python | `basedpyright` | Open-source Pyright fork with better standalone support; no VS Code dependency |
| JS/TS | `typescript-language-server` | npm package; requires Node.js |
| HTML | `vscode-html-languageserver` | |
| CSS/SCSS | `vscode-css-languageserver` | |
| JSON | `vscode-json-languageserver` | |
| YAML | `yaml-language-server` | |
| TOML | `taplo` | Rust-native TOML language server |
| Markdown | Tree-sitter only | No LSP needed for v1; symbol outline via headers |
| Shell | `bash-language-server` | Optional v2 feature |

### 4.3 V1 Language Feature Priority

**V1 must have (synchronous feedback path):**
- Diagnostics (publish on file save + debounced on edit)
- Document symbols (outline panel)
- Syntax highlighting (Tree-sitter, all target languages)
- Formatting (on-save, LSP `textDocument/formatting`)

**V1 should have (on-demand):**
- Hover info
- Go to definition
- Find references

**V2 features:**
- Rename symbol
- Code actions / quick fixes
- Semantic tokens (merge with Tree-sitter tokens)
- Inlay hints

### 4.4 Merging Syntax and Semantic Tokens

Semantic tokens (LSP `textDocument/semanticTokens`) override Tree-sitter tokens for the same ranges. The merge algorithm:

1. Build a sorted interval tree from Tree-sitter spans
2. On semantic token response, for each semantic token range, overwrite the Tree-sitter token in that range
3. Re-render only the affected fragment via `NSTextLayoutManager.invalidateLayout(for:)`

Semantic tokens arrive asynchronously — they should never block the typing pipeline. Apply them as a background update.

***

## 5. Workspace / Search Plan

### 5.1 Document Model

```swift
// Swift document hierarchy
protocol EpistemosDocument: NSDocument {
    var documentID: UUID { get }
    var workspaceURL: URL? { get }
}

class NoteDocument: NSDocument, EpistemosDocument {
    // Existing note infrastructure
    // Markdown storage, attachment refs, frontmatter
}

class CodeFileDocument: NSDocument, EpistemosDocument {
    var language: Language  // detected from extension + content
    var editorState: CodeEditorState  // scroll pos, selections, fold state
    var lspWorkspace: LSPWorkspaceHandle?
    // Rope buffer lives in Rust; NSTextStorage mirrors it
}
```

`NSDocument` gives you: undo stack, dirty tracking, save/revert, autosave, version browsing, window restoration via `NSWindowRestoration`, and Recent Items integration — all for free.[^27][^28]

**Critical:** `CodeFileDocument` must **not** be a subclass of `NoteDocument`. They share the `EpistemosDocument` protocol for workspace metadata but have entirely separate view controllers, editor surfaces, and storage strategies.

### 5.2 Workspace Model

```
WorkspaceController
├── rootURL: URL          // opened folder
├── fileTree: FileNode    // Rust-built tree, FSEvents-maintained
├── noteVault: NoteIndex  // existing note index
├── codeIndex: CodeIndex  // Tantivy + symbol cache
├── lspSupervisor: LSPSupervisorHandle  // Rust
└── openDocuments: [UUID: EpistemosDocument]
```

The `WorkspaceController` is a singleton per opened folder (aligned with `NSWorkspace`-level semantics). Multiple workspaces (multi-root) are a V3 feature.

### 5.3 File Watching

The Rust `notify` crate wraps macOS `FSEvents` natively. The correct latency setting for a code editor is 50–100ms (fast enough to catch external saves, slow enough to batch rapid git operations). The watcher runs on a Rust `tokio` background thread. Events are debounced in Rust before crossing the UniFFI boundary to Swift, which then updates the file tree model on the main actor.[^11][^29]

**What to watch for:**
- External file modification → prompt to reload or auto-reload (user setting)
- File creation/deletion → update file tree
- `.gitignore` modification → re-evaluate ignore rules
- Build output directories (`.build/`, `target/`, `node_modules/`) → exclude from indexing via `.gitignore` rules

### 5.4 Search / Index Architecture

The unified search stack:

```
┌─────────────────────────────────────────────────────┐
│  Rust Search Engine (tantivy + sqlite-vec)           │
│                                                      │
│  tantivy index                                       │
│    schema: {path, content, language, last_modified}  │
│    fields: BM25 full-text over content               │
│    → filename prefix search (ngram field)            │
│    → content search (notes + code)                   │
│    → symbol name search (from tree-sitter outline)   │
│                                                      │
│  sqlite-vec store (rusqlite)                         │
│    table: embeddings(doc_id, chunk_id, vector[^384])  │
│    → semantic similarity for AI context retrieval    │
│    → hybrid search: BM25 + cosine, RRF fusion │
│                                                      │
│  Symbol cache (sled or SQLite)                       │
│    table: symbols(name, kind, path, line, col)       │
│    → workspace symbol search (⌘⇧O equivalent)       │
└─────────────────────────────────────────────────────┘
```

**Indexing strategy:**
1. On workspace open: crawl file tree in Rust background thread; respect `.gitignore`
2. For each file: parse with Tree-sitter to extract symbols; tokenize with tantivy analyzer; generate embeddings via MLX Swift (small model like `nomic-embed-text` or `all-MiniLM-L6-v2`)
3. Incremental updates: FSEvents → re-index changed files only
4. Never index: binary files, files >1MB (configurable), ignored directories

**Tantivy** is the right choice for full-text. It provides Lucene-quality BM25 over Rust with no external dependencies, and a developer on Reddit demonstrated bridging it to Swift iOS/macOS apps via UniFFI in a single weekend. It is dramatically faster than SQLite FTS5 for large corpora (millisecond queries on millions of paragraphs).[^30][^10][^9]

**sqlite-vec** for vector search: it stores vectors on-disk, reads in chunks during KNN, does not load the full index into memory. This is correct for an embedded app where the index must survive restarts without a server process.[^14][^31]

**Hybrid search (RRF):** combine BM25 rank and vector distance rank via Reciprocal Rank Fusion: \[ \text{score}(d) = \frac{w_\text{bm25}}{k + \text{rank}_\text{bm25}(d)} + \frac{w_\text{vec}}{k + \text{rank}_\text{vec}(d)} \] This is the exact formula used in production by Alex Garcia's sqlite-vec hybrid search demo.[^15][^32]

### 5.5 Note + Code Unification Strategy

Notes and code files live in the **same tantivy index** with a `doc_type` field (`note` vs `code`) and a `language` field. Quick open searches both. The file tree shows both. The AI context builder pulls from both. The only divergence is: code documents open a `CodeFileDocument` with a code editor surface; note documents open a `NoteDocument` with the existing note editor. The **router** (`DocumentRouter`) inspects UTType and file extension to dispatch to the correct document type.

***

## 6. AI Integration Plan

### 6.1 Code as First-Class Context

Code files attach to AI chat the same way notes do, via a unified `AttachmentContext` protocol:

```swift
protocol AttachmentContext {
    var displayName: String { get }
    var filePath: URL? { get }
    var language: Language? { get }
    func excerpt(maxTokens: Int) async throws -> ContextExcerpt
}

struct ContextExcerpt {
    let content: String
    let tokenEstimate: Int
    let metadata: [String: String]  // path, language, symbol, range
}
```

Concrete implementations:
- `NoteAttachment` — existing
- `CodeFileAttachment` — full file, AST-chunked if large
- `CodeSelectionAttachment` — current editor selection
- `CodeSymbolAttachment` — enclosing function/class extracted via Tree-sitter
- `WorkspaceQueryAttachment` — semantic search results from Rust index

### 6.2 Safe Excerpt Generation

**Token budget management** is the critical AI context problem. The strategy:

1. **Symbol-level chunking first:** Extract enclosing function/class using Tree-sitter. This is typically 20–200 lines and already semantically coherent. The CMU CAST paper confirms AST-based chunking outperforms fixed-window chunking by 1.2–3.3 points in retrieval precision.[^12]
2. **File-level fallback:** If the file is small (<500 lines), attach the whole file with a language header comment.
3. **Semantic retrieval:** For workspace-wide context, run a vector search query against the question, retrieve the top-k relevant chunks (AST-chunked), and assemble with metadata headers.
4. **Hard ceiling:** Never exceed the model's context window minus 20% for the response buffer. Implement a token estimator (4 chars ≈ 1 token for code).

**AST-based chunking in Rust:**
- Parse file with Tree-sitter
- Walk the tree to find top-level declarations (functions, classes, structs, impl blocks, etc.)
- Each top-level declaration → one chunk, with file path + symbol name + line range as metadata
- Merge adjacent small siblings until chunk size threshold
- Include preceding import/use statements in each chunk for standalone readability[^13][^33]

### 6.3 MLX Integration

MLX Swift runs local models (Qwen, Mistral, Phi-3) using Apple Silicon UMA — the same physical memory serves CPU and GPU, meaning embedding generation and inference have no staging-buffer overhead. The recommended pattern:[^6]

- **Embedding generation:** small model (e.g., `nomic-embed-text-v1.5`, 137M params, 384-dim vectors) runs as a background MLX task; results stored in sqlite-vec
- **Chat inference:** medium model (Qwen2.5-7B or equivalent) runs on demand; streamed token output dispatched to SwiftUI chat view via `AsyncStream`
- **Dual-backend:** when the user has an API key, route to cloud (Anthropic/OpenAI); otherwise fall back to local MLX model; user configures priority

### 6.4 AI Architecture Non-Goals for V1

- No AI code generation / edit agent (V3)
- No "generate tests" / "refactor code" features (V3)
- V1 AI = attach + reference + retrieval + chat reasoning over workspace content

***

## 7. Performance / Isolation Plan

### 7.1 Concurrency Model

```
Main Actor (Swift)
├── All UI updates
├── NSTextView editing callbacks
├── NSDocument lifecycle
├── Apply token spans (batch, never per-keystroke synchronously)
└── Dispatch to actors:

ParseActor (Swift, background serial)
├── Receives edit deltas from NSTextView delegate
├── Debounces (50ms) before crossing UniFFI to Rust
└── Sends token updates back to main actor as batch

IndexActor (Swift, background concurrent)
├── Triggers Rust index updates on file saves
└── Returns search results to Swift via UniFFI async

LSPActor (Swift, background serial per workspace)
├── Routes LSP requests via Rust supervisor
├── Cancels in-flight requests on new cursor position
└── Delivers results to main actor
```

**Swift 6 default actor isolation (`@MainActor` by default)** is the correct foundation for the UI module. The editor shell view controllers are `@MainActor`. Background work uses `nonisolated async` functions or dedicated actor types.[^34][^35]

### 7.2 UniFFI Boundary Design

**Crossing the UniFFI boundary is cheap but not free.** The Godot Rust project's benchmarks show raw FFI calls are in the nanosecond range for primitive types, but marshaling `String`/`Vec` involves allocation. Design the API to minimize per-keystroke crossings:

**Correct pattern — batch edit delta:**
```rust
// UniFFI exposed function
async fn process_edit(
    buffer_id: Uuid,
    byte_range: Range<usize>,
    new_text: String,
) -> Vec<TokenSpan>  // returns updated spans for changed region
```

**Incorrect pattern — per-character query:**
```rust
// Never do this from a keystroke handler:
fn get_token_at_offset(byte_offset: usize) -> TokenKind  // called per keystroke = wrong
```

**Rule:** UniFFI async calls should happen at most once per 50ms debounce cycle during active typing. Diagnostics and symbol updates can happen on file save only (0.1–5s cadence).

### 7.3 Typing Latency Budget

For a premium native macOS editor, the targets:

| Operation | Target | How |
|---|---|---|
| Keystroke → character on screen | < 16ms (1 frame @ 60fps) | TextKit 2 viewport layout; NSTextStorage update on main thread |
| Syntax highlight update | < 100ms after keystroke stop | 50ms debounce + Rust incremental parse (~1–5ms) + apply spans |
| Diagnostics appearance | < 2s after file save | LSP publish notification; apply as custom layout fragment |
| File open (10,000 lines) | < 200ms | TextKit 2 viewport layout; only visible ~40 lines laid out initially |
| File open (100,000 lines) | < 500ms | Same; lazy fragment generation |
| Quick open (filename search) | < 50ms | tantivy prefix query |
| Full-text search | < 200ms | tantivy BM25 query |
| Symbol search (workspace) | < 100ms | SQLite symbol cache query |

### 7.4 Large File Protection

- Files > 500KB: disable real-time Tree-sitter parsing; switch to regex-based fallback tokenizer
- Files > 2MB: display as plain text with a banner; offer "analyze with AI" to summarize
- Never call `NSTextStorage.string` synchronously on a large rope — use chunk iterators

### 7.5 Language Worker Crash Recovery

The Rust LSP supervisor implements:
1. **Process exit detection:** `tokio::process::Child.wait()` via select
2. **Exponential backoff restart:** 0s → 1s → 2s → 4s → 8s → 30s cap
3. **Per-workspace state reset:** clear pending request queue, re-initialize LSP connection on restart
4. **Diagnostic clearing:** on crash, clear all diagnostics to avoid stale red squiggles
5. **Swift notification:** publish a `LanguageServerStatusChange` event to the UI; show a small status indicator in the gutter

No Swift code should ever `fatalError` or crash because a language server died.[^36][^37][^38]

### 7.6 Apple Silicon UMA Design Implications

On M-series Macs, CPU and GPU share a unified memory pool. Implications:[^39][^40]

- **Embedding inference (MLX):** vectors computed on GPU live in the same memory as Swift objects — zero-copy handoff to sqlite-vec storage via pointer, not serialization
- **Metal for minimap only:** render the minimap as a Metal texture (the whole document scaled down) using the token color data from the parse pass. This is an O(document_size) Metal blit, not per-frame expensive
- **Do not use Metal for primary text rendering:** CoreText and TextKit 2 are already GPU-accelerated via CoreAnimation. The Zed GPUI approach is justified by their cross-platform constraints, not by Apple Silicon limitations[^2]
- **Memory pressure:** rust-analyzer for a large Rust workspace can consume 4–10GB. Implement a memory watchdog in the Rust supervisor; if a language server exceeds a configurable threshold, restart it and log the event[^41]

***

## 8. Open-Source Projects to Study

### Zed Editor (https://github.com/zed-industries/zed)

**What to steal:**
- Rope `SumTree` implementation: B-tree of 128-byte chunks; bitmask-indexed newline positions for branchless `offset_to_point` translation (57x speedup in microbenchmarks)[^8]
- Text coordinate system design: `DisplayPoint` (visual row/col) vs `Point` (buffer row/col) vs `Offset` (byte position) — all three needed for a correct editor[^42]
- Two-tier language system: Tree-sitter for syntax, LSP for semantic — exact same model recommended here[^43]
- GPUI 120fps Metal pipeline for reference (study their CADisplayLink / ProMotion tradeoffs, even if you don't replicate it)[^2]

**What to skip:**
- GPUI itself — a cross-platform GPU UI framework unnecessary for a macOS-native Swift app
- WebAssembly extension system — designed for a plugin marketplace; not a v1 concern[^44]
- Collaborative editing CRDT — not in scope

**Architectural lesson:** Zed's Language Server architecture uses the same supervisor pattern (spawn binary, stdio pipes, restart on crash) in Rust. Their language server crash bugs are a useful anti-pattern catalog.[^45][^37][^43][^36]

### CodeEdit (https://github.com/CodeEditApp/CodeEdit)

**What to steal:**
- Swift-native approach to `NSTextView` with TextKit 2 for code editing on macOS[^46][^47]
- Language detection and file type routing patterns
- Workspace and project model structure in Swift

**What to skip:**
- CodeEditKit extension architecture — complex and still evolving[^48]
- The project is heavily community-developed with inconsistent quality; extract patterns, don't fork

**Architectural lesson:** CodeEdit is the closest open-source example of a Swift-native macOS code editor. Study their window/document management and file browser implementation.

### CodeEditorView (https://github.com/mchakravarty/CodeEditorView)

**What to steal:**
- Clean TextKit 2 setup with viewport-based layout[^17]
- Line-number gutter implementation using `NSTextViewportLayoutControllerDelegate`
- Inline message (diagnostic) gutter architecture
- Theme and token-to-color mapping structure
- Minimap layer implementation (macOS-only)

**Architectural lesson:** This is the best compact example of a production-quality TextKit 2 code editor surface for macOS. The regex-based tokenizer should be **replaced** with the Rust Tree-sitter bridge, but the editor shell architecture is sound.[^17]

### Helix Editor (https://github.com/helix-editor/helix)

**What to steal:**
- Tree-sitter integration patterns: language loading, highlight query execution, injection grammar support[^49]
- `ropey`-based text buffer with Unicode-correct line/column tracking[^7]
- LSP client architecture in Rust: JSON-RPC framing, capability negotiation, diagnostic routing

**What to skip:**
- Terminal-based rendering model — entirely irrelevant
- Vim-modal editing model (unless you want it)

**Architectural lesson:** Helix is the purest Rust-native editor with full Tree-sitter + LSP integration. Its `helix-core` crate is an excellent model for the Rust intelligence layer.

### CotEditor (https://github.com/coteditor/CotEditor)

**What to steal:**
- Pure Swift, open-source macOS text editor; study their `NSTextView` performance optimizations, large file handling, and syntax highlight architecture[^50]
- NSDocument integration patterns for a document-based macOS app

### Lapce (https://github.com/lapce/lapce)

**What to steal:**
- Floem (Rust GUI) + Tree-sitter + LSP integration reference
- Rope-backed buffer patterns in Rust

**What to skip:**
- Lapce uses its own GPU rendering framework; not applicable to a Swift/AppKit app[^51]

### swift-tree-sitter (https://github.com/tree-sitter/swift-tree-sitter)

**What to steal:**
- Swift bindings to tree-sitter C runtime (SPM package)[^22][^23][^21]
- Grammar loading patterns

**Architectural lesson:** If parsing in Swift (not Rust) is preferred, `swift-tree-sitter` provides the full runtime API. The tradeoff: parsing on Swift side keeps tokens in-process but moves CPU-heavy work to a background `Task` with Swift concurrency rather than Rust async. Either approach is valid; the Rust path has better ecosystem tooling.

***

## 9. V1 / V2 / V3 Roadmap

### V1 — Foundation + Core Editor (Target: 10–14 weeks)

**Phase 1 — Document Architecture (2 weeks)**
- `EpistemosDocument` protocol; `CodeFileDocument` subclass
- `DocumentRouter`: UTType → document class mapping
- Update `NSDocumentController` subclass to handle code file types
- `WorkspaceController` skeleton; folder open/close
- Preserve all existing `NoteDocument` behavior — zero regression

**Phase 2 — Native Code Editor (3 weeks)**
- `CodeEditorViewController`: AppKit `NSTextView` with TextKit 2 stack
- `GutterLayer` (CALayer): line numbers, pinned to left edge
- Dirty state indicators, save/revert actions
- File reload on external change (FSEvents notification → dialog)
- Language badge header (language icon + file name in toolbar)
- Basic indentation behaviors, bracket matching (Swift-side regex bridge)

**Phase 3 — Tree-sitter Syntax (2 weeks)**
- Rust `EpistemosCore` crate: `ropey` rope + tree-sitter parse + `tree-sitter-highlight` span generation
- UniFFI scaffold with async `process_edit` and `initial_parse` functions
- Swift `ParseBridge`: debounce on `NSTextStorageDelegate`; send deltas to Rust; apply spans as rendering attributes
- Grammars: Swift, Rust, Python, JS/TS, HTML, CSS, JSON, YAML, TOML, Markdown, Shell

**Phase 4 — Workspace + File Tree (2 weeks)**
- Rust file tree builder (recursive scan, `.gitignore` ignore rules, `notify` watcher)
- Swift `FileNavigatorViewController`: SwiftUI `List` over tree model
- Quick open command palette: tantivy filename prefix search
- Recent files (persist in `UserDefaults` + `NSDocumentController` integration)

**Phase 5 — Basic Language Intelligence (3 weeks)**
- Rust `lsp_supervisor` module: spawn/restart/route for `sourcekit-lsp`, `rust-analyzer`
- Swift `LSPClient`: diagnostic overlay on gutter, hover popover, "jump to definition" action
- Document symbols → symbol outline panel (SwiftUI sidebar)
- Formatting on save (`textDocument/formatting`)

### V2 — Intelligence + Search + AI (Target: 8–10 weeks post-V1)

- Tantivy full-text index: notes + code in one index
- sqlite-vec semantic index: AST-chunked embeddings via MLX
- Hybrid search UI (quick open + dedicated search panel)
- AI code attachment: `CodeFileAttachment`, `CodeSelectionAttachment`, `CodeSymbolAttachment`
- Workspace-aware AI context: retrieve relevant chunks before chat
- Remaining LSP features: find references, rename, code actions
- `basedpyright`, TypeScript LS, CSS LS, YAML LS wired up

### V3 — Polish + Advanced Features

- Git integration: file status badges, inline diff surface (read-only)
- Multi-root workspace
- Semantic tokens merge with Tree-sitter tokens
- AI code generation / agentic workflows
- Symbol rename across workspace
- Local MLX model fine-tuning pipeline (stretch)
- Extension / plugin surface (out of scope for V1/V2)

***

## 10. Implementation Risks

### Risk 1: TextKit 2 API Instability
**Risk:** Apple has documented that accessing `textView.layoutManager` on a TextKit 2-configured text view permanently switches it to TextKit 1 compatibility mode. Third-party libraries that call `layoutManager` will silently degrade performance.[^1]
**Mitigation:** Audit every library that touches the text view. Never pass `NSTextView` to code you don't control without wrapping it. Keep all TextKit 2 API access inside `CodeEditorViewController`.

### Risk 2: NSTextStorage / Rope Sync Drift
**Risk:** If the Swift `NSTextStorage` (mirror) gets out of sync with the Rust rope (source of truth), syntax spans will be applied to wrong ranges, corrupting the editor state.
**Mitigation:** Implement a reconciliation check in debug builds (hash-compare NSTextStorage content vs. Rust rope content on every edit). Make the Rust rope the strict write authority — all mutations go through Rust first, then NSTextStorage is updated in the same transaction.

### Risk 3: Language Server Memory Explosions
**Risk:** `rust-analyzer` on large Rust workspaces can consume 4–40GB RAM on edge cases. This will degrade the entire system.[^41]
**Mitigation:** Memory watchdog in Rust supervisor (poll `/proc/self/status` equivalent via `sysinfo` crate or macOS `proc_info`). Hard limit: if any language server process exceeds 4GB, terminate and restart with a user notification. Provide a per-server memory limit setting.

### Risk 4: SourceKit-LSP Build System Dependency
**Risk:** `sourcekit-lsp` requires a `swift build` invocation to build the package index before it provides completions and go-to-definition. For Swift Package Manager projects, this works. For Xcode projects, it requires the `xcode-build-server` BSP bridge. Non-SPM Swift projects will have degraded intelligence.[^52][^53]
**Mitigation:** Document this limitation clearly; support SPM projects first in V1. Implement `xcode-build-server` integration in V2 for Xcode project support.

### Risk 5: UniFFI Async Overhead on Hot Paths
**Risk:** Async UniFFI calls involve Future polling, callback registration, and thread hops. If called too frequently (e.g., per keystroke), this adds latency.[^3]
**Mitigation:** Never call async UniFFI functions on the main actor in a keystroke-synchronous path. All Rust calls from the typing path go through `ParseActor` with a 50ms debounce. The typing path itself (NSTextStorage update) never waits for Rust.

### Risk 6: Tantivy Index Corruption
**Risk:** Tantivy uses an on-disk index that can corrupt on unclean shutdown.
**Mitigation:** Use a write-ahead log (Tantivy supports this); implement index validation on startup; rebuild index from files if validation fails (index is always rebuildable from source files — it is not the source of truth).

### Risk 7: Tree-sitter Grammar Quality
**Risk:** Community-maintained Tree-sitter grammars have varying quality. Some language grammars have poor error recovery, causing excessive re-parses or incorrect highlight spans on incomplete code.
**Mitigation:** Pin grammar versions. Test with intentionally malformed code. Tree-sitter's error recovery is designed for editors (it produces partial trees, not failures). Implement a per-file parse health metric; if error rate exceeds threshold, fall back to regex tokenizer for that file.[^19]

***

## 11. Benchmark / Testing Plan

### 11.1 Typing Latency Benchmark

Instrument with `CATransaction.flush()` timing and Instruments' "Core Animation" template:

| Test | Pass Threshold | Instrument |
|---|---|---|
| Single keystroke → pixel-on-screen | ≤ 16ms | Instruments > Animation Hitches |
| Typing at 100 WPM sustained 30s | 0 dropped frames (60fps) | Metal HUD frame graph |
| Syntax highlight after keystroke-stop | ≤ 100ms | Custom `os_signpost` span |
| Diagnostic display after file save | ≤ 2000ms | Custom `os_signpost` span |

### 11.2 File Open Benchmark

| File Size | Line Count | Pass Threshold |
|---|---|---|
| Small (10KB) | ~300 lines | ≤ 50ms |
| Medium (100KB) | ~3,000 lines | ≤ 150ms |
| Large (1MB) | ~30,000 lines | ≤ 500ms |
| Very large (5MB) | ~150,000 lines | ≤ 1000ms + large-file warning |

Measure: time from `NSDocument.read(from:ofType:)` to first visible frame.

### 11.3 Search Latency Benchmark

| Query Type | Dataset | Pass Threshold |
|---|---|---|
| Filename prefix search | 50,000 files | ≤ 30ms |
| Full-text content search | 50,000 files / 5M tokens | ≤ 200ms |
| Symbol name search | 100,000 symbols | ≤ 50ms |
| Semantic (vector) search | 50,000 chunks | ≤ 300ms |

### 11.4 Parse / Update Benchmark

| Operation | Input | Pass Threshold |
|---|---|---|
| Initial Tree-sitter parse | 10,000 line Swift file | ≤ 50ms |
| Incremental edit re-parse | Single-line change | ≤ 5ms |
| Full token span apply | 10,000 line file | ≤ 20ms (via rendering attribute batch) |

### 11.5 Manual Verification Checklist

- [ ] Code files (.swift, .rs, .py, .ts, .html, .css, .json, .yaml, .toml, .md, .sh) open as `CodeFileDocument`
- [ ] Note files (.md in note vault context) open as `NoteDocument`
- [ ] Existing note editor behavior unchanged
- [ ] Code editor shows correct syntax highlighting for each language
- [ ] Line numbers are correct on scroll for 10,000-line file
- [ ] Dirty state (unsaved indicator) appears on first edit, clears on save
- [ ] Save (⌘S) and Revert to Saved work correctly
- [ ] External file modification triggers reload prompt
- [ ] Language badge in toolbar reflects file language
- [ ] Diagnostics appear after save; clear after fix
- [ ] Jump to definition works for Swift and Rust files in SPM projects
- [ ] Hover info appears on hover for Swift and Rust
- [ ] Document symbols outline populates correctly
- [ ] File navigator shows folder tree; updates on file creation/deletion
- [ ] Quick open (⌘P) finds files across notes and code
- [ ] Full-text search returns results from both notes and code files
- [ ] AI chat can attach a code file; AI sees its content
- [ ] AI chat can attach the current selection with correct file context
- [ ] Language server crash does not crash the app; status indicator appears
- [ ] Language server auto-restarts after crash; diagnostics resume
- [ ] Multiple windows for different files work independently
- [ ] Window state restores on app relaunch

***

## Architecture Summary Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  SWIFT / APPKIT LAYER (UI + Document System)                         │
│                                                                      │
│  NSDocumentController ──► DocumentRouter                            │
│       │                        │                                    │
│       ▼                        ▼                                    │
│  NoteDocument         CodeFileDocument                               │
│  (existing)           └─► CodeEditorViewController                  │
│                               ├─ NSScrollView                       │
│                               │   └─ NSTextView (TextKit 2 stack)   │
│                               ├─ GutterLayer (CALayer)              │
│                               └─ MiniMapLayer (Metal, optional)     │
│                                                                      │
│  WorkspaceController ◄──► FileNavigatorViewController (SwiftUI)     │
│  LSPClient           ◄──► InspectorViewController (SwiftUI)         │
│  AIChatController    ◄──► ChatViewController (SwiftUI)              │
└─────────────────────┬───────────────────────────────────────────────┘
                      │ UniFFI async bridge
┌─────────────────────▼───────────────────────────────────────────────┐
│  RUST / EPISTEMOS-CORE LAYER (Intelligence + Storage)                │
│                                                                      │
│  RopeBuffer (ropey)        FileWatcher (notify / FSEvents)          │
│  TreeSitterParse (C lib)   WorkspaceIndex (file tree, .gitignore)   │
│  HighlightEngine            SymbolCache (SQLite)                    │
│  SearchIndex (tantivy)     VectorStore (sqlite-vec)                 │
│  LSPSupervisor (tokio)     ASTChunker (tree-sitter-derive)          │
│  CodeContextBuilder                                                  │
└─────────────────────┬───────────────────────────────────────────────┘
                      │ stdio (JSON-RPC / LSP)
┌─────────────────────▼───────────────────────────────────────────────┐
│  SUBPROCESS WORKERS (Isolated OS Processes)                          │
│                                                                      │
│  sourcekit-lsp    rust-analyzer    basedpyright                     │
│  typescript-ls    yaml-ls          taplo (TOML)                     │
│  vscode-html-ls   vscode-css-ls    (crash here = no app crash)      │
└─────────────────────────────────────────────────────────────────────┘
```

***

## Key Decisions Summary

| Decision | Choice | Rationale |
|---|---|---|
| Editor surface | TextKit 2 (`NSTextLayoutManager`) | Viewport-only layout, fragment extensibility, no GPU renderer needed |
| Text buffer | `ropey` in Rust | O(log n) edits, SIMD newline indexing, Helix/Zed-proven |
| Syntax parse | Tree-sitter in Rust | Incremental, multi-language, embedded, exact scope queries |
| Semantic intelligence | LSP via Rust supervisor | Process isolation, crash safety, universal language support |
| Full-text search | tantivy in Rust | Sub-ms BM25, no external process, UniFFI-bridgeable |
| Vector search | sqlite-vec | On-disk, no memory explosion, hybrid RRF with tantivy |
| File watching | `notify` crate wrapping FSEvents | Debounce in Rust, cross-workspace fan-out |
| AI code context | AST-chunked by Tree-sitter | Semantic boundaries, best retrieval quality |
| Metal usage | Minimap only | Narrow use case; primary text rendering stays CoreText/CA |
| LSP transport | stdio (all servers) | Universal, no entitlements, crash-isolated |

---

## References

1. [TextKit2: A Top-Down Approach - Flyingharley.dev](https://flyingharley.dev/posts/text-kit2-a-top-down-approach) - Implement with TextKit 2: Use TextKit 2's high-level, fragment-based APIs to achieve that goal. For ...

2. [Optimizing the Metal pipeline to maintain 120 FPS in GPUI - Zed](https://zed.dev/blog/120fps) - Zed feels smoother than ever with today's release of 0.121, thanks to a series of optimizations that...

3. [UniFFI Async FFI details](https://mozilla.github.io/uniffi-rs/latest/internals/async-ffi.html) - This document describes the low-level FFI details of UniFFI async calls. Check out Async overview fo...

4. [Async/Future support - The UniFFI user guide](https://mozilla.github.io/uniffi-rs/0.28/futures.html) - UniFFI supports exposing async Rust functions over the FFI. It can convert a Rust Future / async fn ...

5. [Text render performance question #24260 - GitHub](https://github.com/zed-industries/zed/discussions/24260) - Recently, I have going to find out the gpui-component table performance issues. And then I found tha...

6. [On-device ML research with MLX and Swift | Swift.org](https://swift.org/blog/mlx-swift/) - MLX is an array framework for machine learning research on Apple silicon. MLX is intended for resear...

7. [ropey - Rust - Docs.rs](https://docs.rs/ropey) - Ropey is a utf8 text rope for Rust. It is fast, robust, and can handle huge texts and memory-incoher...

8. [Rope Optimizations, Part 1 — Zed's Blog](https://zed.dev/blog/zed-decoded-rope-optimizations-part-1) - The 1.5hr companion video is the full pairing session in which Antonio and Thorsten first walk throu...

9. [Rust-Powered Full-Text Search w/Tantivy - marley.io](https://marley.io/posts/rust-fts/) - I built a full-text search engine in Rust using Tantivy to ingest and index Brazil's Diário Oficial ...

10. [Mastering Efficient Full-Text Search with Tantivy Library - MyScale](https://myscale.com/blog/mastering-efficient-full-text-search-tantivy-library/) - A code editor for crafting powerful search queries and a Rust environment are all you need to kickst...

11. [macOS File System Events (FSEvents) Store Database | Detection](https://insiderthreatmatrix.org/detections/DT108) - FSEvents is a macOS-specific API that allows applications to register for notifications of file syst...

12. [[PDF] CAST: Enhancing Code Retrieval-Augmented Generation](https://www.cs.cmu.edu/~sherryw/assets/pubs/2025-cast.pdf) - Our work uses the tree-sitter li- brary (Tree-sitter, 2025) for the AST tree parsing. AST-based Recu...

13. [Building code-chunk: AST Aware Code Chunking - Supermemory](https://supermemory.ai/blog/building-code-chunk-ast-aware-code-chunking/) - The core idea is elegant: Parse code into an AST (Abstract Syntax Tree); Use the tree structure to f...

14. [asg017/sqlite-vec - GitHub](https://github.com/asg017/sqlite-vec) - sqlite-vec. An extremely small, "fast enough" vector search SQLite extension that runs anywhere! A s...

15. [Hybrid full-text search and vector search with SQLite - Alex Garcia](https://alexgarcia.xyz/blog/2024/sqlite-vec-hybrid-search/index.html) - You can use SQLite's builtin full-text search (FTS5) extension and semantic search with sqlite-vec t...

16. [How to Use SourceKit-LSP — Feifan Zhou's Blog](https://feifan.blog/posts/how-to-use-sourcekit-lsp) - It uses the workspace/symbol LSP request to get all the symbols from a language server, which is Sou...

17. [CodeEditorView/Documentation/Overview.md at main - GitHub](https://github.com/mchakravarty/CodeEditorView/blob/main/Documentation/Overview.md) - CodeEditor is a SwiftUI view implementing a general-purpose code editor. It works on macOS (from 12....

18. [CodeEditorView - Swift Package Index](https://swiftpackageindex.com/mchakravarty/CodeEditorView) - The package CodeEditorView provides a SwiftUI view implementing a code editor for iOS, visionOS, and...

19. [TreeSitter - Swift Package Registry](https://swiftpackageregistry.com/tree-sitter/tree-sitter) - Tree-sitter is a parser generator tool and an incremental parsing library. It can build a concrete s...

20. [Syntax Highlighting - Tree-sitter](https://tree-sitter.github.io/tree-sitter/3-syntax-highlighting.html) - Tree-sitter has built-in support for syntax highlighting via the tree-sitter-highlight library, whic...

21. [swift-tree-sitter/Package.swift at main - GitHub](https://github.com/tree-sitter/swift-tree-sitter/blob/main/Package.swift) - Swift API for the tree-sitter incremental parsing system - swift-tree-sitter/Package.swift at main ·...

22. [TreeSitter - Swift Package Index](https://swiftpackageindex.com/tree-sitter/tree-sitter) - Tree-sitter is a parser generator tool and an incremental parsing library. It can build a concrete s...

23. [SwiftTreeSitter | Documentation - Swift Package Index](https://swiftpackageindex.com/tree-sitter/swift-tree-sitter/0.25.0/documentation/swifttreesitter) - SwiftTreeSitter provides a Swift interface to the tree-sitter incremental parsing system. You can us...

24. [swiftlang/sourcekit-lsp: Language Server Protocol ... - GitHub](https://github.com/swiftlang/sourcekit-lsp) - SourceKit-LSP is an implementation of the Language Server Protocol (LSP) for Swift and C-based langu...

25. [SourceKitLSP - Swift Package Registry](https://swiftpackageregistry.com/swiftlang/sourcekit-lsp) - SourceKit-LSP is an implementation of the Language Server Protocol (LSP) for Swift and C-based langu...

26. [Per project Language Server configuration is not respected #52465](https://github.com/zed-industries/zed/issues/52465) - Reproduction seems to be inconsistent. I update the reproduction once experiment a bit more. LSP use...

27. [restoreStateWithCoder: | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsdocument/restorestate(with:)?language=objc) - Discussion. This method is part of the window restoration system and is called at launch time to res...

28. [Developing a Document-Based App](https://developer.apple.com/documentation/AppKit/developing-a-document-based-app) - The NSDocument class provides most of the behavior for managing your document. In your subclass, you...

29. [File watcher problems on Mac #210422 - microsoft/vscode - GitHub](https://github.com/microsoft/vscode/issues/210422) - Yes, VS Code is using a 3rd party file watcher (https://github.com/parcel-bundler/watcher) that in t...

30. [I built a full-text search library for my iOS apps - Reddit](https://www.reddit.com/r/iOSProgramming/comments/1osbk3c/i_built_a_fulltext_search_library_for_my_ios_apps/) - I found this one Rust project called tantivy, which provides a low-level interface to building a sea...

31. [Introducing sqlite-vec v0.1.0: a vector search SQLite extension that ...](https://www.reddit.com/r/LocalLLaMA/comments/1ehlazq/introducing_sqlitevec_v010_a_vector_search_sqlite/) - A no-dependency SQLite extension written entirely in C that runs everywhere (MacOS, Linux, Windows, ...

32. [Hybrid full-text search and vector search with SQLite](https://simonwillison.net/2024/Oct/4/hybrid-full-text-search-and-vector-search-with-sqlite/) - Search results from both vector similarity and traditional full-text search are combined together. T...

33. [Chunk Twice, Retrieve Once: RAG Chunking Strategies Optimized ...](https://infohub.delltechnologies.com/es-es/p/chunk-twice-retrieve-once-rag-chunking-strategies-optimized-for-different-content-types/) - The sliding window approach for conversational data maintains context continuity by creating overlap...

34. [Embracing Swift concurrency - WWDC25 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2025/268/) - Join us to learn the core Swift concurrency concepts. Concurrency helps you improve app responsivene...

35. [Explore concurrency in SwiftUI - WWDC25 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2025/266/) - Explore how SwiftUI uses the main actor by default and offloads work to other actors. Learn how to i...

36. [Rust Language Server Dies (Yet Again!) · Issue #22749 - GitHub](https://github.com/zed-industries/zed/issues/22749) - The Rust language server dies for me after just 1-2 minutes of coding. The same happened months ago ...

37. [Zed crashes every time I trigger "restart language server" in a rust ...](https://github.com/zed-industries/zed/issues/38275) - Open a rust project; Ctrl + Shift + P, Restart language server; Zed crashes. Edit: I have tried zed ...

38. [Zed language servers stop working and fail to restart - Reddit](https://www.reddit.com/r/ZedEditor/comments/1rxyvxs/zed_language_servers_stop_working_and_fail_to/) - Upgrading to Biome 2.2.0 or later resolved it for me. Was getting this error in Zed: Language server...

39. [Explore the new system architecture of Apple silicon Macs - WWDC20](https://developer.apple.com/la/videos/play/wwdc2020/10686/) - Discover how Macs with Apple silicon will deliver modern advantages using Apple's System-on-Chip (So...

40. [Evaluating the Apple Silicon M-Series SoCs for HPC Performance ...](https://arxiv.org/html/2502.05317v1) - The unified memory architecture, shared between the CPU, GPU, and accelerators, aims to increase ban...

41. [Massive memory spike sometimes on a Rust project #8436 - GitHub](https://github.com/zed-industries/zed/issues/8436) - When it is triggered, memory usage is filled very quickly; Zed can reach 40 GB of memory consumption...

42. [Text Coordinate Systems — Zed's Blog](https://zed.dev/blog/zed-decoded-text-coordinate-systems) - From the Zed Blog: In this episode of Zed Decoded, Thorsten talks Nathan and Antonio about the text ...

43. [Configuring Languages | Language Server and Tree-sitter Config](https://zed.dev/docs/configuring-languages) - Configure language support in Zed with Tree-sitter for syntax highlighting and LSP for diagnostics, ...

44. [The possibility to add custom language servers in configuration only](https://github.com/zed-industries/zed/discussions/24092) - Zed extensions are compiled to WebAssembly, so: 1. Every LSP code change = Rust rebuild (30-40 secon...

45. [Rust linter intermittently stops working and error highlighting ...](https://github.com/zed-industries/zed/issues/39060) - The Rust language server/linter periodically stops providing error and warning highlights in Zed edi...

46. [️‍   I need this editor alive! · CodeEditApp · Discussion #2149 - GitHub](https://github.com/orgs/CodeEditApp/discussions/2149) - I need it really and want to replace such terrible things like vscode and zed (I really have reasons...

47. [Code Style · CodeEditApp/CodeEdit Wiki - GitHub](https://github.com/CodeEditApp/CodeEdit/wiki/Code-Style) - CodeEdit is entirely written using Swift . We decided to choose SwiftUI for most parts of the app wh...

48. [CodeEditKit is an interface between CodeEdit and extensions - GitHub](https://github.com/CodeEditApp/CodeEditKit) - CodeEditKit is a dynamic library which is shared between CodeEdit and its extensions. It allows them...

49. [Release 24.03 Highlights | Helix](https://helix-editor.com/news/release-24-03-highlights/) - Helix is a modal text editor with built-in support for multiple selections, Language Server Protocol...

50. [CotEditor -Text Editor for macOS](https://coteditor.com) - CotEditor is exactly made for macOS. It looks and behaves just as macOS applications should. Rapid L...

51. [Lapce | Hacker News](https://news.ycombinator.com/item?id=39421090) - That said, we had developed our own cross platform GUI toolkit called Floem, because as you may know...

52. [Extending functionality of Build Server Protocol with SourceKit-LSP](https://forums.swift.org/t/extending-functionality-of-build-server-protocol-with-sourcekit-lsp/74400) - SourceKit-LSP has been able to connect to a build server through the Build Server Protocol (BSP) to ...

53. [a build server protocol implementation for integrate xcode ... - GitHub](https://github.com/SolaWing/xcode-build-server) - Apple's sourcekit-lsp doesn't support xcode project. But I found it provides a build server protocol...

384. [We Have to Start Over: From Atom to Zed — Zed's Blog](https://zed.dev/blog/we-have-to-start-over) - Now we have this way of representing ropes — which is the fundamental text storage structure in Zed ...

