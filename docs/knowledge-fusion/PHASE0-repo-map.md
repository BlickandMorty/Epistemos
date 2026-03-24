# Phase 0: Epistemos Repository Map

## Project Structure

- **170 Swift files** across App/, Engine/, State/, Models/, Graph/, Views/, Sync/, Theme/, Intents/
- **47 Rust files** in graph-engine/src/
- Xcode project: Epistemos.xcodeproj
- Rust FFI: graph-engine-bridge/graph_engine.h (895 lines, ~19 exported functions)

## AI Pipeline

| Component | File | Role |
|-----------|------|------|
| Routing | Engine/TriageService.swift (53KB) | Complexity-based routing: Apple Intelligence vs local Qwen vs cloud |
| Inference | Engine/MLXInferenceService.swift (29KB) | MLX.framework native integration for local models |
| Model management | Engine/LocalModelInfrastructure.swift (39KB) | Model descriptors, paths, installation tracking |
| Gateway | Engine/LLMService.swift (33KB) | Shared text generation gateway |
| Apple AI | Engine/AppleIntelligenceService.swift | Apple on-device AI bridge |
| Download | Engine/ModelDownloadManager.swift | Hugging Face Hub model download |

## Model Loading Path

1. LocalModelManager tracks installed models on disk
2. LocalModelDescriptor holds metadata (size, min memory, display name)
3. LocalModelPaths resolves: ~/Library/Application Support/Epistemos/Models/text/active/{slug}/
4. MLXInferenceService loads via MLX.framework (native, not subprocess)
5. LocalMLXRequest wraps: modelID, modelDirectory, prompt, maxTokens

## Key Finding: No Python Process Bridge Exists

All inference is framework-integrated. Knowledge Fusion introduces the first Swift→Python process bridge for training scripts.

## SwiftData Schema (10 models)

SDPage, SDBlock, SDFolder, SDWorkspace, SDChat, SDMessage, SDGraphNode, SDGraphEdge, SDPageVersion, SDNoteInsight

Database: ~/Library/Application Support/Epistemos/{name}.sqlite

## Environment Pattern

AppBootstrap.swift creates all state objects → AppEnvironment.withAppEnvironment(bootstrap) injects them.
31 total state objects injected via single modifier chain.

## Existing Patterns to Follow

- @MainActor @Observable for state classes
- withAppEnvironment(bootstrap) for injection
- Swift Testing (@Suite, @Test, #expect) — not XCTest
- Task { @MainActor in } for async work
- guard let / if let — no force unwraps
