---
role: detective
slice: runtime-contract-error-class-bridge-pr30
concept: Runtime contract error-class bridge
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §8, §9
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/epistemos-core/uniffi/epistemos_core.udl:653
  - /Users/jojo/Downloads/Epistemos/epistemos-core/src/runtime_contract.rs:196
  - /Users/jojo/Downloads/Epistemos/epistemos-core/uniffi/epistemos_core.udl:740
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/BackendRuntimeContract.swift:356
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_local_mlx_stream_pr28_deliberation_2026_05_03.md
  - docs/fusion/deliberation/agent_event_local_backend_generate_pr29_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "separate runtime-contract follow-up"
  code_says: "RuntimeContractError? error_class"
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/epistemos-core/uniffi/epistemos_core.udl
load_bearing_quote: "Can't lift flat errors"
verdict: open
usefulness: +1
usefulness_reason: Identifies a repeated green-log panic source with a narrow FFI payload fix.
---

## Findings

- The repeated PR28/PR29 log comes from a runtime contract cleanup path, not persisted AgentEvent JSON.
- `RuntimeContractError` must stay as the thrown FFI error type for API failures.
- `RuntimeGenerationSummary.error_class`, `RuntimeGenerationEvent.error_class`, and `finish_failed(error_class:)` are data payloads; because the error type is flat, they should cross FFI as bounded raw strings.
- Swift can preserve the public `BackendRuntimeContractError?` surface by mapping generated strings through `BackendRuntimeContractError(rawValue:)`.

## Open Questions

- The generated Swift binding will change when `build-epistemos-core.sh` runs; the staged commit must include the regenerated `build-rust/swift-bindings/epistemos_core.swift` if it changes.

## Recommendation

Build PR30 as a Core runtime-contract bridge slice: add a failing `BackendRuntimeContractTests` case for failed/cancelled terminal events with error classes, change the Rust/UDL record and non-throwing input payloads to strings, update Swift adapters, regenerate bindings through the existing build script, and verify the focused test log no longer contains `Can't lift flat errors`.
