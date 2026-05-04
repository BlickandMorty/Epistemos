# Current AI / Inference Stack

> **Index status**: SUPERSEDED-HISTORICAL — March 2026 Google research pack; superseded by IMPLEMENTATION_PLAN_FROM_ADVICE (April 2026 4-model council synthesis).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/google_research_packs/` for historical record.



## Current state

Right now the app has:

- Apple Intelligence support
- cloud providers
- Ollama support
- no active MLX provider in the current branch

The old MLX implementation existed historically in git, but it is not the live runtime path today.

## Current provider model

`InferenceState` currently tracks cloud providers and Apple Intelligence availability:

```swift
@MainActor @Observable
final class InferenceState {
    var inferenceMode: InferenceMode = .analytical
    var apiProvider: LLMProviderType = .anthropic

    var anthropicKey: String = ""
    var openaiKey: String = ""
    var googleKey: String = ""
    var kimiKey: String = ""

    var openaiModel: String = "gpt-5.3"
    var anthropicModel: String = "claude-sonnet-4-6"
    var googleModel: String = "gemini-2.5-flash"
    var kimiModel: String = "kimi-k2.5"
    var ollamaBaseUrl: String = "http://localhost:11434"
    var ollamaModel: String = "llama3.2"
    var ollamaAvailable: Bool = false
    var appleIntelligenceAvailable: Bool = false
}
```

Provider enum:

```swift
enum LLMProviderType: String, Codable, Sendable, CaseIterable {
    case anthropic
    case openai
    case google
    case kimi
    case ollama
    case appleIntelligence
}
```

## Current routing logic

The current `TriageService` routes only between Apple Intelligence and a cloud/API provider:

```swift
nonisolated enum TriageDecision: Sendable, Equatable {
    case appleIntelligence
    case apiProvider
}
```

Notes operation complexity is explicit:

```swift
nonisolated enum NotesOperation: Sendable {
    case grammarFix
    case summarize
    case rewrite
    case continueWriting
    case ask(query: String)
    case outline
    case expand
    case analyze
    case learn
}
```

And the current routing rule is basically:

- Apple Intelligence for low-complexity / small-enough tasks
- configured provider for larger tasks

This is important because MLX integration should likely expand this routing graph rather than bypass it.

## Current LLM service pattern

`LLMService` is the provider-facing bridge used by the rest of the app:

```swift
@MainActor
protocol LLMClientProtocol: AnyObject {
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String
    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error>
    func testConnection() async -> ConnectionTestResult
    func configSnapshot() -> LLMSnapshot
    func enrichmentSnapshot() -> LLMSnapshot
}
```

`LLMService` then switches on the selected provider:

```swift
func generate(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 4096) async throws -> String {
    switch inference.apiProvider {
    case .anthropic:
        return try await anthropicGenerate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    case .openai:
        return try await openAIGenerate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    case .google:
        return try await geminiGenerate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    case .kimi:
        return try await kimiGenerate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    case .ollama:
        return try await ollamaGenerate(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
    case .appleIntelligence:
        return try await AppleIntelligenceService.shared.generate(prompt: prompt, systemPrompt: systemPrompt)
    }
}
```

## Bootstrap wiring

Current app bootstrap constructs inference first, then LLM service, then triage:

```swift
let inference = InferenceState()
self.inferenceState = inference

let llm = LLMService(inference: inference)
self.llmService = llm

let triage = TriageService(inference: inference, llmService: llm)
self.triageService = triage
```

This is the core seam where MLX local inference needs to slot in cleanly.

## What research should answer for this stack

Google should determine:

- should MLX become a new `LLMProviderType`
- or should MLX live under triage as a local tier separate from the current provider picker
- how Qwen and Gemma should be represented in state
- whether there should be a `LocalModelManager`, `MLXInferenceService`, and `MLXClient`
- how to keep Apple Intelligence as tier 1 while making MLX tier 2
- how to preserve existing note chat / chat / graph callers that already depend on `TriageService` and `LLMService`

## Likely non-goals

Research should not assume:

- cloud providers are being removed
- Ollama is being removed
- Apple Intelligence becomes user-invisible
- a giant agent framework is being revived

The research target is incremental but production-grade.
