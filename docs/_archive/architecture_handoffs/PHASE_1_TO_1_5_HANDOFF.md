# Phase 1 to 1.5 Handoff

> **Index status**: SUPERSEDED-HISTORICAL — Phase-specific historical reference; superseded by MASTER_FUSION.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



Status: complete under `PLAN_V2`

Date: 2026-04-13

## Scope

This handoff covers only:

- Phase 1 — Stable runtime foundation
- Phase 1.5 — Scaffolding and truthfulness

It does not claim completion of:

- Phase 2 — Compute steering
- Phase 3 — Adaptation + oversight helpers
- Phase 4+ research tracks

The target source of truth is:

- [PLAN_V2.md](/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md)
- [CODEX_CONTEXT_PACK.md](/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md)
- [BACKEND_INTERFACE_SPEC_v1.md](/Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md)

## Architecture Verdict

The codebase now matches the Phase 1 and 1.5 runtime plan:

- Rust remains the sole control-plane authority.
- `gguf`, `mlx`, and later `remote` are sibling runtimes.
- `gguf` is the primary local text-generation path.
- `mlx` remains permanent for embeddings and auxiliary/helper workloads.
- runtime fallback remains explicit and policy-owned
- the public contract remains pull-based
- serial `GPU -> SSD -> GPU` constraints remain enforced in the runtime-control layer
- advanced features remain bounded, fail-closed, and deferred unless explicitly scaffolded for later phases

## Phase 1 Checklist

PLAN_V2 Phase 1 requires:

- one real `gguf` primary path
- `mlx` preserved
- Rust control-plane authority
- explicit fallback
- serial invariant enforcement
- telemetry
- clear runtime truthfulness
- engine/format compatibility audit first

Current state:

- Real `gguf` local execution exists through the in-process GGUF bridge and local client path.
- `mlx` remains a preserved sibling runtime and is not removed or hollowed out.
- Rust owns runtime resolution, policy resolution, capability handshake, and normalized summaries in `epistemos-core/src/runtime_contract.rs`.
- `gguf -> mlx` fallback remains explicit and visible in the runtime contract and tests.
- Serial fallback / SSD streaming rules are enforced in `epistemos-core/src/inference_control.rs`.
- Runtime summaries and stats expose requested vs resolved runtime identity, execution policy metadata, fallback mode, and plan-trace visibility.
- GGUF identity is surfaced truthfully in provider/snapshot surfaces instead of being mislabeled as MLX.

Primary code surfaces:

- [AppBootstrap.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/AppBootstrap.swift)
- [BackendRuntimeContract.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/BackendRuntimeContract.swift)
- [LocalGGUFClient.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGGUFClient.swift)
- [MLXInferenceService.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift)
- [LLMService.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift)
- [runtime_contract.rs](/Users/jojo/Downloads/Epistemos/epistemos-core/src/runtime_contract.rs)
- [epistemos_core.udl](/Users/jojo/Downloads/Epistemos/epistemos-core/uniffi/epistemos_core.udl)

## Phase 1.5 Checklist

PLAN_V2 Phase 1.5 requires:

- capability handshake
- reasoning profiles
- execution policy ref
- plan trace
- protocol scaffolding for agent messages
- overseer role scaffolding
- local guardrail skeleton
- KAN pilot off main path

Current state:

- Capability handshake is implemented in the Rust control plane and surfaced through the backend contract.
- Reasoning profiles are implemented and aligned with PLAN_V2 naming:
  - `standard`
  - `deep_graph`
  - `adaptive`
  - `experimental`
  - `visual_sidecar`
- `execution_policy_ref` is validated by the control plane and denied when mismatched.
- `planTracePresent` is now a first-class runtime summary/stats field.
- protocol scaffolding for hierarchical agent messages exists and validates the documented topology.
- overseer role scaffolding already exists in the runtime/planning layer and associated tests.
- a local guardrail scaffold exists and currently denies later-phase profiles and unsupported modes.
- a KAN pilot scaffold exists, is off-main-path, and is disabled by default.

Primary code surfaces:

- [BackendRuntimeContract.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/BackendRuntimeContract.swift)
- [runtime_contract.rs](/Users/jojo/Downloads/Epistemos/epistemos-core/src/runtime_contract.rs)
- [AgentHierarchyProtocol.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentHierarchyProtocol.swift)
- [LocalGuardrailScaffold.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGuardrailScaffold.swift)
- [KANPilotScaffold.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/KANPilotScaffold.swift)
- [OverseerProtocol.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/OverseerProtocol.swift)
- [PipelineService.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/PipelineService.swift)
- [ChatCoordinator.swift](/Users/jojo/Downloads/Epistemos/Epistemos/App/ChatCoordinator.swift)

## Truthfulness Fixes Closed In This Pass

These were the last Phase 1 to 1.5 gaps and are now closed:

- Embeddings are unified under the backend runtime contract instead of living only as adjacent infrastructure.
- `deep_graph` naming now matches PLAN_V2 while preserving backward-compatible decode of legacy `"deep"` values.
- `planTracePresent` is visible in normalized runtime summaries and stats.
- GGUF-backed local execution no longer presents as `localMLX` in provider identity surfaces.
- SwiftData predicate crashes in live-note and dataview paths were corrected by using `isArchived` instead of the invalid deleted-state assumption.

Relevant files:

- [DataviewService.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/DataviewService.swift)
- [LiveNoteScanner.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Vault/LiveNoteScanner.swift)
- [BrandedTypes.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Models/BrandedTypes.swift)

## Verification

Rust verification:

```bash
cd /Users/jojo/Downloads/Epistemos/epistemos-core && cargo test
```

Result:

- `289 passed, 0 failed`
- repeated successful confirmation passes with no code changes between runs

Focused Swift Phase 1 to 1.5 verification:

```bash
/Users/jojo/Downloads/Epistemos/scripts/xcodebuild_epistemos.sh \
  -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj \
  -scheme Epistemos \
  -destination 'platform=macOS' \
  -only-testing:EpistemosTests/PhaseOneFiveScaffoldingTests \
  -only-testing:EpistemosTests/BackendRuntimeContractTests \
  -only-testing:EpistemosTests/LocalGGUFClientTests \
  -only-testing:EpistemosTests/LocalBackendLLMClientTests \
  -only-testing:EpistemosTests/RuntimeValidationTests \
  -only-testing:EpistemosTests/TriageServiceTests \
  -only-testing:EpistemosTests/OverseerProtocolTests \
  -only-testing:EpistemosTests/PipelineServiceTests \
  -only-testing:EpistemosTests/DataviewServiceTests \
  -only-testing:EpistemosTests/LiveNoteExecutorTests \
  test
```

Result:

- `222 tests in 8 suites passed`
- three consecutive no-edit successful confirmation passes

Primary test coverage added or updated:

- [BackendRuntimeContractTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/BackendRuntimeContractTests.swift)
- [DataviewServiceTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/DataviewServiceTests.swift)
- [PhaseOneFiveScaffoldingTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/PhaseOneFiveScaffoldingTests.swift)
- [LiveNoteExecutorTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/LiveNoteExecutorTests.swift)

## Explicitly Deferred Beyond 1.5

These are intentionally not completed here and should remain out of scope until the next phase:

- Compute Steering execution features
- mask compiler / DIET / DIP / IFPruning work
- KV policy execution
- advanced expert budgeting beyond current scaffolding
- adaptation subsystem implementation
- MLX helper-model LoRA / micro-TTT
- SSM memory sidecar implementation
- active overseer execution beyond scaffolding
- image sidecar implementation
- remote runtime execution

This is correct under PLAN_V2. Their docs and hooks may exist, but their implementation remains deferred.

## Final Verdict

Phase 1 is complete.

Phase 1.5 is complete.

The runtime foundation, truthfulness work, and required scaffolding now satisfy the current PLAN_V2 definition without bleeding into Phase 2 or 3.

The next legitimate step is Phase 2 work under the Compute Steering plan, not more cleanup of Phase 1 to 1.5.
