# SS-PERF — Performance + memory optimization audit (16GB Mac) (2026-06-19)

Read-only research (subagent), code-grounded. Feeds the recursive "super-optimized" mandate. Builds on the
existing perf waves (CLAUDE.md 2026-04-28/29). **Honest: the app is ALREADY meaningfully optimized — this is a
polish pass, not a rescue.** All MB/latency figures are STATIC ESTIMATES from code shape (no Instruments run).

## Headline
Two perf waves already landed: memory-pressure FFI handlers, bounded caches, lazy-init of heavy service chains,
shared `WKProcessPool`, `.nonPersistent()` WebKit stores, MLX idle-unload + KV-drop-on-pressure, tuned FTS
PRAGMAs, minimal tokio features, `to_string` JSON compaction. Low-hanging memory fruit is mostly picked. **Largest
remaining gains:** (1) ~18 health-row 1Hz polling timers (energy/CPU while Settings open), (2) MLX KV cache only
freed REACTIVELY — never proactively bounded by token count (256–512MB on long sessions), (3) agent-loop message-
history clones growing O(turns).

## Memory gains
- **MLX KV cache only dropped reactively** — `persistentSSMSession` holds the KV cache across turns
  (`MLXInferenceService.swift:1619-1657`, fields `:2477-2479`), nil'd only on `.warning` pressure (`:1585-1594`)
  or full unload; **NO proactive cap** on KV token-length/context for long SSM chats. Bound resumed context or
  evict beyond N tokens. Est. **256–512MB** recoverable. **[M]**
- **GraphState holds the full node/edge graph + pending-mutation arrays in @Observable** (`GraphState.swift`,
  3677 lines; `pendingNodeAdds/EdgeAdds/Removals :1062-1090`, `store.nodes/edges` dicts, `semanticClusterIds
  :2511`), unbounded by node count → the biggest in-memory Swift object on large vaults. Window the store or drop
  it when the graph view is off-screen (like the editor `dismantleNSView`). Est. tens of MB on 5K-node graphs.
  **[L]**
- **Engine caches already bounded** (CognitiveDepthOverlay LRU `:77-78`, SidecarCache `bound` `EpistemosSidecar
  .swift:490`, `URLCache.shared` zeroed `AppBootstrap.swift:1684`) — don't redo.

## Startup gains
- A few singleton starts run on the bootstrap path rather than the 250ms `deferredRuntimeServicesDelay` block:
  `PowerGuard.shared.start()` (`AppBootstrap.swift:2057`), `EventStore.shared` (`:2300`), `LatestAnswerPacketSink
  .shared.start()` (`:2201`). Move into the deferred block. Est. small (few ms). **[S]**
- Lazy-init wave already covers the heavy chains (computer-use/ambient `:815-850`, noteInsight/cloudKnowledge
  `:1131-1163`) — don't redo.
- **ShadowVaultBootstrapper full-vault crawl** is batched (`batchSize=64`, `:95-141`) off-main, but runs
  UNCONDITIONALLY every launch (`bootstrap()` calls both domains `:112-114`). **Verify it's mtime/incremental,
  not re-reading every `.md`/`.json` each boot** — if not gated, that's a cold-launch I/O win. **[M]** *(unverified:
  couldn't confirm mtime gating.)*

## Inference gains
- Steady-state SSM path avoids replay (`persistentSSMSession` reuse `:1623-1628`, SSM resume `:1644-1655`) —
  good.
- **Non-SSM models build a fresh `ChatSession` every turn** (`:1629-1635`), re-ingesting `systemPrompt` +
  `additionalContext` each call → re-processes the system prompt per turn. Cache prefill for stable system
  prompts. Est. latency on long prompts. **[M]**
- Generate path signpost-instrumented + serialized (`beginSerialTurn :1614`) — disciplined.

## Search / index gains
- **Already well-tuned** — ShadowIndexingService 500ms debounce + `maxBatchSize=256` (`:38-44,141-158`), per-docId
  dedupe (`:64,85,92`); FTS PRAGMAs cache_size 8MB/mmap 256MiB (`SearchIndexService.swift:204-228`) +
  `releaseMemoryPressureCaches() :298-322`; tantivy heap 15MB. Don't redo.
- Minor: the 500ms debounce is fixed regardless of typing cadence — an adaptive/longer debounce during active
  typing cuts redundant flushes. Est. small CPU. **[S]**

## UI / render gains — BIGGEST low-effort win
- **~18 independent 1Hz polling timers in `SubstrateHealthPanel`.** 25 health rows in one ScrollView
  (`:31-143`); **18** run `refreshTask = Task { while !cancelled { sleep(1s); <FFI>; refresh() } }` (e.g.
  `SystemGHealthRow.swift:128-135` calls `SystemGBridge.status()` every second). They cancel `.onDisappear`
  (`:92-94`) so idle when Settings is closed — **but `.onDisappear` does NOT fire for rows scrolled off inside
  the open panel** → opening Settings spins ~18 timers = ~18 FFI round-trips + 18 SwiftUI invalidations/sec.
  Collapse to ONE shared 1Hz `TimelineView`/clock fanned out (the wave already used `TimelineView(.periodic)` for
  ApprovalModalView). Est. ~18 FFI/sec → 1. **[M] — RANK #1.**
- `SettingsView` = 5089 lines, 78 `@State`/`@Observable`/body sites in one struct (`:48`) → broad re-compute on
  any state change. Split detail panes into separate `View` structs for sub-tree diffing. **[L]**
- WebKit recreation: no `colorScheme`/`onChange`-driven WKWebView rebuild found in `EpdocEditorChromeView.swift`
  (SS-U's dark/light recreation is in `HTMLWorkspaceEditorView`, per SS-U — not the editor). *Flag: targeted look
  worthwhile.*

## Rust / FFI gains
- **Agent-loop history clones grow O(turns)** — `response_blocks.clone()` into the message vec (`agent_loop.rs
  :535,557`) + `config`/`system_prompt` cloned per turn (`:322-323`); `messages` + `full_history` (`:115`)
  accumulate with no in-loop compaction trigger in the hot path. Move blocks instead of clone where the original
  is dropped; trigger compaction by token budget mid-loop. Est. tens of MB on long runs. **[M]**
- **Already optimized:** tokio minimal features (`Cargo.toml:65`), `to_string` JSON, ShmPool TTL eviction
  (`shared_memory.rs`), session prune (`session.rs`), `respond_to_memory_pressure` FFI (`bridge.rs`). Don't redo.

## Ranked top opportunities
| # | Opportunity | Est. gain | Effort | File:line |
|---|---|---|---|---|
| 1 | Collapse ~18 health-row 1Hz timers → one shared clock | ~18 FFI+invalidations/sec → 1 | M | `SubstrateHealthPanel.swift:31-143`; `SystemGHealthRow.swift:128-135` |
| 2 | Proactively bound MLX KV cache by token length | 256–512 MB on long SSM | M | `MLXInferenceService.swift:1619-1657,1585-1594,2477` |
| 3 | Confirm ShadowVault crawl is mtime/incremental | cold-launch I/O | M | `ShadowVaultBootstrapper.swift:112-141` |
| 4 | Avoid `response_blocks.clone()` + token-budget mid-loop compaction | tens of MB long runs | M | `agent_loop.rs:535,557,322` |
| 5 | Defer `PowerGuard`/`EventStore` into deferred block | few ms cold launch | S | `AppBootstrap.swift:2057,2300` |
| 6 | Drop `GraphState.store` when graph view off-screen | tens of MB large graphs | L | `GraphState.swift:1062-1090,2511` |
| 7 | Cache non-SSM prefill for stable system prompts | per-turn latency | M | `MLXInferenceService.swift:1629-1635` |
| 8 | Split `SettingsView` body into sub-View structs | Settings render CPU | L | `SettingsView.swift:48` |
| 9 | Adaptive index debounce during active typing | small CPU | S | `ShadowIndexingService.swift:141-158` |

## Already well-optimized (don't redo)
Memory-pressure FFI chain; WKProcessPool sharing + nonPersistent + dismantleNSView; MLX idle-unload + Metal
deepUnload + KV-drop-on-warning; FTS PRAGMA tuning + releaseMemoryPressureCaches + tantivy 15MB; ShadowIndexing
debounce/coalesce; ShmPool TTL + session prune; tokio minimal; to_string JSON; URLCache zeroed; lazy-init of
computer-use/ambient/noteInsight; engine caches (CognitiveDepthOverlay LRU, SidecarCache bound).

## Verified vs estimated
file:line + code structure verified by read/grep. All MB/latency/energy numbers are ESTIMATES from code shape,
not measured (Instruments/xcodebuild needed to confirm). Unverified: ShadowVault incremental gating (#3); WebKit
colorScheme recreation status.

Key files: `Views/Settings/SubstrateHealthPanel.swift` + `*HealthRow.swift` (×18 timers) · `Engine/MLXInference
Service.swift` (KV/SSM/generate) · `Graph/GraphState.swift` (largest in-memory object) · `App/AppBootstrap.swift`
(init/deferred) · `Engine/ShadowVaultBootstrapper.swift` + `ShadowIndexingService.swift` · `agent_core/src/
agent_loop.rs` + `compaction.rs` (history growth) · `Sync/SearchIndexService.swift` (already tuned).
