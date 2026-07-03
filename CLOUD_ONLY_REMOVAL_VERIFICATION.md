# Cloud-Only Removal — Verification Report

**Date:** 2026-07-03 · **Scope:** the Epistemos app (Goose lane excluded) · **Owner mandate:** remove the Omega/computer-use lane and the app's own local-model (MLX/GGUF/LocalAgent) inference stack; the app is **cloud-only for LLM inference**, keeping only Apple on-device AI. "No dead code remaining."

## Outcome in one paragraph

Epistemos no longer contains the Omega/computer-use subsystem or any app-owned local-model inference. All LLM inference now routes to cloud providers (OpenAI / Anthropic / Google / Z.AI / Kimi) or to Apple Intelligence (FoundationModels) as the on-device baseline. The app target **builds green** (`xcodebuild build -scheme Epistemos` = BUILD SUCCEEDED, 0 errors). A source-level gate proves the local routing path is unreachable, so removal cannot silently degrade cloud inference into a "no model" state. Every feature the owner mandated to keep is intact. One verification remains in progress: the **test target** is being reconciled (test files that exercised the removed features are being deleted/fixed), after which a runtime-gate test confirms end-to-end cloud resolution.

## What was removed (verified)

1. **Omega / computer-use lane** — `Epistemos/Omega/{Vision,Agents,Orchestrator,Knowledge,Safety,Research*,Inference/DeviceAgent…}`, `Bridge/{ComputerUseBridge,Phase4Bridge,Phase5Bridge}`, `Views/Omega/`, the `omega-ax` Rust crate + `build-omega-ax.sh`, the AXorcist SPM dependency, the `.omega` UtilityPanel, and the OMEGA entitlements (`automation.apple-events`, accessibility mach-lookup) + Info.plist usage strings (NSAccessibility/NSScreenCapture/NSAppleEvents). KEPT: `omega-mcp`/`MCPBridge` (the live agent tool-dispatch bus that powers the cloud agent).

2. **MLX / local-model dependency stack** — `vmlx-swift` (9 MLX products) + `GGUFRuntimeBridge` packages removed from `project.yml` and `LocalPackages/` (~360K vendored lines); the `unsigned-executable-memory` entitlement dropped; `SSMStateService`/`SSMMemorySidecar`/`ConstrainedDecodingService` deleted; the last `import MLX` eliminated.

3. **App-internal local-model type/routing layer** (~18 files) — `LocalTextModelID` catalog + all `Local*` types, `LocalModelCatalog`/`GemmaQAT*`, `LocalInferenceRoutingError` (→ existing `CloudLLMError`), `LocalConfigurableLLMClient`, `EpistemosFoundationLineup`, `LocalModelResolution`. `InferenceState` ~6000→3433 lines, `TriageService` 2529→1437, with `LLMService`/`PipelineService`/`AppBootstrap`/`AgentCommandCenterState`/`OverseerProtocol` stripped to cloud-only. Both local-vs-cloud routing brains (`InferenceState.effectiveChatSurfaceSelection`, `TriageService.decide()`) were rewritten cloud-only.

## Evidence (what was verified, and how)

- **Builds green:** `xcodebuild build -scheme Epistemos -destination 'platform=macOS'` → BUILD SUCCEEDED, 0 errors.
- **Source gate (no silent cloud break):** `rg 'return \.localMLX|= \.localMLX(' InferenceState.swift` → 0 producers; no `InferenceRouteKind.localMLX` route producer in `TriageService`. The `.localMLX` enum case is retained only as an unreachable switch tombstone for exhaustiveness.
- **KEEP set intact (removal was surgical):** FoundationModels/AppleIntelligence (18 files), SpeechAnalyzer voice (5), NL embeddings (3), CloudModelProvider (7), MCPBridge tool bus (4), arXiv (10), WebView browser/editor (32) — all present. No KEEP-feature test coverage deleted.
- **Shipping artifacts clean:** `build-rust/` contains only kept dylibs (agent_core, epistemos_core, epistemos_shadow, omega_mcp); link flags reference no `omega_ax`/`mlx`; zero stale MLX/vmlx/llama/omega_ax binaries.
- **User-facing copy corrected:** removed false "local models available" claims from provider descriptions, corrected image-gen (MLX Flux → Fal cloud) and error strings.

## In progress / pending (not claimed complete)

- **Test-target reconciliation** (in progress): ~16 test files referenced deleted symbols; dead-feature test files are being deleted (with justification: they test a removed feature) and mixed files fixed to keep cloud/kept assertions. Error count driven 172 → near-zero. Not yet green.
- **Runtime gate** (drafted, pending test target): asserts `effectiveChatSurfaceSelection` never returns `.localMLX` and resolves to `.cloud` with a configured provider — the end-to-end proof cloud inference works, not just compiles.
- **Minor cleanup** (documented in SURGERY_PLAN.md): delete `AdaptationExecutor.swift` (dead local LoRA, 0 consumers); a few TriageService dead-but-compiling helpers; internal-doc staleness (APP_REVIEW_NOTES.md worth refreshing for Apple submission).

## Deferred (separate, documented)

- **Work/OpenCode lane removal** — the owner also asked to remove this lane (~48 files). Not started; the app is green and cloud-only without touching it. It is a distinct removal with its own reference-unwind.

## Authoritative working record

`SURGERY_PLAN.md` (repo root) holds the full decision log, per-file line references, the locked cross-cutting decisions (why `BackendRuntimeKind`/`ChatModelSelection.localMLX` are kept as tombstones, why `LocalReasoningMode`/`LocalModelSelectionSurface` are shared-cloud and kept), and the residual-fix history. `PROGRESS.md` is the loop resume anchor.
