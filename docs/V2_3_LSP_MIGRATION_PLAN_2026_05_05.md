# V2.3 LSP migration status — 2026-05-05

Closing the last subprocess in the editor surface, per the post-recovery
V2 plan §V2.3. This document is the canonical status after the Codex
correction pass: the previous lightweight lifecycle kernel was not enough.
V2.3 now includes the actual in-process Rust semantic LSP path.

## Implemented

- **`LSPTransport` protocol** — `messages: AsyncStream<LSPMessage>`,
  `send(_:) async throws`, `shutdown() async`. The editor-facing client
  depends on this seam rather than a Foundation `Process`.
- **`RustLSPTransport` actor** — in-process Swift transport that encodes
  JSON-RPC messages, calls the Rust FFI, and feeds responses back through
  `AsyncStream`.
- **Rust `LspKernel`** — lives in `agent_core::lsp_runtime`, behind the
  `lsp-runtime` feature. It maintains lifecycle state, an in-memory
  document cache, and an outbound response queue.
- **`tower-lsp` payload types** — the Rust kernel emits canonical LSP
  initialize/hover/definition payloads through `tower_lsp::lsp_types`.
- **`tree-sitter` semantic handlers** — Rust and Swift grammars parse
  synced documents for hover and same-file definition lookup.
- **Document sync** — `textDocument/didOpen`, `didChange`, and `didClose`
  update the Rust-side cache with full-text sync.
- **Subprocess deletion** — `LSPServerProcess` and its tests are gone.
  The V2.3 sentence "closes last subprocess in editor surface" is true
  at the source level.

## Semantic scope

The shipped semantic LSP is intentionally narrow and honest:

- `initialize` returns `textDocumentSync = full`, `hoverProvider = true`,
  and `definitionProvider = true`.
- `textDocument/hover` parses the active document, resolves the symbol
  under the cursor, and prefers the matching same-file declaration snippet
  when available.
- `textDocument/definition` returns the same-file declaration location for
  Rust/Swift symbols discovered by tree-sitter.
- `shutdown` and `exit` follow the LSP lifecycle contract and clear
  transient document state.

This is not yet a full IDE server. Cross-file project indexing, scope-perfect
shadowing resolution, diagnostics, completion, references, rename, and symbol
mirroring into the cognitive DAG remain deferred.

## Deferred work

### Stage F — richer semantic LSP

- Build a persistent per-workspace symbol index for cross-file definition
  and references.
- Add scope-aware resolution so local shadowing and overloads do not collapse
  to first matching declaration.
- Add hover markdown structured by symbol kind rather than a generic snippet.
- Add diagnostics and completion once the editor route can consume them
  without adding hot-path allocations.

### V3 DAG bridge

- When the LSP kernel observes symbols, mirror them into the cognitive DAG
  through the Phase 8.E dispatch pattern. Do not write DAG state directly
  from the LSP runtime.
- Keep the LSP document cache as kernel-local transient state; durable symbol
  memory belongs in the DAG after the authority flip.

## Verification

- Rust focused semantic runtime:
  `cargo test --manifest-path agent_core/Cargo.toml --features lsp-runtime lsp_runtime`
- Swift focused LSP suite:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LSPMessageTests -only-testing:EpistemosTests/LSPClientTests -only-testing:EpistemosTests/LSPTransportTests -only-testing:EpistemosTests/RustLSPTransportTests`

Both suites must pass before calling the V2.3 correction canonical.
