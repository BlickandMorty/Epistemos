# Native Cleanup Scan

- Generated: Thu Apr  9 19:35:12 CDT 2026
- Root: `/Users/jojo/Downloads/Epistemos`

## Tool Availability
- ast-grep: missing
- periphery: missing
- cargo-machete: missing
- cargo-udeps: missing

## Immediate Install Commands
```bash
brew install ast-grep peripheryapp/periphery/periphery
cargo install cargo-machete
cargo install cargo-udeps
rustup toolchain install nightly
```

## Rule Files
- `/Users/jojo/Downloads/Epistemos/scripts/audit/ast-grep/legacy-runtime-ban-swift.yml`
- `/Users/jojo/Downloads/Epistemos/scripts/audit/ast-grep/observable-object-ban-swift.yml`
- `/Users/jojo/Downloads/Epistemos/scripts/audit/ast-grep/ffi-json-copy-ban-swift.yml`
- `/Users/jojo/Downloads/Epistemos/scripts/audit/ast-grep/legacy-runtime-ban-rust.yml`

### Fallback Legacy Runtime Grep
```bash
rg -n 'LocalSidecar|DeepSeek|\breasoner\b|mlx-openai-server|127\.0\.0\.1|\bSSE\b' '/Users/jojo/Downloads/Epistemos/Epistemos' '/Users/jojo/Downloads/Epistemos/graph-engine' '/Users/jojo/Downloads/Epistemos/graph-engine-bridge' --glob '!docs/**' --glob '!scripts/audit/**'
```
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:443:        let redirectURI = "http://127.0.0.1:\(await callback.currentPort())/oauth2callback"
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:1211:        guard let urlComponents = URLComponents(string: "http://127.0.0.1\(target)"),
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:34:    /// DeepSeek R1: thinking is always on via its template — no key needed.
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:47:            // DeepSeek R1 Distill: thinking is its primary mode, always active.
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:998:        // LLMModelFactory for text-only models (Qwen, DeepSeek, Mistral, etc.)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:1231:        // - DeepSeek R1: temp=0.5 (deterministic reasoning)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/ClaudeManagedRuntime.swift:78:        // TODO: Implement SSE streaming from CMA
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/ClaudeManagedRuntime.swift:80:        // Parse SSE stream → map to AgentEvent enum
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/ClaudeManagedRuntime.swift:109:                return "CMA SSE parse error: \(msg)"
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:315:            summary: "DeepSeek R1 reasoning distilled into 7B. Beats many 14B models on math and logic. Native thinking mode.",
    /Users/jojo/Downloads/Epistemos/Epistemos/Models/BrandedTypes.swift:94:        case .deepseek: "DeepSeek"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:25:    case deepseekR1Distill7B = "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:67:        case .deepseekR1Distill7B: "DeepSeek R1 7B"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:136:            "DeepSeek R1"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:271:    // Based on research: Gemma 4, Qwopus, Qwen 3.5, DeepSeek R1 specs.
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:274:    /// Sources: Gemma 4 model card, Qwen 3.5 Unsloth docs, DeepSeek R1 HF card.
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:293:        case .deepseekR1Distill7B: 128_000   // DeepSeek R1 HF card: 128K
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:330:            false // Qwen, Qwopus, DeepSeek, SmolLM, Mistral, Devstral = text only
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:366:    /// DeepSeek R1 card (0.6), Devstral/Mistral (0.4 for code).
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:380:        // DeepSeek R1: 0.6 in fast mode (HF card recommendation)
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:407:    /// Qwen 3.5 spec: thinking temp = 0.0 (greedy). DeepSeek R1: 0.1.
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:415:            0.1   // DeepSeek R1: very low but not greedy (HF card)
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:567:            .reasoning    // DeepSeek R1 reasoning distilled
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:667:        case .deepseek: "DeepSeek"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:774:            "DeepSeek"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:816:            "Use DeepSeek as the active cloud provider. The public API path is direct-key today, while local models remain available."
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:862:    case deepseekReasoner = "deepseek:deepseek-reasoner"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:915:        case .deepseekReasoner: "deepseek-reasoner"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:947:        case .deepseekChat: "DeepSeek Chat"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:948:        case .deepseekReasoner: "DeepSeek Reasoner"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:980:        case .deepseekChat: "DeepSeek Chat"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:981:        case .deepseekReasoner: "DeepSeek Reasoner"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:1210:        "deepseek-reasoner": .deepseekReasoner,
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:1394:            "DeepSeek currently uses the direct API route in Epistemos. Open the platform, create an API key, then save it here."
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:1413:            "Fastest path: open DeepSeek, create an API key, then use Paste + Save."
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:1432:            "Connect DeepSeek"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:1451:            "Use the provider portal to create an API key, then save it here. DeepSeek's public API path in Epistemos is direct-key today."
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:1470:            "Open DeepSeek API Keys"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:1489:            "Open DeepSeek API Keys"
    /Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift:1555:            "DeepSeek Chat, DeepSeek Reasoner"
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/ModelVaultsSettingsView.swift:338:            "DeepSeek"

### Fallback SwiftUI Legacy State Grep
```bash
rg -n 'ObservableObject|@Published|objectWillChange' '/Users/jojo/Downloads/Epistemos/Epistemos'
```
    /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/MOHAWK/generate_epistemos_training_data.py:747:            # Find @Observable or @Published properties
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:690:final class CodeCompanionService: ObservableObject {
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:692:    @Published private(set) var currentMessage: CompanionMessage?
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:693:    @Published private(set) var isAnalyzing = false
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:694:    @Published var isEnabled = true
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:695:    @Published var mode: CompanionMode = .balanced
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:2795:final class CodeContextBridge: ObservableObject {
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:2797:    @Published private(set) var relatedNotes: [CodeSemanticMatch] = []
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:2798:    @Published private(set) var isSearching = false
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:2799:    @Published private(set) var lastQuery: String = ""
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:2800:    @Published private(set) var aiContextSummary: String = ""
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:3566:final class CodeInsightGenerator: ObservableObject {
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:3568:    @Published private(set) var insights: [CodeInsight] = []
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:3569:    @Published private(set) var isGenerating = false
    /Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/CodeEditorView.swift:3570:    @Published private(set) var currentAnalysis: String = ""

### Fallback FFI JSON Copy Grep
```bash
rg -n 'JSONEncoder\(\)\.encode|JSONDecoder\(\)\.decode|JSONSerialization' '/Users/jojo/Downloads/Epistemos/Epistemos/Graph' '/Users/jojo/Downloads/Epistemos/Epistemos/Engine' '/Users/jojo/Downloads/Epistemos/graph-engine'
```
    /Users/jojo/Downloads/Epistemos/Epistemos/Graph/SDFLabelAtlas.swift:228:        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    /Users/jojo/Downloads/Epistemos/Epistemos/Graph/EntityExtractor.swift:398:        return try? JSONDecoder().decode(type, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:58:        return try? JSONDecoder().decode(Self.self, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:74:        let payload = try JSONSerialization.jsonObject(with: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:129:              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:170:              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:289:            let data = try JSONEncoder().encode(credential)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:336:              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:382:        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:520:              let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:572:              let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:610:            request.httpBody = try JSONSerialization.data(withJSONObject: [
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:620:                      let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:655:        request.httpBody = try JSONSerialization.data(withJSONObject: [
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:662:              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:698:            request.httpBody = try JSONSerialization.data(withJSONObject: [
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:708:               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:774:              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:818:              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/CloudProviderAuthService.swift:862:        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    /Users/jojo/Downloads/Epistemos/Epistemos/Graph/GraphState.swift:948:        if let stepsData = try? JSONEncoder().encode(timelineSteps) {
    /Users/jojo/Downloads/Epistemos/Epistemos/Graph/GraphState.swift:1036:           let steps = try? JSONDecoder().decode([PhysicsScheduleStep].self, from: stepsData) {
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/ArtifactExtractor.swift:100:           let obj = try? JSONSerialization.jsonObject(with: data),
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/ArtifactExtractor.swift:101:           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:88:            let value = try JSONDecoder().decode(T.self, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:715:                    let value = try JSONDecoder().decode(T.self, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:739:                let value = try JSONDecoder().decode(T.self, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1017:        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1088:        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1112:            let value = try JSONDecoder().decode(T.self, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1159:            request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1239:        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1254:            inputData = try JSONSerialization.data(withJSONObject: inputDict)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1256:            inputData = try JSONSerialization.data(withJSONObject: inputArray)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1262:            let value = try JSONDecoder().decode(T.self, from: inputData)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1306:        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1387:            request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1412:        request.httpBody = try JSONSerialization.data(
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1445:            builtRequest.httpBody = try JSONSerialization.data(
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1507:        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1567:            request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:1965:                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:2032:        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/StructuredOutput.swift:23:    /// Uses [String: Any] to match the existing JSONSerialization pattern
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MeaningAnchorService.swift:149:        guard let raw = try? JSONDecoder().decode(RawAnchor.self, from: data) else { return nil }
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:803:        return try? JSONDecoder().decode(PreparedRetrievalIndexManifest.self, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:1019:        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/Log.swift:643:        return try JSONDecoder().decode(RuntimeDiagnosticIssueIndex.self, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/Log.swift:652:        return try JSONDecoder().decode(RuntimeDiagnosticSessionSnapshot.self, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/Log.swift:729:            data = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])

### Periphery Missing
```bash
printf 'periphery is not installed\n'
```
    periphery is not installed

### cargo-machete Missing
```bash
printf 'cargo-machete is not installed\n'
```
    cargo-machete is not installed

### cargo-udeps Missing
```bash
printf 'cargo-udeps is not installed\n'
```
    cargo-udeps is not installed

