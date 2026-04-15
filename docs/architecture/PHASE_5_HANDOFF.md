# Phase 5 Handoff

Status: historical closure record

Historical note:

The blocker analysis below was accurate when written, but it is no longer the active gate for starting Phase 6.

Use `docs/architecture/PHASE_6_PROTOCOL.md` for the current Phase 6 startup protocol and current readiness state.

Date: 2026-04-14

## Scope

This handoff covers the Phase 5 Agent Command Center / product-intelligence slice described in:

- `docs/architecture/PLAN_V2.md`
- `docs/architecture/CODEX_CONTEXT_PACK.md`
- `docs/architecture/RESEARCH_INDEX.md`
- `docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`
- `docs/architecture/PHASE_4_HANDOFF.md`
- `docs/google-agent-research-pack-2026-03-18/03-implemented-agent-history-what-was-real.md`
- `docs/google-agent-research-pack-2026-03-18/04-current-surfaces-agents-should-integrate-with.md`
- `docs/google-agent-research-pack-2026-03-18/05-architecture-options-and-recommended-direction.md`
- `docs/google-agent-research-pack-2026-03-18/06-model-routing-memory-and-tooling-strategy.md`
- `AGENT_COMMAND_CENTER_UX_HANDOFF.md`

Local research that may still be useful, but must not override the architecture docs:

- `jojo/release/new agents/new research on agents/claude's research/CLAUDE.md`
- `jojo/release/new agents/new research on agents/claude's research/EPISTEMOS_GAP_ANALYSIS.md`
- `jojo/last feature after new agents/outdated research/Hermes Agent Integration Research.md`
- `docs/plans/2026-03-07-agent-system-implementation-plan.md`

Those documents are historical or exploratory. `PLAN_V2.md` and the architecture bundle remain the build authority.

## Phase 5 Verdict

The repo has a real Phase 5 Agent Command Center shell now.

What is real and already landed:

- dedicated `AgentCommandCenterState`
- dedicated `AgentChatState`
- dedicated `CommandInputParser`
- dedicated SwiftUI overlay and shell views under `Epistemos/Views/AgentCommandCenter/`
- `RootView` overlay wiring
- landing shortcut / entry point
- main chat simplified so advanced controls move toward the Command Center
- dedicated `handleCommandCenterSubmission()` path in `ChatCoordinator`
- dedicated `planForCommandCenter()` path in `OverseerProtocol.swift`
- project and tests wired for the new files

That means Phase 5 is no longer just an idea.

It also means Phase 6 should **not** start yet.

Historical note as of 2026-04-14: this verdict is superseded by
`docs/architecture/PHASE_6_PROTOCOL.md` for current Communication + Media work.
Use the Phase 6 protocol and the latest Phase 6 handoff as the active source of
truth for whether Phase 6 is blocked or ready to close.

The current implementation is a meaningful shell, but it does not yet satisfy the stricter Phase 5 rules from `PLAN_V2` and the supporting research.

## Why Phase 6 Is Still Blocked

### 1. `@` context attachment is mostly UI-local today

Files:

- `Epistemos/Engine/CommandInputParser.swift`
- `Epistemos/State/AgentCommandCenterState.swift`
- `Epistemos/App/ChatCoordinator.swift`

What is true:

- `@` mentions parse correctly
- attached mentions render in the UI
- `handleCommandCenterSubmission()` receives `mentions`

What is still missing:

- the mentions are not compiled into real context refs or resolved note/tool/graph payloads
- the current submission path passes `notesContext: nil`
- mention presence only affects a boolean (`hasExplicitContext`) instead of providing real control-plane evidence

This means explicit context attachment is not yet an authoritative runtime input.

### 2. Inspector truth is still mostly local UI state, not Rust/runtime truth

Files:

- `Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift`
- `Epistemos/State/AgentCommandCenterState.swift`
- `Epistemos/App/ChatCoordinator.swift`

What is true:

- the inspector tabs exist
- the panel renders Context / Capabilities / Plan / Execution

What is still missing:

- the inspector mostly reads `AgentChatState` and local `AgentCommandCenterState`
- `ACCExecutionDiagnostics` is too small for the architecture contract
- requested vs resolved runtime is not surfaced
- execution policy reference is not surfaced
- resolved permissions are not surfaced
- child-agent turn counts and hierarchy diagnostics are not surfaced
- error class / fallback truth is not surfaced

The architecture requires the inspector to mirror execution truth, not infer it from presentation state.

### 3. Command Center request compilation is still too Swift-owned

Files:

- `Epistemos/Engine/OverseerProtocol.swift`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/State/AgentCommandCenterState.swift`

`PLAN_V2` is explicit:

- SwiftUI owns parsing and explicit user choices
- Rust owns request compilation, routing, permissions, policy, telemetry, and runtime truth

Current status:

- Swift parses the command line correctly
- Swift also decides a large amount of planning and routing behavior in `planForCommandCenter()`
- tool permissions are built in Swift
- route selection is built in Swift
- operating-mode-driven depth and expert selection are built in Swift

That is good scaffolding, but it is still short of the intended authority boundary.

### 4. Requested brain override does not yet come back as requested vs resolved runtime truth

Files:

- `Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift`
- `Epistemos/State/AgentCommandCenterState.swift`
- `Epistemos/App/ChatCoordinator.swift`

What is true:

- explicit brain selection UI exists
- the selection is passed into the submission path

What is still missing:

- no authoritative requested-runtime summary comes back into the inspector
- no resolved-runtime summary is shown beside it
- no clear fallback / denial explanation is shown when the selected brain cannot be honored

Phase 5 requires explicit, inspectable runtime truth.

### 5. Hierarchical agent inspection is not real yet

Files:

- `docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`
- `Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift`
- `Epistemos/App/ChatCoordinator.swift`

What is still missing:

- no surfaced overseer -> main agent -> sub-agent trace
- no structured inter-agent message log in the inspector
- no visible child-agent budget or turn accounting
- no audit-style display of message flow or evidence refs

The repo has hierarchy architecture docs and some lower-level runtime work, but the Command Center surface does not yet expose that hierarchy in a way that matches the product direction.

### 6. Test coverage is still below the requested Phase 5 contract

Files:

- `EpistemosTests/CommandInputParserTests.swift`
- `EpistemosTests/AgentCommandCenterStateTests.swift`
- `EpistemosTests/AgentChatStateTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

What is good:

- parser basics are covered
- state basics are covered
- main-chat simplification is covered

What is still missing:

- no strong test that mention attachments become real compiled context
- no strong test that requested vs resolved runtime is preserved in Command Center summaries
- no strong test that the inspector is driven by runtime diagnostics instead of local-only UI state
- no strong test of hierarchy/execution diagnostics
- no strong test proving the dedicated planner path honors explicit user choices end to end through runtime truth

## What Claude Should Treat As Already Complete

Do not redo these unless you find a concrete regression:

- the Command Center overlay exists
- parser and suggestion UI exist
- landing and root-shell entry points exist
- main chat has already been intentionally simplified
- the project file already includes the new files
- baseline parser/state tests already exist

## What Claude Should Do Next To Actually Close Phase 5

Implement in this order:

1. Define a normalized Command Center request/summary boundary that preserves:
   - explicit mentions/context refs
   - requested brain/runtime
   - resolved runtime
   - execution policy ref
   - resolved tool permissions
   - child-agent / hierarchy telemetry
2. Move Command Center request compilation authority behind the Rust-owned control-plane boundary.
   - Swift should parse
   - Rust should resolve
3. Resolve `@` mentions into real context inputs before execution.
   - notes
   - graph entities
   - tool targets
   - vault/global scopes
4. Replace inspector-local inference with authoritative execution diagnostics.
5. Add hierarchy inspection surfaces that reflect the allowed topology from `OVERSEER_AND_AGENT_HIERARCHY.md`.
6. Add focused tests for the above contract.

## Minimum Exit Criteria Before Phase 6

Do not call Phase 5 complete unless all are true:

1. explicit `@` attachments become real execution context, not just chips
2. requested brain/provider and resolved runtime are both visible
3. the inspector is driven by runtime truth, not local guesswork
4. Rust owns final request compilation / routing / permission truth for the Command Center path
5. hierarchy and execution diagnostics are inspectable and auditable
6. focused tests cover the Command Center contract, not just the parser shell

If any of those are still false, Phase 6 is not ready to start.

## Recommended Read Order For Claude

Read in this order before editing:

1. `docs/architecture/PLAN_V2.md`
2. `docs/architecture/CODEX_CONTEXT_PACK.md`
3. `docs/architecture/RESEARCH_INDEX.md`
4. `docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`
5. `docs/architecture/PHASE_4_HANDOFF.md`
6. `docs/google-agent-research-pack-2026-03-18/03-implemented-agent-history-what-was-real.md`
7. `docs/google-agent-research-pack-2026-03-18/04-current-surfaces-agents-should-integrate-with.md`
8. `docs/google-agent-research-pack-2026-03-18/05-architecture-options-and-recommended-direction.md`
9. `docs/google-agent-research-pack-2026-03-18/06-model-routing-memory-and-tooling-strategy.md`
10. `AGENT_COMMAND_CENTER_UX_HANDOFF.md`
11. `Epistemos/State/AgentCommandCenterState.swift`
12. `Epistemos/State/AgentChatState.swift`
13. `Epistemos/Engine/CommandInputParser.swift`
14. `Epistemos/App/ChatCoordinator.swift`
15. `Epistemos/Engine/OverseerProtocol.swift`
16. `Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift`
17. `Epistemos/Views/AgentCommandCenter/CommandBarView.swift`
18. `Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift`
19. `Epistemos/Views/Chat/ChatInputBar.swift`
20. `Epistemos/Views/Chat/ChatView.swift`
21. `Epistemos/App/RootView.swift`
22. `Epistemos/Views/Landing/LandingView.swift`
23. `EpistemosTests/CommandInputParserTests.swift`
24. `EpistemosTests/AgentCommandCenterStateTests.swift`
25. `EpistemosTests/AgentChatStateTests.swift`
26. `EpistemosTests/RuntimeValidationTests.swift`

Use the older local research only after this read order, and only as inspiration.

## Final Instruction To Claude

Do not treat the current Command Center shell as Phase 5 complete.

Treat it as a strong partial landing:

- the UI shell is real
- the app integration is real
- the parser is real
- the product direction is correct

But the architecture contract is not closed until explicit context, runtime truth, and Rust-owned resolution are fully wired through the Command Center path.
