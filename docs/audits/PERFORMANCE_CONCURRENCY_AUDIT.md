# Performance + Concurrency Audit

Date: 2026-04-25
Authority: PLAN_V2 §22-§27 + EPISTEMOS_DETERMINISTIC_PERF_PLAN + research synthesis.
Acceptance targets: typing does not hitch; graph pan/zoom smooth; AI streaming does not cascade UI/database; app launch responsive; recall does not block UI; no recurring task leaks.

| Finding | File | MainActor risk? | User symptom | Fix | Priority | Test |
|---|---|---|---|---|---|---|
| `InstantRecallService` declared `@MainActor @Observable` (`:33`) with sync `rebuildIndex(notes:)` (`:258`) coexisting with `rebuildIndexAsync` (`:267`) | `Epistemos/KnowledgeFusion/InstantRecallService.swift:33+258+267` | YES if sync called | freeze on large vault import / reindex | force every caller to async path; add `precondition(false, "Use rebuildIndexAsync")` in `#if DEBUG` for sync path | **HIGH** | Synthetic 1000-note vault import → typing remains 60fps (signpost) |
| `MLXInferenceService.LocalMLXClient` `@MainActor final class` (`:492`) uses `MainActor.run` for load (`:1664`) and `releaseWorkingSet` (`:1450`) | `Epistemos/Engine/MLXInferenceService.swift:492+1450+1664` | INDIRECT — fences run on main but generation itself is on @MainActor class | UI may stall during model load/teardown; not per-token | move `LocalMLXClient` off MainActor; isolate UI state to a dedicated `@MainActor` view-model | **MEDIUM** | Cold-load model → app stays responsive in chat list during load |
| `AsyncStream` buffering — verified ALL 10 constructors use `bufferingNewest(N)`, no `unbounded` | `StreamingDelegate.swift:555` (`.bufferingNewest(256)`); `ChatCoordinator.swift:555+2139`; `EventBus.swift:54`; `LocalRustRuntime.swift:39`; `PipelineService.swift:186`; `LocalBackendLLMClient.swift:169`; `AppSupervisor.swift:114`; `ReactiveQuery.swift:41` (1); `ClaudeManagedRuntime.swift:61` (2); `URLSessionTransportSupport.swift:33` | NO | n/a | n/a — keep | DEFER (already correct) | grep regression test in CI |
| `.repeatForever` — zero matches across `Epistemos/Views/`; explicit avoidance documented | `PhysicsModifiers.swift:13` ("WARNING: NO .repeatForever"); `EpistemosTheme.swift:1584` ("v2's .repeatForever caused 70% idle CPU") | NO | n/a | none | DEFER | grep regression test |
| Code editor: `markdown_parse_code_tokens` is whole-file C FFI fallback; viewport-scoped `syntax-core` path is gated by `EPISTEMOS_USE_SYNTAX_CORE=1` env var (default OFF) | `CodeEditorView.swift:2118-2170+2254`; `SyntaxCoreService.swift:10-11` | YES potentially — whole-file parse on per-keystroke could stall at 4k lines | typing hitch on large files | wire viewport-scoped `syntax-core` ON by default for code files; add 4k-line keystroke benchmark | **HIGH (P1)** | 4k-line .swift file: keystroke-to-highlight <16ms p99 |
| `Binding<String>` O(n) cost per keystroke (acknowledged) | `CodeEditorView.swift:398-402` | YES at scale | typing hitch on >100KB files | introduce `SyntaxEditDelta` path so Swift sends deltas to Rust shadow rope rather than the whole string each keystroke; preserve current Swift NSTextStorage authority | **HIGH (P1)** | 50k-line file typing latency p99 <16ms |
| ProseEditor: per-keystroke reparse via `markdown_parse_code_tokens` for fenced blocks; scoped to "edited paragraph and neighbors" | `ProseTextView2.swift:417` (sync) `:463` (scoped) | LOW | n/a — paragraph scope is correct | none | DEFER | existing tests pass |
| Token coalescing absent — every token crosses FFI individually | `agent_core/src/agent_loop.rs:300+312` | n/a (already off-main on Rust side) | not user-visible at current frequencies | optional: 16ms frame-aligned coalescing per PLAN_V2 §24.2; only if benchmarks show benefit | DEFER | future agent-stream benchmark |
| Per-frame allocations in graph render — Rust pre-allocates buffers (`renderer.rs:3018+3212`); Swift `GraphNodeBatchPayload`/`GraphEdgeBatchPayload` lack visible pre-allocation | `MetalGraphView.swift` (Swift); `graph-engine/src/renderer.rs:3018+3212` (Rust) | YES if Swift batch grows per frame | possible jitter on large graphs | audit Swift batch payload mutation sites; reuse buffers | **MEDIUM** | 10K-node graph at 60fps; signpost `frame` p99 <8.3ms |
| `GraphChat` notification observer: `[weak self]` + queue: .main pattern | `AgentCommandCenterState.swift` | NO | n/a — correct pattern | none | DEFER | covered by tests |
| NotificationCenter observers: 42 add/remove pairs balanced (audit confirmed) | scattered | NO | n/a — correct | none | DEFER | grep regression |
| `nonisolated(unsafe)` on NSView properties: 20 uses, all with `// SAFETY:` comments | `EmbeddingService.swift:276-287`; `GraphState.swift:57`; `HomeWindowInputDiagnostics.swift:238` | NO | n/a — disciplined pattern | none | DEFER | grep regression |
| Send-path latency: `ChatCoordinator.handleQuery` synchronous prelude is metadata-only (no disk I/O) | `Epistemos/App/ChatCoordinator.swift:1368-1480` | NO | n/a — already deferred to Task | none | DEFER | manual: send query → spinner appears <50ms |
| Pipeline service `bufferingPolicy: .bufferingNewest(StreamingBufferPolicy.textLimit)` | `PipelineService.swift:186` | NO | n/a | none | DEFER | covered |
| `HologramOverlay.hide()` bounded reopen window 10s, then teardown | `HologramOverlay.swift:532-560+985-1024+1380` | NO | freeze-class fix per AGENT_PROGRESS 2026-04-03 | none | DEFER | `GraphOverlayRetentionPolicyTests` |
| `addGlobalMonitorForEvents` — no synchronous path in `AppBootstrap.init` | `AppBootstrap.swift:1234+1723` (deferred FFI) | NO | n/a — fixed | none | DEFER | per memory entry |

## Performance budget targets (perf-budgets.toml derived from research)

| Metric | Target p99 | Source |
|---|---|---|
| Cold start | < 800 ms | Deterministic perf plan §0.5 |
| Frame | < 8.3 ms (120Hz target) | Deterministic perf plan §0.5 |
| MCP invoke | < 2 ms | Deterministic perf plan §0.5 |
| Graph query | < 1 ms | Deterministic perf plan §0.5 |
| FFI hot-path | < 5 µs | Deterministic perf plan §0.5 |
| Editor open (50K lines) | < 500 ms | PLAN_V2 §23.8 |
| Keystroke-to-highlight | < 16 ms (60Hz) / < 8.3 ms (120Hz) | PLAN_V2 §23.8 |
| Continuous typing (5 min) | no unbounded memory growth | PLAN_V2 §23.8 |
| Vector index search (1M notes) | < 10 ms end-to-end | EPISTEMOS-NORTH-STAR §metrics |
| Continuous encoding latency | < 3 ms / paragraph | EPISTEMOS-NORTH-STAR §metrics |
| Agent streaming main-thread util | < 5% during streaming | PLAN_V2 §24.5 |
| Agent streaming frame drops | 0 | PLAN_V2 §24.5 |
| Bundle size | ≤ 80 MB | Deterministic perf plan §8 |

## Top 5 risks today

1. **Code editor at 4k+ lines** — full-file parse on keystroke will stall. Wire syntax-core viewport path. **HIGH P1**.
2. **Sync `rebuildIndex` on @MainActor** — large vault import freezes app. Force async path. **HIGH P1**.
3. **MLXInferenceService MainActor.run pattern** — load/teardown can stall responsiveness during model swap. Move client off @MainActor. **MEDIUM**.
4. **Swift graph batch payloads** lack visible pre-allocation. Audit + reuse. **MEDIUM**.
5. **Token streaming has no frame-aligned coalescing** — fine today, may matter at higher token rates. **DEFER unless measured**.

## Confidence

HIGH on AsyncStream + animation + observer + nonisolated(unsafe) discipline (parallel-agent audit verified directly against repo).
HIGH on InstantRecall + MLX MainActor concerns (file:line cited).
MEDIUM on actual 4k-line editor performance — never measured. The benchmark scaffolding exists; needs to run.

## Next actions

- Add automated 4k-line editor benchmark to nightly CI.
- Wire syntax-core viewport path with default ON for code files.
- Hard-deprecate sync `rebuildIndex` path.
- Add `os_signpost` interval `editor.typing` and `editor.firstPaint`.
- Audit `GraphNodeBatchPayload`/`GraphEdgeBatchPayload` for per-frame growth.
