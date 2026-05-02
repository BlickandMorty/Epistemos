# AgentEvent Pipeline Hook Mount PR6 Deliberation - 2026-05-02

## Decision

Approved for a narrow production call-site mount inside `PipelineService`'s
local tool-loop path.

## Goal

Use the already-closed `HookRegistry` lifecycle/provenance API in the first
clean production runtime chokepoint. This slice mounts hook calls around
prompt-build and local tool execution without changing approval policy,
routing, UI, streaming, provider selection, graph behavior, Rust bindings, or
Omega.

## Authority Read First

- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
  Card 7.
- `docs/fusion/deliberation/agent_event_hook_registry_pr4_deliberation_2026_05_01.md`.
- `Epistemos/Engine/PipelineService.swift`.
- `Epistemos/Engine/HookRegistry.swift`.
- `EpistemosTests/SourceMirrorTestSupport.swift`.

## Allowed Write Set

- `Epistemos/Engine/PipelineService.swift`.
- `EpistemosTests/PipelineHookRegistryMountTests.swift`.
- `docs/fusion/deliberation/agent_event_pipeline_hook_mount_pr6_deliberation_2026_05_02.md`.
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`.
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`.

## Forbidden Write Set

- `Epistemos/App/ChatCoordinator.swift`.
- `Epistemos/Omega/**`.
- `Epistemos/Engine/HookRegistry.swift`.
- `Epistemos/State/EventStore.swift`.
- `Epistemos/Models/AgentProvenanceEvent.swift`.
- `Epistemos/Views/Graph/**`.
- `Epistemos/Graph/**`.
- `Epistemos/Views/Notes/ProseEditor*.swift`.
- `Epistemos/Views/Notes/ProseTextView2.swift`.
- `graph-engine/**`.
- `agent_core/**`.
- generated Swift/header bindings, generated libraries, Xcode project files,
  entitlements, DerivedData, `.xcresult`, or build artifacts.

## Implementation Contract

- Mount `HookRegistry.shared.fireBeforePromptBuild` in the local tool-loop
  prompt path only.
- Mount `HookRegistry.shared.fireBeforeToolCall` and
  `HookRegistry.shared.fireAfterToolCall` around observed local tool execution.
- Preserve existing behavior when no hooks are registered.
- If a hook cancels a tool call, return a structured local tool error without
  changing human approval semantics.
- Do not emit fake tool provenance for hook events; `HookRegistry` already owns
  hook AgentEvents.
- Do not claim Omega, ChatCoordinator, provider-native tools, or direct-stream
  paths are mounted.

## Tests And Logs

- Red:
  `/tmp/epistemos-agent-event-hook-mount-pr6-red-20260502.log`.
- Green:
  `/tmp/epistemos-agent-event-hook-mount-pr6-green-20260502.log`.
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/PipelineHookRegistryMountTests test`.
- Guardrails:
  `git diff --check`.
  staged protected-path scan.
  code diff grep for forbidden runtime files.

## Acceptance

- Source guard proves `PipelineService` mounts prompt-build and local tool-call
  hook points.
- Source guard proves the mount stays out of ChatCoordinator, Omega, graph,
  Rust, generated bindings, and protected editor files.
- Focused tests pass.

## Result

- Red was valid: the source guard failed before `PipelineService` mounted
  HookRegistry.
- Green passed: `PipelineHookRegistryMountTests` ran 2 Swift Testing tests with
  0 failures. Xcode still printed known SwiftLint package-plugin noise after
  `TEST SUCCEEDED`.
- Closed scope: PipelineService local tool-loop prompt-build, before-tool, and
  after-tool hooks only.
- Still out of scope: Omega, ChatCoordinator, provider-native tools,
  direct-stream paths, graph, Rust, generated bindings, EventStore schema,
  approvals, and UI control flow.

## Stop Triggers

- The slice needs a provider route, Omega edit, ChatCoordinator edit, approval
  policy change, Rust/generated binding change, graph/editor edit, or Xcode
  project change.
- Hook mounting requires changing `HookRegistry` persistence semantics.
- The implementation changes behavior when no hooks are registered.
