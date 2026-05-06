# Epistemos — Project Rules

## Architecture
- Swift 6.0 + Rust (UniFFI FFI) + Metal compute shaders
- GRDB for persistence, MLX-Swift for local inference
- Omega agent system replaced by in-process Rust living loop + MCP peer bridge (no subprocess; legacy agent subprocess removed 2026-05-05)
- ~252K lines Swift, ~71K lines Rust, 634 Swift files, 150 Rust files, 346 Swift test files (verified 2026-05-04)
- Rust agent_core crate owns: agentic loop, HTTP streaming, tool execution, session persistence, memory search, security, prompt caching, context compaction, skills + procedural memory + self-evolution + tool-call parsing (lives in `agent_core::agent_runtime`)
- Swift owns: UI rendering, MLX inference, macOS APIs (AXUIElement via AXorcist, ScreenCaptureKit, CGEvent), permission gate UI, MCP server hosting

## NON-NEGOTIABLE CONSTRAINTS
- NO SIDECAR. All inference AND orchestration in-process via Rust FFI or MLX-Swift. ONLY exception: oMLX bridge for oversized models. The legacy agent subprocess was removed 2026-05-05; orchestration now lives in `agent_core::agent_runtime` (Rust, in-process). LocalAgentPromptBuilder.swift and LocalAgentGatewayPolicy.swift in Epistemos/LocalAgent/ are the canonical local-agent path. Hermes namespace fully purged from code 2026-05-05 (LocalAgent prefix replaces it on the Swift side, Runtime prefix on the Rust side).
- REAL APIs ONLY. Every cloud endpoint verified against provider docs. No fake features.
- HONEST CAPABILITY GATING. Local models get fast/thinking/research. Cloud models get agent/liveAgent. Never fake agent capability for local models.
- RESEARCH-FIRST FOR EVERY TASK. Before code, docs, refactors, reroutes,
  reductions, or "simple" edits, search
  `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`, read the canonical local
  source it names, then verify current code/logs. Use a quick local pass for
  simple edits and a deeper pass for architecture/high-risk work; do not waste
  tokens reading unrelated docs. If local canon has no structured answer or
  current API/OS/model/package/App Store/security facts matter, run targeted web
  validation with primary/official sources. Web validates the local plan; it
  does not replace the user's research corpus. Apply the same rule to Claude,
  Codex, Kimi, and every delegated agent handoff. Use semantic expansion:
  "zero-copy" means UMA, shared buffers, IOSurface, in-process, single-binary,
  deterministic provenance, no hot-path subprocess, no tensor copies,
  direct/bare-metal path, and "as complex as a brain, as simple as an app, as
  fast as a jet."
- Zero test regressions against the 2,679-test suite.
- PRESERVE THINKING BLOCKS. When stop_reason is "tool_use", pass the ENTIRE content array back including thinking blocks + signatures. Dropping them kills the agent.
- STREAM EVERYTHING. Forward every token to the delegate immediately. No buffering.
- AGENT DECIDES TERMINATION. max_turns is a safety rail, not a schedule. Trust stop_reason == "end_turn".
- API keys in macOS Keychain (SecItemAdd/SecItemCopyMatching), NEVER UserDefaults.

## Code Standards
- Use @Observable, not ObservableObject
- Use Swift Testing (@Test, #expect) for new tests
- All inference on background actors — never block @MainActor
- Every unsafe block gets // SAFETY: comment
- No try!, no force-unwraps, no print() in production paths
- DispatchQueue.main.async in UniFFI callbacks, NEVER .sync (deadlock)

## Build & Test
- Build: xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
- Rust: cargo test --manifest-path agent_core/Cargo.toml
- Test: swift test
- Lint: swiftlint

## JS Bundle (Tiptap editor)
- Source: js-editor/ (esbuild bundle for the Epdoc WKWebView editor)
- Build: bash build-tiptap-bundle.sh — content-hash gated on package-lock.json
  so unchanged checkouts skip the npm install + bundle steps
- Output: bundle copied into Epistemos.app/Contents/Resources/Editor/ at
  build time. NEVER spawn npm at runtime — MAS sandbox + hardened runtime
  block subprocess execution from a notarized app
- Health check: Settings → "Editor bundle health" row reads bundle path
  size + last-build timestamp via EditorBundleHealthRow
- Setup: a missing npm prints actionable hints (brew install node / nvm).
  CI must `npm ci` before the Xcode build to keep the lock-hash gate honest

## Halo Shadow index (W8.4 / W8.7)
- Crate: epistemos-shadow (cdylib — see "Why dylib" in build-epistemos-shadow.sh)
- Backend: tantivy 0.22 BM25 + usearch 2.24 HNSW + RRF fusion (k=60)
- FFI: 7 entry points (insert/remove/search/flush/stats/open_at/free_string)
  bound from Swift via @_silgen_name in RustShadowFFIClient
- Open: AppBootstrap.initializeShadowBackendIfReady runs RustShadowFFIClient.openAt
  against `<vault>/.epcache/shadow` and ShadowVaultBootstrapper crawls
  `<vault>/notes/**/*.md` + `<vault>/chats/**/*.json`

## DO NOT
- Edit .xcodeproj directly — use xcodegen
- Commit model files (.gguf, .safetensors, .mlx)
- Import SDKs that don't exist (Anthropic has NO Swift SDK, OpenAI has NO Swift SDK)
- Use Ollama, llama-server, or any subprocess for INFERENCE OR ORCHESTRATION (the legacy agent subprocess was removed 2026-05-05; everything runs in-process now)
- Mark items done in PROGRESS.md until verification greps pass
- Buffer streaming responses — forward every token immediately
- Strip thinking blocks from message history
- Use Debug format ({:?}) for JSON serialization
- Use AsyncStream with .unbounded buffering — use .bufferingNewest(256)

## Swift SDK Reality (DO NOT HALLUCINATE)
- Anthropic: NO Swift SDK → raw URLSession
- OpenAI: NO Swift SDK → raw URLSession or community MacPaw/OpenAI
- Apple MLX: YES → mlx-swift, mlx-swift-lm
- MCP: YES → modelcontextprotocol/swift-sdk (v0.10.2, Swift 6.0+, macOS 14+)
- AXorcist: YES → steipete/AXorcist (fuzzy AX queries, MIT)
- Swift Subprocess: YES → swiftlang/swift-subprocess (Swift 6.1+)

## Provider Matrix (verified March 2026)
- Claude Opus 4.6/Sonnet 4.6: api.anthropic.com/v1/messages, thinking: adaptive, tools ✅, MCP ✅
- Claude Haiku 4.5: same endpoint, thinking: disabled, tools ✅, computer use ❌
- Perplexity Sonar Pro: api.perplexity.ai/chat/completions, no tools
- Local Qwen3.5: in-process MLX, grammar-constrained tools

## Detailed Docs (READ these, don't guess)
- Current sprint: docs/sprint-sessions/sprint-omega-1-foundation.md
- Agent progress: docs/AGENT_PROGRESS.md
- Agent architecture: docs/agent-system/AGENT_ARCHITECTURE.md
- Legacy agent removal archive: docs/_archive/hermes-removal-2026-05-05/ (research + parity report from when the subprocess was still planned)
- Full build spec: docs/EPISTEMOS_FUSED_v3.md
- Deep analysis: docs/epistemos-deep-analysis.md

## FILE MAP — Agent System
### Rust agent_core crate
- Loop: agent_core/src/agent_loop.rs
- Bridge: agent_core/src/bridge.rs
- Claude SSE: agent_core/src/providers/claude.rs
- Perplexity: agent_core/src/providers/perplexity.rs
- Tools: agent_core/src/tools/registry.rs
- Think tool: agent_core/src/tools/think.rs
- Security: agent_core/src/security.rs
- Prompt caching: agent_core/src/prompt_caching.rs
- Compaction: agent_core/src/compaction.rs
- Vault: agent_core/src/storage/vault.rs
- Routing: agent_core/src/routing.rs
- Session: agent_core/src/session.rs

### Rust agent_core — V2.1 Cognitive DAG (Phase 8.A-8.G)
- Schema (10 NodeKind + 10 EdgeKind): agent_core/src/cognitive_dag/node.rs + edge.rs
- Storage trait + InMemoryDagStore (capability-bound put_edge, CD-005): agent_core/src/cognitive_dag/storage.rs
- Merkle root: agent_core/src/cognitive_dag/merkle.rs
- Resonance propagation (DerivesFrom + Contradicts walks, TruthCache): agent_core/src/cognitive_dag/resonance.rs
- Macaroon-style capabilities (orphan until Phase 8.H wires them into dispatch): agent_core/src/cognitive_dag/macaroons.rs
- Companion lifecycle (Companion + Deforms edges + LoRA estimates): agent_core/src/cognitive_dag/companions.rs
- DagMirror trait + 4 mirrors (Skills/Procedural/Provenance/Companion): agent_core/src/cognitive_dag/migration.rs
- Auto-invoke dispatch (sentinel-cap registered on first use): agent_core/src/cognitive_dag/dispatch.rs

### Rust agent_core — Provenance ledger (Phase 1 + Phase 8.F replay)
- ClaimLedger (in-memory, retraction propagation): agent_core/src/provenance/ledger.rs
- ReplayBundle + LedgerSnapshot + DagSnapshot embedding (schema v1 / v2): agent_core/src/provenance/replay.rs

### Rust agent_core — In-process LSP runtime (V2.3)
- LspKernel (initialize/didOpen/didChange/hover/definition + tree-sitter Rust/Swift): agent_core/src/lsp_runtime/mod.rs
- Feature-gated behind `lsp-runtime`; FFI via bridge.rs `lsp_send_message_json` + `lsp_poll_response_json`

### Rust agent_core — In-process agent runtime (renamed from hermes/ 2026-05-05; Hermes namespace fully purged)
- Skills + procedural memory + self-evolution + tool-call parsing: agent_core/src/agent_runtime/

### Rust agent_core — CLI binaries
- `epistemos_trace verify | verify-replay`: agent_core/src/bin/epistemos_trace.rs (Phase 1 ledger integrity + Phase 8.F DAG merkle parity)
- `epistemos_doctrine_lint`: agent_core/src/bin/epistemos_doctrine_lint.rs (cognitive DAG doctrine §5.1-§5.4 gates; CI-enforced)

### Rust agent_core — Examples (CI fixtures)
- Sample .epbundle generator for verify-replay CI gate: agent_core/examples/generate_sample_epbundle.rs

### Rust omega-mcp crate
- Dispatcher: omega-mcp/src/dispatcher.rs
- Catalog: omega-mcp/src/catalog.rs
- Vault ops: omega-mcp/src/vault.rs

### Swift Agent Bridge
- Streaming delegate: Epistemos/Bridge/StreamingDelegate.swift
- Agent ViewModel: Epistemos/ViewModels/AgentViewModel.swift
- MCP Bridge: Epistemos/Omega/MCPBridge.swift

### Swift Local Agent
- Local-agent prompt builder: Epistemos/LocalAgent/LocalAgentPromptBuilder.swift
- Grammar DSL: Epistemos/LocalAgent/LocalToolGrammar.swift
- Local loop: Epistemos/LocalAgent/LocalAgentLoop.swift
- Router: Epistemos/LocalAgent/ConfidenceRouter.swift

### Swift Note Editor
- Editor shell: Epistemos/Views/Notes/ProseEditorView.swift
- TextKit bridge: Epistemos/Views/Notes/ProseEditorRepresentable2.swift
- NSTextView subclass: Epistemos/Views/Notes/ProseTextView2.swift

### Swift LSP (V2.3 — in-process Rust transport)
- LSPTransport protocol seam: Epistemos/Engine/LSPTransport.swift
- RustLSPTransport (production; drives in-process Rust LspKernel via FFI): Epistemos/Engine/RustLSPTransport.swift
- LSPClient + LSPMessage codec: Epistemos/Engine/LSPClient.swift + LSPMessage.swift
- (LSPServerProcess subprocess transport DELETED 2026-05-05 in V2.3 close-out — see commit 813c15dd)

### Swift Computer Use
- Device agent: Epistemos/Omega/Inference/DeviceAgentService.swift
- Visual verify: Epistemos/Omega/Vision/VisualVerifyLoop.swift
- Screen capture: Epistemos/Omega/Vision/ScreenCaptureService.swift
- AX fusion: Epistemos/Omega/Vision/Screen2AXFusion.swift

### Subprocess Hardening (security 2026-04-28)
- `agent_core/src/security.rs` — `harden_cli_subprocess(&mut Command)` +
  `harden_cli_subprocess_extending(cmd, &[extra_var_names])` +
  `harden_cli_subprocess_std()` (sync variant). Helpers do
  `env_clear` + canonical 10-var allowlist (PATH, HOME, USER, LOGNAME,
  TMPDIR, LANG, LC_ALL, LC_CTYPE, TERM, TZ) + 24-vector denylist
  (LD_PRELOAD, all DYLD_*, MallocStackLogging family, NODE_OPTIONS
  family, PYTHONPATH/HOME/STARTUP, RUBYOPT/RUBYLIB, PERL5OPT/PERL5LIB) +
  `kill_on_drop(true)` + `process_group(0)` on Unix.
- 4 tests including a real subprocess that proves LD_PRELOAD + DEBUG
  don't leak through the hardening, plus PATH preservation +
  allowlist/denylist disjoint invariant + doctrine-named-vector
  presence check.
- Applied to 10 subprocess spawn sites across agent_core: cli_passthrough
  (claude/codex/gemini/kimi), mcp/client (arbitrary user MCP servers),
  code_execution (LLM Python/Node/Ruby/Perl/shell), registry bash,
  browser (with `extending` allowlist for HTTP_PROXY family +
  FAKE_BROWSER_LOG fixture), tirith, apple/imessage osascript, media
  `say`. terminal.rs already had its own equivalent hardening pre-session.

### Rust Provenance Ledger + ReplayBundle + epistemos-trace (Phase 1 — 2026-04-28)
- `agent_core/src/provenance/ledger.rs` — `ClaimLedger` with retraction propagation
  (bounded-walk depth ≤ `MAX_RETRACTION_WALK_DEPTH = 16`, deterministic BTreeSet
  output, sorted-BFS for byte-equal `RetractionReport`, `ClaimLedger::snapshot()`
  for ReplayBundle export)
- `agent_core/src/provenance/replay.rs` — `ReplayBundle` + `LedgerSnapshot` +
  `ClaimDerivation` + `ClaimEvidenceLink`. BLAKE3 integrity hash over canonical
  JSON. `to_epbundle_bytes()` / `from_epbundle_bytes()` for `.epbundle` IO.
- `agent_core/src/provenance/mod.rs` — module entry (re-exports the public types)
- `agent_core/src/bin/epistemos_trace.rs` — Phase-1 / parallel-track CLI
  (`epistemos-trace verify <path>`). 5 typed exit codes: 0 success, 1 usage,
  2 io, 3 parse, 4 integrity-mismatch.
- Tests: 10 ledger unit tests + 7 ReplayBundle unit tests + 6 e2e CLI
  integration tests (`agent_core/tests/epistemos_trace_e2e.rs`). 758 lib +
  13 integration = 771 total agent_core tests, zero regressions.
- Phase-1 scope is deliberately minimal per `docs/plan/04_PHASES.md`:
  one Claim type, one Evidence type, four ClaimStatus states. Multi-Claim
  taxonomy + GRDB persistence + Swift mirror land in Phase 2+.

### Swift RRF Cross-Index Fusion (Phases 0-7 — 2026-04-28)
- Fusion query + flag + types + metrics: Epistemos/Sync/RRFFusionQuery.swift
  (`Phase3FusionConsts.K_RRF=60` single-source-of-truth Swift mirror;
   k=60 source-of-truth: epistemos-shadow/src/backend/rrf.rs:22 RRF_K_DEFAULT;
   `RRFFusionFlags.isEnabled` reads env-var `EPISTEMOS_RRF_FUSION_V1`;
   `FusionWeights` Sendable struct; `FusedResult` Sendable struct (with snippet);
   `RRFFusionQuery.sql` with 3 CTEs + UNION ALL + GROUP BY rollup +
   recency exp() boost + snippet projection;
   `SearchFusionMetrics` thread-safe ring buffer for Phase 6 observability)
- Fusion API: Epistemos/Sync/SearchIndexService.swift `fusedSearch`/`fusedSearchAsync`
  (nonisolated public; `Sig.storage.beginInterval("fused_search", ...)` signpost;
   instrumented with `SearchFusionMetrics.shared.record(latencyMs:results:)`)
- Phase-2 tests: EpistemosTests/RRFFusionQueryTests.swift (7 critical-invariant
   tests: K_RRF parity probe of Rust source, bm25 sign assertion,
   EXPLAIN `VIRTUAL TABLE INDEX \d+:M\d+` regex gate, single-source,
   cross-source consensus, empty corpus, recency decay)
- Phase-5 tests: EpistemosTests/SearchIndexServiceFusionTests.swift
  (9 real-DB integration tests against file-backed `SearchIndexService`)
- Phase-1 schema: `ReadableBlocksIndex.installVaultIDColumn` +
   migration key `v3_1_readable_blocks_vault_id` in Epistemos/Sync/ReadableBlocksIndex.swift
- Phase-4 wiring: VaultSyncService.searchFull/searchFullAsync/searchIndex
  (flag-aware), QueryRuntime.fullText (flag-aware fused path); breadcrumbs
  in MeaningAnchorService.swift + IMessageDriverService.swift
- Phase-6 observability UI: Epistemos/Views/Settings/SearchFusionHealthRow.swift
  (mirrors EditorBundleHealthRow shape; 1 Hz polling refresh; flag state +
   last-query latency + p95 + per-source hits + last error). Wired into
   SettingsView General > "Diagnostics" section alongside EditorBundleHealthRow
- Living design doc: docs/RRF_FUSION_DESIGN.md (§8 EXPLAIN plan,
   §14 Phase 4 wiring status, §10 phase status table)
- FFI bridge design (deferred Sites 4+5): docs/RRF_FUSION_FFI_BRIDGE_DESIGN.md
- Mission spec: docs/RRF_FUSION_PROMPT.md (verbatim user brief)

### Rust Memory-Pressure + Bounded Caches (perf 2026-04-28)
- Tantivy writer heap cut 50 MB → 15 MB at both
  `epistemos-shadow/src/backend/lexical_index.rs:42` (`WRITER_HEAP_BYTES`)
  and `agent_core/src/storage/vault.rs:160` — saves ~70 MB resident on idle.
- ShmPool TTL eviction in `agent_core/src/shared_memory.rs`:
  `TrackedSegment { name, created_at, byte_length }`,
  `ShmPool::evict_stale(max_age: Duration) -> (count, bytes)`,
  `ShmPool::evict_oldest_n(n) -> (count, bytes)`,
  `ShmPool::total_bytes() -> usize`, `DEFAULT_SHM_TTL = 300s`.
  Bounds long-running-process growth on the 16 MB-per-segment pool.
- Session prune in `agent_core/src/session.rs`:
  `GlobalSessions::prune_finished(max_age: Duration) -> usize` drops
  Completed/Failed/Terminated/Rescheduled entries past threshold;
  `GlobalSessions::registry_size() -> usize`. Skips sessions with a
  `SessionFolder` (those finalize via `SessionGuard::drop`).
- FFI entry in `agent_core/src/bridge.rs`:
  `respond_to_memory_pressure(level: u8) -> MemoryPressureReliefFFI {
   segments_evicted, segment_bytes_freed, sessions_pruned }`.
  Level 1 (warning): evict_stale(60s) + prune_finished(5min);
  level 2 (critical): cleanup_all + prune_finished(0). Single-call
  hook for the Swift `DispatchSourceMemoryPressure` handler.
- JSON-compaction of FFI + tool result paths: `to_string_pretty` →
  `to_string` in 7 sites (bridge.rs FFI returns ×3, tools/file_ops,
  web_fetch, memory, skills, workspace_search ×2, providers/perplexity).
  Disk-written sites (session_store, raw_thoughts, approval, graph.json)
  remain pretty for human inspection.
- Tests: 5 new ShmPool tests (TTL evict / fresh / oldest_n / overflow /
  total_bytes), 4 new session tests (prune drops aged / keeps running /
  keeps fresh / registry_size). 771 agent_core lib tests + 45 shadow
  lib tests, zero regressions.

### Swift Memory + Energy Hardening (perf 2026-04-28)
- `Epistemos/Models/SDPage+Queries.swift:106-114` —
  `SDChat.recentChatsDescriptor` now defaults `fetchLimit = 200`
  (was unbounded). Caps `MiniChatView.swift:18` `@Query` and any
  future caller that doesn't override.
- `Epistemos/Views/Approval/ApprovalModalView.swift:60-148` —
  replaced `Timer.publish().autoconnect()` with `TimelineView(.periodic)`.
  Pauses when modal is offscreen / occluded; no explicit invalidate
  needed.
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift:27-45` —
  `EpdocWebViewShared.processPool` shared static `WKProcessPool`
  collapses N WKContent processes into one across all editors +
  KaTeX previews (~50 MB / extra editor).
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift:330-365` —
  `dismantleNSView(_:coordinator:)` + `Coordinator.shutdown()`
  releases the WKWebView's userContentController handlers, the
  AP1 outbound display link, the autosave pipeline, and the
  controller dispatch closure on document close (40-60 MB / closed
  editor).
- `Epistemos/Views/Epdoc/EpdocKaTeXPreview.swift:71-86` — KaTeX
  preview now wires `processPool` + `WKWebsiteDataStore.nonPersistent()`.
- `Epistemos/Engine/MLXInferenceService.swift:336-372` — idle
  unload delays roughly halved (16 GB: 6→4 s, 24 GB: 10→6 s,
  36 GB: 20→10 s, larger: 30→15 s); thermal/background modifiers
  also tightened. Returns 1.5–2 GB to the OS sooner per idle.
- `Epistemos/Engine/MLXInferenceService.swift:1163-1195` —
  `.warning` memory-pressure handler now drops `persistentSSMSession`
  to free the KV cache without unloading the model container
  (256–512 MB extra on top of intermediate-tensor cache shrink).
  ChatSession exposes no public `clearKVCache()`; nilling the
  session is the canonical drop path.
- `Epistemos/Engine/ModelDownloadManager.swift:12-22` —
  `configuration.urlCache = nil` on the HF download URLSession
  (already uses `.reloadIgnoringLocalCacheData`; the default 20 MB
  cache header table was wasted memory).
- `Epistemos/App/EpistemosApp.swift:572-602` — the existing
  `RuntimeDiagnosticsMonitor` `DispatchSourceMemoryPressure`
  handler now also calls the Rust FFI
  `respondToMemoryPressure(level:)`. Level 1 (warning) →
  `evict_stale(60s)` + `prune_finished(5min)`; level 2
  (critical) → `cleanup_all` + `prune_finished(0)`. Relief
  metrics (segments evicted / bytes freed / sessions pruned)
  become part of the diagnostic record.
- Pre-existing build blockers fixed in this perf sweep:
  - `Epistemos/Sync/ReadableBlocksIndex.swift:107-122` — moved
    the ISO8601DateFormatter singleton to file scope with
    `nonisolated(unsafe)` so `static func iso8601(_:)` no
    longer trips Swift 6.2 strict concurrency on the
    `.defaultIsolation(MainActor.self)` module.
  - `Epistemos/Engine/OutlineParserCache.swift:26-50` — class
    + members downgraded from `public` to internal (matches
    `OutlineItem`'s access level; tests use `@testable import`).

### Wave 2026-04-29 perf additions (atop the 2026-04-28 hardening above)
- `Epistemos/Sync/SearchIndexService.swift:204-228` — PRAGMA tuning:
  cache_size 64 MB → 8 MB, mmap_size 1 GiB → 256 MiB (derivative
  FTS index, kernel page cache absorbs cold-read regressions).
- `Epistemos/Sync/SearchIndexService.swift:298-322` — new
  `releaseMemoryPressureCaches()` runs `PRAGMA optimize` +
  `PRAGMA shrink_memory` + `dbPool.releaseMemory()`. Wired into the
  global `RuntimeDiagnosticsMonitor.recordMemoryPressure` entry path.
- `Epistemos/Engine/MetalRuntimeManager.swift:368-410` — new
  `deepUnload()` drops 14 cached `MTLComputePipelineState` refs +
  `MTLBinaryArchive` image. Called from `MLXInferenceService.performUnload`
  (line 1493) on top of `releaseWorkingSet()`.
- `Epistemos/App/AppBootstrap.swift:1131-1163` — lazy-init for
  `noteInsightService` + `cloudKnowledgeDistillationService` (private
  optional + computed-getter pattern). Defers 6-15 MB until first
  user-action access (notes reindex / model-vault rebuild).
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift:312-318` —
  `config.websiteDataStore = .nonPersistent()` on the main editor
  WKWebView (matching KaTeX). Tiptap doesn't use IndexedDB /
  LocalStorage / Service Worker; persistent store was 30-50 MB
  dead weight per editor.
- `Epistemos/Graph/SemanticClusterService.swift:69-156` —
  `computeEmbeddings` parallelized via `DispatchQueue.concurrentPerform`
  + `nonisolated` per-node helper. Lock-free slot-fill into a pre-sized
  `[[Float]?]`. ~3-4× faster on 6P+4E M2 Pro. `TextEmbeddingLookup`
  is `Sendable`; `GraphNodeRecord` is `Sendable`.
- `agent_core/Cargo.toml:65` — tokio "full" → minimal feature set
  `["io-util","macros","net","process","rt-multi-thread","sync","time"]`
  (verified against full grep of agent_core/src + binary needs).
- `Epistemos/Engine/SpotlightIndexer.swift:67` — Spotlight item body
  trim 500 → 280 chars (Spotlight surfaces ~100-200 chars; trim
  shaves 30-50 MB resident in `corespotlightd` on 5K-note vaults).
- `Epistemos/App/AppBootstrap.swift:815-850` — ScreenCaptureService →
  Screen2AXFusion → VisualVerifyLoop → AmbientCaptureService chain
  converted to lazy `private var _x: T?` + computed-getter pattern.
  ~8-12 MB freed for sessions that don't open computer-use agent /
  enable ambient capture.
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift:40-77` —
  `EpdocWebViewShared` adds atomic `liveWebViewCount` registry +
  `resetPoolIfIdle()` that swaps the shared `WKProcessPool` when
  no WKWebView is bound. Wired into the global memory-pressure
  handler (`Epistemos/App/EpistemosApp.swift:600-606`). 30-40 MB
  returned on idle pressure.
- Handoff doc: `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md` carries
  the full change list, deferred items (with rationale on which
  failed research), and the JS-bundle Brotli sprint plan.

### Swift Halo (W8 — Contextual Shadows)
- Controller: Epistemos/Engine/HaloController.swift
- Search service: Epistemos/Engine/ShadowSearchService.swift
- Indexing service: Epistemos/Engine/ShadowIndexingService.swift
- Stub FFI: Epistemos/Engine/ShadowFFIClient.swift (StubShadowFFIClient)
- Production FFI: Epistemos/Engine/RustShadowFFIClient.swift (@_silgen_name)
- Vault crawl: Epistemos/Engine/ShadowVaultBootstrapper.swift (W8.7)
- UI: Epistemos/Views/Halo/HaloButton.swift + ShadowPanel.swift + ShadowPanelContent.swift

### Swift Epdoc (W7.17 — Tiptap chrome)
- Chrome: Epistemos/Views/Epdoc/EpdocEditorChromeView.swift
- Toolbar: Epistemos/Views/Epdoc/EpdocEditorToolbar.swift
- Floating panels: Epistemos/Views/Epdoc/Epdoc{Slash,Bubble,KaTeX,BlockContext,InsertLink,BlockGutter,ComplexityMeter,ThoughtAttachedBadge}*
- Paste classifier: Epistemos/Engine/EpdocPasteClassifier.swift
- Block templates: Epistemos/Engine/EpdocBlockTemplateStore.swift
- JS bundle source: js-editor/

### App Bootstrap
- Bootstrap: Epistemos/App/AppBootstrap.swift

## Session Startup Protocol
1. Read docs/APP_ISSUES_AUTO_FIX.md — list of open runtime issues to opportunistically fix
2. Read docs/AGENT_PROGRESS.md to see what's done and what's next
3. Read the current sprint file from docs/sprint-sessions/
4. After completing each task, run its verification command before moving to the next
5. After completing all sprint tasks, update docs/AGENT_PROGRESS.md with ✅ and today's date

## Auto-Fix Opportunities
docs/APP_ISSUES_AUTO_FIX.md tracks runtime issues discovered during normal use. On every session start, check it for `Status: Open` issues and fix any you can address safely (non-destructive) without derailing the user's current request. Update the Investigation Log whenever you add context or attempt a fix.
