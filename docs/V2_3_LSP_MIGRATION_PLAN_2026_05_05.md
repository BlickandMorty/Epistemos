# V2.3 LSP migration plan — 2026-05-05

Closing the last subprocess in the editor surface, per the post-recovery
V2 plan §V2.3. First slice (the protocol seam) shipped today; this doc
records the remaining work so the rest of V2.3 can land cleanly.

## Current state (after first slice)

- **`LSPTransport` protocol** (NEW) — `messages: AsyncStream<LSPMessage>`,
  `send(_:) async throws`, `shutdown() async`. Marked `Sendable` so
  actor-typed transports satisfy it. Lives in
  [Epistemos/Engine/LSPTransport.swift](Epistemos/Engine/LSPTransport.swift).
- **`LSPServerProcess` conforms** via empty extension — same actor,
  same surface, no behavior change. Production wiring unchanged.
- **`InProcessLSPTransport`** (NEW) — Swift actor stub that satisfies
  the protocol. Records every send in an audit log; emits
  `MethodNotFound` for every request. The drop-in zone for the future
  Rust transport.
- **`LSPClient` refactored** to depend on `any LSPTransport` instead
  of the concrete `LSPServerProcess`. Backward-compat
  `init(process:)` preserved. New `init(transport:)` for the in-process
  path. All 36 existing LSP tests + 6 new transport-seam tests pass.

The seam exists. The next slice plugs the Rust crate into the seam.

## What's left for V2.3 — the actual in-process Rust LSP

### Slice 2 — Add `tower-lsp` + `tree-sitter` Rust crates

Rough scope (~1-2 days):

1. **Workspace member.** Add a new crate
   `agent_core/lsp_runtime/` (sibling of cognitive_dag). Keep it
   separate from `agent_core::cognitive_dag` so the LSP-specific
   deps (`tower-lsp` ~0.20, `tree-sitter`, `tree-sitter-rust`,
   `tree-sitter-swift`) don't bleed into the core crate's compile
   times. The crate exposes a thin `LspKernel` struct + the FFI
   surface below.

2. **FFI surface.** Two new UniFFI exports in `bridge.rs`:
   - `lsp_send(envelope_json: String) -> Result<(), AgentErrorFFI>`
     — Swift forwards the encoded `LSPMessage` here; the kernel
     dispatches to the right handler (initialize, hover, definition,
     etc.).
   - `lsp_recv_blocking_with_timeout(timeout_ms: u32) -> Option<String>`
     — Swift polls this from a background task to receive
     server-pushed messages. Or — preferred — a callback-based FFI
     using UniFFI's `Callback<...>` interface so Swift gets push
     notifications without polling.
   - Single global `LspKernel` instance via `OnceLock`, matching the
     `provenance_ledger()` / `cognitive_dag_store()` pattern.

3. **Handlers.** Initial set:
   - `initialize` / `initialized` — return a minimal
     `ServerCapabilities` (textDocumentSync = full; hoverProvider =
     true; definitionProvider = true).
   - `textDocument/didOpen` / `didClose` / `didChange` — maintain
     an in-memory document cache keyed by URI.
   - `textDocument/hover` — tree-sitter parse the document, walk
     the AST to the cursor position, emit a typed hover string.
   - `textDocument/definition` — tree-sitter symbol lookup; return
     the same-file location for now (cross-file lookup arrives
     when the cognitive DAG starts mirroring symbol nodes).
   - `shutdown` / `exit` — drop in-memory state.

4. **Wire `RustLSPTransport` Swift class.** Same shape as
   `InProcessLSPTransport` but the `send` body calls `lsp_send` and
   the messages stream is fed by an FFI poll/callback loop.
   Replace `InProcessLSPTransport` use sites with this once the
   Rust crate is functional.

5. **Tests.** Round-trip tests: open a doc, hover at a known position,
   assert the hover string. Then end-to-end: an Epdoc editor view
   constructed against `RustLSPTransport` shows hover tooltips for
   Rust + Swift symbols without spawning a subprocess.

### Slice 3 — Delete `LSPServerProcess`

Once `RustLSPTransport` is the production wiring + the test suite
green for one CI cycle, the subprocess transport can be deleted:

- Delete `Epistemos/Engine/LSPServerProcess.swift`
- Delete `EpistemosTests/LSPServerProcessTests.swift`
- Drop the empty `extension LSPServerProcess: LSPTransport {}` in
  `LSPTransport.swift`
- Remove the backward-compat `init(process:)` shim from `LSPClient`
- Remove the `process` accessor from `LSPClient`

This is what the V2.3 sentence "closes last subprocess in editor
surface" literally means.

## Why the seam first

Three reasons:

1. **Risk reduction.** The seam refactor is small + reviewable. The
   tower-lsp slice adds substantial Rust crate dependencies + a new
   FFI surface; landing it in a separate slice keeps the diff focused.
2. **Test parity early.** Existing 36 LSP tests passed unchanged
   after the protocol refactor — a trustworthy regression baseline
   for the Rust slice.
3. **Doctrine alignment.** The seam matches the kernel doctrine §3
   pattern: every external dep enters via a Swift protocol, with
   the production binding chosen at construction time. A future
   slice that wants to A/B test subprocess vs. in-process could
   construct two `LSPClient` instances from the same call site.

## Doctrine notes

- The `agent_core::cognitive_dag` doctrine §4.4 says "no DAG state
  outside the kernel." The LSP runtime is a kernel peer, not a DAG
  consumer — it can hold its own document cache. Symbol nodes that
  the LSP discovers should land in the cognitive DAG via the
  `Skill` / `Tool` / `Procedure` mirror pattern (Phase 8.E), but
  that's V2.3 + V3 work.
- The `cognitive_dag::dispatch` auto-invoke pattern from
  Phase 8.E suggests an analog: when the LSP kernel emits hover
  results referencing a symbol, fire a `cognitive_dag::dispatch::
  on_lsp_symbol_observed(...)` so the symbol becomes a typed
  `Tool`-like node. Defer to V3.

## Verification

This first slice (commit forthcoming):
- Swift build: SUCCEEDED
- 42/42 LSP-area tests pass (36 existing + 6 new in
  `LSPTransportTests.swift`)
- Zero regression in any other test suite
