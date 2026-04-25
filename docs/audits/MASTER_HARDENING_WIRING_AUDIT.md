# Master Hardening + Wiring Audit

Date: 2026-04-25
Authority: PLAN_V2 + RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20 + MASTER_PLAN_2026-04-19 + KNOWN_ISSUES_REGISTER + research synthesis (claude work / gpt work / claude opt 2 / deterministic perf plan).

## Executive Summary

Epistemos has substantial, disciplined infrastructure: TextKit 2 prose editor (protected), real multi-turn Rust agent loop with thinking-block + signature preservation, FTS5 search, HNSW Instant Recall substrate, sound vault sync with Blake3 atomic writes, properly gated MAS profile via compile-time `#if !EPISTEMOS_APP_STORE`, comprehensive test discipline (50+ Phase R regression tests, 95% Swift Testing coverage, 191+ Rust tests, S.4 App Store hardening with 16 tests, S.6 Privacy transparency pane with drift detection). Phase R closure is real (15/18 issues fixed). The repo's foundational invariants are honored: zero `try!`/`as!`, all `AsyncStream` use `bufferingNewest`, zero `DispatchQueue.main.sync`, all 42 NotificationCenter observers balanced, all 20 `nonisolated(unsafe)` properties have `// SAFETY:` comments, no `.repeatForever`, compaction preserves thinking blocks, prompt-cache breakpoints land correctly.

**The dominant V1 risks are not "build it" risks. They are wiring + product-expression risks.**

The single most important V1 BLOCKER is that Pro mode on cloud models has zero tools, because `PipelineService.shouldUseToolLoop` short-circuits at `:313-314` when the selection is not `.localMLX`. This means the most common configuration silently hallucinates "find my note about X" answers. Master Plan §HH.4 narrative claims a fix; the line is still in place.

The second critical V1 gap is that the canonical product moat — Raw Thoughts as first-class run artifacts — exists at the data level (thinking blocks persist in message history) but not as standalone artifacts (no `events.jsonl` per run, no graph node/edge taxonomy for `Run`/`RawThought`/`ToolTrace`).

The third is that Contextual Shadows (the ambient-recall UI moment) is entirely absent despite a fully-wired HNSW substrate with <3ms vault-wide search SLA.

Code editor fluidity at ~4k+ lines is unverified — the benchmark scaffolding exists but is disabled-by-default; the `syntax-core` crate is scaffolded with the right shape but is not wired by default (`SyntaxCoreService.swift:10-11` reads an env var that defaults off).

App Store posture is shippable with documented JIT entitlement justification. Bundle size is small but unmonitored. PolicyProfile is enforced via single-app compile-time gating, not double-helper IPC; this is acceptable.

## Highest-Risk Findings

| # | Finding | File | Severity | Confidence |
|---|---|---|---|---|
| H1 | Pro+Cloud agent loop is unwired; tools never invoked | `Epistemos/Engine/PipelineService.swift:308-330`; `Epistemos/App/ChatCoordinator.swift:361-373` | BLOCKER | HIGH |
| H2 | Raw Thoughts artifact persistence missing despite canon centrality | `agent_core/src/storage/session_store.rs:5-8`; absence of per-run `events.jsonl` + `manifest.json` + graph node types | HIGH | HIGH |
| H3 | Code editor fluidity at 4k+ lines unverified; syntax-core not wired by default | `Epistemos/Views/Notes/CodeEditorView.swift:2118-2254`; `SyntaxCoreService.swift:10-11` (default OFF) | HIGH | HIGH |
| H4 | Contextual Shadows UI absent despite HNSW substrate live | `InstantRecallService.swift` (substrate WIRED) + no panel/button/sidebar | HIGH | HIGH |
| H5 | InstantRecall sync `rebuildIndex` exists on @MainActor; can stall on large vault | `Epistemos/KnowledgeFusion/InstantRecallService.swift:33+258` | HIGH | HIGH |
| H6 | Disabled tests (~2,140 lines) with no documented re-enable plan | `EpistemosTests/InstantRecallTests.swift` (306 lines `#if false`); `EpistemosTests/HermesSubprocessTests.swift` (1697 lines `#if false`) | HIGH | HIGH |
| H7 | Bundle size unmonitored in CI | `.github/workflows/ci.yml` | MEDIUM | HIGH |
| H8 | JIT entitlement requires App Review documentation | `Epistemos/Epistemos-AppStore.entitlements` | MEDIUM | HIGH |
| H9 | Reliability gate freshness not re-verified this session | `scripts/run_reliability_quality_gates.sh` + recent commits | MEDIUM | MEDIUM |
| H10 | Rust `mas-sandbox` feature coverage on `nix::process::*` etc. requires spot-check | `agent_core/Cargo.toml`; `omega-mcp/Cargo.toml` | MEDIUM | MEDIUM |

## Product Identity Recommendation

Epistemos's identity for V1 is:

> **"A native macOS cognitive workspace that knows what you're thinking about, surfaces what you've already thought, and remembers exactly what every model said while it worked for you — entirely on your machine."**

This concentrates on three product moments:

1. **Type and the app already knows** — Contextual Shadows recall surfaces while you write (in note or chat), not as a search step. This is the V1 "wow" moment.
2. **Open a chat run and see the model's actual thinking** — Raw Thoughts as inspectable per-run artifacts, with provider-exposed reasoning + tool traces + planner summaries, all linked into the typed graph.
3. **Write fast in any file type** — Prose stays native and protected, Code stays fluid even at 4k+ lines, Documents arrive in V1.5 as a typed artifact (file-type-driven, not a sidebar silo).

The MAS-first sequencing means: ship a tight, native-feeling, sandboxed V1 with these three moments + correct routing + correct privacy posture. Pro V1.5 unlocks computer use, terminal, iMessage inbound, agent command center.

## P0 Must Fix Before V1

| # | Item | Files | Verification |
|---|---|---|---|
| P0-1 | Route Pro+Cloud through Rust agent loop with `chat_pro` tier | `Epistemos/Engine/PipelineService.swift:308-330`; `Epistemos/App/ChatCoordinator.swift:361` | New test: Pro+cloud "find note" emits at least one `vault_search` tool call |
| P0-2 | Raw Thoughts V0 artifact persistence under flag | new: `agent_core/src/storage/raw_thoughts.rs`; `Epistemos/State/RawThoughtsState.swift`; `SDGraphNode` + `SDGraphEdge` extensions for `Run` / `RawThought` / `ToolTrace` types | Integration test: chat with thinking → run folder + events.jsonl + manifest + graph nodes appear |
| P0-3 | Document JIT entitlement App Review justification | `docs/release/MAS_APP_REVIEW_NOTES.md` (new) | Reviewable artifact attached to submission |
| P0-4 | Verify Rust `mas-sandbox` gating on subprocess/PTY/AX surfaces | `agent_core/src/`, `omega-mcp/src/` grep audit | spot-check confirms `#[cfg(not(feature = "mas-sandbox"))]` on every `nix::process` and `omega-ax` consumer |
| P0-5 | Hard-deprecate sync `InstantRecallService.rebuildIndex(notes:)` | `Epistemos/KnowledgeFusion/InstantRecallService.swift:258` | DEBUG `precondition(false, "Use rebuildIndexAsync")`; production callers all async |
| P0-6 | Remove or annotate disabled tests with explicit re-enable date/issue | `EpistemosTests/InstantRecallTests.swift`, `HermesSubprocessTests.swift`, `ExecutionContextTests.swift`, `HermesBridgeIntegrationTests.swift` | Either re-enabled, deleted, or comment-linked to issue |

## P1 Should Fix Before Public Beta

| # | Item | Files | Verification |
|---|---|---|---|
| P1-1 | Wire `syntax-core` viewport-scoped path ON by default for code files; commit 4k-line benchmark | `Epistemos/Views/Notes/CodeEditorView.swift`, `SyntaxCoreService.swift`, `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift` | 4k-line .swift: open <500ms; keystroke-to-highlight <16ms p99 |
| P1-2 | Contextual Shadows V0 panel + button + state class | new files per AMBIENT_RECALL_WIRING_PLAN.md §5 | typing 200ms after pause → button appears; click → top-K notes; off-MainActor verified |
| P1-3 | Bundle-size CI gate (<600 MB) | `.github/workflows/ci.yml` | regression alerts |
| P1-4 | Verify reasoning summary persistence for all 4 providers (Anthropic/OpenAI/Google/Perplexity) | `Epistemos/Engine/LLMService.swift` per-provider test | each provider routes thinking_delta → ThinkingPopover → SDMessage.thinkingTrace persists across reload |
| P1-5 | Line-count gutter (code editor) without theme conflict | `Epistemos/Views/Notes/CodeEditorView.swift` | toggle on/off; respects theme; no per-frame allocation |
| P1-6 | Re-run reliability gate baseline; record evidence | `scripts/run_reliability_quality_gates.sh`; `artifacts/reliability/` | green tail in fresh log |
| P1-7 | Audit `GraphNodeBatchPayload` / `GraphEdgeBatchPayload` for per-frame growth; reuse buffers | `Epistemos/Views/Graph/MetalGraphView.swift` | 10K-node graph 60fps signpost p99 <8.3ms |
| P1-8 | Empty-state polish across notes/vault/search/chat | various Views | first-run guidance hints |
| P1-9 | MLXInferenceService LocalMLXClient → off MainActor (architectural) | `Epistemos/Engine/MLXInferenceService.swift:492+1450+1664` | model load doesn't stall chat list scroll |
| P1-10 | Quick Capture top-level entry decision (ship + global hotkey OR hide) | `Epistemos/Engine/AmbientCaptureService.swift` + menu bar | discoverable or hidden behind flag |

## P2 Safe to Defer

| # | Item | Reason |
|---|---|---|
| P2-1 | Documents (.epdoc + Tiptap WKWebView) | V1.5 |
| P2-2 | Agent Command Center full surface | V1.5; PLAN_V2 §4.1 |
| P2-3 | Memory diff card | V1.5; novel UX |
| P2-4 | Embedded terminal (Pro) | Pro V1.5 |
| P2-5 | Bundled `rg`/`fd` (Pro) | Pro V1.5 |
| P2-6 | Knowledge Core production view-model wiring | deterministic perf Sprint 3 territory |
| P2-7 | BTK live consumer in main UI | deterministic perf territory |
| P2-8 | Frame-aligned token coalescing | only if benchmarks show benefit |
| P2-9 | Metal binary archive | deterministic perf Sprint 3 |
| P2-10 | substrate-rt zero-copy FFI ring | deterministic perf Sprint 4 |
| P2-11 | PGO + bumpalo arenas | deterministic perf Sprint 5 |
| P2-12 | Diagnostics panel | post-V1 polish |
| P2-13 | Voice/dictation in note composer | post-V1 polish |
| P2-14 | Memory diff card | post-V1 |

## Hidden Capabilities That Should Be Surfaced

1. **Saved permission grants** — currently in `AgentControlSettingsView.activeGrantsSection`; surface link from Privacy pane (LOW).
2. **Effective Model Badge "Why this model?"** — already wired (`[7235802f]` per Master Plan); verify discoverability.
3. **Reasoning trail expansion** — auto-expand on stream start, auto-collapse on first text token (per Master Plan §FF.4).
4. **Contextual Shadows (ambient recall)** — entirely hidden today; surface per AMBIENT_RECALL_WIRING_PLAN.md.
5. **Quick Capture** — likely hidden; surface via menu bar + global hotkey if shippable.

## Capabilities That Should Stay Hidden

1. **Hermes orphan-cleanup status / process tree** — internal only.
2. **KnowledgeCoreShadowRuntime debug counters** — until production-wired.
3. **BoltFFI graph flag** — internal until parity proven.
4. **`EPISTEMOS_USE_SYNTAX_CORE` env var** — flip default ON for code files; the env var becomes a debug escape hatch only.
5. **Diagnostics panel** — Settings → Advanced → Developer (off by default).

## Features That Are Built But Not Wired

1. `KnowledgeCoreShadowRuntime` — constructed but not threaded into AppEnvironment as first-class query engine (`ARCHITECTURE_MAP.md §7`).
2. `syntax-core` crate — linked into Swift LDFLAGS but no Swift consumer wires it for code editor by default.
3. BTK live consumer in main UI — translator+OpLog+kernel exist; no driver for live query UI (`ARCHITECTURE_MAP.md §1`).
4. Hermes Swift-side health-check bridge — Phase Omega-2 deferred.
5. BoltFFI graph typed-buffer prototype — landed behind `bolt-graph` Cargo feature + `EPISTEMOS_USE_BOLT_GRAPH` Swift flag, default OFF.

## Features That Are Wired But Not Visible

1. **Contextual Shadows** — InstantRecall service is wired and fast; no UI surface.
2. **Saved permission grants** — list visible in AgentControl settings only; not linked from Privacy pane.
3. **Quick Capture** — capture pipeline likely wired; user-facing entry uncertain.
4. **Reasoning summary** — wired per provider in LLMService; verify all four producers route to ThinkingPopover.

## Features That Are Visible But Not Stable

1. **Pro mode + cloud model** — visible to user as a normal config but silently has zero tools (BLOCKER P0-1).
2. **Code editor at 4k+ lines** — visible (opens), unverified at scale (HIGH P1-1).

## Performance/Concurrency Risks

(See PERFORMANCE_CONCURRENCY_AUDIT.md.) Top three:
1. Sync `InstantRecallService.rebuildIndex` on @MainActor (HIGH P0-5).
2. Code editor whole-file parse fallback when `EPISTEMOS_USE_SYNTAX_CORE=0` (HIGH P1-1).
3. MLXInferenceService MainActor.run pattern during model load/teardown (MEDIUM P1-9).

All `AsyncStream` constructors use `bufferingNewest`; zero `unbounded`. Zero `DispatchQueue.main.sync`. Zero `.repeatForever`. NotificationCenter observers all `.main` queue + `MainActor.assumeIsolated`. `nonisolated(unsafe)` always paired with `// SAFETY:` comments.

## App Store/Privacy Risks

(See PRIVACY_APP_STORE_AUDIT.md.) Top three:
1. JIT entitlement requires App Review justification (P0-3).
2. Rust `mas-sandbox` feature coverage on subprocess/PTY surfaces requires spot-check (P0-4).
3. Bundle size CI gate missing (P1-3).

PrivacyInfo.xcprivacy clean. TCC discipline correct (all prompts originate from sandboxed frontend). Single-app compile-time gating sufficient (no XPC double-helper required for V1).

## Data Integrity Risks

(See DATA_PERSISTENCE_INDEXING_AUDIT.md.) None blocking V1.
- NoteFileStorage atomic + Blake3 sidecar.
- Multi-fallback read cascade.
- Derived indexes rebuildable.
- Permission grants persisted via `permission_store_init_at_path`.
- Verified-write contract enforced (I-007/I-008 closed).

Two product gaps (already in P0/P1):
- Raw Thoughts artifact persistence (P0-2).
- Chat messages not in FTS5 (P1, only matters if Contextual Shadows includes Chats tab).

## Recommended Minimal V1 User Surface

(See UI_PRODUCT_EXPRESSION_PLAN.md §"Recommended minimal V1 user surface".)

**Visible**: Vault tree (with file-type-driven entries: Prose / Raw Thoughts / Code), top toolbar (New / Vault / Model / Search / Settings), note composer + AI button + Recall button (only when results exist), chat composer + EffectiveModelBadge + ThinkingPopover + Recall button, Settings (AI / Vault / Recall / Privacy / Developer hidden by default).

**Invisible until earned**: Quick Capture global hotkey, reasoning expansion in chat, saved grants list (link from Privacy).

**MAS-stripped**: Computer use, terminal, bash/PTY, ACC.

## Implementation Patch Plan

(See PATCH_QUEUE.md for the full ordered queue with dependencies, files, verification.) The plan in priority order:

1. P0-4 (Rust mas-sandbox spot-check; non-code → may already be correct).
2. P0-5 (sync rebuildIndex DEBUG precondition; small).
3. P0-1 (PipelineService Pro+Cloud routing).
4. P0-2 (Raw Thoughts V0 — Rust artifact emitter + Swift consumer + graph types).
5. P1-1 (syntax-core viewport wiring + 4k-line bench).
6. P1-2 (Contextual Shadows V0).
7. P1-7 (graph batch payload audit).
8. P1-3 (bundle-size CI gate).
9. P1-4 (per-provider reasoning verification).
10. P1-5 (gutter design).
11. P1-9 (MLXInferenceService off MainActor — architectural; may slip to V1.5).
12. P1-10 (Quick Capture decision).
13. P0-3 (App Review notes — submission task).
14. P0-6 (disabled-test triage).

## Verification Plan

After every patch:
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify`
- `cargo test --manifest-path agent_core/Cargo.toml --lib`
- `cargo test --manifest-path graph-engine/Cargo.toml --lib`
- Focused Swift test sweep: `xcodebuild ... test -only-testing:EpistemosTests/<targeted>`
- Reliability gate baseline (per-PR if cheap; nightly otherwise).
- Manual UI smoke test for any P0 (golden path + edge case).

Final V1 ship gate per V1_SHIP_GATE_DECISION.md §"Final ship gate criteria".

## Final Ship Gate

V1 (MAS) ships only when:

1. P0-1 through P0-6 closed and verified.
2. Reliability gate green on a fresh run.
3. Bundle size <600 MB.
4. JIT entitlement justification documented for App Review.
5. AppStoreHardeningTests + Phase R + new P0/P1 tests green.
6. Smoke test plan executed manually.
7. Zero `try!`/`as!`/`unbounded`/`DispatchQueue.main.sync` regressions.
8. PrivacyInfo.xcprivacy drift-test passes.
9. PolicyProfile startup verification works (boot Pro and MAS builds; both must `verifyAgentCorePolicyProfile()` cleanly).
10. TestFlight cycle ≥ 1 with feedback addressed.

V1.5 (Pro) ships when:

1. Computer use stack regression-tested on macOS 26.
2. Embedded terminal complete.
3. iMessage inbound + outbound fully wired.
4. ACC full surface complete.
5. Documents (.epdoc) editor.
6. Memory diff card.

---

This audit is the authoritative input to PATCH_QUEUE.md. No code change should land without a corresponding patch entry.
