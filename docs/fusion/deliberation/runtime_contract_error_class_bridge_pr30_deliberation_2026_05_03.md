# Runtime Contract Error-Class Bridge PR30 Deliberation - 2026-05-03

## Tier

Core. This is a runtime-contract FFI payload repair. It must not add UI, graph, cloud, Hermes/MCP, browser/computer-use, LocalAuthentication, ANE/private API, routing policy, model loading behavior, or EventStore schema work.

## Problem

The PR28/PR29 green logs still contain `Can't lift flat errors` when cancellation cleanup calls `finishCancelled`. Current code exposes `RuntimeContractError? error_class` inside `RuntimeGenerationSummary` and `RuntimeGenerationEvent` records, and `finish_failed` accepts `RuntimeContractError` as a non-throwing data input, even though `RuntimeContractError` is a UniFFI flat error. The thrown API error type is fine; record/input payloads are not.

## Allowed Files

- `/Users/jojo/Downloads/Epistemos/epistemos-core/src/runtime_contract.rs`
- `/Users/jojo/Downloads/Epistemos/epistemos-core/uniffi/epistemos_core.udl`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/BackendRuntimeContract.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/BackendRuntimeContractTests.swift`
- `/Users/jojo/Downloads/Epistemos/build-rust/swift-bindings/epistemos_core.swift`
- `/Users/jojo/Downloads/Epistemos/build-rust/swift-bindings/epistemos_coreFFI.h`
- `/Users/jojo/Downloads/Epistemos/build-rust/swift-bindings/epistemos_coreFFI/module.modulemap`
- `/Users/jojo/Downloads/Epistemos/build-rust/swift-bindings/epistemos_coreFFI/epistemos_coreFFI.h`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/runtime-contract-error-class-bridge-pr30/`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_62_2026_05_03.md`

## Forbidden Files

- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `agent_core/**`
- `omega-mcp/**`
- `Epistemos.xcodeproj/**`
- local model routing policy or provider behavior outside the listed runtime contract files

## Report Before Code

KIMI ORDER / builder order:

Tier: Core

Allowed files/subsystems:
- Runtime contract Rust/UDL bridge
- Swift runtime contract adapter
- Backend runtime contract tests
- Regenerated epistemos-core Swift bindings if the build script changes them

Forbidden files/subsystems:
- UI, graph, agent_core, omega-mcp, routing policy, model loading, EventStore schema, Hermes/MCP, browser/computer-use, LocalAuthentication, ANE/private API.

Task:
- Add a red Swift test proving failed/cancelled terminal runtime events with error-class payloads can cross FFI without `Can't lift flat errors`.
- Keep thrown API failures typed as `RuntimeContractError`.
- Change only the record/input payload `error_class` values to bounded raw strings.
- Map those strings back to `BackendRuntimeContractError?` in Swift.
- Regenerate/check epistemos-core Swift bindings through the existing build path.

Acceptance:
- `BackendRuntimeContractTests` proves failed and cancelled terminal events preserve `.backendFailure` / `.cancelled` error classes after polling.
- The PR30 green log contains no `Can't lift flat errors`.
- `RuntimeContractError` remains the thrown FFI error type for methods marked `[Throws=RuntimeContractError]`.
- `finish_failed(error_class:)` crosses generated FFI as a raw string while Swift preserves the typed `BackendRuntimeContractError` API.
- No UI, graph, Hermes/MCP, browser/computer-use, LocalAuthentication, ANE/private API, subprocess, or EventStore schema changes.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §8
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §9

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 Raw Thoughts / Provenance Spine Hardening
- Deviation: This is a runtime-contract cleanup follow-up surfaced by PR28/PR29 verification rather than a new AgentEvent surface.

## Failure-Proof Guardrails (post-merge)

- grep: `string? error_class`
- grep: `string error_class`
- grep: `Option<String>`
- log: absence of `Can't lift flat errors`
- test: `BackendRuntimeContractTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/runtime-contract-error-class-bridge-pr30/aggregator.md`

## Usefulness

usefulness: +1
usefulness_reason: Removes a repeated runtime-contract FFI bridge panic from green verification logs without changing routing behavior.
