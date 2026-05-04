# Research Dossier — Tier 3 (R14-R16) + Tier 4 (W9.6-W9.30)

> **Status**: CANONICAL — research synthesis + paste-ready prompts (synthesis of `/Advice`, `/final`, `/final v2` corpora).
> **Role**: Per-item research findings (concrete file paths + diff size + ship-in-N-PRs estimates), Bucket A/B/C/D sequencing, Common Epistemos Context block (paste into external research tools), self-contained research prompts per item. Companion to `03_EXECUTION_MAP.md` (which is the implementation gating layer).
> **Read with**: [`docs/plan/03_EXECUTION_MAP.md`](plan/03_EXECUTION_MAP.md) (per-item DoD/WRV) + [`docs/plan/05_RESEARCH_INDEX.md`](plan/05_RESEARCH_INDEX.md) (corpus map) + [`docs/STRUCTURING_AUDIT.md`](STRUCTURING_AUDIT.md) (input pipeline).
> **Note on consolidation**: this dossier and `03_EXECUTION_MAP.md` overlap on item-name + risk + targets but serve different audiences (dossier = research delivery + paste-ready prompts; execution map = implementation gating + WRV proof). They're kept separate by design.

Authored 2026-04-26. This is the canonical research-prompt + analysis
document for every item still in the inventory after the Wave 9-15
wrap. **Use these prompts verbatim** when researching with
ChatGPT/Claude/Perplexity/etc. — each prompt is self-contained and
includes the Epistemos context the external tool needs.

---

## Common Epistemos Context (paste into any external research session)

> **About Epistemos** (the app being researched):
>
> macOS-native Personal Knowledge Management app. Stack: **Swift 6.2 +
> Rust (UniFFI 0.28 FFI) + Metal compute shaders + GRDB + MLX-Swift
> for local inference + Foundation Models (AFM) on macOS 26**. The
> codebase is 137K Swift / 94K Rust / 370 Swift files / 99 Rust files
> / 115 test files.
>
> **Crate split:**
> - `agent_core` (Rust) — agentic loop, HTTP streaming, tool
>   execution, session persistence, memory search, security, prompt
>   caching, context compaction
> - `epistemos-shadow` (Rust cdylib) — tantivy 0.22 BM25 + usearch
>   2.24 HNSW + RRF fusion (BM25 + vector recall over the vault)
> - `omega-mcp` (Rust) — MCP dispatcher + vault ops
> - `epistemos-core` (Rust) — adaptation logic
> - `Epistemos/` (Swift) — UI rendering, MLX inference, macOS APIs
>   (AXUIElement via AXorcist, ScreenCaptureKit, CGEvent), permission
>   gate UI, MCP server hosting
> - `hermes-agent` (Python subprocess) — cloud API orchestration,
>   skills system, procedural memory, multi-step planning
>
> **Hardware target**: 16 GB unified memory Mac, realistic budget
> ~10-11 GB for weights + KV cache. Sweet spot is 4-bit 7-8B local
> models (Qwen3 0.6B/8B, Hermes-3, plus Apple Foundation Models on
> macOS 26).
>
> **Non-negotiable constraints** (do not violate when proposing
> implementations):
> - All inference in-process via Rust FFI or MLX-Swift. NO sidecar
>   for inference (Hermes subprocess is for orchestration only).
> - REAL APIs only — no fake features.
> - Honest capability gating: local models → fast/thinking/research;
>   cloud → agent/liveAgent.
> - Stream every token immediately to the delegate, no buffering.
> - Preserve thinking blocks when stop_reason == "tool_use".
> - API keys in macOS Keychain, never UserDefaults.
> - No `try!`, no force-unwraps, no `print()` in production.
> - `DispatchQueue.main.async` in UniFFI callbacks, NEVER `.sync`.
>
> **Distribution**: dual build — App Store ("Bounded Intelligence
> OS", review-safe, sandboxed) AND Pro ("Full Autonomy OS", shell +
> Docker + iMessage + long-horizon).

Use this block as the "About the codebase" prefix to any research
prompt below.

---

## 🎯 Recommended sequencing (after 4 background research agents 2026-04-26)

After deep audit of the actual codebase state, the items split into
4 buckets by **how much actually needs building**:

### Bucket A — "90 % already done, just wire it" (do FIRST, low risk)
These have shipping infrastructure already in the repo; only need a
small finishing pass.

- **W9.25 grammar masking** — `mlx-swift-structured` already
  referenced in `LocalToolGrammar.swift:3-4` behind `canImport`
  guards. Just link the package in `project.yml` + flip the
  `isFullyConstraining` flag. **~1 session.**
- **W9.30 KIVI quant** — `MLXLMCommon.QuantizedKVCache` already
  exists (lines 700-951). Add sibling `KIVIKVCache` with K/V axis
  asymmetry. Existing reference impl in
  `epistemos-core/src/instant_recall/kv_cache_quant.rs`. **~2-3
  sessions.** Better-than-KIVI option: vendor `arozanov/turboquant-mlx`
  fused Metal kernel for FP16 decode speed.
- **R14 UniFFI 0.28→0.29.5** — 4 Cargo.toml files, ~50 hand-written
  LOC + ~5K LOC regenerated bindings. Pin **0.29.5 EXACTLY**, not
  0.30/0.31 (method-checksum changes warn). `epistemos-shadow` does
  NOT need bumping (uses `@_silgen_name` raw FFI). **~1 session.**

### Bucket B — "concrete spec, additive scope" (do SECOND, medium risk)

- **R15 benchmark harness** — extend existing `bench/` Rust crate +
  4 new XCTest files in `EpistemosTests/Benchmarks/`. **~2 PRs, 880
  LOC.**
- **W9.6 cost dashboard + W9.7 vault selector + W9.8 approval modal +
  W9.13 daily notes** — all SwiftUI-only, additive views. Each ~1-2
  sessions.
- **W9.23 bit-packed circuit breaker + W9.29 thermal-aware throttling**
  — small Rust modules in `agent_core/src/`. Each ~1 session.

### Bucket C — "real work, established pattern" (do THIRD, larger scope)

- **W9.21 Honest FFI** — touches 5 Rust crates (`epistemos-shadow`,
  `syntax-core`, `substrate-rt`, `substrate-core`, `graph-engine`)
  + ~7 Swift consumer files. **4 PRs, ~1100 LOC.** `agent_core` is
  ALREADY honest (UniFFI handles).
- **W9.22 Typestate Islands** — MUST come AFTER W9.21 (typestate
  holds the new handles). Spike `~Copyable` + actor compat first.
  **~1 PR, ~650 LOC.**
- **W9.26 B-tree rope (`crop` crate w/ `utf16-metric` feature)** —
  3-4 sessions. NoteFileStorage.swift + ProseEditorRepresentable2.swift
  rewrite + new agent_core/src/rope/ + UniFFI bindings.
- **W9.27 OpLog (hand-roll, NOT automerge)** — single-writer scope
  keeps it manageable. Use additive flag `EPISTEMOS_GRAPH_OPLOG`.
  **2-3 sessions.**
- **R16 ETL crawler** — 3 PRs, ~1400 LOC. New `agent_core/src/etl/`
  module (NOT a separate crate). Pin `apalis = "=1.0.0-rc.7"` exactly
  (RC churned).

### Bucket D — "research-grade, gate on actual roadmap need" (defer)

- **W9.10 TurboQuant** — paper just landed (ICLR 2026); `arozanov/
  turboquant-mlx` is a swift port that may obviate hand-impl.
- **W9.11 Create ML personalized embeddings** — large Create ML
  surface; eval methodology nontrivial.
- **W9.12 Orphan rediscovery** — needs the OpLog (W9.27) substrate
  for time-travel queries to feel right.
- **W9.14 Block references** — 5+ session refactor; needs rope
  (W9.26) for cheap snapshots.
- **W9.15 Routing macro** — ROI unclear vs hand-rolled NavigationStack
  at current view count (~30 types).
- **W9.24 Metal zero-copy buffers** — measure first; Apple Silicon
  UMA may make `bytesNoCopy` a no-op gain.
- **W9.28 Blelloch scan** — `Mamba2/inter_chunk_scan.metal` already
  uses 3-dispatch Reduce-then-Scan because Apple lacks Forward-
  Progress Guarantees. This task is an OPTIMIZATION on an experimental
  path; gate on Mamba-2 being on the active roadmap (not just
  research backlog).

### Cross-cutting hard rules
1. **W9.21 MUST precede W9.22** — typestate handles wrap honest-FFI
   pointers; doing W9.22 first means a second rewrite when W9.21
   lands.
2. **W9.26 should precede W9.27** — OpLog wants O(1) snapshots
   which the rope provides for free.
3. **R14 (UniFFI bump) is independent** — can land any time but
   coordinates with W9.21 since both touch FFI surface.
4. **W9.30 KIVI as opt-in flag first** (`EPISTEMOS_KV_KIVI=1`) —
   never default-on without a perplexity regression test.

---

# Tier 3 Items

## R14 — UniFFI 0.28 → 0.29.5 bump + Issue #2818 SwiftPM target separation

### 🔬 Research findings (background agent 2026-04-26)
- **Pin 0.29.5 exactly** — DO NOT bump to 0.30/0.31 (method-checksum changes; explicit warning in `WAVE_9_POLISH_AND_NATIVE.md` §305 + plan §1037).
- **Issue #2818 is NOT fixed in 0.29.5** (open since 2026-02-11). The `patch-uniffi-bindings.py` post-processor must stay in place.
- **Diff size**: ~50 LOC hand-written + ~5K LOC regenerated bindings.
- **Ship in 1 PR**: 4 Cargo.toml files (`agent_core`, `epistemos-core`, `omega-mcp`, `omega-ax`). `epistemos-shadow` does NOT use UniFFI (uses `@_silgen_name` raw FFI), no bump needed.
- **Breaking changes 0.28→0.29.5**:
  1. Async name renames: `UniffiForeignFutureFree` → `UniffiForeignFutureDroppedCallback`, `RustFuturePoll::MaybeReady` → `Wake`. Affects custom bindgen authors only — Epistemos uses upstream Swift bindgen, so neutral.
  2. `UniffiCustomTypeConverter` removed → `custom_type!` macro. Epistemos uses derive-only types; grep confirmed no `UniffiCustomTypeConverter` impls.
  3. UDL typedef syntax changed; Epistemos is proc-macro (no `.udl` files) — neutral.
  4. **0.29.1 added Sendable**: generated protocols now conform to `Sendable`. Foreign-implemented traits (callbacks) must also be `Sendable`. **Affects** `RustShadowFFIClient`, `RustEventRingClient`, `EventDrain`, `AgentGrepService`, `StreamingDelegate`. Add a `nonisolated` annotation pass to `patch-uniffi-bindings.py`.
- **Files needing review**: `Epistemos/Engine/RustShadowFFIClient.swift`, `Epistemos/Engine/RustEventRingClient.swift`, `Epistemos/Engine/EventDrain.swift`, `Epistemos/Engine/AgentGrepService.swift`, `Epistemos/Bridge/StreamingDelegate.swift`, plus `patch-uniffi-bindings.py`.

### What it is
The `uniffi` crate generates FFI bindings between Rust and Swift.
Epistemos pins `uniffi = "0.28"` across `agent_core`,
`epistemos-shadow`, `epistemos-core`. Version 0.29 (released Q4 2024)
introduced significant changes: (a) external types are gated behind
`feature = "external_types"`, (b) Swift checksumming changed,
(c) Issue #2818 added per-bridge SwiftPM target separation so each
generated binding becomes its own SwiftPM module instead of one
catch-all module that forces every consumer to recompile when any
binding changes.

### Why for Epistemos
- **Build hygiene**: today, touching the smallest agent_core function
  signature triggers a rebuild of every Swift file that imports the
  catch-all UniFFI module. With per-bridge targets, only consumers of
  the changed binding rebuild.
- **Compile-time safety**: 0.29 added stricter type checking on
  callback interfaces — catches `DispatchQueue.main.sync` deadlock
  patterns at codegen time.
- **MAS compliance**: 0.29's improved error type generation helps
  with App Review's static-analyzer pass (no opaque NSError-bridging
  errors).

### Files touched
- `agent_core/Cargo.toml` (line with `uniffi = "0.28"`)
- `epistemos-shadow/Cargo.toml`
- `epistemos-core/Cargo.toml`
- `omega-mcp/Cargo.toml` (if it uses uniffi)
- `patch-uniffi-bindings.py` — post-processor that strips
  noisy attributes from generated `*.swift` files; verify it still
  matches 0.29's output format
- Every `@_silgen_name` Swift bridge file (search:
  `Grep -r "@_silgen_name" Epistemos --include="*.swift"`)
- `build-epistemos-shadow.sh` and any other build scripts that
  invoke `cargo run --bin uniffi-bindgen-swift`

### Approach options
1. **Big-bang bump in one PR** — bump all crates simultaneously,
   regenerate all bindings, fix every breakage in a marathon session.
   Risk: monolithic diff, hard to bisect.
2. **Crate-by-crate bump** — bump epistemos-core first (smallest FFI
   surface), then epistemos-shadow, then agent_core. Risk: temporary
   version skew between crates that share types.
3. **Fork and patch path** — pin to a specific 0.29.x git SHA and
   patch any blocker upstream. Risk: divergence from upstream main.

Recommended: **Option 2** with a feature branch per crate.

### Performance / security / optimization angles
- Bindings ABI compat: 0.28 → 0.29 changed the metadata format,
  forcing a full rebuild of every Rust → Swift call site.
- Memory: 0.29's improved Arc handling reduces refcount thrash on
  cross-FFI calls (claimed 5-10% throughput gain for small-payload
  callbacks).
- Security: 0.29 closes a soundness hole where `Vec<u8>` returned
  from Rust could alias caller memory — Epistemos' shadow FFI
  returns lots of byte payloads (search results), so this matters.

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block from top of dossier]

I need to bump UniFFI from 0.28 to 0.29.5 across an existing Rust →
Swift codebase. Specifically I need:

1. The full 0.28 → 0.29.x changelog highlighting BREAKING changes
   that affect Swift codegen (callback interfaces, error types,
   external types, async traits).

2. Specific guidance on Issue #2818 (SwiftPM target separation):
   what exactly does this enable, and how do I configure my
   uniffi.toml + build script to emit per-bridge SwiftPM targets?
   Show a working uniffi.toml example.

3. The Swift-side migration path for:
   - `@_silgen_name` bridge files (do these still work or do I need
     to switch to UniFFI's auto-generated extern decls?)
   - DispatchQueue.main.async patterns in callback handlers
   - Vec<u8> return values (does the new Arc handling change the
     copy semantics?)

4. A bisection strategy for finding which of my crates breaks
   first. I have 4 crates pinning uniffi: agent_core,
   epistemos-shadow, epistemos-core, omega-mcp.

5. Real-world example diffs from open-source Rust+Swift projects
   that successfully bumped from 0.28 to 0.29. Cite the
   repos+commits.

Output format: a single numbered migration checklist with
copy-paste commands and code snippets. Mark each step "low risk /
medium risk / blocker" so I can sequence carefully.
```

---

## R15 — Benchmark harness

### 🔬 Research findings (background agent 2026-04-26)
- **Use existing `bench/` Rust crate** — already has `morning_session.rs`, `model2vec_bench.rs`. Add `bench/src/uniffi_throughput.rs`, `bench/src/sqlite_vec_knn.rs`. No new crate.
- **Use XCTest `measure {}` with `XCTCPUMetric`/`XCTMemoryMetric`/`XCTClockMetric`** (NOT swift-collections-benchmark — no thermal hooks). Existing pattern: `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift` and `GraphFFIBenchmarkTests.swift`.
- **Add 4 new test files**:
  - `EpistemosTests/Benchmarks/AFMGenerableBenchTests.swift` — wraps `@Generable` round-trip via `LanguageModelSession`
  - `EpistemosTests/Benchmarks/MLXThermalBenchTests.swift` — wires existing `PowerGate.swift` thermal sampling via `ProcessInfo.thermalState` between iterations
  - `EpistemosTests/Benchmarks/SQLiteVecKNNBenchTests.swift` — uses GRDB connection from existing storage layer
  - `EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift` — uses `bench/` Rust binary as oracle
- **Run via**: `swift test --filter Benchmarks` (matches existing naming) or `cargo bench`.
- **Diff size**: ~600 LOC Swift + ~250 LOC Rust + ~30 LOC Cargo.toml.
- **Ship in 2 PRs**: PR1 = AFM + UniFFI scaffold; PR2 = MLX thermal + sqlite-vec.

### What it is
Build a runnable benchmark suite that measures four critical
performance dimensions:
1. **AFM `@Generable` round-trip latency** — how long does
   `LanguageModelSession.respond(to:generating: T.self)` take for
   small, medium, large schemas?
2. **MLX Qwen3 0.6B 4-bit tok/s under thermal pressure** — sustained
   tokens-per-second after the M-series chip throttles.
3. **sqlite-vec KNN at 100k vectors** — query latency p50/p95/p99
   for vector search at production-realistic scale.
4. **UniFFI callback throughput** — Rust → Swift callback rate ceiling.

### Why for Epistemos
- Today there's no signal when a Wave 9 perf optimization actually
  helps vs hurts. Every claim ("5.7× latency cut", "40% token
  reduction") is theoretical until measured.
- Thermal throttle is the silent killer on a 16GB Mac — sustained
  inference can drop to 30% of cold tok/s after ~4 minutes.
- Vector search latency is the floor for any "ambient retrieval"
  feature — if KNN @ 100k vectors > 50ms, the user notices.

### Files touched
- New `benchmarks/` directory at repo root
- `Package.swift` (add benchmark target)
- `agent_core/Cargo.toml` (criterion dev-dependency)
- `Epistemos/Engine/MLXService.swift` (add `runBenchmark()` entry)
- `Epistemos/Engine/RustShadowFFIClient.swift` (add benchmark hooks
  for KNN)
- New `Epistemos/Engine/AFMBenchmarkRunner.swift`

### Approach options
1. **Swift Testing's `.measure {}`** — built-in, low ceremony, but
   poor for sustained-throughput tests (only measures one block).
2. **swift-collections-benchmark** (Apple) — designed for
   data-structure benchmarks; less ideal for end-to-end inference.
3. **Custom harness with structured JSON output** — most flexible;
   pairs with a Python plotter for thermal-decay curves over time.
4. **Criterion (Rust side)** — already standard; use for the Rust
   crates and write a Swift-side harness for the FFI/MLX/AFM bits.

Recommended: **Option 4** — Criterion for Rust, custom Swift
harness for AFM/MLX. Output to `benchmarks/results/<date>.json` so
you can graph regressions over time.

### Performance / security / optimization angles
- Thermal pressure: must run benchmark for >5 minutes to see the
  throttle — Apple's IOKit `thermalState` notification fires before
  hardware throttle kicks in.
- Cache-warm vs cold: AFM has a 1-3s cold start; benchmark should
  measure both.
- Battery: benchmarks should NOT run on battery (skews thermal
  curves) — gate with `IOPSGetTimeRemainingEstimate()` check.
- Reproducibility: pin macOS version + chip generation in the
  results filename so you can compare across hardware.

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I need to design a benchmark harness for a Swift 6.2 + Rust app
that tests:

(a) Apple Foundation Models @Generable round-trip latency on
    macOS 26 (the new on-device LLM API)
(b) MLX-Swift inference tok/s for Qwen3 0.6B 4-bit under sustained
    thermal pressure (>5 min runs)
(c) sqlite-vec KNN at 100k vectors p50/p95/p99
(d) UniFFI callback throughput Rust → Swift

Specific questions:

1. What's the canonical 2026 way to measure Apple Foundation Models
   on-device latency? Does Swift Testing's `.measure {}` capture
   the right signal, or do I need to wrap CFAbsoluteTimeGetCurrent
   manually because the AFM session has internal queueing?

2. For thermal-pressure inference benchmarks, how do I monitor
   IOKit thermal state and emit a "throttle event" timestamp so I
   can graph tok/s decay against thermal level? Show real
   IOPowerSources / IOPMrootDomain code.

3. For sqlite-vec, what's the right vector dimensionality to
   benchmark? My embedding model emits 768-dim vectors. Should I
   benchmark with cosine distance or dot product? What HNSW
   parameters (M, ef_construction, ef_search) match a "production-
   realistic" build?

4. Compare three benchmark approaches: Swift Testing's measure {},
   swift-collections-benchmark from Apple, and rolling my own with
   structured JSON output + Python plotter. Which is best for
   tracking regressions over time and graphing thermal decay
   curves?

5. For the Rust side (UniFFI callback throughput), should I use
   criterion or divan? What's the canonical way to measure cross-
   FFI calls without optimizer dead-code elimination?

6. Show me a real benchmark suite from an open-source on-device LLM
   app that does similar things (cite the repo + paste relevant
   files).

Output: a complete benchmark harness spec ready to implement,
with Swift + Rust + Python file skeletons, JSON output schema, and
CI integration notes.
```

---

## R16 — Phase 13 ETL Rust crawler (apalis-sqlite + ignore + xxh3)

### 🔬 Research findings (background agent 2026-04-26)
- **Verified crate pins** (Apr 2026):
  ```toml
  apalis = "=1.0.0-rc.7"            # MUST pin exact — RC API churned across rc.4..7
  apalis-sql = { version = "0.7.3", features = ["sqlite"] }
  ignore = "0.4.25"                  # gitignore-aware walker (BurntSushi, used by ripgrep)
  xxhash-rust = { version = "0.8.15", features = ["xxh3", "const_xxh3"] }
  tokio-util = "0.7"                 # CancellationToken (already transitive — promote to direct)
  ```
- **Architecture: new module at `agent_core/src/etl/`** (NOT a new crate — avoids another UniFFI surface):
  - `agent_core/src/etl/mod.rs` — apalis Monitor + WorkerBuilder
  - `agent_core/src/etl/walker.rs` — `ignore::WalkBuilder` with `<vault>/.gitignore` + `.epignore` respected
  - `agent_core/src/etl/hash.rs` — xxh3_64 content fingerprint, dedupes against `.epcache/etl-fingerprints.sqlite`
  - `agent_core/src/etl/jobs.rs` — `IngestMarkdownJob`, `IngestPdfJob` (PDF via existing `lopdf` 0.34 in tree)
  - `agent_core/src/etl/afm.rs` — bridges to AFM 3B via existing `agent_core/src/providers/`
- **Swift wiring**: extends existing `Epistemos/Engine/ShadowVaultBootstrapper.swift` (267 LOC); replace its current ad-hoc batch crawl with apalis-driven dispatch.
- **3 new FFI exports in `epistemos-shadow/src/lib.rs`**: `etl_enqueue_walk`, `etl_pause`, `etl_status`.
- **Diff size**: ~1,400 LOC.
- **Ship in 3 PRs**: PR1 = walker + hash + fingerprint sidecar (no apalis yet); PR2 = apalis Monitor + job runners; PR3 = AFM sidecar generation + Swift wiring.

### What it is
A background ETL job that walks the user's vault, finds loose `.md`
and `.pdf` files, generates structured sidecar JSON via Apple
Foundation Models 3B, and writes the result to
`<file>.epistemos.json`. Built on:
- **apalis-sqlite** — Rust async work queue backed by SQLite (zero
  external deps, survives crashes)
- **ignore** — gitignore-aware filesystem traversal (Rust's
  reference implementation, used by ripgrep)
- **xxh3** — fast non-cryptographic hash for content-change
  detection

### Why for Epistemos
- Today the vault crawl in `ShadowVaultBootstrapper.swift` only
  indexes for BM25 + HNSW; loose markdown notes never get
  structured sidecar generation. Every note that bypasses the
  in-app editor stays "dumb" until the user opens it.
- The cognitive layer (W10.x) only fires for notes the user
  actively touches — a background ETL extends it to the long tail.
- Resumable + crash-safe: SQLite-backed queue means an interrupted
  crawl picks up where it left off; xxh3 means re-runs skip
  unchanged files.

### Files touched
- New crate: `epistemos-etl/` with `Cargo.toml`, `src/lib.rs`,
  `src/queue.rs`, `src/walker.rs`, `src/hasher.rs`
- `Epistemos/Engine/ShadowVaultBootstrapper.swift` — extend to
  trigger the ETL crawler after the BM25/HNSW pass completes
- `Epistemos/Engine/RustEtlFFIClient.swift` (new) — `@_silgen_name`
  bridge to `epistemos-etl`
- New AFM `@Generable` schema in
  `Epistemos/Engine/AFMSidecarGenerator.swift` (use the existing
  AFMSessionPool)

### Approach options
1. **Pure Rust ETL** — crawler + AFM bridge both in Rust. Problem:
   AFM is Swift-only; can't call from Rust without going back
   through the FFI boundary.
2. **Rust crawler + Swift AFM call site** — Rust does walk + hash +
   queue management; Swift owns the AFM call. Crosses FFI per file
   but each call is small.
3. **Pure Swift ETL** — skip the Rust crate; write everything in
   Swift using FileManager + AsyncSequence. Simpler but loses
   apalis-sqlite's crash resilience.

Recommended: **Option 2** — Rust handles I/O + queue + hashing;
Swift handles AFM calls. Coordinated via a callback FFI.

### Performance / security / optimization angles
- xxh3 throughput: 30+ GB/s on Apple Silicon — hashing 100k notes
  averaging 4KB each takes <500ms.
- Battery: ETL should pause on battery (check `IOPSCopyPowerSources`)
  + thermal throttle (use the existing `PowerGate.shouldDefer()`).
- Sandbox: in MAS build, the crawler can only walk paths the user
  has explicitly granted via NSOpenPanel — must respect security-
  scoped bookmarks.
- Privacy: `.epistemos.json` sidecars contain LLM-generated
  summaries — these should be `xattr`-marked as model-derived so
  the user knows they're not authored content.
- Code-file exclusion: must NOT generate sidecars for source code
  (`.swift`, `.rs`, `.py`, etc.) — that's the user's authored work
  and would pollute the AFM context with noise.

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I'm designing a Rust-based ETL crawler that walks a user's notes
vault, hashes files with xxh3, queues changed files in a SQLite-
backed apalis queue, and triggers Apple Foundation Models @Generable
sidecar generation in the Swift host process via a UniFFI callback.

Specific questions:

1. For the queue layer, compare apalis-sqlite vs sqlx-based hand-
   rolled queue vs sqlx + serde-only. Which gives the best tradeoff
   for: (a) crash resilience, (b) low-latency dequeue (<10ms),
   (c) zero external dependencies (no Redis, no separate worker).

2. For the file walker, ignore vs walkdir vs jwalk. My vault has
   ~100k files including a `.git` directory and a `node_modules`
   directory I MUST skip. Show me a working walker that respects
   .gitignore + custom exclude patterns + emits a stream of
   (path, xxh3_hash) tuples.

3. For xxh3 in Rust, twox-hash vs xxhash-rust vs the official
   xxhash bindings. Which is fastest on Apple Silicon arm64 for
   small files (<10KB)?

4. For the Swift callback bridge, how do I architect this so the
   Rust crawler can call into Swift to fire AFM @Generable on a
   per-file basis WITHOUT blocking the Rust runtime? UniFFI's
   async callback pattern in 0.28+?

5. For sandbox compatibility, the macOS App Store build can only
   walk paths the user has granted via security-scoped bookmarks.
   How do I pass a CFData bookmark from Swift down to Rust so the
   crawler stays inside the granted scope?

6. For the AFM @Generable side, what's the right schema for a
   note sidecar? I want: title, summary (1-2 sentences), tags
   (3-5), entities (people, projects, concepts), suggested_links
   (other notes in the vault by id). Show me a @Generable struct
   + @Guide annotations for this on macOS 26.

7. Real-world references: are there open-source Rust ETL crawlers
   for personal-knowledge or note-management apps I can study?
   Cite repos.

Output: a complete crate skeleton with Cargo.toml, src/lib.rs
public API, FFI signatures, and a worked example of crawling a
1000-note vault with throughput metrics.
```

---

# Tier 4 — UX Features

## W9.6 — Cost dashboard + per-session budget gate

### What it is
A SwiftUI view that surfaces `estimated_cost_usd` (already tracked
in `agent_core/src/session_insights.rs`) per session, plus a budget
gate that pauses agent execution when the session crosses a user-
configured cap.

### Why for Epistemos
- Cloud agent runs (Claude Sonnet/Opus, Perplexity Sonar Pro) burn
  $0.05–$0.50 per session today and the user has no visibility
  until the monthly bill arrives.
- Per-session cap = trust mechanic: user can set "max $0.50 per
  session" and the agent auto-pauses when it crosses the line.

### Files touched
- `agent_core/src/session_insights.rs` (already tracks cost — add
  budget gate hook)
- `agent_core/src/agent_loop.rs` (check budget before each tool
  call; emit `SessionState::PausedForApproval` with reason="budget")
- `Epistemos/Views/Chat/CostDashboardView.swift` (new)
- `Epistemos/Views/Settings/BudgetSettingsSection.swift` (new)
- `Epistemos/State/BudgetPreferences.swift` (new — UserDefaults-
  backed budget config)

### Approach options
1. **Hard cap with PausedForApproval modal** — agent stops, user
   approves to continue. Best UX, ties into existing W9.8 modal.
2. **Soft cap with notification** — agent continues; user sees a
   banner. Worse for runaway costs.
3. **Tiered caps** — warn at 50%, pause at 100%. Best for power
   users but more UI surface area.

Recommended: **Option 1** — reuse the W9.8 PausedForApproval modal
with `tool_name = "budget_gate"` and `args_json` carrying current
spend + cap.

### Performance / security / optimization angles
- Cost computation should be O(1) per turn — accumulate, don't
  recompute from history.
- Per-provider pricing tables must be checked in to source (not
  fetched at runtime — providers change pricing without notice and
  silent failures are dangerous).
- Privacy: never log per-message cost to a remote service.

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I'm building a cost dashboard + per-session budget gate for an LLM
agent. Cost is tracked in Rust (estimated_cost_usd field on each
session insight); UI is SwiftUI. The agent uses Claude Sonnet 4.6,
Claude Opus 4.6, and Perplexity Sonar Pro.

Questions:

1. What's the canonical 2026 pricing for: (a) Claude Sonnet 4.6
   input/output/cache-read/cache-write per million tokens,
   (b) Claude Opus 4.6 same, (c) Perplexity Sonar Pro input/output?
   Cite source URLs from each provider's official docs.

2. How do I structure a Swift `enum ProviderPricing` so adding a
   new provider is one struct literal? Show idiomatic Swift 6.2.

3. For the dashboard UI, what do other agent apps (Cursor,
   Continue, Cody) show? Screenshots/descriptions of their cost
   surfaces.

4. For the budget gate, when should it fire — before tool call,
   before LLM call, or both? What's the right user prompt: "you
   spent $0.50, continue?" vs "you're about to spend $0.05 on the
   next call, continue?"

5. Privacy: should cost data ever leave the device? If I want
   per-month aggregates without telemetry, where do I store the
   running total (Keychain? File? UserDefaults)?

6. Real-world examples of LLM apps with per-session budget caps —
   describe the UX patterns and any pitfalls.

Output: a complete spec for both the SwiftUI dashboard and the
Rust-side budget gate, with code snippets, file paths, and the
provider pricing table baked in.
```

---

## W9.7 — Vault sidebar selector

### What it is
A SwiftUI sidebar view that exposes the LIVING_VAULT_ARCHITECTURE
"Vault-Per-Model" registry — each model (Qwen3, Hermes-3,
Claude Sonnet, Claude Opus, Perplexity, etc.) gets its own vault +
graph, and the user switches between them.

### Why for Epistemos
- The model_profiles memory says: "v2: models (not agents) are
  primary entity, each with vault + graph; cloud models same but
  no fine-tuning." This UI is the surface for that.
- Solo developer (jojo) wants to compare model performance on the
  same task by switching vaults.

### Files touched
- `Epistemos/Models/ModelVaultRegistry.swift` (already exists per
  memory — verify)
- `Epistemos/Views/Sidebar/VaultSelectorView.swift` (new)
- `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` (already
  exists — extend to be the selector site)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I'm building a vault selector sidebar — like Obsidian's vault
switcher but tied to LLM model identity (each model gets its own
vault).

Questions:

1. What's the canonical SwiftUI 6.2 pattern for a sidebar selector
   that shows "current vault" + "switch to..." menu without
   triggering a full view-tree rebuild on switch?

2. How do I architect the underlying GRDB / SwiftData container
   swap so switching vaults takes <100ms? Multiple containers vs
   one container with a "vault_id" predicate on every fetch?

3. Show me the Obsidian vault-switching UX in detail (the
   keyboard shortcut, the modal, the recents list). What did
   they get right?

4. For the "model identity" tie-in: should switching the model
   automatically switch the vault, or are they orthogonal?
   What's the principle of least surprise?

5. Privacy / sandbox: each vault may live in a different security-
   scoped folder. How do I gracefully handle the case where the
   user revokes access to a vault folder mid-session?

Output: a complete UX spec + Swift code snippets for the selector,
the swap mechanic, and the GRDB container architecture.
```

---

## W9.8 — Approval modal (PausedForApproval surface)

### What it is
A SwiftUI modal that surfaces `SessionState::PausedForApproval {
tool_name, args_json, deadline_secs }` (defined in
`agent_core/src/session.rs:208`). The agent runtime stops the loop;
the modal asks the user to approve or deny the pending tool call;
on approval the loop resumes; on timeout (deadline_secs) the action
auto-denies.

### Why for Epistemos
- Today, dangerous tool calls (file delete, shell exec, network
  POST) either always-allow or always-deny based on policy. There's
  no "ask-once" interactive path.
- Required for the App Store build's "Bounded Intelligence OS" —
  every irreversible action gets human approval.
- Required for the Pro build's iMessage / shell escape — approval
  modal is the trust boundary between "automated agent" and
  "controlled-by-user".

### Files touched
- `agent_core/src/session.rs:208` (struct exists ✅)
- `agent_core/src/agent_loop.rs` (call site that triggers the pause —
  verify it currently fires `request_approval`)
- `Epistemos/Bridge/StreamingDelegate.swift` (forward the pause
  event to UI)
- `Epistemos/Views/Approval/ApprovalModal.swift` (new — the modal)
- `Epistemos/State/ApprovalQueue.swift` (new — coordinates pending
  approvals across multiple sessions)

### Approach options
1. **Modal sheet, blocking** — covers the chat surface; user can't
   dismiss without choosing. Strongest trust signal.
2. **Inline notification card** — appears in the chat as a special
   message; clickable to approve/deny. Lower friction; good for
   rapid-fire approvals.
3. **System notification + modal** — fires a UNUserNotification so
   the user can approve from anywhere; opens modal on click.

Recommended: **Option 2 inline** for in-app approvals, **Option 3
system notification** when the app is backgrounded.

### Performance / security / optimization angles
- Timeout: the deadline_secs field is in the struct — UI must
  visibly count down so the user knows when auto-deny kicks in.
- Replay safety: an approved action must NOT be re-prompted if the
  agent retries the same tool call (use args_json hash as dedupe).
- Audit log: every approval/denial decision logs to
  `<session>/approvals.jsonl` for security review.
- Test path: ensure the modal renders correctly when the agent
  fires it during a stream (not just between turns).

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I have a Rust agent loop that pauses execution and surfaces a
SessionState::PausedForApproval { tool_name, args_json,
deadline_secs } event to the Swift UI. I need the Swift side:
modal/inline UI, countdown timer, approval queue across multiple
sessions, audit log.

Questions:

1. Compare Anthropic's Computer Use approval flow, Cursor's tool-
   call approval, and Goose's permission prompts. What patterns
   work? What pitfalls?

2. SwiftUI 6.2 inline-card vs sheet vs window for an approval
   surface — which feels right for a chat-style UI? Cite Apple's
   Human Interface Guidelines on irreversible-action confirmation.

3. For the countdown timer (deadline_secs UI), should it pause when
   the user is reading vs always tick down? What happens if the
   app is backgrounded mid-countdown — system notification + auto-
   deny?

4. Audit log format: JSONL is convenient but Apple's PrivacyManifest
   may require flagging it. What's the right xattr / file-extension
   convention for "this file contains agent-action history"?

5. Multi-session: if 3 agent sessions all hit approval gates
   simultaneously, do I queue them (one modal at a time) or stack
   them (all visible)? UX research.

6. For the Pro build's shell-exec / iMessage approval: should the
   modal show a diff-like preview of "this command will do X" or
   just the raw command? How do I generate the preview deterministi-
   cally in Rust before showing in Swift?

Output: complete UX spec + SwiftUI code + Rust-side approval
queue protocol + audit log schema + system notification fallback
flow.
```

---

## W9.12 — Orphan Knowledge Rediscovery (Night Brain digest)

### What it is
A nightly background job that surfaces "forgotten but relevant"
notes — notes that were written, never linked, and have been
gathering dust. Uses existing HNSW + GRDB to find clusters of
orphaned notes that semantically relate to the user's recent
activity, then emits a digest the user reads in the morning.

### Why for Epistemos
- The "vault as memory" vision (project_meaning_anchors memory)
  depends on the system actively re-surfacing forgotten work.
- Current Halo recall only fires on demand; this is the proactive
  counterpart.
- Differentiator vs Obsidian/Notion: those tools never tell you
  "you wrote about X 6 months ago, want to reconnect it?"

### Files touched
- `Epistemos/Engine/NightBrainScheduler.swift` (already exists —
  add OrphanRediscoveryJob)
- `Epistemos/Engine/OrphanKnowledgeRediscovery.swift` (new)
- `Epistemos/Views/DailyBriefing/OrphanRediscoverySection.swift`
  (new — surfaces in the daily brief)
- `agent_core/src/recall.rs` (extend with `find_orphans()` query)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to build a "forgotten knowledge" surfacer for a notes app —
a nightly job that finds notes the user wrote but never connected,
that semantically relate to recent activity, and surfaces them in
a morning digest.

Questions:

1. What's the canonical algorithm for "orphan detection" in a
   knowledge graph? Connected-component analysis? Pagerank with
   reverse-link weighting? Cite papers.

2. Given my existing HNSW (usearch 2.24) + BM25 (tantivy 0.22) +
   RRF fusion, how should I combine "semantic similarity to recent
   activity" with "low link degree" into a single relevance score?

3. What's the right surfacing UX — daily digest email (intrusive),
   morning notification (less intrusive), or in-app card the user
   sees on first launch? Compare Roam's Random Note feature, Reflect's
   "Today's Forgotten Notes", and Obsidian's Random Note plugin.

4. For the "you wrote about X 6 months ago" suggestion, how do I
   compute the right confidence threshold so the user doesn't get
   noise (low-confidence) or banalities (already-linked notes)?

5. For the on-device LLM step (using Apple Foundation Models 3B
   to compose the digest), what's the right prompt that produces
   a 2-3 sentence "why this matters" annotation per surfaced note?

6. Privacy: this job runs background — does macOS 26 enforce any
   power / focus-mode integration I should respect?

Output: complete spec — algorithm, data flow, UI surface, AFM
prompt template, scheduling integration with my existing
NightBrainScheduler.
```

---

## W9.13 — Daily Notes UI + FSRS surfacing

### What it is
A daily-notes view (one note per calendar day, à la Logseq /
Roam) plus FSRS-6 (spaced-repetition) surfacing of notes due for
review. FSRSDecayState already exists per W10.2 — this is the UI.

### Why for Epistemos
- Daily notes is the most-requested PKM feature pattern; without
  it, Epistemos feels less like a journaling tool than its peers.
- FSRS surfacing turns the vault into an active study companion —
  "today you should review these 5 notes" surfaced in the daily
  view.

### Files touched
- `Epistemos/Views/Journal/DailyNoteView.swift` (new)
- `Epistemos/Views/Journal/JournalCalendarSidebar.swift` (new)
- `Epistemos/Engine/FSRSDecayStore.swift` (already exists per AP5
  refactor — add `notesDueForReview(date:)` query)
- `Epistemos/Models/SDPage.swift` (already has `isJournal: Bool`
  and `journalDate: String?` — query against these)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I'm building daily notes (one note per calendar day) + FSRS-6
spaced-repetition surfacing for a PKM app. FSRS state is already
tracked in an actor-based store.

Questions:

1. Compare daily-notes UX in Logseq, Roam, Obsidian Daily Notes
   plugin, Reflect, Capacities, and Tana. Which patterns work?
   Specifically: calendar sidebar vs sticky header vs URL routing.

2. For SwiftUI 6.2 calendar sidebar, what's the canonical
   implementation that handles 10 years of dates without
   reinstantiating the view tree? DatePicker(.graphical) vs
   custom MonthView grid?

3. FSRS-6: what's the right surfacing cadence — show all due
   notes at once, or paginate by review difficulty? Cite the
   Anki / SuperMemo design literature.

4. For the "today's daily note", should it auto-create on app
   launch, on first edit, or never (always manual)? Compare the
   3 patterns from the apps above.

5. For backlinks in daily notes: should journal-day mentions (e.g.
   "[[2026-04-26]]") render as a special node type in the graph
   or just as regular links?

6. For the FSRS due-review surface: where in the daily-note view
   does it live — top sidebar, bottom card, separate sheet?

Output: complete UX spec, SwiftUI view hierarchy, FSRS query API
extension, daily-note auto-creation policy.
```

---

## W9.14 — Block References + Transclusion

### What it is
Block-level addressing — every paragraph/heading gets a stable ID
so other notes can `((block-id))` to embed it. Edits to the source
propagate to all transclusion points. Like Roam blocks but in a
markdown-native app.

### Why for Epistemos
- Block refs are the "unfair advantage" PKM feature — once users
  have them, they refuse to switch back.
- Critical for academic / research workflows (cite a specific
  paragraph from a long note).

### Files touched
- `js-editor/src/extensions/block-id.ts` (new — Tiptap extension
  that auto-assigns IDs)
- `js-editor/src/extensions/block-transclusion.ts` (new — renders
  `((id))` as live embed)
- `Epistemos/Sync/NoteFileStorage.swift` (extend to write block-ID
  metadata sidecar)
- `Epistemos/Engine/BlockReferenceIndex.swift` (new — maps
  block-id → source-note-id + offset)
- `agent_core/src/storage/vault.rs` (extend graph with block-ref
  edges)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I'm adding block references + transclusion to a markdown-native
PKM app. The editor is Tiptap (ProseMirror) in a WKWebView; the
data layer is GRDB + SwiftData; the graph is in Rust (agent_core
storage::vault).

Questions:

1. How does Roam Research store block IDs — UUID per block, or
   structural hash, or both? Performance tradeoffs for a 100k-block
   graph?

2. For markdown-native storage, where does the block ID live?
   HTML comment (<!-- id:abc123 -->), inline marker (^abc123 at
   end of line, à la Obsidian), YAML front-matter mapping? Trade-
   offs for portability + diffability?

3. For Tiptap (ProseMirror), show me a working extension that:
   (a) auto-assigns IDs to new blocks
   (b) preserves IDs across edits (don't regenerate on
       split/merge)
   (c) renders ((id)) tokens as live transclusions
   (d) handles edit propagation: editing the source updates every
       transclusion display in real-time

4. How does Logseq handle the "edit a transcluded block" UX — do
   you edit in place (changes flow back to source) or open the
   source in a popover? UX research.

5. For the graph (Rust), should block-refs be a separate edge
   type from page-links, or unified? How do I efficiently query
   "all transclusions of block X" at 100k blocks?

6. Security: a malicious vault could have circular transclusions
   (block A refs B refs A). What's the right depth limit + cycle
   detection algorithm?

Output: complete spec — Tiptap extension code, ProseMirror schema
extension, sidecar storage format, Rust graph schema, cycle-
detection algorithm.
```

---

# Tier 4 — Performance Items

## W9.10 — TurboQuant KV cache compression

### What it is
TurboQuant (Google ICLR 2026) is a KV-cache compression scheme
that combines bit-packing + outlier separation to deliver 6× memory
reduction with 25-32% throughput gain on M2 16GB. KV cache is the
attention key/value tensors that grow linearly with context length;
compressing them is the difference between 4K and 32K context on
constrained hardware.

### Why for Epistemos
- 16GB Mac ceiling is the hard constraint. At 32K context, KV cache
  for a 7B model can hit 8-10GB — that's the entire weights budget
  blown.
- 6× compression = 32K context for the same memory footprint as 5K
  uncompressed. Game-changing for "vault as context" workflows.

### Files touched
- `Epistemos/Engine/MLXService.swift` (where MLX inference runs)
- `Epistemos/Engine/MLXCacheManager.swift` (new — wraps the KV
  cache with compression layer)
- The local mlx-swift-lm fork referenced in project_mamba2_runtime
  (need to add a custom KV cache adapter)

### Approach options
1. **Wait for MLX upstream** — Apple is working on this; could land
   in mlx-swift Q2 2026.
2. **Patch the mlx-swift-lm fork** — already self-maintained per
   memory; add TurboQuant as a custom KV cache strategy.
3. **Hand-port the TurboQuant paper** — write a Metal kernel from
   the paper's algorithm spec.

Recommended: **Option 2** plus contribute back upstream once it
works.

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to implement TurboQuant (Google, ICLR 2026) KV-cache
compression in MLX-Swift for a 7B model on a 16GB M2 Mac. Goal:
extend usable context from ~5K to ~32K with no quality regression.

Questions:

1. Find the TurboQuant paper. Summarize the core algorithm: how
   does it compress, what bit-width, what's the outlier path?

2. Compare TurboQuant against: KIVI (W9.30), KVQuant, 8-bit
   per-channel, GPTQ-KV, AWQ-KV. Which is best for: (a) Apple
   Silicon GPU friendliness, (b) quality preservation on 4-bit
   weights base model, (c) implementation complexity.

3. Show me the existing MLX-Swift KV cache API surface — where
   would I plug in a custom compression strategy? Cite the
   mlx-swift-lm repo files.

4. For the Metal kernel side, what's the right launch geometry
   for a (batch, heads, seq_len, head_dim) tensor? Threadgroup
   size, memory layout?

5. Memory math: for Qwen3 7B 4-bit at 32K context, what's the
   uncompressed KV footprint, and what does TurboQuant promise
   to bring it down to?

6. Are there reference implementations in vLLM, llama.cpp, or
   any Rust LLM crate (mistralrs, candle) I can study?

Output: complete implementation plan — algorithm summary, MLX-
Swift integration point, Metal kernel skeleton, validation
benchmarks, fallback strategy if it doesn't ship in time.
```

---

## W9.15 — Static compile-time view routing macro

### What it is
A Swift macro that compiles SwiftUI navigation routes into a
static dispatch table — eliminating `AnyView` and the
AttributeGraph diff cost that comes with dynamic view trees.
Trade typesafety for compile-time perf.

### Why for Epistemos
- The AttributeGraph diff cost in deep view trees is the dominant
  cost in SwiftUI apps. Profiling shows AnyView-heavy paths can
  burn 200-300ms per frame.
- Once-per-build cost (macro expansion) trades for runtime
  speedup.

### Files touched
- New macro target in `Package.swift`
- `EpistemosMacros/RouteMacro.swift` (new)
- `Epistemos/Navigation/RouteRegistry.swift` (new — declarative
  route table)
- Refactor `Epistemos/App/RootView.swift` to use the new dispatch

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to build a Swift 6.2 macro that compiles SwiftUI navigation
routes into a static dispatch table to eliminate AnyView and
AttributeGraph diff overhead.

Questions:

1. What does the existing landscape look like — swift-navigation
   (Point-Free), TCA's Stack pattern, swift-coordinator? Why are
   they not enough?

2. Show me a working Swift macro that:
   - Takes a `@RouteEnum` declaration on an enum
   - Generates a `route(to:) -> some View` static dispatch function
   - Is fully type-safe (no AnyView)

3. AttributeGraph diff cost: cite the WWDC sessions or blog posts
   that quantify the AnyView penalty on M-series.

4. How do I handle dynamic routes (e.g. "open note with ID X"
   where X is runtime data)? Generic association vs separate
   dispatch?

5. For a real PKM app with ~30 view types, is the macro worth the
   complexity vs hand-rolled NavigationStack? Where's the
   crossover point?

6. Show me 2-3 production Swift macros that do similar codegen so
   I can study the pattern.

Output: complete macro source + integration example + perf
benchmark methodology.
```

---

## W9.24 — Metal zero-copy graph buffers

### What it is
Use `MTLDevice.makeBuffer(bytesNoCopy:length:options:deallocator:)`
to share page-aligned Rust allocations directly with Metal — no
copy from Rust → Swift → GPU. For a 10k-node graph rendering at
120Hz, this saves ~50MB/s of allocation churn.

### Why for Epistemos
- The MetalGraphView already pushes large vertex/index buffers per
  frame. Today these are copied from Rust → Swift → Metal staging.
- 120Hz rendering at 10k nodes: every byte of allocation churn
  matters.

### Files touched
- `Epistemos/Engine/MetalGraphView.swift`
- `Epistemos/Engine/MetalRuntimeManager.swift`
- `agent_core/src/graph_buffers.rs` (new — page-aligned alloc)
- FFI surface to expose the Rust pointer + length to Swift

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want zero-copy Metal buffers backed by Rust allocations
(makeBuffer(bytesNoCopy:)). The Rust side allocates page-aligned
vertex + index buffers; the Swift side wraps them as MTLBuffer
without a CPU copy.

Questions:

1. Show me the canonical pattern: Rust allocates with mmap or
   posix_memalign(4096), exposes (ptr, len, deallocator) to Swift,
   Swift wraps with makeBuffer(bytesNoCopy:). Cite Apple
   documentation on alignment + lifetime requirements.

2. What goes wrong if the Rust deallocator runs while Metal still
   holds the buffer? How do I sequence with MTLCommandBuffer's
   completion handler so the dealloc happens after GPU finishes?

3. For dynamic-size buffers (vertex count changes per frame),
   should I reallocate every frame or use a ring buffer / arena?

4. Performance: cite real benchmarks of bytesNoCopy vs the regular
   makeBuffer + memcpy path. When does the savings actually
   matter vs not?

5. Security: bytesNoCopy reads/writes happen at the GPU's
   discretion — is there a TOCTOU risk if Rust mutates the buffer
   while GPU reads?

6. UMA (Unified Memory Architecture) on Apple Silicon: does
   bytesNoCopy actually skip a copy, or does the GPU driver still
   do an internal page mapping?

Output: complete pattern with Rust + Swift + FFI code, lifetime
diagram, error handling, benchmark methodology.
```

---

## W9.28 — Blelloch scan in Metal for Mamba-2 prefill

### 🔬 Research findings (background agent 2026-04-26) — **REALITY CHECK**
- **The Mamba-2 SSD ALREADY lives in Metal**. `Epistemos/Shaders/Mamba2/inter_chunk_scan.metal` (253 lines) explicitly implements **3-dispatch Reduce-then-Scan** because Apple GPUs **lack Forward-Progress Guarantees (FPG)** — Decoupled Lookback (NVIDIA SOTA) **hangs** on Apple. The kernel header has a SAFETY comment to this effect.
- 14 pipelines already compile via `MetalRuntimeManager` with binary-archive caching.
- **So the task is NARROWER than "implement scan"**: replace the Phase 2 sequential prefix scan (currently single-threadgroup serial) with a true **work-efficient Blelloch up-sweep/down-sweep** to win when n_chunks is large (e.g., 100K-token prompt → ~780 chunks at Q=128).
- **References to cite in shader comments**:
  - Matthew Kieber-Emmons, "Efficient Parallel Prefix Sum in Metal for Apple M1" (Better Programming, Medium) — covers raking, SIMD-group cooperative, and Blelloch on Apple Silicon
  - Mark Harris, "Parallel Prefix Sum (Scan) with CUDA" (NVIDIA, 2007 PDF) — canonical Blelloch reference, port directly
  - WWDC20 "Optimize Metal Performance for Apple silicon Macs" (session 10632)
  - Tri Dao / Goomba Lab, "Mamba-2 Part IV — Systems"
- **Files**:
  - `Epistemos/Shaders/Mamba2/inter_chunk_scan.metal` — replace serial Phase 2
  - `Epistemos/Engine/MetalRuntimeManager.swift` — add `interChunkScanBlellochPipeline`, increment archive version
  - `agent_core/src/storage/ssm_state.rs` — state-buffer layout, if D_head padding needed for SIMD
  - `EpistemosTests/Mamba2MetalRuntimeTests.swift` — numerical parity vs current scan
- **16GB feasibility: YES** for shader work. The associative `(decay, state)` pair is non-commutative but associative — Blelloch fits.
- **Risk: HIGH** — non-commutative associative scan is hardest scan flavor; numerical drift between FP16 paths.
- **Caveat**: `WAVE_9_POLISH_AND_NATIVE.md` line 244 explicitly warns: *"Mamba history: master plan explicitly notes prior Mamba/SSM attempts failed; Phase 2 stays on standard Transformers. Tier 5 W9.28 (Blelloch scan) remains a research item, NOT a hard plan dependency."*
- **Effort: XL (5-7 sessions)**. Recommend doing W9.26 + W9.27 first; **gate W9.28 on Mamba-2 actually being on the active roadmap**, not just the research backlog.

### What it is
Blelloch scan = parallel-prefix-sum, the GPU primitive that lets
you compute `[a, b, c, d] → [0, a, a+b, a+b+c]` in O(log N) parallel
steps. Mamba-2's selective state-space update is fundamentally a
scan — implementing it in Metal lets prefill (initial context
encoding) run in milliseconds instead of seconds.

### Why for Epistemos
- Mamba-2 is the architecture behind the "vault as memory" vision
  (project_mamba2_runtime memory). Phase 1A is complete — save/
  load/resume works. Prefill is the bottleneck.
- 100K-token vault prefill in 5 seconds (target) requires Metal
  scan. Today's prefill is sequential.

### Files touched
- New Metal shader: `Epistemos/Engine/Shaders/BlelloochScan.metal`
- `Epistemos/Engine/MambaPrefillService.swift` (new)
- mlx-swift-lm fork (custom prefill kernel)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to implement Blelloch (work-efficient) parallel prefix sum
in Metal compute shaders to accelerate Mamba-2 prefill on Apple
Silicon. Goal: 100K-token prefill in <5 seconds for a 7B Mamba-2
model.

Questions:

1. Walk me through the Blelloch up-sweep + down-sweep algorithm.
   What's the work complexity vs Hillis-Steele (the simpler but
   less efficient scan)?

2. Show me a complete Metal Shading Language implementation of
   Blelloch scan for Float32 arrays of arbitrary length. Handle
   the case where input length isn't a power of 2.

3. For Mamba-2 specifically, the scan operator is a 2x2 matrix
   multiply (associative but not commutative). How do I generalize
   the scan to arbitrary associative ops in MSL?

4. Threadgroup size, simdgroup ops (simd_prefix_inclusive_sum on
   M2+), shared memory bank conflicts — what are the right
   parameters for M2/M3?

5. Compare against Apple's MPSGraph reduce/scan primitives. Are
   they fast enough to skip writing my own?

6. Cite real implementations from llama.cpp Metal backend, MLX
   Swift, candle's metal feature, or vLLM Metal.

7. Validation: how do I unit-test a parallel scan against a
   sequential reference?

Output: complete .metal shader, Swift host code, validation suite,
integration point for the Mamba-2 prefill path.
```

---

## W9.30 — KIVI per-channel/per-token KV quantisation

### 🔬 Research findings (background agent 2026-04-26)
- **`MLXLMCommon.QuantizedKVCache` already exists** at `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift` lines 700-951 — affine quantization, configurable `groupSize`/`bits`, default 8-bit, supports 4-bit and 2-bit. **Currently quantizes both K and V identically per-group.** Activated via `GenerateParameters(kvBits: 4, kvGroupSize: 64, quantizedKVStart: 0)` and `maybeQuantizeKVCache(...)`.
- **The KIVI asymmetry**: K per-channel (group across channel dim), V per-token (group across token dim). 2.6× peak-memory cut, ~4× batch.
- **Better alternative discovered**: **`arozanov/turboquant-mlx` + `SharpAI/SwiftLM` (March 2026)** — fused Metal kernels for PolarQuant; **3-bit K + 2-bit V (turbo3v2)** and **4-bit K + 2-bit V (turbo4v2)**; 4.6× compression at 98% FP16 speed; **native Swift port available**. Strictly supersedes plain KIVI for M-series.
- **Existing reference impl in repo**: `epistemos-core/src/instant_recall/kv_cache_quant.rs` (676 lines) — full per-channel K + per-token V, INT2/4/8 progressive degrade. **This is the recall layer's reference**, NOT runtime path. Don't move into MLX inference loop (CPU round-trip).
- **Memory math (Qwen3.5 7B 4-bit, 8K context)**: 28 layers, 4 KV-heads (GQA), head_dim=128.
  | Config | KV bytes / 8K |
  | ------ | ------------- |
  | FP16 baseline | **448 MB** |
  | 4-bit affine (today) | ~120 MB (~27%) |
  | **KIVI 2-bit** | **~58 MB (~13%)** |
  | TurboQuant turbo4v2 | ~85 MB (~19%) |
  
  Frees ~390 MB → directly enables 16K-32K context within 10-11 GB realistic budget on 16GB Mac.
- **Files**:
  - `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift` — add `KIVIKVCache: QuantizedKVCacheProtocol` next to existing `QuantizedKVCache` (lines 700-951). Same protocol; `updateQuantized` quantizes K with `groupAxis = -1 (channel)` and V with `groupAxis = -2 (token)`. Reuse `quantizedScaledDotProductAttention` (line 1456) — already axis-agnostic.
  - `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/Evaluate.swift` — extend `GenerateParameters` with `kvScheme: KVQuantScheme = .affine` (`.affine` | `.kivi` | `.turboQuantV4V2`). Update `maybeQuantizeKVCache` (line 1560) to dispatch.
  - `Epistemos/Engine/MLXInferenceService.swift` — surface `LocalMLXRequest.kvScheme`. For 16GB Macs default to `.kivi` once context > 4096; keep `.affine` for short prompts.
  - `Epistemos/State/InferenceState.swift` + `Epistemos/Views/Chat/ModelAboutSheet.swift` — display "KV: 2-bit KIVI" so user sees what's running.
- **Risk: Swap-in replacement** affects every inference. Mitigations:
  - Keep `kvScheme = .affine` as default; ship `.kivi` as opt-in for 16GB Mac path.
  - Add perplexity regression test on fixed Qwen3.5 7B prompt set BEFORE flipping defaults.
  - `RotatingKVCache.toQuantized` already `fatalError`s — don't combine sliding window + KIVI in v1.
  - Tokenizer-state and prompt-cache files (`savePromptCache` / `loadPromptCache`, KVCache.swift line 1168) need new class name `"KIVIKVCache"` in dispatch table.
  - Wire as feature flag `EPISTEMOS_KV_KIVI=1` first ship — mirror existing `EPISTEMOS_GRAPH_INDEX_CHATS` rollback pattern.
- **Recommended sequence**: KIVI in pure MLX ops first (de-risk protocol fit), then optionally vendor `arozanov/turboquant-mlx`'s fused Metal kernel for FP16 decode speed.

### What it is
KIVI (paper: "KIVI: A Tuning-Free Asymmetric 2-bit Quantization
for KV Cache", 2024) compresses KV cache with 2-bit quantization
using DIFFERENT axes for K and V: 2-bit per-channel for K (because
keys have outlier channels), 2-bit per-token for V (because values
have outlier tokens). Tuning-free = works without retraining.

### Why for Epistemos
- Same goal as W9.10 (TurboQuant) — extend usable context. KIVI
  is older but more battle-tested; TurboQuant is newer/better but
  less mature.
- Strategy: ship KIVI now, swap to TurboQuant if/when it
  outperforms.

### Files touched
- Same as W9.10.
- New: `Epistemos/Engine/KIVIQuantization.swift` (Swift wrapper)
- New Metal kernels for asymmetric K/V quant

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to implement KIVI (2024 paper, asymmetric 2-bit KV quant)
in MLX-Swift for a 7B model on a 16GB M2 Mac.

Questions:

1. Find the KIVI paper. Explain the asymmetric axis choice (K
   per-channel, V per-token) — what does the empirical analysis
   show about outlier distribution?

2. Quality: at 2-bit, what's the perplexity delta on standard
   benchmarks (WikiText, LongBench)? Cite the paper's tables.

3. Show me the MLX-Swift KV cache API surface — same question as
   for TurboQuant: where do I plug in?

4. Memory math: for Qwen3 7B 4-bit at 8K context, what's the
   uncompressed KV footprint, what does KIVI bring it to?

5. Existing implementations: is there a Rust crate (candle, mistralrs)
   or vLLM extension that implements KIVI? Cite repos.

6. Comparison: KIVI vs TurboQuant vs KVQuant — pick one for
   Epistemos based on (a) Apple Silicon friendliness, (b) tuning-
   free promise, (c) implementation complexity, (d) recency of
   active maintenance.

7. Quantization-aware vs post-hoc: KIVI claims tuning-free, but
   can per-model calibration improve quality? Worth the complexity?

Output: complete impl plan — algorithm, MLX integration point,
Metal kernels, validation, KIVI vs TurboQuant decision matrix.
```

---

# Tier 4 — Hardening Items

## W9.21 — Honest FFI (Arc::into_raw + ~Copyable wrappers)

### 🔬 Research findings (background agent 2026-04-26)
- **`agent_core` is ALREADY honest** — UniFFI uses handle-managed Arc. No work needed there.
- **Raw `Box::into_raw` lives in 5 crates** that need the rewrite:
  - `epistemos-shadow/src/lib.rs` (lines 102-260) — currently uses global `RwLock<Option<Backend>>`; rip and return `*const ShadowEngine` from `shadow_open_at`; add `shadow_retain` / `shadow_release`
  - `syntax-core/src/ffi.rs` (lines 60, 75)
  - `substrate-core/src/ffi.rs` (lines 57, 67)
  - `substrate-rt/src/lib.rs` (lines 61, 146)
  - `graph-engine/src/lib.rs` (lines 573, 585, 1521, 1548, 1870, 1983, 2062, 2095, 2435, 2448 — engine + boxed-slice result vectors)
- **Swift consumer files**: `RustShadowFFIClient.swift`, `SyntaxCoreService.swift`, `RustEventRingClient.swift`, `KnowledgeCoreBridge.swift`, `GraphEngine.swift`, `EventStore.swift`, `EventDrain.swift` — adopt `~Copyable` handle struct OR retain/release-wrapping `final class`.
- **Concrete pattern** (paste-ready):
  ```rust
  // epistemos-shadow/src/lib.rs (replaces global RwLock<Option<Backend>>)
  #[unsafe(no_mangle)]
  pub extern "C" fn shadow_open_at(path: *const c_char) -> *const ShadowEngine {
      let backend = RealBackend::open(unsafe { c_str(path)? })?;
      Arc::into_raw(Arc::new(ShadowEngine { backend }))
  }
  #[unsafe(no_mangle)]
  pub unsafe extern "C" fn shadow_retain(p: *const ShadowEngine) {
      if !p.is_null() { Arc::increment_strong_count(p); }
  }
  #[unsafe(no_mangle)]
  pub unsafe extern "C" fn shadow_release(p: *const ShadowEngine) {
      if !p.is_null() { Arc::decrement_strong_count(p); }
  }
  ```
  ```swift
  public struct ShadowEngineHandle: ~Copyable {
      private let raw: OpaquePointer
      public init(openingAt path: String) throws {
          guard let p = path.withCString({ shadow_open_at($0) }) else {
              throw ShadowFFIError.openFailed
          }
          self.raw = OpaquePointer(p)
      }
      public borrowing func search(_ q: String) throws -> [ShadowHit] { ... }
      deinit { shadow_release(UnsafePointer(raw)) }   // single-owner drop
  }
  ```
- **Diff size**: ~700 LOC Rust + ~400 LOC Swift, ~12 files.
- **Risk: Medium-High** — touches 5 Rust crates; one wrong `decrement_strong_count` is a UAF. Requires TSan stress test + 2,679-test suite green.
- **Ship in 4 PRs**: (1) `epistemos-shadow` headline; (2) `syntax-core` + `substrate-core` + `substrate-rt`; (3) `graph-engine`; (4) Swift `~Copyable` consumer cutover.

### What it is
"Honest FFI" = the Rust side uses `Arc::into_raw`/`from_raw` to
manage refcounted handles passed to Swift, and the Swift side
wraps those raw handles in `~Copyable` (move-only) Swift types so
the type system enforces single-owner semantics — no
double-frees, no use-after-free, all checked at compile time.

### Why for Epistemos
- The shadow FFI today uses raw pointers + Box::from_raw — fragile
  if Swift forgets to call the dealloc function.
- Swift 6.2 ~Copyable types finally make move-only enforcement
  practical at the type system level. Caught at compile time, not
  runtime.

### Files touched
- `agent_core/src/lib.rs` (FFI export side)
- `epistemos-shadow/src/lib.rs` (shadow FFI)
- `Epistemos/Engine/RustShadowFFIClient.swift` (Swift wrapper)
- `omega-mcp/src/dispatcher.rs` (any FFI exports)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to harden my Rust → Swift FFI boundary using:
- Rust side: Arc::into_raw + Arc::from_raw for refcounted handles
- Swift side: ~Copyable wrapper types for move-only semantics

Questions:

1. Compare Arc::into_raw vs Box::into_raw vs std::ptr::raw alone.
   When does each apply? Cite Rust API docs + Rustonomicon.

2. Show me a complete Rust FFI export pattern using Arc::into_raw
   that:
   - Creates an opaque handle on the Swift side
   - Allows Swift to call methods that take a borrowed reference
     (no clone overhead)
   - Frees correctly when Swift drops the handle

3. Swift 6.2 ~Copyable: show me a wrapper type that:
   - Holds an opaque OpaquePointer
   - Cannot be copied (compile error)
   - CAN be moved
   - Calls the Rust dealloc on deinit
   - Provides borrowing accessor methods

4. For callbacks (Rust calls into Swift), what's the canonical
   pattern when the Swift callback may run on a different
   DispatchQueue than the Rust call site? UniFFI 0.28 vs 0.29
   handling.

5. Soundness: are there known UB patterns at the Arc::into_raw /
   ~Copyable boundary I should avoid? Cite the Rustonomicon or
   miri docs.

6. Compare Honest FFI to CXX (the dtolnay crate) and UniFFI's
   built-in handle management. When is hand-rolled Arc::into_raw
   worth it over those abstractions?

Output: complete FFI hardening guide — Rust pattern, Swift
~Copyable wrapper, callback handling, compile-time invariants
documented, miri test plan.
```

---

## W9.22 — Typestate Islands for MLX/subprocess lifecycles

### 🔬 Research findings (background agent 2026-04-26)
- **W9.21 must land first** — typestate Islands hold the Honest-FFI handles. Doing W9.22 first means a second rewrite when W9.21 lands.
- **No external crate needed** — phantom-type typestate using `PhantomData<S>` markers; each transition `consumes self`. `typed-builder` 0.20 covers builder typestate; `state_machine_future` is over-engineered.
- **`~Copyable` interacts awkwardly with `actor`** — AFMSessionPool may need to switch from `actor` to `final class` + `Mutex` because actor methods can't easily return `~Copyable` values across isolation boundaries (Swift 6.2 limitation; SE-0437 is partial fix). Spike this with a 1-line proof BEFORE the rewrite.
- **Concrete pattern** (paste-ready):
  ```rust
  // agent_core/src/runtime/mlx_session.rs (NEW file)
  pub struct Loaded;  pub struct Warm;  pub struct Generating;  pub struct Disposed;
  pub struct MlxSession<S> { inner: Arc<MlxInner>, _state: PhantomData<S> }
  impl MlxSession<Loaded> {
      pub fn warm_up(self) -> MlxSession<Warm> { /* prefill */ self.transition() }
  }
  impl MlxSession<Warm> {
      pub fn begin(self) -> MlxSession<Generating> { self.transition() }
  }
  impl MlxSession<Generating> {
      pub fn step(&mut self, t: Token) -> Token { ... }
      pub fn finish(self) -> MlxSession<Warm> { self.transition() }
  }
  impl<S> MlxSession<S> { pub fn dispose(self) -> MlxSession<Disposed> { ... } }
  // Disposed has zero methods → calling `.step()` on it is a compile error.
  ```
- **Files** (concrete paths):
  - NEW: `agent_core/src/runtime/mlx_session.rs`
  - `Epistemos/Engine/AFMSessionPool.swift` (PooledSession → typestate enum of move-only structs)
  - `Epistemos/Engine/MLXInferenceService.swift` (LocalMLXRequest → wrap call in Loaded → Warm → Generating → Warm typestate)
  - `Epistemos/Omega/Inference/MLXConstrainedGenerator.swift`, `ReasoningLoopService.swift`
  - `Epistemos/LocalAgent/LocalAgentLoop.swift`
  - `Epistemos/Engine/LSPServerProcess.swift` — same pattern (Spawned → Initialized → Serving → ShutDown). Hermes subprocess lives in agent_core, not Swift, so no separate Swift wrapper needed.
- **Diff size**: ~400 LOC Rust + ~250 LOC Swift, 5-6 files.
- **Risk: Medium**. Pure compile-time win, no runtime semantics change.
- **Ship in 1 PR** after the actor-vs-class spike — fully additive.

### What it is
Typestate pattern in Rust = a struct with a phantom-type parameter
encoding its current "state". Methods are only callable in the
right state, enforced at compile time. "Islands" = applying it to
specific lifecycles (MLX session: Loaded → Warm → Inference →
Disposed; Hermes subprocess: Spawned → Initialized → Ready →
Terminated; AFM session pool entry: Created → Warm → Stale).

### Why for Epistemos
- Today the MLX session lifecycle has implicit invariants (don't
  call inference on a disposed session) enforced only by runtime
  checks.
- Subprocess lifecycle bugs are notoriously hard — typestate moves
  the assertion to compile time.
- 16GB ceiling means session disposal is critical; typestate helps
  reason about cleanup paths.

### Files touched
- `agent_core/src/inference/mlx_session.rs` (new — typestate
  wrapper)
- `agent_core/src/hermes_subprocess.rs` (typestate wrapper)
- `Epistemos/Engine/AFMSessionPool.swift` (Swift-side phantom-type
  equivalent — ~Copyable + state enum)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to apply the typestate pattern in Rust to enforce correct
lifecycle order for: (a) MLX inference sessions (Loaded → Warm →
Inference → Disposed), (b) Hermes Python subprocess (Spawned →
Initialized → Ready → Terminated), (c) AFM session pool entries
(Created → Warm → Stale).

Questions:

1. Show me the canonical Rust typestate pattern using PhantomData
   + zero-sized state markers. Cite the "typestate-rs" crate or
   show a hand-rolled version.

2. For my three lifecycles, draw out the full state diagram and
   show the Rust struct + impl blocks that enforce it. Include
   the state-transition methods (e.g. fn warm_up(self: Loaded) ->
   Warm).

3. How do I handle "fallible transitions" (warm-up fails, where
   does the session land)? Result<NextState, Error> vs returning
   the original state on error vs Disposed.

4. For the Swift side, can I express the same invariants? Swift
   6.2 ~Copyable + phantom types vs runtime state check. When is
   each appropriate?

5. Does the typestate pattern compose with Tokio's async/await
   (the MLX session is used from async code)? Any pitfalls with
   await points crossing state transitions?

6. Compare typestate vs runtime state machine vs Drop-based
   cleanup. Which is most appropriate for each of my three
   lifecycles?

7. Cite real production Rust codebases using typestate at scale.

Output: complete typestate pattern + worked examples for all
three lifecycles + tests showing the compile-time guarantees +
benchmark to confirm zero runtime cost.
```

---

## W9.23 — Bit-packed circuit breaker

### What it is
Replace the current circuit breaker (likely a Mutex<Option<state>>
or similar) with a single AtomicU64 bit-packed structure: state in
2 bits, recent failure count in 16 bits, last-fail timestamp in 32
bits, generation counter in 14 bits. Read/write with a single
compare-exchange — lock-free, zero-allocation, cache-line friendly.

### Why for Epistemos
- Per-call latency in the agent loop is dominated by lock contention
  on shared resources. The circuit breaker is on the hot path for
  every cloud API call.
- popcnt + AtomicU64 = ~5ns per check vs ~50ns for a Mutex.
- Resilience pattern: trip, half-open, retry, all encoded in 64
  bits.

### Files touched
- `agent_core/src/resilience.rs` or `agent_core/src/circuit_breaker.rs`
  (find current location)
- `agent_core/src/providers/claude.rs` + `perplexity.rs` (call
  sites)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to implement a lock-free, zero-allocation circuit breaker
using a single AtomicU64 with bit-packed state (2 bits = state,
16 bits = recent failure count with sliding window, 32 bits =
last-fail Unix epoch seconds, 14 bits = generation counter).

Questions:

1. Show me the canonical Rust pattern for bit-packing into an
   AtomicU64 with safe accessor methods (no manual masking at
   call sites). const fn for the pack/unpack ops.

2. For the sliding-window failure count, how do I update it
   atomically without TOCTOU? Compare-and-swap loop vs fetch_add
   + post-hoc reset.

3. What's the right state machine? Closed → Open → HalfOpen →
   Closed/Open. Where do the transitions trigger?

4. For "recent" failures (e.g. 5 failures in last 60s), how do I
   encode the sliding window in 16 bits? Approximate count via
   exponential decay vs exact count via ring buffer?

5. Cache-line behavior: if multiple call sites contend on the
   AtomicU64, do I need padding to avoid false sharing? Crossbeam's
   CachePadded vs hand-rolled.

6. Compare bit-packed AtomicU64 to: failsafe-rs, circuit-breaker
   crate, tower::ratelimit, governor. Performance + ergonomics
   tradeoffs.

7. How do I observability-instrument this without breaking the
   lock-free property? Atomic counters for {trips, half-open
   probes, recovery} as separate fields.

Output: complete circuit breaker module + tests + benchmark
showing per-call latency vs the existing implementation.
```

---

## W9.29 — Thermal-aware breaker throttling

### What it is
Pair the W9.23 circuit breaker with thermal monitoring: when
macOS reports thermal pressure, preemptively throttle inference
calls before the OS hardware-throttle kicks in. Better UX than
waiting for tok/s to crater.

### Why for Epistemos
- Thermal throttle on MLX inference is the dominant UX killer —
  the user sees responses slow from 60 tok/s to 8 tok/s with no
  warning.
- Preemptive throttle = lower peak load, longer sustained
  throughput, no cliff.

### Files touched
- `Epistemos/State/ThermalMonitor.swift` (new — wraps
  IOPMRootDomain)
- `Epistemos/Engine/MLXService.swift` (consult thermal state
  before each inference)
- `agent_core/src/circuit_breaker.rs` (FFI in the thermal signal)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want a thermal-aware throttle that preemptively reduces
inference throughput before macOS hardware-throttles the M-series
chip. Goal: smooth degradation, not a cliff.

Questions:

1. What APIs does macOS 26 expose for thermal monitoring? Compare
   ProcessInfo.thermalState vs IOPMRootDomain notifications vs
   IOReport (private framework). Which is App Store safe?

2. What's the correlation between thermalState (Nominal / Fair /
   Serious / Critical) and actual hardware throttle on M2/M3/M4?
   Cite WWDC sessions or Apple docs.

3. For my MLX inference service, what's the right back-pressure
   mechanism? Rate-limit token-emission rate? Reduce batch size?
   Switch to a smaller model? Cite Apple's recommendations.

4. For the Swift → Rust signal path (Swift owns the thermal
   monitor; Rust owns the circuit breaker), what's the lowest-
   latency way to push thermal updates? UniFFI callback vs
   shared atomic.

5. Battery vs AC power: should thermal-throttle behavior differ
   on battery (more aggressive) vs AC (only when serious)? Cite
   IOPSCopyPowerSources patterns.

6. UI: should the user see a "thermal throttle active" indicator?
   Where does it live? Compare Activity Monitor's CPU% indicator,
   Discord's "voice quality" indicator, etc.

7. Test methodology: how do I reproduce thermal throttle on
   demand for testing? Run heavy MLX inference + concurrent CPU
   load? Use Apple's powermetrics CLI?

Output: complete thermal monitor + integration with circuit
breaker + UI indicator + test methodology.
```

---

# Tier 4 — Architecture

## W9.25 — Grammar-constrained logit masking (mlx-swift-structured)

### 🔬 Research findings (background agent 2026-04-26) — **HUGE WIN: 90% already done**
- **`mlx-swift-structured` is ALREADY referenced in the codebase** at `Epistemos/LocalAgent/LocalToolGrammar.swift` lines 3-4 and 67-103, behind `#if canImport(MLXStructured) && canImport(CMLXStructured) && canImport(JSONSchema)` guards. **The DSL is wired but the package is not currently linked**, so every call falls into the `omegaSoftGuidance` else-branch.
- **The fix is mostly a `project.yml` + Package.resolved change** — link the package, remove the canImport guards, flip `isFullyConstraining` to true.
- **MLXLMCommon.LogitProcessor exists** at `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/Evaluate.swift` (3 hooks: `prompt(_:)`, `process(logits:)`, `didSample(token:)`).
- **Current `MLXConstrainedGenerator`** at `Epistemos/Omega/Inference/MLXConstrainedGenerator.swift` already uses `LogitProcessor` but only does soft EOS biasing (`isFullyConstraining = false`).
- **Recommendation: Swift+MLX directly** (NOT Rust+llguidance). Reasons:
  - Masking lookup must run inside MLXLMCommon's `TokenIterator` loop — FFI per token (50–200 ms/response) defeats the purpose.
  - mlx-swift-structured already targets this exact integration point with a Swift-native FSA.
- **API sketch** (paste-ready):
  ```swift
  let plan = LocalToolGrammar.buildToolCallingPlan(tools: tools, forceThinking: false)
  let processor = GrammarMaskedLogitProcessor(grammar: plan.grammar!,
                                              tokenizer: tokenizer,
                                              vocab: tokenizer.vocab)
  let iterator = try TokenIterator(input: prompt, model: model, cache: cache,
                                   processor: processor, sampler: sampler)
  ```
- **Files**:
  - `project.yml` — add `mlx-swift-structured` SwiftPM dep; add `MLXStructured`, `CMLXStructured`, `JSONSchema` to dependencies
  - `Epistemos/LocalAgent/LocalToolGrammar.swift` — already complete; remove `canImport` guards once package linked
  - `Epistemos/Omega/Inference/MLXConstrainedGenerator.swift` — replace `JSONSchemaLogitProcessor` (soft EOS) with `GrammarMaskedLogitProcessor`; flip `isFullyConstraining` to `true`
  - `Epistemos/Engine/MLXInferenceService.swift` — already accepts a LogitProcessor; just forward
  - `Epistemos/LocalAgent/LocalAgentLoop.swift` — wire `structuredGenerator` so `ToolCallingPlan.backend == .mlxStructured` takes the masked path
  - `Epistemos/LocalAgent/HermesPromptBuilder.swift` — no edits needed (Hermes XML is already the trigger string)
- **Risk: Additive feature flag**, low-medium. Backend is already a `Backend` enum (`mlxStructured` vs `omegaSoftGuidance`). Falls back gracefully. Bigger risk: tokenizer mismatch — Qwen 3.5 BPE vocab and Hermes-3 vocab need exact `tokens_to_string` round-trips.

### What it is
At sample time, mask the logits so the model can ONLY emit tokens
that conform to a grammar (JSON schema, EBNF, regex, DSL).
Eliminates the "did the LLM produce valid JSON?" retry loop —
output is structurally valid by construction.

### Why for Epistemos
- LocalToolGrammar.swift today does post-hoc regex matching on
  completions. Failures cause retries — wasted tokens, wasted
  latency.
- Tool-call grammars: the local Hermes-3 + Qwen models output
  `<tool_call>{...}</tool_call>` blocks. With logit masking, this
  is structurally guaranteed.
- Bigger upside: the cognitive layer's `@Generable` schemas (e.g.
  OntologyClassifier, IntakeValve) get the same guarantee for
  local models, not just AFM.

### Files touched
- `Epistemos/LocalAgent/LocalToolGrammar.swift` (replace regex with
  logit masking)
- `Epistemos/LocalAgent/LocalAgentLoop.swift` (call site)
- `Epistemos/LocalAgent/HermesPromptBuilder.swift` (grammar
  construction)
- mlx-swift-lm fork (custom LogitProcessor)

### Approach options
1. **outlines-rs port** — port outlines-rs (Hugging Face's
   constrained decoding lib) to Swift/Metal. Largest scope.
2. **llguidance integration** — Microsoft's grammar-constrained
   decoder. Has Swift-callable C bindings? TBD.
3. **Hand-rolled JSON-schema-only mask** — limit scope to JSON
   schemas (most common use case); skip arbitrary EBNF. Smallest
   scope.

Recommended: **Option 3** initially, with a clean abstraction so
you can swap to a richer grammar engine later.

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want grammar-constrained decoding for local LLM inference (MLX-
Swift, Qwen3 7B 4-bit + Hermes-3). Goal: 100% structurally valid
output for tool calls + cognitive @Generable schemas. No retry
loops.

Questions:

1. Compare the existing landscape: outlines, lm-format-enforcer,
   llguidance (Microsoft), guidance, jsonformer, gbnf (llama.cpp).
   For each: what grammars are supported (JSON schema only? EBNF?
   regex?), what's the language binding story, what's the latency
   overhead per token?

2. For MLX-Swift specifically, is there a built-in LogitProcessor
   interface? Cite mlx-swift-lm or mlx-swift APIs.

3. For Apple Silicon Metal, what's the right way to apply a mask
   to the logits without copying the entire vocab tensor each
   step? In-place masked_fill on the GPU?

4. JSON-schema-only path: show me a working algorithm that takes
   a JSON schema + the current partial output + the next-token
   logits and returns a masked logit tensor. Edge cases: nested
   objects, arrays, strings with escape sequences.

5. Can I share a grammar between local MLX inference and Apple
   Foundation Models @Generable? They both emit structured output
   but from different code paths.

6. Cite real implementations from llama.cpp's GBNF, vLLM's guided
   decoding, or transformers' ConstrainedBeamSearch.

7. Performance overhead: what's the per-token latency cost? On
   Apple Silicon M2, what's the budget I can afford?

Output: complete plan — algorithm choice, MLX integration point,
fallback path, performance budget, test methodology.
```

---

## W9.26 — B-tree text rope (crop crate + UTF-16 metrics)

### 🔬 Research findings (background agent 2026-04-26)
- **Use `crop` v0.4+ with `utf16-metric` cargo feature** — B-tree rope, UTF-8 byte indexing, O(log n) UTF-16↔UTF-8 conversion (matches WKWebView selection API). 1KB chunks per leaf. O(1) clone via copy-on-write. ~50% faster concat than ropey on 200KB docs.
- **Why NOT jumprope**: ~3x faster on edit traces (35-40M edits/sec) BUT no O(1) clone, no line API, no UTF-16 metric → wrong fit for WKWebView snapshots.
- **Why NOT ropey**: full-featured (lines, UTF-16, O(1) clone) but slower; mature fallback if `crop`'s UTF-16 feature regresses.
- **Files (verified file sizes)**:
  - `Epistemos/Sync/NoteFileStorage.swift` (49,524 bytes — large; replace `String` body with FFI-backed rope handle)
  - `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` (63,934 bytes — WKWebView ↔ TextKit bridge — UTF-16 offset translation is the load-bearing change)
  - NEW: `agent_core/src/rope/` + UniFFI bindings (4-6 entry points: new/insert/delete/snapshot/utf16_to_byte/byte_to_utf16)
  - `Epistemos/Models/SDPage.swift` body persistence path
- **16GB feasibility: YES**. crop chunks at 1KB; 100KB note ≈ 100 leaf chunks. 10K notes loaded = <100MB resident. FFI cost dominates over algorithm.
- **Risk**: WKWebView's TipTap ProseMirror state and Rust rope drift if not single-source-of-truth — UTF-16 offset bugs cause cursor jumps. Mitigate by making JS bundle stateless and rope authoritative.
- **Effort: L (3-4 sessions)**.

### What it is
Replace String-based document storage with a B-tree rope (the
`crop` crate or `jumprope`). Edits are O(log n) instead of O(n);
snapshots are O(1); huge documents (100MB+ markdown) edit
smoothly. UTF-16 metrics matter because WKWebView's selection /
range API is UTF-16-indexed.

### Why for Epistemos
- The current ProseEditorRepresentable2.swift uses NSTextStorage
  which copies on every edit. Documents >100KB lag noticeably.
- Code-edit-mode opens at 1MB+ files; rope is non-negotiable.
- Block references (W9.14) need cheap snapshots — rope structural
  sharing makes this free.

### Files touched
- New crate: `epistemos-rope/` (or use crop directly via FFI)
- `Epistemos/Sync/NoteFileStorage.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- New `Epistemos/Engine/RopeFFIClient.swift`

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to replace String-based note storage with a B-tree rope
in Rust (`crop` crate) accessed from Swift via UniFFI. UTF-16
indexed because WKWebView and NSTextStorage are UTF-16. Goal:
smooth editing of 1MB+ markdown documents.

Questions:

1. Compare crop vs jumprope vs ropey vs xi-rope. For each:
   (a) UTF-16 metrics support, (b) snapshot/checkpoint cost,
   (c) maintenance status as of 2026, (d) memory overhead per
   character.

2. For the FFI boundary, what's the right pattern? Pass the
   entire rope across FFI per call (slow), or hold an opaque rope
   handle Swift-side and call mutation methods (UniFFI 0.28
   pattern)?

3. UTF-16 specifics: ProseMirror (the editor my Tiptap is built
   on) uses UTF-8 offsets internally but the WebView surfaces
   ranges in UTF-16. How do I bridge cleanly without an O(n)
   conversion per call?

4. For block references / transclusion (W9.14), how do I express
   "subspan from offset X to Y" so it survives later edits? Rope's
   stable cursor / interval support?

5. Persistence: rope snapshots are O(1) but I still need to write
   to disk. What's the right serialization format for incremental
   diff (so I'm not rewriting 1MB on every edit)?

6. Concurrency: edits come from the WebView (one thread) and
   from the agent's tool calls (background). What's the right
   concurrent-rope strategy? RwLock<Rope> vs append-only OpLog
   (W9.27) vs pim.

7. Cite real production apps using crop or similar (Helix editor,
   Lapce, others).

Output: complete migration plan — crate choice, FFI surface,
UTF-16 bridging strategy, persistence format, concurrency model,
benchmark vs current NSTextStorage.
```

---

## W9.27 — Append-only OpLog + replay (event-sourced graph)

### 🔬 Research findings (background agent 2026-04-26)
- **Recommendation: hand-roll OpLog first, NOT automerge/yrs/diamond-types**. Reasons:
  - Single-writer (Epistemos is local-first single-user today) — CRDT merge complexity is unnecessary.
  - automerge: mature but ~MB binary cost, heavy.
  - yrs (y-crdt Rust): best for cross-network sync; not needed today.
  - diamond-types: fastest CRDT but docs.rs warns published cargo crate is "quite out of date"; only plain text supported (wrong fit for graph nodes).
  - Hand-roll: ~400 LOC, no CRDT merge complexity.
- **Schema**: event = `{ts, lamport, actor_id, op: NodeAdd|EdgeAdd|PropSet|...}`. Persist to GRDB as `epistemos_oplog(seq INTEGER PRIMARY KEY, payload BLOB)`. Materialise into existing SDPage/SDGraphEdge.
- **Reserve `automerge` upgrade for when multi-device sync ships.** The spec sized this M (not L like W9.26) because single-user is the current scope.
- **Files (verified)**:
  - `Epistemos/Views/Graph/MetalGraphView.swift` (note: moved from `Engine/MetalGraphView.swift` to `Views/Graph/`)
  - `Epistemos/Models/SDGraphNode.swift` + `SDGraphEdge.swift` + `SDPage.swift` (treat as projections, not source of truth)
  - `Epistemos/Graph/GraphState.swift`
  - `agent_core/src/storage/vault.rs` (18,259 bytes; add `oplog` module + replay function alongside existing tantivy/rusqlite stack)
  - `Epistemos/Sync/VaultIndexActor.swift` (consume oplog events)
- **16GB feasibility: YES**. Oplog bounded by user actions (~10K-100K ops typical); compact representation = <50MB for years of history. Replay is one-shot startup cost.
- **Risk**: migration of existing SwiftData → oplog (snapshot-then-replay needed). Use additive-only schema flag `EPISTEMOS_GRAPH_OPLOG` (mirrors existing `EPISTEMOS_GRAPH_INDEX_CHATS` rollback pattern).
- **Effort: M (2-3 sessions, scoped)** — single-writer keeps this manageable.

### What it is
Replace mutable graph state with an append-only event log: every
mutation is a Op (CreateNode, UpdateEdge, DeletePage, etc.) appended
to a log. Current state is the fold of all ops. Enables: time-
travel debugging ("what did the graph look like 3 days ago?"),
perfect undo (reverse the last N ops), branch+merge, multi-user
audit.

### Why for Epistemos
- The "vault as time machine" feature (deferred per master plan) is
  trivial with an OpLog.
- Multi-device sync (future) needs a CRDT-friendly replication
  layer; OpLog is the substrate.
- Debugging: today, "why did this graph mutation happen?" requires
  log archaeology; with OpLog, you replay.

### Files touched
- `agent_core/src/storage/oplog.rs` (new — append-only log
  primitive)
- `agent_core/src/storage/vault.rs` (refactor to fold ops)
- `Epistemos/Engine/MetalGraphView.swift` (subscribe to op stream
  for incremental render)
- `agent_core/src/replay.rs` (new — replay engine)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to convert my current mutable graph state into an append-
only event log (OpLog) so I get time-travel debugging, perfect
undo, and a CRDT-compatible substrate for future multi-device
sync. Current state lives in Rust (agent_core/src/storage/vault.rs)
and is mirrored into a SwiftData model.

Questions:

1. Compare existing Rust event-sourcing crates: cqrs-es,
   eventually-rs, kameo. For a single-process, on-device, ~100k-
   op-per-day workload, which is appropriate?

2. For the storage layer, what's the right format? JSONL append-
   only file? SQLite with auto-increment id? Custom binary log
   with magic bytes? Tradeoffs for: (a) crash safety, (b) replay
   speed, (c) inspection/grep.

3. For the fold function, do I materialize the current state into
   a separate cache (snapshot every N ops) or recompute from the
   beginning? Both? What's the right snapshot cadence?

4. Schema evolution: when I add a new Op type, how do I handle
   replay of an old log that doesn't know about it? Versioned ops
   vs migrations vs strict-equality.

5. For the Swift mirror, how do I subscribe to "new ops appended"
   without polling? UniFFI async stream vs callback vs file-watcher
   on the log path.

6. CRDT-readiness: which existing CRDT formats (Automerge, Yjs,
   diamond-types) could I migrate to later if I keep my OpLog
   structurally similar? What invariants must I preserve?

7. Compare to: Datomic, XTDB, CouchDB, Git's object model. Any
   of these patterns directly applicable?

8. Time-travel UX: what's the right user-facing affordance for
   "show me the graph as of 3 days ago"? Slider? Date picker?
   Branch-name picker?

Output: complete spec — Op enum, log storage format, fold function,
snapshot policy, schema evolution rules, Swift subscription
mechanism, CRDT-readiness checklist.
```

---

# Tier 4 — ML / Embedding

## W9.11 — Create ML personalized embeddings

### What it is
Train a small embedding model on the user's own vault content
overnight via Apple's Create ML framework. Inference latency drops
from ~100ms (general model like all-MiniLM-L6-v2) to ~1ms because
the personalized model is much smaller and tuned to the user's
distribution.

### Why for Epistemos
- Embedding latency is the floor for "instant recall" features.
  100ms feels laggy; 1ms feels magical.
- Privacy: all training on-device, no data leaves.
- Personalization: user-specific jargon, project names, references
  embed correctly without RAG retrieval failures.

### Files touched
- `Epistemos/Engine/PersonalizedEmbeddingTrainer.swift` (new)
- `Epistemos/Engine/NightBrainScheduler.swift` (existing — add
  training job)
- `Epistemos/Engine/EmbeddingService.swift` (already exists —
  swap in personalized model when available)
- `agent_core/src/embeddings.rs` (FFI in if needed)

### Research prompt (paste-ready)

```
[Paste Common Epistemos Context block]

I want to train a personalized text embedding model on a user's
notes vault (~10k notes) overnight using Apple's Create ML
framework. Goal: <1ms inference latency for personalized recall.

Questions:

1. What does Create ML support as of macOS 26 for text embedding
   training? CMLTextClassifier, CMLWordTagger, custom MLLinearModel
   on top of a base embedding? Cite Apple docs + WWDC sessions.

2. Compare strategies: (a) fine-tune all-MiniLM-L6-v2 on user
   data (transfer learning), (b) train a domain-adapter on top of
   a frozen base model, (c) train a from-scratch tiny model on
   user data only. Quality vs latency vs training cost.

3. For training data: do I need explicit labels (which-note-relates-
   to-which) or can I do contrastive learning with positive pairs
   from the link graph (linked notes are positives) and negatives
   from random pairs?

4. Inference latency target: 1ms for a 384-dim embedding on M2.
   What's the smallest model architecture that hits 1ms while
   beating the base model on user-specific recall benchmarks?

5. Where do I store the trained model? Per-vault? Shared across
   vaults? How big is the artifact (need to respect 16GB Mac).

6. Eval: how do I measure that the personalized model is actually
   better than the base on the user's own recall queries? Held-out
   link-prediction task?

7. Update cadence: nightly retraining vs incremental updates as
   new notes land. What's the right approach if the user adds 50
   notes/day?

8. Privacy: Create ML training is on-device but does it use any
   networked resources I should disable? Sandbox compatibility?

Output: complete training pipeline — Create ML config, training
data assembly, model architecture, eval benchmark, NightBrain
integration, update cadence policy.
```

---

# How to use this dossier

1. **Pick an item** from the inventory (Tier 3 first if you want
   hardening; Tier 4 if you want features).
2. **Paste the Common Epistemos Context block** into your chosen
   external research tool (ChatGPT / Claude / Perplexity).
3. **Paste the item's research prompt** below it.
4. **Save the research output** to `docs/research-results/<item>.md`
   so future sessions can skip re-researching.
5. **When ready to implement**, point a Claude Code session at
   the research result + the file paths in this doc; the
   implementation should take 1-3 sessions per item.

This dossier deliberately includes nothing already in the codebase
or research corpus — every prompt is for the gap between "what
Epistemos has today" and "what shipping the item requires".

When all 21 items ship, the V1.5 inventory closes. At that point
the Wave 9-15 plan stack + the research corpus in
`~/Downloads/Epistemos/` can be archived — every load-bearing fact
will be in the codebase.
