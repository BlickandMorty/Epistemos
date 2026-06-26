# Swift Chat Donor Contracts

This folder is the anti-drift ledger for the Swift Chat lane. The owner intent
is not "AgentClone mounted, done." The real target is a capability-preserving
Epistemos Chat surface: old Epistemos chat ontology, new Swift clone foundation,
and every donor repo used where it actually improves the app.

The build-facing contract package is:

- `LocalPackages/EpistemosChatDonorContracts`

That package defines the donor IDs, import modes, destination seams, threading
policy, memory policy, and proof requirements. It is intentionally
dependency-free so future agents can run it quickly and use it as the first gate
before changing Chat.

## Donor Rule

Every donor must finish in one honest state:

- implemented as live product code,
- adapted through an Epistemos-owned adapter,
- clean-room recreated because the license is unresolved,
- reference-only with a source-backed rejection,
- or blocked with a source-backed reason.

No donor may silently disappear.

## Native Performance Rule

Every runtime donor contract must preserve:

- UI updates on `MainActor`;
- provider, tool, MCP, parsing, persistence, and workflow work off the main
  actor;
- structured concurrency and explicit cancellation;
- bounded stream buffers;
- large files as resource chips instead of prompt-sized string copies;
- preallocated hot buffers where stream/render loops are involved;
- proof commands and endpoint/visual checks before marking complete.

## Current Contracts

| Donor | Contract ID | Role |
|---|---|---|
| AgentClone | `agent-clone.visible-foundation` | Full visible Chat foundation and current live capability stack |
| AgentClone | `agent-clone.capability-preservation-manifest` | Provider/tool/MCP/session/history/rollback/usage/permission/messages/settings/automation inventory adapted with source-anchor tests |
| AgentClone | `agent-clone.visible-ontology-chrome` | Mounted Epistemos title/context/model chrome and monospace user/composer/tool styling adapted with source tests; fresh visual readback still required |
| AgentClone | `agent-clone.start-message-bar-ontology` | Empty/start Chat lands directly on Epistemos message bar; donor instruction copy removed with source and visual proof |
| AgentClone | `agent-clone.full-app-chat-route-start-proof` | Current code hosts `AgentClone.ContentView()` inside an Epistemos-owned Chat/Act shell while keeping theme tokens and prompt-bridge ownership |
| AgentClone | `agent-clone.chatview2-route-ontology` | Rejected historical route experiment; ChatView 2 may inform visual language only, while the live RootView route remains an AgentClone-backed Epistemos host shell |
| AgentClone | `agent-clone.chatview2-brain-panel-parity` | Rejected historical panel experiment; old ChatBrainPanel diagnostics may inform future progressive disclosure only inside AgentClone |
| AgentClone | `agent-clone.chatview2-transcript-bubble-parity` | Rejected historical transcript experiment; old MessageBubble visual language must be rebuilt over AgentClone message models, not restored through the deleted backend route |
| AgentClone | `agent-clone.message-bar-layout-parity` | AgentClone package composer is capped to the old 620pt Epistemos/MiniChat rhythm; current full app route hosts AgentClone in the Epistemos shell |
| Agent upstream | `agent-upstream.provenance-baseline` | Provenance/diff baseline |
| Swarm | `swarm.typed-runtime-substrate` | Typed runtime, tools, memory/session, guardrails, workflow, observability |
| Swarm | `swarm.in-process-chat-substrate` | Bounded explicit provider/session/event projection substrate adapted with tests; visible AgentClone shell preserved |
| SwiftedMind | `swiftedmind.transcript-stream-values` | Streaming/session/tool-call values; fragment buffer/token usage adapted with tests |
| MCP Swift SDK | `mcp-swift-sdk.canonical-mcp-bridge` | Canonical live MCP bridge contract; endpoint proof still pending |
| MCP Swift SDK | `mcp-swift-sdk.semantic-values` | Tools/resources/prompts/progress/cancel/auth/elicitation semantics adapted with tests |
| AgentSDK Swift | `agentsdk.typed-agent-boundaries` | Typed agent/tool/guardrail/handoff boundaries adapted with tests |
| AgentKit | `agentkit.lightweight-agent-ergonomics` | Broad retry/callback/window/MCP ergonomics contract; live service lifecycle still pending |
| AgentKit | `agentkit.retry-window-callbacks` | Retry/backoff receipts, callback ordering, and conversation windowing adapted with tests |
| AgentKit | `agentkit.mcp-ergonomics` | MCP config decoding, tool routing/wrappers, prompt rendering, and server capability assembly adapted with tests |
| Foundation Models example | `foundation-models.apple-native-model-ux` | Apple-native model UX motifs |
| Foundation Models example | `foundation-models.availability-options-values` | Apple-native availability, runtime picker, generation options, and structured-output values adapted with tests |
| Foundation Models example | `foundation-models.runtime-picker-live-readback` | Existing Epistemos picker carries Apple-native availability/settings/new-session readback with tests; broad visual UX still pending |
| swiftagent-1amageek | `swiftagent-1amageek.permissions-sandbox-cleanroom` | Broad permission/sandbox/approval/cancel motifs, clean-room only; skills/MCP/sandbox execution still pending |
| swiftagent-1amageek | `swiftagent-1amageek.permission-policy-cleanroom` | Clean-room permission rules, approval receipts, sandbox requirements, timeout, and turn cancellation adapted with tests |
| swiftaia-agent | `swiftaia-agent.workflow-model-cleanroom` | Clean-room workflow, model-output, tool-call parsing, goal-plan, and max-iteration motifs adapted with tests |

## Verification

Run:

```sh
swift test --package-path LocalPackages/EpistemosChatDonorContracts
```

The tests require every listed Swift donor to have a valid contract, bounded
memory policy, native threading policy, and proof requirement.
