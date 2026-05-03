# Hermes Provider Surface Policy PR8 Deliberation - 2026-05-02

Slice: `hermes-provider-surface-policy-pr8`

Tier: Pro

## Decision

Approved: strengthen the existing Hermes Gateway policy so the actual cloud
provider families are first-class gateway surfaces, not an implied generic
cloud bucket. This is policy-only scaffolding for the user's Hermes-as-cloud-
gateway direction and does not migrate runtime provider code yet.

## Allowed Files

- `Epistemos/LocalAgent/HermesGatewayPolicy.swift`
- `EpistemosTests/HermesGatewayPolicyTests.swift`
- `docs/fusion/fleet/hermes-provider-surface-policy-pr8/**`
- `docs/fusion/deliberation/hermes_provider_surface_policy_pr8_deliberation_2026_05_02.md`
- `docs/fusion/oversight/PREFLIGHT_38_2026_05_02.md`
- Canon status/guard docs after verification.

## Forbidden Files

- `Epistemos/Engine/CloudLLMClient.swift`
- `Epistemos/Engine/CloudProviderAuthService.swift`
- `Epistemos/Engine/LLMService.swift`
- `Epistemos/Engine/TriageService.swift`
- `Epistemos/Omega/**`
- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `epistemos-core/**`
- Xcode project files, entitlements, generated bindings, generated libraries,
  subprocess launchers, MCP bridges, browser/computer-use, Docker/devcontainer,
  and network/auth runtime code.

## Implementation

- Add named cloud-provider gateway surfaces for OpenAI, Anthropic, Google,
  OpenAI-compatible providers, and Codex account-backed providers.
- Keep every named cloud provider Pro/Research, network-required, and routed to
  `.hermesGateway`.
- Keep direct deterministic substrate and in-process local prompt formatting
  Core-safe and non-gateway.
- Add focused tests that fail until these named provider surfaces are present.

## Verification

- Red log: `/tmp/epistemos-hermes-provider-surface-pr8-red-20260502.log`
- Green log: `/tmp/epistemos-hermes-provider-surface-pr8-green-20260502.log`
- Claude red-team: `docs/fusion/fleet/hermes-provider-surface-policy-pr8/claude-red-team/attacks.md`
- Claude P1 resolution: `.cloudProvider` is included in
  `cloudProviderSurfaces`, `externalGatewaySurfaces` composes from that group,
  and the focused test suite now includes a composition regression test.
- Focused command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/HermesGatewayPolicyTests test`

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §6
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §12
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §22

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 10 - Hermes Gateway Directness
- Deviation: none. This is an allowed pure-policy follow-up.

## Failure-Proof Guardrails (post-merge)

- grep: `cloudProviderSurfaces|openAIProvider|anthropicProvider|googleProvider|openAICompatibleProvider|codexAccountProvider`
- grep: `externalGatewaySurfaces: [Self] = cloudProviderSurfaces`
- forbidden grep: `URLSession|Process\.|MCPBridge|DockerClient|DockerBridge|docker run|LAContext|evaluatePolicy`
- log: `✔ Test "named cloud provider surfaces are gateway only" passed`
- log: `✔ Test "external gateway surfaces compose all cloud provider surfaces" passed`
- test: `HermesGatewayPolicyTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/hermes-provider-surface-policy-pr8/aggregator.md`
- `docs/fusion/fleet/hermes-provider-surface-policy-pr8/claude-red-team/attacks.md`

## Usefulness

usefulness: +1

usefulness_reason: Turns Hermes cloud-gateway exclusivity into a named policy invariant while preserving Core directness.
