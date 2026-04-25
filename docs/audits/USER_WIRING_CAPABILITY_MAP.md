# User Wiring Capability Map

Date: 2026-04-25
Scope: Every major capability traced UI → state/controller → service → bridge/engine → persistence/result.

A capability is **WIRED** only if every link in the chain is present, the user can discover and activate it, and it is stable. Otherwise it is **PARTIAL**, **SCAFFOLD**, or **ABSENT**. Severity uses BLOCKER / HIGH / MEDIUM / LOW / DEFER.

## Legend

- **Status**: WIRED / PARTIAL / SCAFFOLD / ABSENT / VIOLATED-CANON
- **App Store safe**: YES / GATED / NO (Pro-only) / RISKY-NEEDS-REVIEW
- **Confidence**: HIGH / MEDIUM / LOW

---

## 1. Notes / Prose Editor

- **Status**: WIRED
- **Built**: yes — TextKit 2 confirmed at `Epistemos/Views/Notes/ProseTextView2.swift:707` (`usingTextLayoutManager: true`).
- **User-visible**: yes (primary editor).
- **Stable**: yes — debounced binding sync 300ms (`ProseEditorRepresentable2.swift:1357-1366`), 5s disk sync (`:333-334`), all NotificationCenter observers `MainActor.assumeIsolated` guarded (`:104-186`, `ProseTextView2.swift:775-784`), no `try!`/`as!`, divider zone protection scoped via `isFlushingTokens` (`:599-607`) + `hasProtectedInlineResponseDivider` (`:356-357`).
- **Tested**: yes (`ProseEditor*` test suites; ChatPresentationTests).
- **Path**: `ProseEditorView` → `ProseEditorRepresentable2` (`Coordinator2`) → `ProseTextView2` (NSTextView) → `MarkdownContentStorage` → 300ms debounce → SwiftData save / `NoteFileStorage`.
- **Risk**: LOW. Protected by canon.
- **Recommendation**: HARDEN. Watch regressions; do not refactor.
- **App Store safe**: YES. Confidence: HIGH.

## 2. Notes / Code Editor

- **Status**: PARTIAL
- **Built**: CodeEditSourceEditor 0.15.2 with Binding<String> O(n) acknowledged at `CodeEditorView.swift:398-402`. Outline replaces minimap (`:1267`). `markdown_parse_code_tokens` C FFI at `:2254`. `EPISTEMOS_USE_SYNTAX_CORE=1` gates a viewport-scoped tree-sitter path at `:2118-2170` via `SyntaxCoreService.swift:10-11`.
- **User-visible**: yes (opens for code-like file types).
- **Stable**: acceptable for files <100KB; documented O(n) Binding cost. No frame-drop benchmark for 4k-line files committed yet.
- **Tested**: benchmark harness exists (`EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift`) but disabled-by-default.
- **Path**: `CodeEditorView` → CodeEditSourceEditor + Binding<String> → optional syntax-core (off by default) → C-FFI markdown tokens.
- **Gaps** (HIGH): syntax-core scaffold not consumed by default; line-count gutter exists in comments only; 4k-line fluidity not measured; benchmark suite manual-only.
- **Recommendation**: WIRE syntax-core viewport path with default ON for code files; add automated 4k-line benchmark; design line-count gutter that respects theme.
- **App Store safe**: YES. Confidence: HIGH.

## 3. Notes / Documents (.epdoc)

- **Status**: ABSENT (canon-listed, 0% built)
- **Built**: no. Zero matches for `.epdoc`, `Tiptap`, `ProseMirror`, `WKWebView` in `Epistemos/`. `GraphTypes.swift:7-25` has 14 node types, NO `Document` or `RawThought`.
- **Recommendation**: HOLD for V1 unless explicitly slated. If pursued, follow canon: WKWebView+Tiptap, canonical ProseMirror JSON, Markdown derived. **DO NOT** ship as separate sidebar silo.
- **App Store safe**: YES (when built). Confidence: HIGH.

## 4. Chat (main)

- **Status**: WIRED with one BLOCKER on Pro+Cloud routing.
- **Built**: yes. ChatView, MessageBubble, ThinkingPopoverView, ThinkingTrailView all live. `EffectiveModelBadge` shows actual answering model.
- **Path**: ChatInputBar → `ChatCoordinator.handleQuery` (`:1368`) → routes by `effectiveOperatingMode`:
  - `.agent` + cloud → `runCommandCenterRustAgentPath` (`:373`) ✅
  - all other (Fast/Thinking/Pro for both local + cloud) → `PipelineService.run` (`:401`) → `shouldUseToolLoop` returns false unless `case .localMLX` (`:313-314`) ⚠️
- **Stable**: yes; thinking blocks preserved across tool_use rounds (verified — `agent_core/src/types.rs:39-41`, `agent_loop.rs:410+504`, `compaction.rs:211-280`).
- **Tested**: 7-suite sweep per AGENT_PROGRESS 2026-04-19; ChatPresentationTests, AgentChatStateTests.
- **Gap (BLOCKER)**: Pro mode on cloud has zero tools because `shouldUseToolLoop` short-circuits at `:313-314`. The MASTER_PLAN §HH.4 fix narrative is partially landed (intent classifier and persistence are in), but the `.localMLX` guard in `PipelineService.swift:313` was not flipped. **Verify with the user** whether HH.4 is closed against this exact line.
- **Recommendation**: WIRE Pro+cloud through Rust agent loop, OR honestly downgrade Pro+cloud doc to "no tools". Decide before V1.
- **App Store safe**: YES. Confidence: HIGH on routing analysis.

## 5. Streaming pipeline

- **Status**: WIRED
- **Path**: `StreamingDelegate.swift:555` `AsyncStream<...>(bufferingPolicy: .bufferingNewest(256))`. Verified ALL 10 AsyncStream constructors use `bufferingNewest` — no `unbounded`. Thinking deltas routed to thinking pipeline (not text). MainActor.assumeIsolated on `.main`-queue observers throughout.
- **Stable**: yes.
- **Recommendation**: KEEP; consider 16ms token coalescing per PLAN_V2 §24.2 only if benchmarks show benefit (PLAN_V2 says "first agent optimization may be coalescing alone").
- **App Store safe**: YES. Confidence: HIGH.

## 6. Agent runtime (Rust agent_core)

- **Status**: WIRED (multi-turn loop is real, not scaffold).
- **Path**: `agent_core/src/agent_loop.rs:136-587` real loop. SSE provider via `providers/claude.rs` (interleaved-thinking-2025-05-14 beta header at `:21`). Thinking + signature blocks preserved across tool_use turns. Permission gate fail-closed at `agent_loop.rs:738-789`. Prompt caching breakpoints land at system+first+third-from-last+last (`prompt_caching.rs:1-71`). Compaction does not strip thinking (`compaction.rs:211-280`).
- **Tools**: `agent_core/src/tools/registry.rs` — verified `vault_write` (`:820-832`), `patch`, `memory` are reassigned to `ChatPro` tier inside `apply_tier_overrides` (`:760+832`). Default `.with_tier()` sets Agent (`:290`); the override migrates them to ChatPro at registry construction time. So MASTER_PLAN §HH.3 claim is **CORRECT** when overrides apply (not as the previous parallel-agent audit reported — re-verified directly via grep).
- **Recommendation**: HARDEN. Add Raw Thoughts artifact persistence layer (currently scaffolded only — thinking is in message history but no separate per-run folder).
- **App Store safe**: YES (Rust core itself). Specific tools may be MAS-gated. Confidence: HIGH.

## 7. Raw Thoughts (artifact persistence)

- **Status**: SCAFFOLD (canon-listed, partially captured)
- **Built**: thinking blocks live in `agent_core/src/types.rs:39-41` (`Thinking { thinking, signature }`); session_store has `transcript.jsonl`, `trace.json`, `summary.md`, `artifacts/` per `agent_core/src/storage/session_store.rs:5-8`. NO per-model run folder, NO `events.jsonl` of raw provider deltas (thinking_delta + signature_delta + tool_use + tool_result + reasoning_summary), NO `manifest.json`/`links.json` per run, NO graph node/edge for `Run` / `RawThought` / `ToolTrace`.
- **Recommendation**: This is the canonical first slice candidate. Wire under flag `EPISTEMOS_RAW_THOUGHTS_V0`, default-on if size budget passes. Add typed graph nodes/edges (`Run`, `RawThought`, `ToolTrace`; `produced_during`, `derived_from`, `cites`, `summarizes`, `generated_by`).
- **App Store safe**: YES. Confidence: HIGH.

## 8. MCP bridge

- **Status**: WIRED
- **Path**: `omega-mcp/src/dispatcher.rs` 16 UniFFI exports. PTY: `omega-mcp/src/pty.rs:45-693` orphan cleanup, SIGTERM→200ms→SIGKILL (`:428`), echoed `__EPPWD__` marker fixed (`:522`/`:680`).
- **Stable**: yes; 8 PTY regression tests passing.
- **Recommendation**: KEEP. Future Phase Omega-2 Swift-side health check bridge is non-blocking.
- **App Store safe**: GATED — PTY/subprocess stays Pro-only. Confidence: HIGH.

## 9. Computer use stack (Omega + AX + Screen)

- **Status**: WIRED in Pro; STUBBED in MAS.
- **Built**: `Epistemos/Omega/Inference/DeviceAgentService.swift`, `VisualVerifyLoop.swift`, `ScreenCaptureService.swift`, `Screen2AXFusion.swift`. AX via Rust `omega-ax`.
- **MAS**: `Epistemos/AppStore/AppStoreComputerUseStubs.swift:1-184` provides denied/empty stubs; `omega-ax` excluded post-build (`project.yml:189-192`).
- **Stable**: yes for Pro; correctly stripped for MAS.
- **Recommendation**: KEEP. Verify TCC discipline (audit confirmed all TCC prompts originate from sandboxed frontend).
- **App Store safe**: GATED (correctly).

## 10. Vault sync + persistence

- **Status**: WIRED
- **Path**: `VaultSyncService.swift` SwiftData-authoritative; vault `.md` files are export-only (no live file watcher per `:10-15`). `NoteFileStorage.swift` atomic writes via `mutationQueue` (`:211`); Blake3 sidecar checksums (`:233`). Bookmark restore (`:118`); `startAccessingSecurityScopedResource` matched (`:997+1738+1891` ↔ `:999+1770+1804+2045`).
- **Stable**: yes; recent S.4 commits added bookmark startup validation (`2c41f2cc`).
- **Tests**: `VaultSyncServiceAuditTests.swift:198-273` covers stale bookmarks, restore disable under test hosts, pending startup restore.
- **Recommendation**: KEEP. Consider lightweight inotify/FSEvents only if it can stay off MainActor and not cause loops.
- **App Store safe**: YES. Confidence: HIGH.

## 11. Search index (FTS5)

- **Status**: WIRED
- **Path**: `Epistemos/Sync/SearchIndexService.swift:275-352` GRDB FTS5 with `page_search` + `block_search` virtual tables, `unicode61` tokenizer; INSERT/DELETE/UPDATE triggers; FTS5 manages deletions via content pragma (no external-content pattern).
- **Stable**: yes; graceful fallback if FTS5 module absent (`:287+326`).
- **Recommendation**: KEEP. Consider unifying into a single `search_text` projection per gpt work 2.md if Documents persistence lands.
- **App Store safe**: YES. Confidence: HIGH.

## 12. Instant Recall / Phase 18 (HNSW)

- **Status**: PARTIAL (substrate WIRED, UI ABSENT)
- **Built**: `InstantRecallService.swift:1-294` C-FFI to `instantRecallCreate/Insert/Search`; <3ms vault-wide SLA; rebuild path async (`:267`); sync `rebuildIndex` exists (`:258`).
- **Substrate**: `graph-engine/src/retrieval_index.rs:1-300+` usearch HNSW (`HNSW_CONNECTIVITY=16`, `HNSW_EXPANSION_ADD=128`, `HNSW_EXPANSION_SEARCH=64`).
- **Gap (HIGH)**: NO Contextual Shadows UI; NO 200ms continuous encoding loop; integration is event-driven on note save/edit only. `InstantRecallService` is `@MainActor @Observable` (`:33`) — sync rebuild path could block on large vault import.
- **Recommendation**: WIRE Contextual Shadows panel (see AMBIENT_RECALL_WIRING_PLAN.md). Force `rebuildIndexAsync` everywhere and gate sync path behind `precondition(false)` in Debug.
- **App Store safe**: YES. Confidence: HIGH on substrate; HIGH on UI absence.

## 13. Knowledge Core (staged shadow runtime)

- **Status**: SCAFFOLD
- **Built**: ring buffer + payload accessors at `graph-engine/src/knowledge_core/*` + `Epistemos/Engine/KnowledgeCoreBridge.swift`.
- **Gap**: not threaded into AppEnvironment as first-class query engine (per `ARCHITECTURE_MAP.md §7`). Drains into shadow counters only.
- **Recommendation**: DEFER until deterministic perf plan Sprint 3 (typed mutation envelopes + watch plans + production adapter). Do not surface to users.
- **App Store safe**: YES.

## 14. Graph (renderer + physics)

- **Status**: WIRED
- **Path**: `MetalGraphView.swift` Metal renderer; physics in `graph-engine/src/{engine.rs,physics.rs,renderer.rs}`. Force_alive flag for pinned panels (per AGENT_PROGRESS 2026-04-15).
- **Stable**: yes after the Vec from_raw_parts fix (ISSUE-2026-04-04-001) and bounded reopen window. No `.repeatForever`; explicit avoidance documented at `PhysicsModifiers.swift:13` and `EpistemosTheme.swift:1584`.
- **BoltFFI**: typed buffer prototype landed behind `bolt-graph` Cargo feature + `EPISTEMOS_USE_BOLT_GRAPH` Swift flag; defaults off. Verified by `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift` and `graph-engine/benches/graph_ffi_baselines.rs`.
- **Recommendation**: KEEP. Do NOT rewrite. Optionally flip BoltFFI flag once parity proven on real hardware.
- **App Store safe**: YES. Confidence: HIGH.

## 15. Local model catalog + cloud providers

- **Status**: WIRED (per Master Plan 2026-04-19 batches A/B/H/T)
- **Path**: `Epistemos/Engine/LLMService.swift` reasoning tier (`:2405+`); ProviderRegistry; `MASTER_MODEL_STACK_PLAN.md`.
- **Tested**: 37 tests / 2 suites (CloudStreamingParserTests + TriageServiceTests focused).
- **Recommendation**: KEEP. Continue DD batch (3-tier reasoning controls per provider).
- **App Store safe**: YES. Confidence: HIGH.

## 16. Quick capture / Audio / Transcription

- **Status**: PARTIAL
- **Built**: `Epistemos/KnowledgeFusion/DataIngestion/AudioRecorder.swift:24` mic auth; `AudioTranscriber.swift:179-184` SFSpeechRecognizer auth; `Epistemos/Engine/ComposerVoiceInputService.swift:144` mic auth.
- **Gap (MEDIUM)**: no top-level "Quick Capture" surface verified yet; behind composer + Knowledge Fusion entry only.
- **Recommendation**: VERIFY user discoverability. If shippable, surface via global hotkey + menu bar. Otherwise hide behind a Settings flag for V1.
- **App Store safe**: YES (with usage descriptions present).

## 17. Settings + Privacy transparency pane (S.6)

- **Status**: WIRED
- **Path**: `Epistemos/Views/Settings/PrivacyDetailView.swift:1-205`. Surfaces `PrivacyInfo.xcprivacy`, deployment-profile copy (lines 113-123 distinguish MAS vs Pro), links to Inference/Vault/Agent settings.
- **Stable**: yes; drift-test `AppStoreHardeningTests.swift` lines 74-85.
- **Recommendation**: KEEP. Confidence: HIGH.

## 18. Agent Command Center

- **Status**: PARTIAL / SCAFFOLD
- **Built**: `AgentCommandCenterState` referenced; canon (PLAN_V2 §4.1) calls for slash commands, at-mentions, capability pills, brain selector, right-side inspector.
- **Gap (MEDIUM)**: full surface and right-side inspector not verified built. Defer to V1.5 unless shippable surface exists.
- **Recommendation**: VERIFY current state with explicit grep; if not built, hide entry point until proper Phase 5 work.
- **App Store safe**: YES.

## 19. App Store profile (PolicyProfile)

- **Status**: WIRED (compile-time gating; not double-helper IPC)
- **Path**: Rust `mas-sandbox` feature; Swift `EPISTEMOS_APP_STORE` + `MAS_SANDBOX`; post-build scrub of `omega_ax.dylib` + `AXorcist.framework`. Startup integrity check `verifyAgentCorePolicyProfile()` at `AppBootstrap.swift:2686-2704`.
- **Stable**: yes; 16-test `AppStoreHardeningTests.swift`.
- **Recommendation**: KEEP. Document JIT entitlement justification for App Review.
- **App Store safe**: YES with documentation. Confidence: HIGH.

## 20. Diagnostics / Observability

- **Status**: PARTIAL
- **Built**: `OSSignposter` subsystems `com.epistemos.bench` (graph FFI + editor) and `com.epistemos.ffi` (per research synthesis). Benchmark harness present but disabled-by-default.
- **Gap (MEDIUM)**: no in-app diagnostics panel; no automated perf gate in CI; agent streaming baselines TBD (`AGENT_STREAM_BASELINES.csv` 9 rows empty).
- **Recommendation**: P1 — add nightly perf gate using existing benchmark harness. KEEP signpost coverage.
- **App Store safe**: YES.

---

## Summary table (capability vs status)

| # | Capability | Status | App Store | Severity if broken | Confidence |
|---|---|---|---|---|---|
| 1 | Prose Editor | WIRED | YES | BLOCKER | HIGH |
| 2 | Code Editor | PARTIAL | YES | HIGH | HIGH |
| 3 | Documents (.epdoc) | ABSENT | YES | DEFER | HIGH |
| 4 | Chat | WIRED + Pro+Cloud BLOCKER | YES | BLOCKER | HIGH |
| 5 | Streaming | WIRED | YES | BLOCKER | HIGH |
| 6 | Agent runtime | WIRED | YES | BLOCKER | HIGH |
| 7 | Raw Thoughts | SCAFFOLD | YES | HIGH | HIGH |
| 8 | MCP bridge | WIRED | GATED (Pro) | HIGH | HIGH |
| 9 | Computer use | WIRED Pro / Stubbed MAS | GATED | HIGH | HIGH |
| 10 | Vault sync | WIRED | YES | BLOCKER | HIGH |
| 11 | Search FTS5 | WIRED | YES | HIGH | HIGH |
| 12 | Instant Recall | PARTIAL (no UI) | YES | HIGH | HIGH |
| 13 | Knowledge Core | SCAFFOLD | YES | DEFER | HIGH |
| 14 | Graph | WIRED | YES | MEDIUM | HIGH |
| 15 | Local + Cloud models | WIRED | YES | HIGH | HIGH |
| 16 | Quick capture | PARTIAL | YES | LOW | MEDIUM |
| 17 | Privacy pane | WIRED | YES | LOW | HIGH |
| 18 | Agent Command Center | SCAFFOLD | YES | DEFER | MEDIUM |
| 19 | MAS profile | WIRED | YES | BLOCKER | HIGH |
| 20 | Diagnostics | PARTIAL | YES | MEDIUM | HIGH |
