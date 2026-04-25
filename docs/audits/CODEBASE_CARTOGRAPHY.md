# Codebase Cartography

Date: 2026-04-25
Branch: `feature/landing-liquid-wave` (1443 files, +100K/-22K vs main)
Scope: Live app structure, where each feature lives, dead-code candidates.

This document maps the actual repo as of 2026-04-25 with file:line evidence. It is the input to USER_WIRING_CAPABILITY_MAP.md and USER_WIRING_GAPS.md.

## 1. Repo shape

| Layer | Path | Files | Notes |
|---|---|---|---|
| App entry | `Epistemos/App/` | ~30 Swift | `EpistemosApp.swift`, `AppBootstrap.swift`, `AppEnvironment.swift`, `ChatCoordinator.swift` |
| Views | `Epistemos/Views/` | ~200 Swift | Notes, Chat, Graph, Landing, Settings, Shell |
| Engine | `Epistemos/Engine/` | ~60 Swift | LLMService, PipelineService, TriageService, MLXInferenceService, KnowledgeCoreBridge, QueryEngine, QueryRuntime, ReactiveQuery, InstantRecallService |
| State | `Epistemos/State/` | ~25 Swift | `@Observable` ChatState, AgentChatState, NoteChatState, InferenceState, GraphState |
| Models | `Epistemos/Models/` | ~30 Swift | SwiftData entities (SDPage, SDChat, SDMessage, SDGraphNode, SDGraphEdge), GraphTypes |
| Sync | `Epistemos/Sync/` | ~20 Swift | VaultSyncService, NoteFileStorage, BlockParser, SearchIndexService, SpotlightIndexer |
| Bridge | `Epistemos/Bridge/` | ~10 Swift | StreamingDelegate, FFI helpers |
| Omega | `Epistemos/Omega/` | ~40 Swift | Computer-use stack (AX, screen, vision) |
| KnowledgeFusion | `Epistemos/KnowledgeFusion/` | ~50 Swift | InstantRecallService, training pipelines (mostly excluded from build per project.yml) |
| AppStore stubs | `Epistemos/AppStore/` | 1 Swift | `AppStoreComputerUseStubs.swift` provides denied/empty stubs in MAS profile |
| Bridging | `Epistemos-Bridging-Header.h`, `graph-engine-bridge/graph_engine.h` | 2 | C-FFI surface for graph-engine (~127 functions, 1042 lines) |
| Rust crates | 7 | 7984 .rs files | agent_core, epistemos-core, graph-engine, omega-ax, omega-mcp, substrate-core, syntax-core |
| Tests | `EpistemosTests/` | 212 Swift, 201 with `@Test`/`@Suite` | Phase R + reliability + benchmarks + AppStore hardening |

Confidence: HIGH (counts derived from `find` over the repo).

## 2. Entry points

| Entry | File | Notes |
|---|---|---|
| App init | `Epistemos/App/EpistemosApp.swift` | SwiftUI App scene |
| Bootstrap | `Epistemos/App/AppBootstrap.swift` | constructs AppEnvironment, wires services, defers heavy init off `init()` (`:1234`, `:1723`) |
| Environment | `Epistemos/App/AppEnvironment.swift` | single source of truth for `.environment(...)` injection per AGENTS.md |
| Chat router | `Epistemos/App/ChatCoordinator.swift` | `handleQuery` at `:1368`; pro+cloud routing at `:361`; only `.agent` mode goes to `runCommandCenterRustAgentPath` (`:373`) |
| Pipeline | `Epistemos/Engine/PipelineService.swift` | `shouldUseToolLoop` at `:308`; explicit guard `case .localMLX = effectiveChatSelection else { return false }` at `:313`; comment at `:307`: agent loop "handled by ChatCoordinator, not here" |

## 3. Rust crate map

| Crate | Lib type | Linked in app? | Purpose |
|---|---|---|---|
| `agent_core` | dylib | YES (`-lagent_core` in `project.yml:81`) | Agent loop, providers, tools, sessions, vault, security, prompt caching, compaction |
| `graph-engine` | staticlib | YES (`-lgraph_engine`) | Metal renderer, physics, BTK, KnowledgeCore SHM, retrieval HNSW |
| `omega-mcp` | dylib | YES (`-lomega_mcp`) | MCP dispatcher, catalog, vault ops, PTY |
| `omega-ax` | dylib | YES in Pro (`-lomega_ax`); EXCLUDED from MAS via post-build scrub (`project.yml:189-192`) | Accessibility tree |
| `epistemos-core` | dylib | YES (`-lepistemos_core`) | Runtime contract, SSM, content-hash checksum |
| `substrate-core` | crate | scaffold (no Swift FFI surface yet) | Future entity store + slotmap per deterministic perf plan |
| `syntax-core` | staticlib | YES (`-lsyntax_core`) but **NOT WIRED** to CodeEditorView at runtime | tree-sitter + ropey shadow rope, 7 `#[repr(C)]` FFI types |

Confidence: HIGH (verified against `project.yml:81` and `ls build-rust/`).

## 4. Live UI surfaces

| Surface | Files | Status | Notes |
|---|---|---|---|
| Landing (current branch) | `Epistemos/Views/Landing/LandingView.swift`, `LandingWaveMetalView.swift`, `LandingWaveSearchBar.swift`, `Wave/*` | IN-FLIGHT (1443-file branch) | Click-to-search ASCII liquid wave + flat compact bar |
| Notes (Prose) | `Epistemos/Views/Notes/ProseEditorView.swift`, `ProseEditorRepresentable2.swift`, `ProseTextView2.swift`, `MarkdownContentStorage.swift` | LIVE | TextKit 2 confirmed (`ProseTextView2.swift:707` `usingTextLayoutManager: true`) |
| Notes (Code) | `Epistemos/Views/Notes/CodeEditorView.swift` | LIVE | CodeEditSourceEditor + Binding<String> O(n) (`:398-402`); outline replaces minimap (`:1267`) |
| Notes (Document) | none | ABSENT | `.epdoc`/Tiptap/WKWebView: zero matches in `Epistemos/` |
| Chat (main) | `Epistemos/Views/Chat/ChatView.swift`, `MessageBubble.swift`, `ThinkingPopoverView.swift`, `ThinkingTrailView.swift` | LIVE | Thinking lifecycle ON; `ThinkingPopoverView.swift:28` defaults expanded |
| Chat (note inline) | `Epistemos/State/NoteChatState.swift` + ProseEditor divider zone | LIVE | divider zone protected when `isFlushingTokens` (`ProseEditorRepresentable2.swift:599-607`) |
| Graph | `Epistemos/Views/Graph/HologramOverlay.swift`, `MetalGraphView.swift`, `HologramController.swift`, `HologramSearchSidebar.swift` | LIVE | bounded reopen window per AGENT_PROGRESS 2026-04-03 |
| Settings | `Epistemos/Views/Settings/*` | LIVE | Includes `PrivacyDetailView.swift:1-205` (S.6 Privacy transparency pane) |
| Agent Command Center | partial | SCAFFOLD | `AgentCommandCenterState` referenced; full surface per PLAN_V2 §4.1 not built |
| Quick Capture | `Epistemos/Engine/AmbientCaptureService.swift` (and related) | PARTIAL | Pipeline exists; user-facing entry uncertain — see USER_WIRING_GAPS.md |
| Diagnostics | none top-level | ABSENT for users; `Epistemos/Views/Settings/PrivacyDetailView.swift` is closest |

## 5. Build/test wiring

| Component | Path | Status |
|---|---|---|
| Project source of truth | `project.yml` | Canonical (`xcodegen` regenerates pbxproj on CI per `.github/workflows/ci.yml:103`) |
| Rust build scripts | `build-{rust,syntax-core,omega-mcp,omega-ax,epistemos-core,agent-core}.sh`, `bundle-app-runtime-assets.sh`, `embed-and-sign-rust-dylib.sh` | All present, chained in `project.yml:94-100` |
| CI | `.github/workflows/ci.yml` | Rust tests + clippy/fmt + `xcodegen generate` + Swift build/test + xcresult upload (14-day retention) |
| Reliability gate | `scripts/run_reliability_quality_gates.sh` | DerivedData decoupling for TCC-protected folders (`:34-41`); 6 gates (baseline, perf_diagnostics, asan, tsan, ubsan, soak_repeat) |
| Benchmark harness | `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift`, `CodeEditorBenchmarkTests.swift`, `graph-engine/benches/graph_ffi_baselines.rs`, `docs/architecture/BENCHMARK_BASELINES.csv` | Disabled-by-default, manual invocation; `com.epistemos.bench` signpost subsystem |

## 6. Profile gating (PolicyProfile)

- Single-app conditional compilation (NOT XPC double-helper).
- MAS feature flag: Rust `mas-sandbox` (`agent_core/Cargo.toml:9`); Swift `EPISTEMOS_APP_STORE` + `MAS_SANDBOX` (`project.yml:186`).
- MAS post-build scrub removes `libomega_ax.dylib` + `AXorcist.framework` (`project.yml:189-192`).
- MAS stubs: `Epistemos/AppStore/AppStoreComputerUseStubs.swift:1-184` (returns denied/empty for ComputerUseBridge, ScreenCaptureService, Screen2AXFusion, VisualVerifyLoop, AXMutationDetector, Phase4Bridge).
- AppBootstrap startup verification: `verifyAgentCorePolicyProfile()` at `:2686-2704`; fatal in MAS if linked agent_core is not `mas_sandbox`.

Confidence: HIGH.

## 7. Dead/stale code candidates

| Candidate | File | Severity | Notes |
|---|---|---|---|
| `Engine/ClaudeManagedRuntime.swift` | excluded in `project.yml:42` | LOW | Excluded from target |
| `Engine/LocalRustRuntime.swift` | excluded in `project.yml:43` | LOW | Excluded from target |
| `KnowledgeFusion/MOHAWK/**` | excluded in `project.yml:46` | LOW | Training-only, excluded |
| `KnowledgeFusion/MoLoRA/__pycache__/**`, `molora_inference.py`, `sgmm_kernel.py`, `tests/**`, `train_router.py` | excluded `:47-51` | LOW | Python sidecar, excluded |
| `Omega/Knowledge/ODIATraceGenerator.swift` | excluded `:53` | LOW | Excluded |
| `Omega/Knowledge/TraceDataMixer.swift` | excluded `:54` | LOW | Excluded |
| `Vault/KnowledgeGraphService.swift` | excluded `:55` | LOW | Excluded |
| Disabled tests | `InstantRecallTests.swift` (306 lines, `#if false`); `HermesSubprocessTests.swift` (1697 lines, `#if false`); `ExecutionContextTests.swift` (136 lines, `#if false`); `HermesBridgeIntegrationTests.swift` | HIGH | ~2,140 lines disabled with no documented re-enable plan; trustworthiness gap |
| 6 conditional `#if false` blocks in `RuntimeValidationTests.swift` | LOW | Gated for absent features (Hermes panel/subprocess, omega surfaces, agent heartbeat) |

Confidence: HIGH for excluded files; MEDIUM for disabled-test re-enable rationale.

## 8. Services that exist but are not injected into UI

| Service | Files | Status | Notes |
|---|---|---|---|
| `KnowledgeCoreShadowRuntime` | `Epistemos/Engine/KnowledgeCoreBridge.swift` + `graph-engine/src/knowledge_core/*` | SCAFFOLD | constructed in bootstrap but not threaded into AppEnvironment as first-class query engine (per `ARCHITECTURE_MAP.md §7`) |
| BTK live consumer | `agent_core` translator + `graph-engine` BTK | SCAFFOLD | live BTK subscription has no main UI consumer (`ARCHITECTURE_MAP.md §1`) |
| `syntax-core` | `syntax-core/src/lib.rs` | SCAFFOLD | linked in LDFLAGS but no Swift call site wires it; `EPISTEMOS_USE_SYNTAX_CORE` env var checked in `SyntaxCoreService.swift:10-11` (gated, defaults off) |
| Raw Thoughts persistence | none | ABSENT | thinking blocks live in message history (`agent_core/src/types.rs:39-41`) but no per-run folder/manifest/jsonl artifact |
| Documents (.epdoc) | none | ABSENT | full canon target unbuilt |

## 9. FFI surface summary

| Crate | Transport | Function count | Notes |
|---|---|---|---|
| graph-engine | C FFI header `graph_engine.h` | 127 functions, 1042 lines, 28 sections | Knowledge Core section (`:752-921`) is shared-memory pattern (already proven) |
| agent_core | UniFFI | 182 exports across 20 files | streaming via `runAgentSession` callback delegate, not FFI return |
| omega-mcp | UniFFI | 16 exports | dispatcher, catalog, vault ops |
| omega-ax | UniFFI | small | Pro-only |
| epistemos-core | UniFFI | mostly via sub-modules |  |
| syntax-core | C FFI scaffold | 7 `#[repr(C)]` types | Not wired in Swift |
| substrate-core | none | 0 | Plan-only crate per deterministic perf plan |

See `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md` for the full classification.

## 10. Open programs at start

1. **Release Hardening Canonical Plan** (`docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md`) — authoritative.
2. **Master Plan 2026-04-19** (`docs/architecture/MASTER_PLAN_2026-04-19.md`) — broad sprint log; batches HH/DD/EE/FF/GG.
3. **Phase R (Resource Runtime Hardening)** — substantively closed, 15/18 fixed, 3 design partials (`docs/KNOWN_ISSUES_REGISTER.md`).
4. **Phase S (App Store hardening)** — sub-phases S.2/S.3/S.4/S.5/S.6 in flight per recent commits (`a6f0fa99`, `4a35105b`, `adf67b30`, `2c41f2cc`).
5. **PLAN_V2 Sessions 0-6** — Editor doc-truth, benchmark harness, Swift 6 hardening, Graph BoltFFI typed buffer (flag-gated), Graph Chat receiver, syntax-core scaffold, Agent streaming instrumentation. Landed.
6. **Deterministic Performance Plan** (Sprint 0-6, `docs/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` — newly imported from `/Users/jojo/Downloads/opt/`) — runs parallel; never touches `agent_core/`.
7. **Landing Wave Search Redesign** — current feature branch.

## 11. Verdict

The repo is large, disciplined, and program-rich. Foundation is real. The dominant risks are not "build it" risks — they are "wire it, expose it, gate it for MAS, keep editor fluid at scale" risks. Documents and Raw Thoughts are the only major pieces of canon not built. Everything else is wiring + polish + verification.
