# Epistemos App Overview

## What the app is right now

Epistemos is a native macOS knowledge workstation. The current app is not a generic chatbot shell. It is a multi-surface desktop product with:

- a home window that switches between a landing experience and chat
- a detached settings window
- detached note windows with a high-performance AppKit markdown editor
- a full-screen graph overlay powered by Rust + Metal
- per-note AI chat
- current Apple Intelligence + cloud-provider routing

The current visual baseline is considered correct and should be preserved.

The user does **not** want:

- the old library feature
- the old nav pill structure
- broad restoration of older agent-system UI
- a heavy-handed redesign

## Main surfaces

### 1. Main app window

The app boots into a root SwiftUI scene and injects a centralized environment graph:

```swift
@main
struct EpistemosApp: App {
    @State private var bootstrap = AppBootstrap()

    var body: some Scene {
        Window("Epistemos", id: "main") {
            RootView(
                databaseError: bootstrap.databaseError,
                onResetDatabase: { bootstrap.resetDatabaseAndRelaunch() }
            )
            .withAppEnvironment(bootstrap)
        }
        .modelContainer(bootstrap.modelContainer)
    }
}
```

### 2. Root/home architecture

The top-level home window is intentionally simple right now:

```swift
private struct HomeRouter: View {
    @Environment(ChatState.self) private var chat

    private var showChat: Bool { !chat.messages.isEmpty && !chat.showLanding }

    var body: some View {
        ZStack {
            if showChat {
                ChatView()
            } else {
                LandingView()
            }
        }
    }
}
```

This means any new local AI / TTS work should fit into the current home/chat split, not revive old shell complexity.

### 3. Notes

Notes are not lightweight SwiftUI text editors. They are AppKit-backed, persistent-editor windows with markdown storage, inline AI streaming, folding, block refs, tables, and right-click AI operations.

### 4. Graph

The graph is a separate overlay window managed by a singleton controller and backed by a Rust engine. It is not a simple in-view SwiftUI graph.

### 5. Settings

Settings already exist as a standalone split-view window and already contain inference and landing sections. New local-AI / TTS controls should fit this current settings architecture.

## Current dependency injection pattern

The app uses one centralized environment injection path:

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
            .environment(bootstrap.physicsCoordinator)
            .environment(bootstrap.dialogueChatState)
    }
}
```

This matters because any MLX manager, local model manager, or voice engine should fit this centralized bootstrap/environment model, not create ad hoc global wiring.

## What must not regress

- launch performance
- home window fluidity
- note editor performance
- graph overlay responsiveness
- existing Apple Intelligence routing
- current settings window behavior
- current visual identity

## Architectural tone to preserve

The app is already aiming at:

- native-feeling macOS UX
- high-polish visuals
- fast interaction
- strong AppKit where needed
- Rust only where it materially helps
- minimal UI clutter

Research should assume this product direction is correct.
