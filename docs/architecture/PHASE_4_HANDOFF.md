# Phase 4 Handoff

Status: ready to start under `PLAN_V2`

Date: 2026-04-13

## Scope

This handoff assumes the following are complete enough to build on:

- Phase 1 — Stable runtime foundation
- Phase 1.5 — Scaffolding and truthfulness
- Phase 2 — Compute steering
- Phase 3 — Adaptation + oversight helpers

This handoff does not claim completion of:

- Phase 5 — Product-level intelligence extensions
- release readiness
- App Store / direct distribution ship approval

The target source of truth is:

- [PLAN_V2.md](/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md)
- [CODEX_CONTEXT_PACK.md](/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md)
- [BACKEND_INTERFACE_SPEC_v1.md](/Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md)
- [COMPUTE_STEERING_SPEC_v1.md](/Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md)
- [ADAPTATION_SUBSYSTEM_SPEC_v1.md](/Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md)
- [OVERSEER_AND_AGENT_HIERARCHY.md](/Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md)

## Architecture Verdict

The repo now matches the intended Phase 2 and Phase 3 baseline under `PLAN_V2`:

- Rust remains the sole control-plane authority.
- `gguf`, `mlx`, and later `remote` remain sibling runtimes.
- `gguf` remains the primary local text-generation and reasoning path.
- `mlx` remains preserved for embeddings, helper models, adaptation helpers, and sidecar-native work.
- Compute steering is explicit, policy-driven, and telemetry-visible.
- Adaptation remains bounded, reversible, helper-model-first, and MLX-first.
- SSM sidecar behavior remains helper-mode only and fail-closed.
- Oversight remains advisory and scaffolded; it does not silently mutate runtime behavior.

## What Phase 4 Means In This Repo

Per `PLAN_V2`, Phase 4 is:

- IFPruning-like learned mask predictor
- stronger planner overseer
- richer agent hierarchy
- advanced expert budgeting
- main-model adaptive experiments behind strict flags

That means Phase 4 is not:

- a rewrite of the runtime contract
- a rewrite of the control-plane authority model
- an excuse to make `mlx` the main reasoning runtime
- an excuse to make adaptation silent or always-on
- a reason to collapse helper lanes into the main decode loop

## Verified Baseline Before Phase 4

### Phase 2 baseline

Verified and in place:

- compute profiles and steering metadata are wired through the runtime contract
- steering hints flow from overseer/planning surfaces into the local runtime path
- budget trimming and budget denial are visible in summaries/stats
- typed steering state includes masking, KV policy, expert budget, sidecar state, budget outcome, and plan-trace presence
- `DIET` / `DIP` remain feature-gated experiments, not default behavior

Primary code surfaces:

- [compute_steering.rs](/Users/jojo/Downloads/Epistemos/epistemos-core/src/compute_steering.rs)
- [runtime_contract.rs](/Users/jojo/Downloads/Epistemos/epistemos-core/src/runtime_contract.rs)
- [BackendRuntimeContract.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/BackendRuntimeContract.swift)
- [PipelineService.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/PipelineService.swift)
- [TriageService.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/TriageService.swift)
- [OverseerProtocol.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/OverseerProtocol.swift)

### Phase 3 baseline

Verified and in place:

- adaptation helper subsystem exists as a bounded MLX-side helper path
- adaptation sessions enforce helper-model-only / MLX-only boundaries
- adaptation step budgets are real
- rejected updates fail closed instead of silently progressing
- canary / rollback / anchor-style stabilizer helpers exist
- sidecar compression clears stale context on failure and remains disabled by default
- local guardrail scaffolding explicitly gates adaptive and sidecar flows

Primary code surfaces:

- [adaptation.rs](/Users/jojo/Downloads/Epistemos/epistemos-core/src/adaptation.rs)
- [AdaptationExecutor.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/AdaptationExecutor.swift)
- [AdaptationStabilizer.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/AdaptationStabilizer.swift)
- [SSMMemorySidecar.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/SSMMemorySidecar.swift)
- [LocalGuardrailScaffold.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGuardrailScaffold.swift)
- [AgentHierarchyProtocol.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentHierarchyProtocol.swift)

## Important Intentional Boundaries

These are intentional and should not be “fixed” casually in Phase 4:

- The base canonical runtime `adapt()` surface is still fail-closed.
  - Phase 3 adaptation lives in the dedicated helper/prototype subsystem, not as a silently live canonical runtime operation.
- `DIET` / `DIP` are opt-in experiments behind feature flags, not default steering behavior.
- Sidecar work is explicit and bounded, not always-on.
- `adaptive` and `experimental` are not license to bypass guardrails.
- Rust remains authoritative for routing, fallback, and policy decisions.

## Exact Read Order For Claude

Read these first before editing:

1. [PLAN_V2.md](/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md)
2. [CODEX_CONTEXT_PACK.md](/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md)
3. [COMPUTE_STEERING_SPEC_v1.md](/Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md)
4. [ADAPTATION_SUBSYSTEM_SPEC_v1.md](/Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md)
5. [OVERSEER_AND_AGENT_HIERARCHY.md](/Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md)
6. [runtime_contract.rs](/Users/jojo/Downloads/Epistemos/epistemos-core/src/runtime_contract.rs)
7. [compute_steering.rs](/Users/jojo/Downloads/Epistemos/epistemos-core/src/compute_steering.rs)
8. [adaptation.rs](/Users/jojo/Downloads/Epistemos/epistemos-core/src/adaptation.rs)
9. [BackendRuntimeContract.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/BackendRuntimeContract.swift)
10. [OverseerProtocol.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/OverseerProtocol.swift)
11. [LocalGuardrailScaffold.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGuardrailScaffold.swift)
12. [AgentHierarchyProtocol.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentHierarchyProtocol.swift)

## Best Next Phase 4 Order

The safest implementation order is:

1. stronger planner overseer
2. richer agent hierarchy
3. advanced expert budgeting
4. IFPruning-like learned mask predictor behind strict flags
5. main-model adaptive experiments last, and only behind strict flags

Why this order:

- planner/agent work can build on Phase 2/3 scaffolding without destabilizing the runtime
- expert budgeting is closer to existing compute steering than learned mask prediction
- learned masking should come after richer budget/policy plumbing exists
- main-model adaptive experiments are the highest-risk Phase 4 item and should be last

## Phase 4 Guardrails

These must remain true while building Phase 4:

- no silent backend reroute
- no silent cloud escalation
- no mid-generation backend switch
- no unbounded adaptation
- no helper-lane work leaking into the default main reasoning path
- no speculative expert prefetch during active decode
- no loss of requested vs resolved runtime / profile / policy visibility
- no collapse of the `gguf` / `mlx` split

## Recommended Acceptance Bar For Phase 4

Do not call Phase 4 done unless:

- new Phase 4 features remain explicitly gated
- dense / baseline fallback still exists for any advanced masking path
- planner overseer remains advisory to Rust
- agent hierarchy remains structured and budgeted
- expert-budget telemetry is visible and test-covered
- any new adaptive main-model experiment is off by default, strict-flagged, and rollback-capable

## Verification Baseline

These commands were green before starting Phase 4:

```bash
cd /Users/jojo/Downloads/Epistemos/epistemos-core && cargo test
cd /Users/jojo/Downloads/Epistemos/epistemos-core && cargo test --features diet_experiment,dip_experiment
/Users/jojo/Downloads/Epistemos/scripts/xcodebuild_epistemos.sh \
  -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj \
  -scheme Epistemos \
  -destination 'platform=macOS' \
  -only-testing:EpistemosTests/ComputeSteeringTests \
  -only-testing:EpistemosTests/BackendRuntimeContractTests \
  -only-testing:EpistemosTests/OverseerProtocolTests \
  -only-testing:EpistemosTests/PhaseOneFiveScaffoldingTests \
  -only-testing:EpistemosTests/AdaptationExecutorTests \
  -only-testing:EpistemosTests/AdaptationStabilizerTests \
  -only-testing:EpistemosTests/SSMMemorySidecarTests \
  -only-testing:EpistemosTests/PipelineServiceTests \
  -only-testing:EpistemosTests/TriageServiceTests \
  -only-testing:EpistemosTests/LocalBackendLLMClientTests \
  -only-testing:EpistemosTests/LocalGGUFClientTests \
  test
```

Observed results:

- Rust default: `348 passed, 0 failed`
- Rust with feature flags: `350 passed, 0 failed`
- Swift integrated Phase 2 + 3 suite: `86 tests in 10 suites passed`
- the Swift integrated Phase 2 + 3 suite passed three consecutive no-edit confirmation runs

## Final Instruction To Claude

Do not reopen Phase 1 to 3 unless you find a concrete regression.

Start from the current audited baseline.
Preserve the runtime split.
Keep Rust sovereign.
Treat Phase 4 as bounded research integration, not architectural identity drift.
