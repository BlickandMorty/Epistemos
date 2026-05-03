Slice:          AgentEvent Local GGUF direct stream provenance PR32
Tier:           Core
Allowed files:  /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGGUFClient.swift
                /Users/jojo/Downloads/Epistemos/EpistemosTests/LocalGGUFClientTests.swift
                /Users/jojo/Downloads/Epistemos/docs/fusion/**
Forbidden:      UI, graph, Rust, generated bindings, EventStore schema, model loading, routing policy, Hermes/MCP, browser/computer-use, LocalAuthentication, ANE/private API, Xcode project files

## Decision
Approved for a narrow red-first implementation: instrument only `LocalGGUFClient.stream(...)` with bounded AgentEvents.

## Why This Slice
PR24 closed direct GGUF non-streaming generation. PR25 closed router-level local backend streaming. PR28 closed direct MLX streaming. PR29 closed router-level local backend generation. Direct `LocalGGUFClient.stream(...)` remains the clean sibling seam: it is Core, in-process, non-UI, non-graph, and already has runtime-control-plane lifecycle semantics that can be mirrored into durable AgentEvents without changing generation behavior.

## Implementation Order
1. Add failing tests in `LocalGGUFClientTests` for successful, failed, and cancelled GGUF streams proving requested/started/completed/failed/cancelled AgentEvents and no secret leakage.
2. Add stream-specific provenance context/helpers to `LocalGGUFClient`.
3. Record requested/started before runtime launch.
4. Count chunks and output characters while preserving existing token delivery.
5. Record completed, failed, and cancelled terminal events with bounded classes and counts.
6. Do not change request resolution, GGUF model lookup, runtime-control-plane launch/finish policy, token streaming, lower runtime behavior, or app boot.

## Acceptance
- Successful stream records requested, started, completed with `local_stream.gguf`, source `local_gguf_client`, surface `stream`, provider `local_gguf`, bounded counts, and completed status.
- Failed stream records requested, started, failed with `backend_failure` or the mapped closed failure class.
- Cancelled stream records requested, started, failed with status `cancelled` and no arbitrary error text.
- Persisted AgentEvents exclude prompt text, system prompts, steering hints JSON, streamed output, model id, artifact id, filesystem paths, localized descriptions, arbitrary error text, Hermes/MCP/subprocess surfaces, browser/computer-use surfaces, LocalAuthentication, and ANE/private API details.
- Focused tests pass under `pipefail`.

## Canon Anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §8`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §9`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7`

## Workcard Match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: none. This gate names exact runtime files and focused tests as required.

## Failure-Proof Guardrails (Post-Merge)
- grep: `rg -n "local_stream\\.gguf|local-gguf-stream|surface.*stream" Epistemos/Engine/LocalGGUFClient.swift EpistemosTests/LocalGGUFClientTests.swift`
- log: `/tmp/epistemos-agent-event-local-gguf-stream-pr32-green-20260503.log`
- test: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/LocalGGUFClientTests test`

## Fleet Evidence Packet
- `docs/fusion/fleet/agent-event-local-gguf-stream-pr32/aggregator.md`
- `docs/fusion/fleet/agent-event-local-gguf-stream-pr32/claude-red-team/attacks.md` after Red Team returns

## Usefulness
usefulness: +1
usefulness_reason: Closes a real direct GGUF stream AgentEvent blind spot with no protected-surface work.
