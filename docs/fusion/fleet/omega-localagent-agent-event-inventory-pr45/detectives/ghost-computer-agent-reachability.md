---
role: detective
slice: omega-localagent-agent-event-inventory-pr45
concept: GhostComputerAgent reachability and AgentEvent closure
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §14
tier: Pro
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/omega-localagent-agent-event-inventory-pr45/claude-side-fleet/OMEGA_LOCALAGENT_AGENT_EVENT_INVENTORY_2026_05_03.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/GhostComputerAgentReachabilityGuardTests.swift:10
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase4Bridge.swift:53
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/StreamingDelegate.swift:453
  - /Users/jojo/Downloads/Epistemos/agent_core/src/agent_loop.rs:916
drift:
  detected: false
load_bearing_quote: "If GhostComputerAgent becomes routed, add a dedicated provenance slice instead of silently half-instrumenting it"
verdict: closed
usefulness: +1
usefulness_reason: Closes PR45 as an explicit no-route guard instead of adding duplicate high-risk provenance.
---

## Findings

- `GhostComputerAgentReachabilityGuardTests` proves production Swift must not instantiate `GhostComputerAgent(` outside `GhostComputerAgent.swift`.
- The same guard blocks calls to `GhostComputerAgent.mcpSee`, `mcpClick`, `mcpType`, `mcpKeys`, `mcpScroll`, and `mcpScreenshot`.
- The canonical shipping path remains `ComputerUseBridge`: `Phase4Bridge` calls `ComputerUseBridge.shared.execute(actionJSON: actionJson)`, `StreamingDelegate` calls the same bridge, and Rust delegates `name == "computer"` through the native computer-action callback.
- `GhostComputerAgent` still compiles and exposes high-risk actions, but it remains `#if !EPISTEMOS_APP_STORE` and has no `AgentToolProvenanceRecorder` until a future slice deliberately routes it.

## Verification

- Focused command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/GhostComputerAgentReachabilityGuardTests test`
- Log: `/tmp/epistemos-ghost-computer-agent-reachability-guard-pr45-20260503.log`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: 4 tests in 1 suite passed.

## Recommendation

Treat PR45 as closed with no production code changes. Future computer-use routing must stay on `ComputerUseBridge`; if any production caller begins routing through `GhostComputerAgent`, open a dedicated provenance slice first with ComputerUseBridge-grade sanitization tests.
