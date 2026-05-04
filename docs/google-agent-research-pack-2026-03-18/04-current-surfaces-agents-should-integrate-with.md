# Current Surfaces Agents Should Integrate With

> **Index status**: SUPERSEDED-HISTORICAL — March 2026 Google research pack; superseded by IMPLEMENTATION_PLAN_FROM_ADVICE (April 2026 4-model council synthesis).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/google_research_packs/` for historical record.



The current app already has several strong surfaces that can host agents or agent-like flows.

## 1. Main chat

`ChatCoordinator` already runs the full chat query lifecycle:

```swift
@MainActor
final class ChatCoordinator {
    func handleQuery(_ query: String, pipeline: PipelineService, chatState: ChatState) {
        // query -> notes context -> pipeline -> streaming -> persistence
    }
}
```

Source:
- `Epistemos/App/ChatCoordinator.swift`

This suggests a strong V1 path:

- keep the main chat as the primary "receptionist" / triage surface
- let it dispatch to specialized agent sessions when appropriate

## 2. Note chat

`NoteChatState` is already a specialized note-scoped AI surface:

```swift
@MainActor @Observable
final class NoteChatState {
    var chatMode: NoteChatMode
    var overrideProvider: LLMProviderType?
    var onStreamStart: ((_ query: String) -> Void)?
    var onTokenFlush: ((_ delta: String) -> Void)?
    var noteBodyProvider: (() -> String)?
}
```

Source:
- `Epistemos/State/NoteChatState.swift`

This is an obvious host for:

- enrich note
- summarize note
- connect note
- rewrite note
- explain note
- turn note into outline / essay draft

## 3. Research service

The app already has a research-oriented service layer:

```swift
@MainActor @Observable
final class ResearchService {
    func searchPapers(query: String, yearRange: String? = nil) async throws -> [ResearchPaper]
    func checkNovelty(...) async throws -> NoveltyResult
    func reviewPaper(...) async throws -> ReviewResult
}
```

Source:
- `Epistemos/Engine/ResearchService.swift`

This is a natural foundation for a Research agent.

## 4. Query engine and graph search

The app already has a unified query engine:

```swift
@MainActor
@Observable
final class QueryEngine {
    func execute(query: String)
    func executeReactive(query: String)
}
```

Source:
- `Epistemos/Engine/QueryEngine.swift`

This is a strong foundation for:

- graph-aware retrieval
- knowledge graph search as a tool
- agent grounding over the user's second-brain data

## 5. Graph state and graph overlay

Even if graph NPCs are deferred, the graph remains useful as:

- a search and discovery tool
- a place to surface agent outputs later
- a context source for retrieval and linking

Graph theatrics should probably be deferred before core usefulness is proven.

## 6. Settings and current preferences architecture

The app already has a detached settings window and a live state/preferences system.

That means:

- agent permissions
- local/cloud routing controls
- proactive behavior controls
- read-aloud / TTS controls
- download/runtime status

can all fit into the existing settings architecture instead of requiring a separate agent app mode.

## Practical Integration Reading

The right first integration points are probably:

- main chat
- note chat
- research workflows
- note enrichment flows
- settings

The wrong first integration points are probably:

- graph NPC theatrics
- giant agent control panels
- full Builder IDE resurrection

