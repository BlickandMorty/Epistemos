# AgentEvent LocalBackend Direct Generate PR29 Deliberation - 2026-05-03

## Tier

Core. This is local runtime provenance for an already-mounted local backend router. It must not add Pro tunnels, cloud model routing, Hermes/MCP, browser/computer-use, LocalAuthentication, ANE/private API, UI, graph, Rust, generated bindings, or EventStore schema work.

## Problem

PR25 closed `LocalBackendLLMClient.stream(...)` AgentEvents and PR26 mounted the recorder into `LocalBackendLLMClient`, but current canon explicitly says PR26 does not instrument `LocalBackendLLMClient.generate(...)`. Current code confirms direct generate still routes to GGUF/MLX clients without router-level AgentEvent requested/started/completed/failed records.

## Allowed Files

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalBackendLLMClient.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/LocalBackendLLMClientTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-local-backend-generate-pr29/`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_61_2026_05_03.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/agent_event_local_backend_generate_pr29_deliberation_2026_05_03.md`

## Forbidden Files

- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `epistemos-core/**`
- `omega-mcp/**`
- `Epistemos.xcodeproj/**`
- generated bindings

## Report Before Code

KIMI ORDER / builder order:

Tier: Core

Allowed files/subsystems:
- `Epistemos/Engine/LocalBackendLLMClient.swift`
- `EpistemosTests/LocalBackendLLMClientTests.swift`

Forbidden files/subsystems:
- UI, graph, Rust, generated bindings, EventStore schema, AppBootstrap remounting, Hermes/MCP, browser/computer-use, LocalAuthentication, ANE/private API, routing policy, lower GGUF/MLX runtime behavior.

Task:
- Add router-level AgentEvent provenance to `LocalBackendLLMClient.generate(...)`.
- Emit requested and started before refresh/resolve.
- Update the provenance context after runtime resolution so terminal metadata records `resolved_runtime`.
- Emit completed after the selected lower runtime returns.
- Emit failed for routing/runtime/backend errors with bounded failure class only.
- Count generated output characters in result JSON but never persist generated output.
- Reuse/refactor existing LocalBackend stream provenance helpers into shared generate/stream helpers; do not copy-paste a second nearly identical helper set.

Acceptance:
- Success records exactly three router-level `local_backend.generate` events for the LocalBackend run id: requested, started, completed with `local-backend-generate:N`, actor `local-backend-llm-client`, `source=local_backend_llm_client`, `surface=generate`, `provider=local_backend`, requested/resolved runtime, reasoning mode, max token count, prompt/system prompt character counts, steering-hints presence, elapsed milliseconds, output character count, and success boolean. This must not suppress lower-runtime GGUF/MLX AgentEvents when real lower clients emit them.
- Failure records exactly three router-level `local_backend.generate` events for the LocalBackend run id: requested, started, failed with bounded failure class such as `runtime_unavailable`, `model_unavailable`, `model_required`, or `backend_failure`.
- Persisted arguments/results/errors/metadata do not contain prompt text, system prompt text, steering hint JSON, generated output, model id, artifact id, filesystem paths, localized descriptions, arbitrary error text, Hermes/MCP/subprocess names, browser/computer-use surfaces, LocalAuthentication, or ANE/private API details.
- Existing PR25 stream tests continue passing.
- Focused test command passes under `pipefail`.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §8
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §9

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 Raw Thoughts / Provenance Spine Hardening
- Deviation: none. This is a narrow runtime AgentEvent coverage slice under the same provenance spine.

## Failure-proof guardrails (post-merge)

- grep: `local_backend.generate`
- log: `✔ Test run with 16 tests in 1 suite passed`
- test: `LocalBackendLLMClientTests`

## Fleet evidence packet

- `docs/fusion/fleet/agent-event-local-backend-generate-pr29/aggregator.md`
- `docs/fusion/fleet/agent-event-local-backend-generate-pr29/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes the LocalBackend non-streaming generate provenance gap named by PR26.
