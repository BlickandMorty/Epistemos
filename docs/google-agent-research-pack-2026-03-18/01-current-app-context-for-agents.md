# Current App Context For Agents

This file explains the live app architecture that any new agent system must fit into.

## Product Shape Today

Epistemos is already a real AI-enabled knowledge app. It is not a blank slate.

Current major surfaces:

- Home / landing window
- Main AI chat
- Native note windows with AppKit-backed markdown editing
- Inline note chat
- Research service
- Graph overlay powered by Rust + Metal
- Settings window

The correct direction is to extend these surfaces, not replace them.

## App Bootstrap And Environment Graph

The app already has a centralized bootstrap and environment system:

```swift
@MainActor
final class AppBootstrap {
    let chatState = ChatState()
    let pipelineState = PipelineState()
    let uiState = UIState()
    let notesUI = NotesUIState()
    let researchState = ResearchState()
    let soarState = SOARState()
    let inferenceState: InferenceState
    let dailyBriefState = DailyBriefState()
    let threadState = ThreadState()
    let graphState = GraphState()
    let queryEngine = QueryEngine()

    let llmService: LLMService
    let triageService: TriageService
    let researchService: ResearchService
    let vaultSync: VaultSyncService
    let pipelineService: PipelineService
}
```

Source:
- `Epistemos/App/AppBootstrap.swift`

Environment injection is already centralized:

```swift
extension View {
    func withAppEnvironment(_ bootstrap: AppBootstrap) -> some View {
        self
            .environment(bootstrap.uiState)
            .environment(bootstrap.chatState)
            .environment(bootstrap.pipelineState)
            .environment(bootstrap.notesUI)
            .environment(bootstrap.researchState)
            .environment(bootstrap.soarState)
            .environment(bootstrap.eventBus)
            .environment(bootstrap.inferenceState)
            .environment(bootstrap.llmService)
            .environment(bootstrap.triageService)
            .environment(bootstrap.researchService)
            .environment(bootstrap.vaultSync)
            .environment(bootstrap.dailyBriefState)
            .environment(bootstrap.threadState)
            .environment(bootstrap.graphState)
            .environment(bootstrap.queryEngine)
    }
}
```

Source:
- `Epistemos/App/AppEnvironment.swift`

Implication:
- agents should plug into the existing bootstrap/environment graph
- avoid introducing a second parallel dependency world

## Current LLM And Routing Stack

The app already has:

- `InferenceState`
- `LLMService`
- `TriageService`
- `PipelineService`
- `ChatCoordinator`

Current triage is Apple-vs-cloud, not yet full Apple-vs-MLX-vs-cloud:

```swift
nonisolated enum TriageDecision: Sendable, Equatable {
    case appleIntelligence
    case apiProvider
}

@MainActor @Observable
final class TriageService {
    private let inference: InferenceState
    private let llmService: any LLMClientProtocol
}
```

Source:
- `Epistemos/Engine/TriageService.swift`

Implication:
- agent routing should probably extend this stack, not replace it
- Apple Intelligence remains the trivial-task route
- MLX local can become the next local tier
- cloud remains necessary for frontier-quality agent reasoning

## Current Main Chat

The main chat already has:

- session state
- streaming
- reasoning text
- research mode
- ambient vault context
- persistence through coordinators

```swift
@MainActor @Observable
final class ChatState {
    var isStreaming = false
    var streamingText = ""
    var activeChatId: String?
    var messages: [ChatMessage] = []
    var showLanding = true
    var isResearchMode: Bool
}
```

Source:
- `Epistemos/State/ChatState.swift`

Implication:
- an agent system can likely piggyback on existing chat/session concepts
- the app already knows how to stream model output safely

## Design Constraint

Any serious agent system should:

- reuse `AppBootstrap`
- reuse `withAppEnvironment`
- reuse `InferenceState` / `LLMService` / `TriageService`
- reuse `ChatCoordinator` style orchestration patterns
- preserve the current UI

The best path is additive and native, not a reset.

