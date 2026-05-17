# H-2 Idle Memory Allocations - User Decision Research

**Status:** COMPLETE_RESEARCH_READY
**Date:** 2026-05-16
**Terminal E scope:** user-decision preparation only; no implementation.

## Problem Statement

The user needs to decide how to handle `ISSUE-2026-04-21-004`, the idle resident-memory regression where the app idles around 500 MB instead of the historical roughly 50 MB floor.

The current code already contains mitigation and visibility work:

- `DeferredTextEmbeddingLookup` wraps `AppleHybridEmbeddingLookup` in `GraphState`.
- Read-only process RSS diagnostics ship in Settings.
- Force Idle Unload can trigger Rust shared-memory cleanup, search-cache release, and MLX unload on demand.
- App-level and MLX-level memory-pressure handlers can release caches, sessions, and model working sets.
- SwiftData chat queries and Tantivy writer heap already have caps.

Those mitigations do not answer the root question: which allocation category accounts for at least 80 MB of persistent idle memory after the app has launched, idled, and returned to rest. The decision is whether to require an Instruments Allocations trace before implementation, use in-app diagnostics as a first triage gate, authorize speculative cleanup, or defer the issue.

## Options

### Option A - Run Instruments Allocations before any fix

Keep H-2 operator-required. Build the app in Debug, launch through Xcode Product -> Profile, select Allocations, mark idle generations, and sort persistent bytes by retain stack.

**Pros**
- Identifies actual persistent allocations rather than RSS symptoms.
- Separates Apple NaturalLanguage embeddings, prepared runtime descriptors, SwiftData caches, MLX/tokenizer residency, shared-memory segments, and Tantivy writer heap.
- Produces a defensible root-cause threshold: at least 80 MB persistent bytes.
- Matches the existing MAS A.8 operator-required row and the issue log state.

**Cons**
- Requires human action on the Mac.
- Blocks code fixes until the allocation category is known.
- Takes longer than using the in-app RSS row.

### Option B - Use Force Idle Unload as first triage, then run Allocations if RSS remains high

Use Settings -> Diagnostics -> Process memory -> Force Idle Unload to capture RSS before/after and subsystem contribution. If it frees most of the 500 MB, prioritize the contributing subsystem. If RSS remains high, continue to Instruments.

**Pros**
- Fast and already available in the app.
- Gives immediate evidence for Rust shared-memory, search-cache, and MLX-release contribution.
- Helpful before asking the user to run Instruments.

**Cons**
- RSS delta is not an allocation retain stack.
- A low freed-MB result does not identify what remains.
- Cannot close H-2 alone because it does not show persistent allocation ownership.

### Option C - Apply speculative memory cleanup now

Patch likely contributors before profiling: tighten deferred embedding dimension behavior, evict prepared runtime descriptors, narrow or cap SwiftData queries, nil tokenizer state on unload, surface ShmPool counters, or re-check Tantivy heap.

**Pros**
- May reduce idle RSS quickly.
- Several candidate fixes are plausible and already named in the issue log.
- Can be split into small targeted commits.

**Cons**
- High risk of chasing the wrong memory owner.
- Some fixes are behavior changes, especially embedding dimension semantics and SwiftData query narrowing.
- A blind patch can hide the root cause without proving the idle floor is fixed.

### Option D - Defer H-2 until after V1

Leave the issue operator-required and accept the current idle RSS unless the app crosses memory-pressure thresholds.

**Pros**
- Avoids late release churn.
- Current app has memory-pressure relief hooks, so the 500 MB idle footprint may not be immediately fatal on the 16 GB target.

**Cons**
- P1 idle-memory regression remains unresolved.
- 500 MB idle is still a product-quality issue for a resident desktop app.
- Deferring without a fresh trace leaves the historical 50 MB target unexplained.

## Canonical Sources

### `docs/APP_ISSUES_AUTO_FIX.md`

- Lines 2424-2435: ISSUE-2026-04-21-004 records the idle RSS regression: about 500 MB now, historical about 50 MB, with Metal working-set release only partially addressing post-unload memory.
- Lines 2437-2447: suspected causes are Apple NaturalLanguage embeddings, prepared retrieval descriptors, SwiftData query caches, and tokenizer/model residency.
- Lines 2448-2458: safe next action is Allocations top-10 persistent allocations; destructive fixes include lazy-loading `AppleHybridEmbeddingLookup` and narrowing `@Query` predicates.
- Lines 2460-2478: prior investigation corrected the status back to open/operator-required and records that `DeferredTextEmbeddingLookup` and `ProcessMemoryHealthRow` are mitigation/visibility work, not root-cause proof.

### `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`

- Lines 190-232: Phase A.8 already classifies H-2 as operator-required, gives the Allocations workflow, lists six hypotheses, and sets the acceptance bar at <=200 MB idle RSS with >=80 MB root-cause attribution.

### `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md`

- Lines 85-89: PASS 1 H-2 keeps the idle-memory regression in HIGH priority and notes that Instruments Allocations is required.

### `Epistemos/Graph/EmbeddingService.swift` and `Epistemos/Graph/GraphState.swift`

- `EmbeddingService.swift` lines 45-63: `DeferredTextEmbeddingLookup` resolves its lookup lazily through a locked storage wrapper.
- `EmbeddingService.swift` lines 145-164: `AppleHybridEmbeddingLookup` initializes contextual and word embedding lookups and pins a dimension.
- `GraphState.swift` lines 863-877: `GraphState.init()` constructs `EmbeddingService` with `DeferredTextEmbeddingLookup { AppleHybridEmbeddingLookup() }`.

### `Epistemos/Views/Settings/ProcessMemoryHealthRow.swift`

- Lines 4-8: Process memory row is explicitly read-only diagnostics and does not replace Instruments.
- Lines 31-37 and 74-84: live snapshot records RSS, physical memory, and memory-pressure flag using Mach task info.
- Lines 95-100: Force Idle Unload is an in-app diagnostic substitute for users who cannot run Instruments.
- Lines 177-184: report summary exposes freed MB plus MLX, search, and Rust segment/session contribution.

### `Epistemos/App/AppBootstrap.swift`

- Lines 2859-2868: `IdleUnloadReport` records before/after RSS, freed MB, Rust segments/bytes/sessions, MLX unload, search-cache release, and duration.
- Lines 2871-2910: `forceIdleUnload()` calls Rust relief, releases search caches, unloads local inference, and reports the RSS delta.

### `Epistemos/App/EpistemosApp.swift`

- Lines 631-640: app installs a `DispatchSourceMemoryPressure` listener.
- Lines 643-710: pressure transitions record resident MB, call Rust memory-pressure relief, release search caches, and unload the local model on critical pressure.

### `agent_core/src/bridge.rs` and `agent_core/src/shared_memory.rs`

- `bridge.rs` lines 1031-1082: `respond_to_memory_pressure` returns `segments_evicted`, `segment_bytes_freed`, and `sessions_pruned`, with warning versus critical cleanup levels.
- `shared_memory.rs` lines 220-224: default ShmPool TTL is 300 seconds.
- `shared_memory.rs` lines 366-400: `evict_stale` returns segment count and bytes freed.

### `Epistemos/Engine/MLXInferenceService.swift` and `Epistemos/Engine/MetalRuntimeManager.swift`

- `MLXInferenceService.swift` lines 1540-1589: warning pressure clears caches/KV while critical pressure unloads the active model.
- `MLXInferenceService.swift` lines 1894-1914: unload clears persistent SSM state, drops Metal runtime manager, releases working set or deep unloads, and clears MLX cache limits.
- `MetalRuntimeManager.swift` lines 365-405: `releaseWorkingSet` clears large buffers/heap; `deepUnload` also clears compiled pipelines and binary archive.

### `Epistemos/Models/SDPage+Queries.swift` and `epistemos-shadow/src/backend/lexical_index.rs`

- `SDPage+Queries.swift` lines 105-116: `SDChat.recentChatsDescriptor` caps default chat queries at 200 rows.
- `lexical_index.rs` lines 39-45: Tantivy writer heap is already lowered to 15 MB from the older 50 MB budget.

## Code Impact Estimate

### Option A - Allocations first

Implementation now: docs only.

Follow-up implementation depends on trace result:

- Apple NaturalLanguage embeddings: likely change in `DeferredTextEmbeddingLookup` / `AppleHybridEmbeddingLookup` dimension behavior or graph embedding fallback.
- Prepared runtime descriptors: likely release/weak-reference change in `PreparedModelRegistrySnapshot`, `PreparedRetrievalRuntimeConfiguration`, `AppBootstrap`, `GraphState`, or `QueryEngine`.
- SwiftData caches: targeted fetch-limit/predicate changes in affected `@Query` views.
- MLX/tokenizer retention: unload-path cleanup in `MLXInferenceService` and possibly tokenizer/container ownership.
- ShmPool: diagnostics or eviction-policy change in `agent_core/src/shared_memory.rs`, bridge FFI, or `ProcessMemoryHealthRow`.
- Tantivy: regression fix in `epistemos-shadow/src/backend/lexical_index.rs` or search-service lifecycle.

Tests after a trace-driven fix:

- Targeted Swift or Rust tests for the touched subsystem.
- Manual idle launch smoke test.
- Force Idle Unload before/after record, if relevant.
- Saved before/after Allocations trace showing the persistent allocation owner is gone or reduced.

### Option B - Force Idle Unload triage first

Estimated implementation now: none.

Possible follow-up:

- If `mbFreed` is high and attributed to MLX/search/Rust, narrow the next patch to that subsystem.
- If `mbFreed` is low, do not infer root cause; continue to Allocations.

Risk:

- RSS can lag allocation release because of allocator behavior and unified-memory accounting.
- The button does not inspect retain stacks, so it cannot prove SwiftData, NLEmbedding, or descriptor retention.

### Option C - Speculative cleanup

Estimated implementation: 50-500 LOC per candidate, depending on owner.

Risks:

- Embedding laziness can alter `dimension` contract behavior.
- Query narrowing can hide content or change sidebar ordering.
- Prepared-descriptor eviction can cause repeated manifest parse churn.
- Tokenizer/container cleanup can regress first-turn latency.
- ShmPool policy changes can remove payloads still needed by active sessions if not scoped correctly.

### Option D - Defer

Estimated implementation: docs/status only.

Risk:

- Leaves a known P1 idle-memory regression unresolved.
- Future performance work may misattribute the idle floor without a baseline allocation trace.

## Recommendation

Recommend **Option A: run Instruments Allocations before implementation**.

Recommended decision record:

> H-2 remains operator-required until an Allocations trace identifies at least one allocation owner accounting for >=80 MB persistent bytes in the launched-then-idle app. The in-app Force Idle Unload row is useful triage, but it does not replace retain-stack evidence. After the trace, patch only the confirmed owner and rerun until idle RSS is <=200 MB or the remaining owner is logged as the next H-2 sub-issue.

Reasoning:

- The code already contains several mitigations, so blind cleanup has lower expected value than it did in April.
- The plausible owners live in different subsystems and carry different behavior risks.
- RSS is a symptom; Allocations gives ownership.
- The existing acceptance bar is concrete and should be preserved: >=80 MB attribution and <=200 MB idle RSS.

## Acceptance Criteria

If the user chooses **Option A**:

- Save an Allocations trace for a Debug launched app.
- Store the trace at `artifacts/perf/ISSUE-2026-04-21-004-allocations.trace` or attach it to the issue log.
- Mark Generation 1 after first launch, one note/chat/graph pass, and 60 seconds idle.
- Mark Generation 2 after another idle window.
- Sort persistent bytes descending and paste the top 10 entries with retain stacks.
- Identify at least one root owner accounting for >=80 MB persistent bytes, or document that no single owner meets the threshold.
- Apply the targeted fix for the confirmed owner.
- Rerun and confirm idle RSS <=200 MB, or record the next largest persistent owner as the follow-up.

If the user chooses **Option B**:

- Record Force Idle Unload before/after RSS and subsystem contribution.
- Use the result only to prioritize the next trace or fix.
- Do not close H-2 without either Allocations retain-stack evidence or a verified <=200 MB idle rerun.

If the user chooses **Option C**:

- Split speculative cleanup by subsystem.
- Preserve behavior tests for any embedding, query, model-unload, ShmPool, or Tantivy change.
- Keep H-2 open until RSS and allocation evidence satisfy the acceptance bar.

If the user chooses **Option D**:

- Record a defer decision in MAS and `APP_ISSUES_AUTO_FIX.md`.
- Require a fresh baseline trace before any later memory work claims to fix the idle floor.

## Decision-Ready Prompt

Choose the H-2 idle-memory path:

1. **Recommended:** Run Instruments Allocations, paste top persistent allocations with retain stacks, then implement only the confirmed fix.
2. Use Force Idle Unload first as quick triage, then run Allocations if the RSS delta does not explain the regression.
3. Authorize speculative cleanup by subsystem, with H-2 staying open until allocation/RSS evidence passes.
4. Defer H-2 post-V1, accepting the current 500 MB idle footprint until a future profiling pass.
