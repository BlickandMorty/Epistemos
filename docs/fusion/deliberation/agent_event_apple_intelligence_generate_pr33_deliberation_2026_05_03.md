# Deliberation - AgentEvent Apple Intelligence Generate PR33

## Classification

- Tier: Core
- Slice: `agent-event-apple-intelligence-generate-pr33`
- Canon anchors:
  - `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H3
  - `MASTER_RESEARCH_INDEX_2026_05_02.md` §12
  - `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` Safe Next Build Order / OpLog-GraphEvent-AgentEvent provenance hardening
  - `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7

## Report Before Code

Apple Intelligence is a real on-device provider path and is Core-compatible in the App Store profile. The direct `AppleIntelligenceService.generate(...)` boundary currently has no AgentEvent provenance, even though cloud, GGUF, MLX, local backend, image-generation, and search/runtime surfaces now do.

## Allowed Files

- `Epistemos/Engine/AppleIntelligenceService.swift`
- `EpistemosTests/AppleIntelligenceServiceAgentEventTests.swift`
- `docs/fusion/**`

## Forbidden Files

- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `epistemos-core/**`
- generated bindings/libraries
- Xcode project files
- Hermes/MCP/subprocess/browser/computer-use surfaces
- `LocalAuthentication` / `LAContext`
- ANE/private API
- EventStore schema
- routing policy / provider selection semantics

## Implementation Order

1. Write failing focused Swift Testing coverage for successful and failed direct Apple Intelligence generation provenance.
2. Add minimal test seams to instantiate `AppleIntelligenceService` with a recorder and deterministic generate/thermal/system-prompt closures.
3. Record requested/started before generation and completed/failed after generation with one run id and one `apple-intelligence-generate:N` tool call id.
4. Persist only sanitized metadata and counts: provider, surface, prompt/system prompt char counts, augmented-system-prompt presence, elapsed milliseconds, output character count, success, and bounded failure class.
5. Preserve existing FoundationModels availability, breaker, thermal, session recycling, context-window retry, and knowledge-vault prompt behavior.

## Acceptance

- Success records requested, started, completed AgentEvents for `AppleIntelligenceService.generate(...)`.
- Failure records requested, started, failed AgentEvents with bounded error class and no arbitrary error text.
- Tests prove prompt text, system prompt text, augmented prompt content, generated output, localized descriptions, and arbitrary error text are not persisted in arguments/results/errors/metadata.
- Source guards prove no Hermes, MCP, subprocess, browser/computer-use, LocalAuthentication, ANE/private API, graph, Rust, generated binding, or EventStore schema work.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H3
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §12
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: this is a new exact-runtime-file gate under Card 7's "broader runtime instrumentation" clause.

## Failure-Proof Guardrails (post-merge)

- grep: `apple_intelligence.generate`
- log: `/tmp/epistemos-agent-event-apple-intelligence-generate-pr33-green-20260503.log`
- test: `AppleIntelligenceServiceAgentEventTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/agent-event-apple-intelligence-generate-pr33/aggregator.md`
- `docs/fusion/fleet/agent-event-apple-intelligence-generate-pr33/claude-red-team/attacks.md` (added after red team)

## Usefulness

usefulness: +1
usefulness_reason: Closes a real Core on-device runtime provenance gap without changing provider behavior.
