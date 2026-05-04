# Epistemos Complete Model Support & Feature Expansion Plan
## Claude Code Execution Blueprint — Q4/Q8 Models, Dual Backend, Fast+Thinking Mode, Agent Mode & SOAR Research

***

## Executive Summary

This document is the **single executable source of truth** for Claude Code to implement full model support across Epistemos — covering every model from the X/Twitter bookmark research, validated against the master gap closure plan and the complete feature spec. The primary research is the X bookmark compilation; all other documents serve as validation and architecture context.[^1][^2][^3]

**What this plan delivers:**
- Dual inference backend: MLX (existing) + GGUF/llama.cpp (new)
- Q4 and Q8 quantization variants for every new model with RAM display
- Perfectly organized model selector with RAM-tiered sections
- Fast + Thinking dual mode toggle (Gemini Flash Thinking equivalent) for all supported models
- Agent Mode as an explicit UI surface (Gemini Agent Mode equivalent)
- TurboQuant KV cache compression (8x memory reduction)
- Prompt Repetition technique (free quality boost)
- Full SOAR Research Mode rebuild on the Omega stack
- All 11 new models from community consensus bookmarks

**Validation status before starting:** The gap closure audit confirms `LocalTextModelID`, `ModelDownloadManager`, `MLXInferenceService`, `OrchestratorState`, `ResearchOrchestrator`, and `MCPBridge` all exist and are **TRUSTWORTHY**. GGUF inference does **NOT** exist — it must be built. The model picker currently shows no RAM information and has no Q4/Q8 sections.[^1]

***

## Part 1 — Current State Audit (What Claude Must Verify First)

Before writing a single line of code, Claude Code must **grep and verify** the following. If any item shows differently than stated, halt and report before proceeding.

### 1.1 What Currently Exists (Verified Trustworthy)[^1]

```
VERIFY: grep -r "LocalTextModelID" --include="*.swift" | head -20
EXPECTED: nonisolated enum LocalTextModelID with cases qwen3508B4Bit through qwen3535BA3B4Bit (6 cases)
STATUS: EXISTS — MLX only, no GGUF, no Q8, no RAM labels
```

```
VERIFY: grep -r "ModelDownloadManager\|MLXInferenceService" --include="*.swift" | head -10
STATUS: EXISTS — MLX pipeline only, no GGUF backend
```

```
VERIFY: grep -r "fastThinking\|thinking.*toggle\|thinkMode" --include="*.swift" | head -10
STATUS: EXISTS — fast/thinking toggle present, but model-agnostic
```

```
VERIFY: grep -r "OrchestratorState\|ResearchOrchestrator\|MCPBridge" --include="*.swift" | head -10
STATUS: ALL TRUSTWORTHY — per 2,679-test passing suite
```

```
VERIFY: grep -r "GGUF\|llama\.cpp\|LlamaInference" --include="*.swift" | head -5
EXPECTED: ZERO results
STATUS: ABSENT — llama.cpp not integrated
```

### 1.2 What Blocks the New Model Additions[^2][^1]

| Blocker | File | Fix Required |
|---------|------|--------------|
| No GGUF/llama.cpp backend | `MLXInferenceService.swift` | Add `ModelBackend` enum + GGUF path |
| `LocalTextModelID` is MLX-only | `LocalTextModelID.swift` (or `LocalModelInfrastructure.swift`) | Add all 11 new models with backend tag |
| Model picker has no Q4/Q8 sections | Model selector SwiftUI view | Add quantization-grouped sections + RAM labels |
| No RAM display in model picker | `LocalTextModelID.minimumRecommendedMemoryGB` | Add `var ramRequirementQ4GB: Int` and `var ramRequirementQ8GB: Int?` |
| Thinking toggle not model-aware | Chat/inference path | Route `thinkMode` to `/think` token injection for supported models |
| SOAR tools not in OmegaToolRegistry | `OmegaToolRegistry.swift` | Register 4 new research tool schemas |

***

## Part 2 — ModelBackend Dual Infrastructure

This is the **foundation** that everything else builds on. Do this first.

### 2.1 New File: `ModelBackend.swift`

```swift
// File: Epistemos/Services/Inference/ModelBackend.swift

/// Identifies which inference runtime handles a given model.
/// MLX = Apple Silicon GPU via mlx-swift (existing pipeline)
/// GGUF = llama.cpp via bundled binary or LlamaKit SPM (new)
enum ModelBackend: String, Codable, Sendable {
    case mlx   // mlx-community/* models — existing MLXInferenceService
    case gguf  // *.gguf files — new GGUFInferenceService

    /// Whether this backend natively supports streaming partial tokens
    var supportsStreaming: Bool {
        switch self {
        case .mlx:  return true
        case .gguf: return true  // via llama.cpp token callback
        }
    }

    /// Whether this backend supports native grammar-constrained generation
    var supportsGrammar: Bool {
        switch self {
        case .mlx:  return false  // soft EOS only today
        case .gguf: return true   // llama.cpp gbnf grammar support
        }
    }
}
```

### 2.2 New File: `GGUFModelConfig.swift`

```swift
// File: Epistemos/Services/Inference/GGUFModelConfig.swift

/// Configuration for a single GGUF quantization variant.
struct GGUFQuantVariant: Codable, Identifiable, Sendable {
    let id: String           // e.g. "Q4_K_M"
    let label: String        // e.g. "Q4 (Recommended)"
    let huggingFaceFile: String  // e.g. "model-Q4_K_M.gguf"
    let ramRequirementGB: Int    // minimum unified memory
    let isDefault: Bool

    static func q4(file: String, ram: Int) -> GGUFQuantVariant {
        GGUFQuantVariant(id: "Q4_K_M", label: "Q4 · \(ram)GB RAM",
                         huggingFaceFile: file, ramRequirementGB: ram, isDefault: true)
    }
    static func q8(file: String, ram: Int) -> GGUFQuantVariant {
        GGUFQuantVariant(id: "Q8_0", label: "Q8 · \(ram)GB RAM",
                         huggingFaceFile: file, ramRequirementGB: ram, isDefault: false)
    }
}
```

### 2.3 New File: `GGUFInferenceService.swift`

This wraps the llama.cpp Swift binding. Use **LlamaKit** (Swift Package) or bundle a pre-compiled `llama` static library via the existing Rust/UniFFI approach.

```swift
// File: Epistemos/Services/Inference/GGUFInferenceService.swift
// Requires: LlamaKit SPM package OR omega-llama Rust crate with UniFFI

import Foundation

/// Thin Swift wrapper around llama.cpp inference.
/// Designed to mirror MLXInferenceService's public API so callers are backend-agnostic.
actor GGUFInferenceService {

    private var loadedModelPath: String?
    private var llamaContext: OpaquePointer?  // llama_context* from C API

    // MARK: - Model Loading

    /// Load a GGUF model from disk. Replaces any currently loaded model.
    func loadModel(at path: String, contextLength: Int = 8192) async throws {
        // llamaContext = try LlamaKit.load(path: path, contextLength: contextLength)
        loadedModelPath = path
    }

    func unloadModel() async {
        // LlamaKit.free(llamaContext)
        llamaContext = nil
        loadedModelPath = nil
    }

    // MARK: - Inference

    /// Generate with streaming token callback. Mirrors MLXInferenceService.generateStream.
    func generateStream(
        prompt: String,
        maxTokens: Int = 2048,
        temperature: Float = 0.7,
        thinkMode: Bool = false,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        // Inject think token for models that support it
        let fullPrompt = thinkMode ? "<think>\n\(prompt)" : prompt
        // LlamaKit.generate(context: llamaContext, prompt: fullPrompt, ...)
        return ""
    }

    /// Check if a model is currently loaded.
    var isLoaded: Bool { loadedModelPath != nil }
}
```

**SPM Integration** — Add to `Package.swift` or via XcodeGen `project.yml`:
```yaml
# In project.yml packages section:
LlamaKit:
  url: https://github.com/your-org/LlamaKit-Swift  # or use llamafile SPM wrapper
  version: "1.0.0"
```

**Alternative (Rust route):** Add an `omega-llama` Rust crate alongside existing `omega-mcp`, using `llama-cpp-rs` crate + UniFFI bindings. This matches the existing build pattern.

***

## Part 3 — Complete `LocalTextModelID` Enum Replacement

**Replace the entire existing `LocalTextModelID` enum** with this expanded version. This is the canonical, authoritative definition of every model Epistemos supports.[^2]

```swift
// File: Epistemos/Models/LocalTextModelID.swift
// REPLACE entire existing file content

import Foundation

nonisolated enum LocalTextModelID: String, Codable, Sendable, CaseIterable {

    // MARK: — Qwen 3.5 Core Family (MLX, existing)
    case qwen3_0_8B_4bit  = "mlx-community/Qwen3.5-0.8B-4bit"
    case qwen3_2B_4bit    = "mlx-community/Qwen3.5-2B-4bit"
    case qwen3_4B_4bit    = "mlx-community/Qwen3.5-4B-4bit"
    case qwen3_9B_4bit    = "mlx-community/Qwen3.5-9B-4bit"
    case qwen3_27B_4bit   = "mlx-community/Qwen3.5-27B-4bit"
    case qwen3_35B_A3B_4bit = "mlx-community/Qwen3.5-35B-A3B-4bit"

    // MARK: — Qwen 3.5 Distilled / Pruned (GGUF, NEW)
    case qwen3_27B_opusDistilled  = "Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF"
    case qwen3_28B_A3B_REAP       = "0xSero/Qwen-3.5-28B-A3B-REAP"
    case qwen3_40B_opusUncensored = "mradermacher/Qwen3.5-40B-Claude-4.6-Opus-Deckard-Heretic-Uncensored-Thinking-GGUF"

    // MARK: — Mistral Family (GGUF, NEW)
    case devstralSmall2_24B    = "mistralai/devstral-small-2-2512"
    case mistralSmall3_1_24B   = "mistralai/Mistral-Small-3.1-24B-Instruct-2503"

    // MARK: — Google (GGUF, NEW)
    case gemma3_27B_QAT  = "google/gemma-3-27b-it-qat-q4_0-gguf"

    // MARK: — Microsoft (GGUF, NEW)
    case phi4_14B  = "microsoft/phi-4"

    // MARK: — HuggingFace Small (MLX/GGUF, NEW)
    case smolLM3_3B  = "HuggingFaceTB/SmolLM3-3B"

    // MARK: — Meta MoE (MLX, NEW)
    case llama4Scout_109B_MoE  = "mlx-community/meta-llama-Llama-4-Scout-17B-16E-4bit"

    // MARK: — MiniMax (GGUF, NEW — when weights public)
    case miniMax_M2_5  = "MiniMaxAI/MiniMax-M2.5"

    // MARK: — Chroma Context-1 (GGUF, NEW — agentic search)
    case chroma_context1_20B  = "chroma-ai/Context-1-20B"
}

// MARK: — Display & Metadata

extension LocalTextModelID {

    var displayName: String {
        switch self {
        case .qwen3_0_8B_4bit:          return "Qwen 3.5 · 0.8B"
        case .qwen3_2B_4bit:            return "Qwen 3.5 · 2B"
        case .qwen3_4B_4bit:            return "Qwen 3.5 · 4B"
        case .qwen3_9B_4bit:            return "Qwen 3.5 · 9B"
        case .qwen3_27B_4bit:           return "Qwen 3.5 · 27B"
        case .qwen3_35B_A3B_4bit:       return "Qwen 3.5 · 35B MoE"
        case .qwen3_27B_opusDistilled:  return "Qwen 3.5 27B · Opus-Distilled"
        case .qwen3_28B_A3B_REAP:       return "Qwen 3.5 28B · MoE REAP"
        case .qwen3_40B_opusUncensored: return "Qwen 3.5 40B · Uncensored Thinking"
        case .devstralSmall2_24B:       return "Devstral Small 2 · 24B"
        case .mistralSmall3_1_24B:      return "Mistral Small 3.1 · 24B"
        case .gemma3_27B_QAT:           return "Gemma 3 · 27B QAT"
        case .phi4_14B:                 return "Phi-4 · 14B"
        case .smolLM3_3B:              return "SmolLM3 · 3B"
        case .llama4Scout_109B_MoE:     return "Llama 4 Scout · 17B active MoE"
        case .miniMax_M2_5:            return "MiniMax M2.5"
        case .chroma_context1_20B:     return "Chroma Context-1 · 20B"
        }
    }

    var familyName: String {
        switch self {
        case .qwen3_0_8B_4bit, .qwen3_2B_4bit, .qwen3_4B_4bit,
             .qwen3_9B_4bit, .qwen3_27B_4bit, .qwen3_35B_A3B_4bit,
             .qwen3_27B_opusDistilled, .qwen3_28B_A3B_REAP, .qwen3_40B_opusUncensored:
            return "Qwen"
        case .devstralSmall2_24B, .mistralSmall3_1_24B:
            return "Mistral"
        case .gemma3_27B_QAT:   return "Google"
        case .phi4_14B:         return "Microsoft"
        case .smolLM3_3B:      return "HuggingFace"
        case .llama4Scout_109B_MoE: return "Meta"
        case .miniMax_M2_5:    return "MiniMax"
        case .chroma_context1_20B: return "Chroma"
        }
    }

    /// Primary inference backend for this model
    var backend: ModelBackend {
        switch self {
        // MLX (existing pipeline)
        case .qwen3_0_8B_4bit, .qwen3_2B_4bit, .qwen3_4B_4bit,
             .qwen3_9B_4bit, .qwen3_27B_4bit, .qwen3_35B_A3B_4bit,
             .llama4Scout_109B_MoE, .smolLM3_3B:
            return .mlx
        // GGUF (new pipeline)
        default:
            return .gguf
        }
    }

    // MARK: — Q4 RAM Requirements (minimum GB unified memory)
    var ramRequirementQ4_GB: Int {
        switch self {
        case .qwen3_0_8B_4bit, .smolLM3_3B: return 8
        case .qwen3_2B_4bit:                return 10
        case .qwen3_4B_4bit, .phi4_14B:     return 12
        case .qwen3_9B_4bit:                return 16
        case .devstralSmall2_24B, .mistralSmall3_1_24B, .gemma3_27B_QAT: return 16
        case .qwen3_28B_A3B_REAP:           return 20  // MoE, only 3B active
        case .qwen3_27B_4bit, .qwen3_27B_opusDistilled: return 20
        case .miniMax_M2_5, .chroma_context1_20B:       return 16
        case .qwen3_40B_opusUncensored:     return 24
        case .qwen3_35B_A3B_4bit:           return 32
        case .llama4Scout_109B_MoE:         return 64
        }
    }

    // MARK: — Q8 RAM Requirements (nil if Q8 not recommended / unavailable)
    var ramRequirementQ8_GB: Int? {
        switch self {
        case .smolLM3_3B:               return 4
        case .qwen3_0_8B_4bit:          return 4
        case .phi4_14B:                 return 18
        case .qwen3_9B_4bit:            return 14
        case .devstralSmall2_24B, .mistralSmall3_1_24B, .gemma3_27B_QAT: return 32
        case .qwen3_27B_opusDistilled:  return 48
        case .qwen3_28B_A3B_REAP:       return 36
        case .qwen3_40B_opusUncensored: return 64
        // MLX core family: Q8 not separately available (mlx-community provides 4-bit)
        case .qwen3_2B_4bit, .qwen3_4B_4bit,
             .qwen3_27B_4bit, .qwen3_35B_A3B_4bit,
             .llama4Scout_109B_MoE:
            return nil
        case .miniMax_M2_5, .chroma_context1_20B: return nil
        }
    }

    // MARK: — Feature Capabilities

    /// Whether this model supports fast/thinking dual mode via /think /nothink tokens
    var supportsDualThinkMode: Bool {
        switch self {
        case .qwen3_0_8B_4bit, .qwen3_2B_4bit, .qwen3_4B_4bit,
             .qwen3_9B_4bit, .qwen3_27B_4bit, .qwen3_35B_A3B_4bit,
             .qwen3_27B_opusDistilled, .qwen3_28B_A3B_REAP,
             .qwen3_40B_opusUncensored, .smolLM3_3B:
            return true
        default:
            return false
        }
    }

    /// Whether this model is a Mixture of Experts architecture
    var isMoE: Bool {
        switch self {
        case .qwen3_35B_A3B_4bit, .qwen3_28B_A3B_REAP, .llama4Scout_109B_MoE:
            return true
        default: return false
        }
    }

    /// Active parameter count for MoE models (same as total for dense)
    var activeParametersB: Double {
        switch self {
        case .qwen3_35B_A3B_4bit:    return 3.0
        case .qwen3_28B_A3B_REAP:    return 3.0
        case .llama4Scout_109B_MoE:  return 17.0
        default:
            return Double(rawValue.components(separatedBy: "/").last?
                .components(separatedBy: "-")
                .first(where: { $0.hasSuffix("B") })?
                .dropLast().description ?? "7") ?? 7.0
        }
    }

    /// Whether this model has explicit uncensored/unrestricted thinking
    var isUnrestrictedThinking: Bool {
        self == .qwen3_40B_opusUncensored
    }

    /// Whether this model is specialized for coding/agentic tasks
    var isCodeSpecialist: Bool {
        switch self {
        case .devstralSmall2_24B, .miniMax_M2_5, .chroma_context1_20B: return true
        default: return false
        }
    }

    /// Context window in tokens (thousands)
    var contextWindowK: Int {
        switch self {
        case .llama4Scout_109B_MoE:     return 10_000  // 10M tokens
        case .devstralSmall2_24B:       return 256
        case .mistralSmall3_1_24B, .smolLM3_3B: return 128
        default:                        return 32
        }
    }

    // MARK: — Download URLs

    /// GGUF file name for Q4 variant (nil for MLX models)
    var ggufFileQ4: String? {
        switch self {
        case .qwen3_27B_opusDistilled:  return "Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-Q4_K_M.gguf"
        case .qwen3_28B_A3B_REAP:       return "Qwen-3.5-28B-A3B-REAP-Q4_K_M.gguf"
        case .qwen3_40B_opusUncensored: return "Qwen3.5-40B-Claude-4.6-Opus-Deckard-Heretic-Uncensored-Thinking-Q4_K_M.gguf"
        case .devstralSmall2_24B:       return "devstral-small-2-2512-Q4_K_M.gguf"
        case .mistralSmall3_1_24B:      return "Mistral-Small-3.1-24B-Instruct-2503-Q4_K_M.gguf"
        case .gemma3_27B_QAT:           return "gemma-3-27b-it-qat-q4_0.gguf"
        case .phi4_14B:                 return "phi-4-Q4_K_M.gguf"
        case .smolLM3_3B:              return "SmolLM3-3B-Q4_K_M.gguf"
        default:                        return nil
        }
    }

    /// GGUF file name for Q8 variant (nil if unavailable)
    var ggufFileQ8: String? {
        switch self {
        case .qwen3_27B_opusDistilled:  return "Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-Q8_0.gguf"
        case .qwen3_28B_A3B_REAP:       return "Qwen-3.5-28B-A3B-REAP-Q8_0.gguf"
        case .qwen3_40B_opusUncensored: return "Qwen3.5-40B-Claude-4.6-Opus-Deckard-Heretic-Uncensored-Thinking-Q8_0.gguf"
        default: return nil
        }
    }
}
```

***

## Part 4 — Model Selector UI with Q4/Q8 RAM Sections

Replace or extend the existing model picker view. The design mirrors Gemini's model selector: grouped by capability tier, each entry shows quantization options with RAM requirements.

### 4.1 New File: `LocalModelSelectorView.swift`

```swift
// File: Epistemos/Views/Settings/LocalModelSelectorView.swift

import SwiftUI

struct LocalModelSelectorView: View {

    @Binding var selectedModel: LocalTextModelID
    @Binding var selectedQuantization: ModelQuantization  // Q4 or Q8
    @State private var systemRAM: Int = ProcessInfo.processInfo.physicalMemory.ramGB

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ramBanner
                ForEach(ModelTier.allCases, id: \.self) { tier in
                    let models = LocalTextModelID.allCases.filter { $0.tier == tier }
                    if !models.isEmpty {
                        ModelSectionView(
                            tier: tier,
                            models: models,
                            selectedModel: $selectedModel,
                            selectedQuantization: $selectedQuantization,
                            systemRAM: systemRAM
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Choose Model")
    }

    private var ramBanner: some View {
        HStack {
            Image(systemName: "memorychip")
            Text("Your Mac has \(systemRAM)GB unified memory")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: — Section per Tier

struct ModelSectionView: View {
    let tier: ModelTier
    let models: [LocalTextModelID]
    @Binding var selectedModel: LocalTextModelID
    @Binding var selectedQuantization: ModelQuantization
    let systemRAM: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: tier.iconName)
                    .foregroundStyle(tier.color)
                Text(tier.displayName)
                    .font(.headline)
                Text(tier.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()

            ForEach(models, id: \.self) { model in
                ModelRowView(
                    model: model,
                    isSelected: selectedModel == model,
                    selectedQuantization: $selectedQuantization,
                    systemRAM: systemRAM,
                    onSelect: { selectedModel = model }
                )
            }
        }
    }
}

// MARK: — Individual Model Row

struct ModelRowView: View {
    let model: LocalTextModelID
    let isSelected: Bool
    @Binding var selectedQuantization: ModelQuantization
    let systemRAM: Int
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .fontWeight(isSelected ? .semibold : .regular)
                        if model.isMoE {
                            badge("MoE", color: .purple)
                        }
                        if model.isCodeSpecialist {
                            badge("Code", color: .blue)
                        }
                        if model.supportsDualThinkMode {
                            badge("Think", color: .orange)
                        }
                        if model.isUnrestrictedThinking {
                            badge("Uncensored", color: .red)
                        }
                    }
                    Text(model.familyName + " · \(model.contextWindowK)K ctx")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            // Q4 / Q8 quantization picker (shown when model is selected or on hover)
            if isSelected {
                quantizationPicker
            }
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
        )
    }

    // MARK: — Quantization Picker (Q4 / Q8)

    @ViewBuilder
    private var quantizationPicker: some View {
        HStack(spacing: 8) {
            quantButton(.q4)
            if model.ramRequirementQ8_GB != nil {
                quantButton(.q8)
            }
        }
        .padding(.top, 4)
    }

    private func quantButton(_ quant: ModelQuantization) -> some View {
        let ram = quant == .q4 ? model.ramRequirementQ4_GB : (model.ramRequirementQ8_GB ?? 0)
        let fits = systemRAM >= ram
        let isActive = selectedQuantization == quant

        return Button(action: { selectedQuantization = quant }) {
            VStack(spacing: 2) {
                Text(quant.displayLabel)
                    .font(.caption.bold())
                HStack(spacing: 3) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 9))
                    Text("\(ram)GB")
                        .font(.system(size: 10))
                }
                .foregroundStyle(fits ? .primary : .red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor : Color.gray.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(isActive ? .white : (fits ? .primary : .red))
        }
        .buttonStyle(.plain)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: — Supporting Types

enum ModelQuantization: String, CaseIterable, Codable {
    case q4 = "Q4"
    case q8 = "Q8"

    var displayLabel: String {
        switch self {
        case .q4: return "Q4 · Fast"
        case .q8: return "Q8 · Quality"
        }
    }
}

enum ModelTier: CaseIterable {
    case ultraLight    // ≤8GB RAM
    case efficient     // 10-16GB
    case standard      // 16-24GB
    case professional  // 24-48GB
    case maximum       // 48GB+

    var displayName: String {
        switch self {
        case .ultraLight:   return "Ultra Light"
        case .efficient:    return "Efficient"
        case .standard:     return "Standard"
        case .professional: return "Professional"
        case .maximum:      return "Maximum"
        }
    }
    var subtitle: String {
        switch self {
        case .ultraLight:   return "≤8GB · Runs on any Mac"
        case .efficient:    return "10–16GB"
        case .standard:     return "16–24GB"
        case .professional: return "24–48GB"
        case .maximum:      return "48GB+ · Mac Studio / Pro"
        }
    }
    var iconName: String {
        switch self {
        case .ultraLight: return "hare"
        case .efficient:  return "bolt"
        case .standard:   return "cpu"
        case .professional: return "brain"
        case .maximum:    return "server.rack"
        }
    }
    var color: Color {
        switch self {
        case .ultraLight: return .green
        case .efficient:  return .blue
        case .standard:   return .orange
        case .professional: return .purple
        case .maximum:    return .red
        }
    }
}

extension LocalTextModelID {
    var tier: ModelTier {
        let ram = ramRequirementQ4_GB
        switch ram {
        case ...8:    return .ultraLight
        case 9...16:  return .efficient
        case 17...24: return .standard
        case 25...48: return .professional
        default:      return .maximum
        }
    }
}

extension Int {
    var ramGB: Int {
        Int(self / (1024 * 1024 * 1024))
    }
}
```

***

## Part 5 — Fast + Thinking Dual Mode (Gemini Flash Thinking Equivalent)

This implements the equivalent of Google Gemini's "Flash Thinking" vs "Flash" distinction. Every model that supports `supportsDualThinkMode` gets a toggle that controls whether `<think>...</think>` reasoning is activated.[^2]

### 5.1 Extend Existing Thinking Toggle in `InferenceState.swift` or `LLMService.swift`

```swift
// MODIFY: wherever fastThinking / thinkMode is currently handled

extension LLMService {  // or MLXInferenceService

    /// Build the correct prompt prefix for the model's thinking mode.
    /// Models differ in how they activate/deactivate chain-of-thought reasoning.
    func thinkingPromptPrefix(for model: LocalTextModelID, thinkMode: Bool) -> String {
        guard model.supportsDualThinkMode else { return "" }

        if thinkMode {
            // Activate chain-of-thought reasoning (Qwen3.5, SmolLM3 style)
            return "/think\n"
        } else {
            // Suppress reasoning for fast responses
            return "/no_think\n"
        }
    }

    /// Wrap user prompt with appropriate thinking directive.
    /// This is the ONLY change needed to existing generateStream calls.
    func buildPromptWithThinkMode(
        userMessage: String,
        systemPrompt: String?,
        model: LocalTextModelID,
        thinkMode: Bool
    ) -> String {
        let prefix = thinkingPromptPrefix(for: model, thinkMode: thinkMode)
        let system = systemPrompt.map { "\($0)\n\n" } ?? ""
        return "\(system)\(prefix)\(userMessage)"
    }
}
```

### 5.2 UI Toggle for Fast / Thinking Mode

Add to the chat input bar (or wherever the existing `fastThinking` toggle lives):

```swift
// MODIFY: ChatInputBar.swift or wherever fastThinking toggle renders

// Existing toggle (just make it model-aware):
if viewModel.selectedModel.supportsDualThinkMode {
    Toggle(isOn: $viewModel.thinkMode) {
        Label(
            viewModel.thinkMode ? "Thinking" : "Fast",
            systemImage: viewModel.thinkMode ? "brain.filled.head.profile" : "bolt.fill"
        )
    }
    .toggleStyle(.button)
    .tint(viewModel.thinkMode ? .orange : .blue)
    .disabled(false)
} else {
    // Show greyed toggle for models without think support
    Label("Fast Only", systemImage: "bolt.fill")
        .foregroundStyle(.secondary)
        .font(.caption)
}
```

***

## Part 6 — Agent Mode (Gemini Agent Mode Equivalent)

Epistemos already has the Omega agent system. This exposes it as an explicit **Agent Mode** UI entry point — the equivalent of Gemini's Agent Mode or Claude's Projects.[^3][^2]

### 6.1 `AgentModeSelector.swift` — Mode Entry Point

```swift
// File: Epistemos/Views/Chat/AgentModeSelector.swift

import SwiftUI

/// Three operating modes, mirroring Gemini's model tiers.
/// Fast = quick chat, no agent scaffolding
/// Thinking = chain-of-thought reasoning, /think tokens
/// Agent = full Omega multi-step task execution
enum EpistemosOperatingMode: String, CaseIterable, Codable {
    case fast     = "Fast"
    case thinking = "Thinking"
    case agent    = "Agent"

    var icon: String {
        switch self {
        case .fast:     return "bolt.fill"
        case .thinking: return "brain.filled.head.profile"
        case .agent:    return "cpu.fill"
        }
    }

    var description: String {
        switch self {
        case .fast:     return "Quick answers · No reasoning overhead"
        case .thinking: return "Chain-of-thought · Better accuracy"
        case .agent:    return "Multi-step tasks · Web search · Notes · Code"
        }
    }

    var color: Color {
        switch self {
        case .fast:     return .blue
        case .thinking: return .orange
        case .agent:    return .purple
        }
    }
}

struct AgentModeSelectorView: View {
    @Binding var mode: EpistemosOperatingMode
    let selectedModel: LocalTextModelID

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EpistemosOperatingMode.allCases, id: \.self) { m in
                modeButton(m)
            }
        }
        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func modeButton(_ m: EpistemosOperatingMode) -> some View {
        let isActive = mode == m
        let isAvailable = isAvailable(m)

        return Button(action: { if isAvailable { mode = m } }) {
            HStack(spacing: 4) {
                Image(systemName: m.icon)
                    .font(.system(size: 11))
                Text(m.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? m.color : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(isActive ? .white : (isAvailable ? .primary : .tertiary))
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }

    /// Agent mode requires a model with sufficient context (≥9B recommended)
    private func isAvailable(_ m: EpistemosOperatingMode) -> Bool {
        switch m {
        case .fast:     return true
        case .thinking: return selectedModel.supportsDualThinkMode
        case .agent:    return true  // Omega works with all models via TriageService routing
        }
    }
}
```

### 6.2 Wire Operating Mode to Existing Systems

```swift
// MODIFY: wherever submitTask / chat message is sent (ChatState.swift or similar)

func sendMessage(_ text: String, mode: EpistemosOperatingMode) async {
    switch mode {
    case .fast:
        // Existing chat path — no Omega, direct LLM call
        await chatViewModel.sendDirectMessage(text, thinkMode: false)

    case .thinking:
        // Existing fast-thinking path — direct LLM with /think prefix
        await chatViewModel.sendDirectMessage(text, thinkMode: true)

    case .agent:
        // Route through OrchestratorState — existing Omega pipeline
        await orchestratorState.submitTask(text)
    }
}
```

***

## Part 7 — TurboQuant KV Cache Compression

The Google Research TurboQuant paper shows 6x KV cache memory reduction and up to 8x speedup with zero accuracy loss. Atomic Chat already demonstrated this running Qwen3.5-9B with 50K context on a MacBook Air M4 16GB.[^2]

### 7.1 Implementation in `MLXInferenceService.swift`

```swift
// MODIFY: MLXInferenceService.swift (add KV cache quantization option)

/// KV cache quantization configuration.
/// Mirrors the approach from Google's TurboQuant paper and Atomic Chat's implementation.
struct KVCacheConfig {
    /// Number of bits for key/value cache quantization
    /// 4 = ~6x memory reduction, minimal quality impact
    /// 8 = ~3x reduction, negligible quality impact  
    /// 16 = no compression (current default)
    var quantizationBits: Int = 4

    /// Maximum context window to maintain in compressed cache
    var maxCachedTokens: Int = 50_000

    static let turboQuant = KVCacheConfig(quantizationBits: 4, maxCachedTokens: 50_000)
    static let standard   = KVCacheConfig(quantizationBits: 16, maxCachedTokens: 8_192)
    static let balanced   = KVCacheConfig(quantizationBits: 8, maxCachedTokens: 32_000)
}

// In MLXInferenceService.generateStream:
// Add kvCacheConfig parameter and pass to MLX model generation:
// mlxModel.generate(prompt: prompt, kvCacheQuantBits: kvCacheConfig.quantizationBits, ...)
```

**Note:** Full TurboQuant integration requires MLX framework support for quantized KV caches. Check `mlx-lm` Python API for `kv_bits` parameter (available in mlx-lm ≥ 0.21). Expose via Swift/Python bridge. Until available in stable MLX, implement as a **UserDefaults flag** `turboQuant.enabled` that gets passed through to the Python inference script.

### 7.2 Prompt Repetition (Free Quality Boost)[^2]

```swift
// MODIFY: LLMService.swift or PipelineService.swift
// Add to system prompt construction for local model calls:

extension SystemPromptBuilder {
    /// Implements the Leviathan et al. (Google Research) Prompt Repetition technique.
    /// Duplicating the user prompt in the system message improves non-reasoning model output
    /// quality at zero token cost and zero latency overhead.
    static func withPromptRepetition(
        baseSystemPrompt: String,
        userMessage: String,
        modelSupportsThinking: Bool
    ) -> String {
        // Only apply for non-thinking mode (reasoning models already self-repeat via think tags)
        guard !modelSupportsThinking else { return baseSystemPrompt }
        return """
        \(baseSystemPrompt)

        The user's request is: \(userMessage)
        """
    }
}
```

***

## Part 8 — SOAR Research Mode (Verification + Gap Fill)

The gap closure audit confirms `ResearchOrchestrator.swift` is **TRUSTWORTHY**. The SOAR redesign blueprint and migration blueprint define exactly what needs to be added. The master feature spec defines the tool schemas.[^4][^5][^3][^1]

### 8.1 Verification Checklist — Run These Greps First

```bash
# Verify what already exists:
grep -r "ResearchOrchestrator\|ResearchComplexityGate\|ResearchEvidenceScorer" --include="*.swift"
grep -r "deepsearchweb\|captureandgradesource\|checkcontradiction\|synthesizeresearchnode" --include="*.swift"
grep -r "OmegaToolRegistry\|OmegaToolDefinition" --include="*.swift"
grep -r "ResearchPauseHandler\|ResearchRequest" --include="*.swift"
```

### 8.2 New Tools Required in `OmegaToolRegistry.swift`[^5][^4]

Add these four tool definitions to the static `all` array:

```swift
// ADD to OmegaToolRegistry.swift — research tool schemas

// Tool 1: Deep boolean web search with recency filter
OmegaToolDefinition(
    name: "deepsearchweb",
    agent: "safari",
    description: "Execute an advanced Boolean web search. Returns top results with URLs and summaries.",
    argumentsExample: ["query": "transformer attention mechanisms site:arxiv.org", "timerange": "year", "requireAcademic": false],
    schemaJson: """
    {"type":"object","properties":{"query":{"type":"string"},"timerange":{"type":"string","enum":["day","week","month","year","all"]},"requireAcademic":{"type":"boolean"}},"required":["query"]}
    """,
    destructive: false,
    requiresConfirmation: false
),

// Tool 2: Capture page + compute SOAR evidence quality score
OmegaToolDefinition(
    name: "captureandgradesource",
    agent: "safari",
    description: "Capture full page text and compute SOAR (Structure, Originality, Authority, Recency) evidence quality score. Returns rawText, wordCount, soarScore (0.0-1.0), rejectionReason.",
    argumentsExample: ["url": "https://arxiv.org/abs/...", "domainContext": "computerscience"],
    schemaJson: """
    {"type":"object","properties":{"url":{"type":"string","format":"uri"},"domainContext":{"type":"string","enum":["medical","financial","computerscience","general"]}},"required":["url"]}
    """,
    destructive: false,
    requiresConfirmation: false
),

// Tool 3: NLI contradiction check (TMS)
OmegaToolDefinition(
    name: "checkcontradiction",
    agent: "notes",
    description: "Check a newly extracted fact against established core facts for logical contradictions via NLI. Returns contradictionDetected (bool), confidence (float), conflictSummary (string).",
    argumentsExample: ["newClaim": "Market size is $12B", "coreFactsContext": "Source A states market size is $5B (soarScore: 0.82)"],
    schemaJson: """
    {"type":"object","properties":{"newClaim":{"type":"string"},"coreFactsContext":{"type":"string"}},"required":["newClaim","coreFactsContext"]}
    """,
    destructive: false,
    requiresConfirmation: false
),

// Tool 4: Write verified research finding with enforced citation
OmegaToolDefinition(
    name: "synthesizeresearchnode",
    agent: "notes",
    description: "Write a verified, non-contradictory research finding to the vault with strict citation. Rejects writes if citationUrl is not in the active citation graph.",
    argumentsExample: ["noteTitle": "Transformer Research 2026", "synthesizedText": "Attention mechanisms...", "citationUrl": "https://arxiv.org/abs/..."],
    schemaJson: """
    {"type":"object","properties":{"noteTitle":{"type":"string"},"synthesizedText":{"type":"string"},"citationUrl":{"type":"string","format":"uri"}},"required":["noteTitle","synthesizedText","citationUrl"]}
    """,
    destructive: false,
    requiresConfirmation: false
)
```

### 8.3 New File: `TMSService.swift` (Truth Maintenance System)[^4]

```swift
// File: Epistemos/Services/Research/TMSService.swift
// SOAR Evidence Quality Scoring + NLI Contradiction Detection

import Foundation

struct TMSService {

    // MARK: — SOAR Evidence Quality Score

    /// Compute SOAR score for a captured source.
    /// Weights are adjusted per domain context per the SOAR redesign spec.
    static func calculateSOAR(
        url: String,
        text: String,
        wordCount: Int,
        domainContext: SOARDomainContext = .general
    ) -> SOARResult {
        let s = structureScore(text: text, wordCount: wordCount)
        let o = originalityScore(url: url, text: text)
        let a = authorityScore(url: url, domainContext: domainContext)
        let r = recencyScore(url: url, text: text)

        let weights = domainContext.weights
        let total = weights.s * s + weights.o * o + weights.a * a + weights.r * r

        return SOARResult(
            structure: s, originality: o, authority: a, recency: r,
            total: total,
            tier: total >= 0.75 ? .high : total >= 0.55 ? .medium : .low
        )
    }

    // MARK: — NLI Contradiction Detection

    /// Check if newClaim logically contradicts any established core fact.
    /// Uses local LLM via TriageService for NLI evaluation.
    static func evaluateNLI(
        newClaim: String,
        coreFactsContext: String
    ) async -> NLIResult {
        // Route to local model for NLI evaluation
        let prompt = """
        You are a Natural Language Inference classifier.
        Established facts: \(coreFactsContext)
        New claim: \(newClaim)
        Does the new claim CONTRADICT any established fact?
        Respond with JSON only: {"contradicts": true/false, "confidence": 0.0-1.0, "summary": "brief explanation"}
        """
        // Use TriageService.generateRawLocal for this
        // Parse JSON response
        return NLIResult(contradicts: false, confidence: 0.0, summary: "")
    }

    // MARK: — Private Scoring Functions

    private static func structureScore(text: String, wordCount: Int) -> Double {
        var score = 0.0
        if wordCount > 300 { score += 0.3 }
        if text.contains("abstract") || text.contains("introduction") { score += 0.2 }
        if text.components(separatedBy: "\n").count > 10 { score += 0.2 }
        if text.contains("doi:") || text.contains("DOI:") { score += 0.3 }
        return min(score, 1.0)
    }

    private static func originalityScore(url: String, text: String) -> Double {
        let secondarySources = ["medium.com", "substack.com", "wordpress.com", "blogspot.com"]
        if secondarySources.contains(where: url.contains) { return 0.2 }
        if url.contains("arxiv.org") || url.contains("doi.org") { return 0.9 }
        return 0.5
    }

    private static func authorityScore(url: String, domainContext: SOARDomainContext) -> Double {
        let highAuth = [".edu", ".gov", "nature.com", "science.org", "pubmed", "arxiv.org",
                        "openai.com", "deepmind.com", "anthropic.com", "apple.com"]
        let medAuth  = ["techcrunch.com", "wired.com", "reuters.com", "nytimes.com"]
        if highAuth.contains(where: url.contains) { return 0.95 }
        if medAuth.contains(where: url.contains)  { return 0.55 }
        return 0.30
    }

    private static func recencyScore(url: String, text: String) -> Double {
        let currentYear = Calendar.current.component(.year, from: Date())
        if text.contains("\(currentYear)") { return 1.0 }
        if text.contains("\(currentYear - 1)") { return 0.7 }
        if text.contains("\(currentYear - 2)") { return 0.4 }
        return 0.2
    }
}

// MARK: — Supporting Types

struct SOARResult {
    let structure: Double
    let originality: Double
    let authority: Double
    let recency: Double
    let total: Double
    let tier: SOARTier

    enum SOARTier { case high, medium, low }
}

struct NLIResult {
    let contradicts: Bool
    let confidence: Double
    let summary: String
}

enum SOARDomainContext {
    case medical, financial, computerScience, general

    struct Weights { let s, o, a, r: Double }

    var weights: Weights {
        switch self {
        case .medical:         return Weights(s: 0.35, o: 0.20, a: 0.35, r: 0.10)
        case .financial:       return Weights(s: 0.20, o: 0.25, a: 0.30, r: 0.25)
        case .computerScience: return Weights(s: 0.25, o: 0.25, a: 0.25, r: 0.25)
        case .general:         return Weights(s: 0.25, o: 0.25, a: 0.25, r: 0.25)
        }
    }
}
```

### 8.4 SQLite Schema Extension for `MCPBridge.swift`[^4]

```swift
// MODIFY: MCPBridge.swift — add columns to mcpexecutions table migration

let migrationSQL = """
ALTER TABLE mcpexecutions ADD COLUMN soarScore REAL;
ALTER TABLE mcpexecutions ADD COLUMN contradictionFlag INTEGER DEFAULT 0;
ALTER TABLE mcpexecutions ADD COLUMN citationHash TEXT;
ALTER TABLE mcpexecutions ADD COLUMN modelHash TEXT;
"""
// Run as a migration if columns don't exist (use IF NOT EXISTS workaround for SQLite)
```

***

## Part 9 — ModelDownloadManager Extension for GGUF

```swift
// MODIFY: ModelDownloadManager.swift (add GGUF download support)

extension ModelDownloadManager {

    /// Download path for a GGUF model variant.
    func ggufModelPath(for model: LocalTextModelID, quantization: ModelQuantization) -> URL {
        let modelsDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .appendingPathComponent("Epistemos/Models/GGUF")
        let fileName = quantization == .q4
            ? (model.ggufFileQ4 ?? "\(model.rawValue.split(separator: "/").last!)-Q4_K_M.gguf")
            : (model.ggufFileQ8 ?? "\(model.rawValue.split(separator: "/").last!)-Q8_0.gguf")
        return modelsDir.appendingPathComponent(model.familyName)
                        .appendingPathComponent(fileName)
    }

    /// Download a GGUF file from HuggingFace.
    /// Uses existing download infrastructure (URLSession + progress reporting).
    func downloadGGUF(
        model: LocalTextModelID,
        quantization: ModelQuantization,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        guard model.backend == .gguf else {
            throw DownloadError.notGGUFModel
        }
        let hfRepo = model.rawValue  // e.g. "Jackrong/Qwen3.5-27B-..."
        let fileName = quantization == .q4 ? model.ggufFileQ4! : model.ggufFileQ8!
        let hfURL = URL(string: "https://huggingface.co/\(hfRepo)/resolve/main/\(fileName)")!
        let destPath = ggufModelPath(for: model, quantization: quantization)

        // Create directory
        try FileManager.default.createDirectory(at: destPath.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        // Download using existing download infrastructure
        // ... (wire to existing URLSessionDownloadTask + progress callback pattern)
        return destPath
    }
}
```

***

## Part 10 — Research Training Data (Layer 16 Generator Wiring)[^1]

The gap audit identifies that `ResearchOrchestrator-22.swift` is TRUSTWORTHY but the Layer 16 research training data generator has never been run to disk. Fix this.[^1]

```python
# MODIFY: generateepistemostrainingdata.py — add research workflow examples function

def generate_research_workflow_examples(count: int = 100) -> list[dict]:
    """Generate ODIA trace examples for the full SOAR research pipeline.
    Per the gap closure plan, these should be written to researchtraining.jsonl
    and included in the trainfinal.jsonl composition via composetrainingmix.py.
    """
    examples = []
    research_queries = [
        "research transformer attention vs Mamba-2 state space models",
        "find evidence for TurboQuant KV cache compression benchmarks",
        "research Qwen3.5 REAP expert pruning ICLR 2026",
    ]
    for query in research_queries[:count]:
        example = {
            "messages": [
                {"role": "system", "content": "You are Epistemos-Nano, an embodied macOS research agent..."},
                {"role": "user", "content": query},
                {"role": "assistant", "content": (
                    "<think>Research task detected. Decomposing into sub-questions...</think>"
                    "[TOOL:deepsearchweb]{\"query\": \"" + query + "\", \"timerange\": \"year\"}"
                )}
            ],
            "category": "research",
            "taskType": "research",
            "layer": 16
        }
        examples.append(example)
    return examples

# ADD to main() in generateepistemostrainingdata.py:
research_examples = generate_research_workflow_examples(100)
with open("researchtraining.jsonl", "w") as f:
    for ex in research_examples:
        f.write(json.dumps(ex) + "\n")
print(f"Generated {len(research_examples)} research training examples -> researchtraining.jsonl")
```

***

## Part 11 — Complete File-Level Implementation Order

Execute these steps **in exact order**. Steps marked `[PARALLEL]` can run simultaneously.

### Phase 0 — Foundation (No Dependencies)

| Step | File | Action | Blocker For |
|------|------|---------|-------------|
| 0.1 | `ModelBackend.swift` | **CREATE NEW** — `ModelBackend` enum | All new models |
| 0.2 | `GGUFQuantVariant.swift` | **CREATE NEW** — quantization config types | Model picker |
| 0.3 | `ModelQuantization` enum | Add to `LocalModelSelectorView.swift` or shared types | Q4/Q8 picker |

### Phase 1 — Core Enum Replacement

| Step | File | Action | Blocker For |
|------|------|---------|-------------|
| 1.1 | `LocalTextModelID.swift` | **REPLACE ENTIRE FILE** with Part 3 content[^2] | Everything |
| 1.2 | `LocalTextModelID` extensions | Add `tier`, `ramRequirementQ4_GB`, `ramRequirementQ8_GB`, `supportsDualThinkMode`, `isMoE` | UI + inference |
| 1.3 [PARALLEL] | `MLXInferenceService.swift` | Add `backend` check — route GGUF models to `GGUFInferenceService` | GGUF models |

### Phase 2 — GGUF Backend

| Step | File | Action |
|------|------|---------|
| 2.1 | `omega-llama/` (Rust crate) OR `Package.swift` | Add LlamaKit/llama.cpp dependency |
| 2.2 | `GGUFInferenceService.swift` | **CREATE NEW** — Part 2.3 |
| 2.3 | `ModelDownloadManager.swift` | **MODIFY** — add GGUF download path (Part 9) |
| 2.4 [PARALLEL] | `InferenceState.swift` or `LLMService.swift` | Route based on `model.backend` |

### Phase 3 — Model Selector UI

| Step | File | Action |
|------|------|---------|
| 3.1 | `LocalModelSelectorView.swift` | **CREATE NEW** — Part 4 full implementation |
| 3.2 | Existing settings/model picker | Replace old picker call with `LocalModelSelectorView` |
| 3.3 [PARALLEL] | `UserDefaults` / `AppState` | Add `selectedQuantization: ModelQuantization` persistent preference |

### Phase 4 — Fast + Thinking + Agent Mode

| Step | File | Action |
|------|------|---------|
| 4.1 | `LLMService.swift` | Add `thinkingPromptPrefix(for:thinkMode:)` + `buildPromptWithThinkMode(...)` |
| 4.2 | `ChatInputBar.swift` | Make existing thinking toggle model-aware (Part 5.2) |
| 4.3 | `AgentModeSelector.swift` | **CREATE NEW** — Part 6.1 |
| 4.4 | `ChatState.swift` or message send handler | Wire `EpistemosOperatingMode` to existing Omega/direct paths |

### Phase 5 — TurboQuant + Prompt Repetition [PARALLEL with Phase 4]

| Step | File | Action |
|------|------|---------|
| 5.1 | `MLXInferenceService.swift` | Add `KVCacheConfig` struct + `turboQuant` flag via UserDefaults |
| 5.2 | `SystemPromptBuilder.swift` (or equivalent) | Add `withPromptRepetition(...)` for non-thinking models |
| 5.3 | Settings UI | Add TurboQuant toggle + Prompt Repetition toggle |

### Phase 6 — SOAR Research Mode

| Step | File | Action |
|------|------|---------|
| 6.1 | `TMSService.swift` | **CREATE NEW** — Part 8.3 |
| 6.2 | `OmegaToolRegistry.swift` | Add 4 new research tool definitions (Part 8.2) |
| 6.3 | `MCPBridge.swift` | Add SQLite column migration (Part 8.4) |
| 6.4 | `SafariAgent.swift` | Wire `deepsearchweb` and `captureandgradesource` tool handlers |
| 6.5 | `NotesAgent.swift` | Wire `checkcontradiction` and `synthesizeresearchnode` tool handlers |
| 6.6 | `OmegaPanel.swift` | Add SOAR score badge in `ExecutionProgressView` + Citation Tracker section |
| 6.7 | `TriageService.swift` | Add research keyword detection → force local Thinking Mode routing |

### Phase 7 — Training Data (Claude Can Do This Without Hardware)

| Step | File | Action |
|------|------|---------|
| 7.1 | `generateepistemostrainingdata.py` | Add `generate_research_workflow_examples()` — Part 10 |
| 7.2 | `composetrainingmix.py` | Include `researchtraining.jsonl` in compose pipeline |
| 7.3 | `QLoRATrainer.swift` | Verify `trainfinal.jsonl` is wired as default training data path[^1] |

***

## Part 12 — Test Coverage Requirements

Every new component requires at minimum these tests. Add to `ThemePairTests.swift` or create `ModelSupportTests.swift`:

```swift
// File: EpistemosTests/ModelSupportTests.swift

import XCTest

final class ModelSupportTests: XCTestCase {

    // MARK: — LocalTextModelID

    func testAllModelsHaveRAMRequirements() {
        for model in LocalTextModelID.allCases {
            XCTAssertGreaterThan(model.ramRequirementQ4_GB, 0,
                "\(model.rawValue) missing Q4 RAM requirement")
        }
    }

    func testQ8RAMAlwaysGreaterThanQ4() {
        for model in LocalTextModelID.allCases {
            if let q8 = model.ramRequirementQ8_GB {
                XCTAssertGreaterThanOrEqual(q8, model.ramRequirementQ4_GB,
                    "\(model.rawValue): Q8 RAM should be ≥ Q4 RAM")
            }
        }
    }

    func testModelTierAssignment() {
        XCTAssertEqual(LocalTextModelID.smolLM3_3B.tier, .ultraLight)
        XCTAssertEqual(LocalTextModelID.qwen3_9B_4bit.tier, .efficient)
        XCTAssertEqual(LocalTextModelID.devstralSmall2_24B.tier, .standard)
        XCTAssertEqual(LocalTextModelID.qwen3_40B_opusUncensored.tier, .professional)
        XCTAssertEqual(LocalTextModelID.llama4Scout_109B_MoE.tier, .maximum)
    }

    func testThinkModeOnlyForSupportedModels() {
        XCTAssertTrue(LocalTextModelID.qwen3_9B_4bit.supportsDualThinkMode)
        XCTAssertTrue(LocalTextModelID.smolLM3_3B.supportsDualThinkMode)
        XCTAssertFalse(LocalTextModelID.gemma3_27B_QAT.supportsDualThinkMode)
        XCTAssertFalse(LocalTextModelID.devstralSmall2_24B.supportsDualThinkMode)
    }

    func testBackendAssignment() {
        XCTAssertEqual(LocalTextModelID.qwen3_9B_4bit.backend, .mlx)
        XCTAssertEqual(LocalTextModelID.qwen3_27B_opusDistilled.backend, .gguf)
        XCTAssertEqual(LocalTextModelID.gemma3_27B_QAT.backend, .gguf)
        XCTAssertEqual(LocalTextModelID.llama4Scout_109B_MoE.backend, .mlx)
    }

    // MARK: — SOAR / TMS

    func testSOARRejectsLowQualitySources() {
        let result = TMSService.calculateSOAR(
            url: "https://medium.com/some-blog-post",
            text: "Some opinion piece",
            wordCount: 150
        )
        XCTAssertLessThan(result.total, 0.65, "Low-quality blog should score below threshold")
    }

    func testSOARAcceptsAcademicSources() {
        let result = TMSService.calculateSOAR(
            url: "https://arxiv.org/abs/2601.00001",
            text: "Abstract: Introduction: We present... doi: 10.1234/... References: [^1]...",
            wordCount: 5000
        )
        XCTAssertGreaterThanOrEqual(result.total, 0.65, "ArXiv paper should pass SOAR threshold")
    }

    // MARK: — Research Tools Registered

    func testResearchToolsAreInRegistry() {
        let names = OmegaToolRegistry.all.map(\.name)
        XCTAssertTrue(names.contains("deepsearchweb"))
        XCTAssertTrue(names.contains("captureandgradesource"))
        XCTAssertTrue(names.contains("checkcontradiction"))
        XCTAssertTrue(names.contains("synthesizeresearchnode"))
    }
}
```

***

## Part 13 — Known Gaps & Suggested Implementations

Items from the X research that cannot be fully implemented yet but should be stubbed:

| Item | Status | Suggested Stub |
|------|--------|---------------|
| **Llama 4 Scout 109B** | MLX model available but requires 64GB | Add to enum; disable in picker if RAM < 64GB |
| **MiniMax M2.5** | Weights not yet public as of March 2026 | Add enum case + `isComingSoon: Bool = true` flag |
| **Chroma Context-1** | May require registration/access | Same `isComingSoon` treatment |
| **Full TurboQuant** | Requires MLX `kv_bits` param (check mlx-lm ≥ 0.21) | Implement flag now, wire when mlx-lm available |
| **Exo distributed inference** | Multi-Mac networking | Out of scope for this sprint; file as enhancement issue |
| **omlx SSD caching** | github.com/jundo/tomlx | Out of scope; note in architecture comments |

***

## Part 14 — Acceptance Criteria (Claude Code "Done" Definition)

A session is complete when **all** of the following are true:

- [ ] `LocalTextModelID` has all 17 models (6 existing MLX + 11 new)
- [ ] Every model has `ramRequirementQ4_GB` and `ramRequirementQ8_GB?` populated
- [ ] `ModelBackend.swift` exists with `.mlx` and `.gguf` cases
- [ ] `GGUFInferenceService.swift` exists and compiles (even if inference calls are stubbed)
- [ ] Model picker shows 5 tier sections (Ultra Light → Maximum) with RAM labels
- [ ] Q4 / Q8 buttons render in picker for each model row
- [ ] Thinking toggle is model-aware (disabled/greyed for models without `supportsDualThinkMode`)
- [ ] `AgentModeSelector.swift` renders Fast / Thinking / Agent three-way toggle
- [ ] `EpistemosOperatingMode.agent` routes through `OrchestratorState.submitTask`
- [ ] `TMSService.swift` exists with `calculateSOAR()` and `evaluateNLI()`
- [ ] All 4 SOAR tool schemas are in `OmegaToolRegistry.all`
- [ ] MCPBridge SQLite migration adds `soarScore`, `contradictionFlag`, `citationHash`, `modelHash`
- [ ] `KVCacheConfig` struct exists; TurboQuant flag wired to MLX inference call
- [ ] Prompt Repetition function exists in `SystemPromptBuilder` (or equivalent)
- [ ] All `ModelSupportTests` pass
- [ ] All existing `ThemePairTests` continue to pass (no regressions)
- [ ] `generate_research_workflow_examples()` runs and produces `researchtraining.jsonl`

---

## References

1. [2026-03-27-master-gap-closure-plan-2.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/a801ec0e-b40f-4179-b5c5-0447d3f831b8/2026-03-27-master-gap-closure-plan-2.md?AWSAccessKeyId=ASIA2F3EMEYETX27VVL3&Signature=x%2FIZ7MsP12lFpAlEG%2BbvN1GOeaI%3D&x-amz-security-token=IQoJb3JpZ2luX2VjECAaCXVzLWVhc3QtMSJGMEQCID3grZFDEXq5tL8kb6CyTIm03ByoY%2BJ8S0p5dK%2Fy5%2F7wAiAeFwuQ%2BaN%2Fz4y1whDOk5nI8PJhtg3E8aULV7HEXeDqICr8BAjo%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAEaDDY5OTc1MzMwOTcwNSIMA4h3qND%2FJCBJ3mfeKtAEJefIrdV6GbxFA4mcXvlMmPgbuR4RbMn6tMuJNjwy0ASj%2B%2FVU%2F5VHvGs7T4JK7zPYWAtsrmwfMQZ33HD6j%2FX3%2BCmoBsnfB06pa9U4y3W8T612BCCLxK6sFDFhlvHvDBT29JT48nzueNF%2FMCyrSddgIEv7e2Cs%2F1fJacK07ouzQZ1zJ0223CYffnZ%2BnTc5aU7Rsz3eB4NuK7fiSzZlunfLNZyyATM4DI7mF5hH7BcT6jXa8M8UIAhFkQElf2eO60KyvUoZnCUWUVrJkDVN5LMN98o%2FjvDf7AGTcqTolVJmo2RaH5ORYHlIo3iu37RR%2BzcPd4bvTNWQ2euaEuPY0jOZ70k8pVQoEESH8YdrCWu4q16wMmUh06M95L5MpbiRMDpL%2FpLy267gKAsaWtJeGSIyYKv3MQzRgy5gnPtN3i%2FdeQHs%2BJaMtr%2B8lhtdd5vj1e9H9G1m12q9t1%2FKh8Ud2Ln7vdXQXU3BACN7rQcDYX63%2F8Y%2BRosEPgRSKRodgCroFrsjIfmEAEPTHm9yQ8h6M2nGFZGmXDHhjVoC9vcgS5D8cvEYk6ORbmbQ83oMUaRhBa33im2Rrfq%2FKRjIewU5RqhVftLyqD4GzAXvoJrd1asEevr2OLETLkZrpsNPuJlJZxGoRNHFWt76P1GTmrarz5YUpNGccJEzUAC3aQrkm8NEtOIN89wHuM6ouACbNUVtN5b0jWs1oAqFkah2HyoyYvIi4hTLp63bWqQs2SPd8cn6J77IoZCvX0Zt5t2R%2FP367ky5wZXxxqbefaxx3%2BVdQbIZpjCtnZzOBjqZAbeiZLouXnPrFrzeM%2Fx%2FltrEl%2B2lwYR1aHCydJqWlsikuZ%2FJEuDtvJYTVlMHFbh%2FYrjJiweERFrBneLs8cExD%2FyRvnyLUnqNHpGh2%2BnXCQAdyuXHYsxPfdGAx95C0QD5weHfPa%2Bu37SexfhyQvfeLYOrO2yNP10ctjrBOvnv22LgGTAHMaqNfy13meSueGxLuAoHTURSWSGcEw%3D%3D&Expires=1774656640) - Date 2026-03-27 Author Claude Opus 4.6 Automated Audit Scope All 30 source files Swift, Python, Rust...

2. [epistemos-upgrade-plan-1-5.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/101cb014-f169-4930-86bf-e09c396f8dd8/epistemos-upgrade-plan-1-5.md?AWSAccessKeyId=ASIA2F3EMEYETX27VVL3&Signature=TBzSjcRyUHvIOp5Tv4yjGLVmwOY%3D&x-amz-security-token=IQoJb3JpZ2luX2VjECAaCXVzLWVhc3QtMSJGMEQCID3grZFDEXq5tL8kb6CyTIm03ByoY%2BJ8S0p5dK%2Fy5%2F7wAiAeFwuQ%2BaN%2Fz4y1whDOk5nI8PJhtg3E8aULV7HEXeDqICr8BAjo%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAEaDDY5OTc1MzMwOTcwNSIMA4h3qND%2FJCBJ3mfeKtAEJefIrdV6GbxFA4mcXvlMmPgbuR4RbMn6tMuJNjwy0ASj%2B%2FVU%2F5VHvGs7T4JK7zPYWAtsrmwfMQZ33HD6j%2FX3%2BCmoBsnfB06pa9U4y3W8T612BCCLxK6sFDFhlvHvDBT29JT48nzueNF%2FMCyrSddgIEv7e2Cs%2F1fJacK07ouzQZ1zJ0223CYffnZ%2BnTc5aU7Rsz3eB4NuK7fiSzZlunfLNZyyATM4DI7mF5hH7BcT6jXa8M8UIAhFkQElf2eO60KyvUoZnCUWUVrJkDVN5LMN98o%2FjvDf7AGTcqTolVJmo2RaH5ORYHlIo3iu37RR%2BzcPd4bvTNWQ2euaEuPY0jOZ70k8pVQoEESH8YdrCWu4q16wMmUh06M95L5MpbiRMDpL%2FpLy267gKAsaWtJeGSIyYKv3MQzRgy5gnPtN3i%2FdeQHs%2BJaMtr%2B8lhtdd5vj1e9H9G1m12q9t1%2FKh8Ud2Ln7vdXQXU3BACN7rQcDYX63%2F8Y%2BRosEPgRSKRodgCroFrsjIfmEAEPTHm9yQ8h6M2nGFZGmXDHhjVoC9vcgS5D8cvEYk6ORbmbQ83oMUaRhBa33im2Rrfq%2FKRjIewU5RqhVftLyqD4GzAXvoJrd1asEevr2OLETLkZrpsNPuJlJZxGoRNHFWt76P1GTmrarz5YUpNGccJEzUAC3aQrkm8NEtOIN89wHuM6ouACbNUVtN5b0jWs1oAqFkah2HyoyYvIi4hTLp63bWqQs2SPd8cn6J77IoZCvX0Zt5t2R%2FP367ky5wZXxxqbefaxx3%2BVdQbIZpjCtnZzOBjqZAbeiZLouXnPrFrzeM%2Fx%2FltrEl%2B2lwYR1aHCydJqWlsikuZ%2FJEuDtvJYTVlMHFbh%2FYrjJiweERFrBneLs8cExD%2FyRvnyLUnqNHpGh2%2BnXCQAdyuXHYsxPfdGAx95C0QD5weHfPa%2Bu37SexfhyQvfeLYOrO2yNP10ctjrBOvnv22LgGTAHMaqNfy13meSueGxLuAoHTURSWSGcEw%3D%3D&Expires=1774656640) - Date March 27, 2026 --- TITLE Epistemos Master Upgrade Plan - Compiled from 641 X Bookmarks, 70 Retw...

3. [EPISTEMOS-FEATURE-SPEC-copy-9.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/7fff36f3-f08f-4ee7-b256-2ef5abd8b0a7/EPISTEMOS-FEATURE-SPEC-copy-9.md?AWSAccessKeyId=ASIA2F3EMEYETX27VVL3&Signature=Gtg4DSvFLhEsFsUSnbsLlYUNoRM%3D&x-amz-security-token=IQoJb3JpZ2luX2VjECAaCXVzLWVhc3QtMSJGMEQCID3grZFDEXq5tL8kb6CyTIm03ByoY%2BJ8S0p5dK%2Fy5%2F7wAiAeFwuQ%2BaN%2Fz4y1whDOk5nI8PJhtg3E8aULV7HEXeDqICr8BAjo%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAEaDDY5OTc1MzMwOTcwNSIMA4h3qND%2FJCBJ3mfeKtAEJefIrdV6GbxFA4mcXvlMmPgbuR4RbMn6tMuJNjwy0ASj%2B%2FVU%2F5VHvGs7T4JK7zPYWAtsrmwfMQZ33HD6j%2FX3%2BCmoBsnfB06pa9U4y3W8T612BCCLxK6sFDFhlvHvDBT29JT48nzueNF%2FMCyrSddgIEv7e2Cs%2F1fJacK07ouzQZ1zJ0223CYffnZ%2BnTc5aU7Rsz3eB4NuK7fiSzZlunfLNZyyATM4DI7mF5hH7BcT6jXa8M8UIAhFkQElf2eO60KyvUoZnCUWUVrJkDVN5LMN98o%2FjvDf7AGTcqTolVJmo2RaH5ORYHlIo3iu37RR%2BzcPd4bvTNWQ2euaEuPY0jOZ70k8pVQoEESH8YdrCWu4q16wMmUh06M95L5MpbiRMDpL%2FpLy267gKAsaWtJeGSIyYKv3MQzRgy5gnPtN3i%2FdeQHs%2BJaMtr%2B8lhtdd5vj1e9H9G1m12q9t1%2FKh8Ud2Ln7vdXQXU3BACN7rQcDYX63%2F8Y%2BRosEPgRSKRodgCroFrsjIfmEAEPTHm9yQ8h6M2nGFZGmXDHhjVoC9vcgS5D8cvEYk6ORbmbQ83oMUaRhBa33im2Rrfq%2FKRjIewU5RqhVftLyqD4GzAXvoJrd1asEevr2OLETLkZrpsNPuJlJZxGoRNHFWt76P1GTmrarz5YUpNGccJEzUAC3aQrkm8NEtOIN89wHuM6ouACbNUVtN5b0jWs1oAqFkah2HyoyYvIi4hTLp63bWqQs2SPd8cn6J77IoZCvX0Zt5t2R%2FP367ky5wZXxxqbefaxx3%2BVdQbIZpjCtnZzOBjqZAbeiZLouXnPrFrzeM%2Fx%2FltrEl%2B2lwYR1aHCydJqWlsikuZ%2FJEuDtvJYTVlMHFbh%2FYrjJiweERFrBneLs8cExD%2FyRvnyLUnqNHpGh2%2BnXCQAdyuXHYsxPfdGAx95C0QD5weHfPa%2Bu37SexfhyQvfeLYOrO2yNP10ctjrBOvnv22LgGTAHMaqNfy13meSueGxLuAoHTURSWSGcEw%3D%3D&Expires=1774656640) - Version 1.0 Author Jordan Tyrell Conley Date March 27, 2026 Repository BlickandMortyEpistemos Purpos...

4. [Omega-Research-SOAR-Redesign-6.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/43b6b65b-99d5-4014-8e49-cd4aebf322be/Omega-Research-SOAR-Redesign-6.md?AWSAccessKeyId=ASIA2F3EMEYETX27VVL3&Signature=6JRyHmgLqHarIQgskS%2FtzaJq7CA%3D&x-amz-security-token=IQoJb3JpZ2luX2VjECAaCXVzLWVhc3QtMSJGMEQCID3grZFDEXq5tL8kb6CyTIm03ByoY%2BJ8S0p5dK%2Fy5%2F7wAiAeFwuQ%2BaN%2Fz4y1whDOk5nI8PJhtg3E8aULV7HEXeDqICr8BAjo%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAEaDDY5OTc1MzMwOTcwNSIMA4h3qND%2FJCBJ3mfeKtAEJefIrdV6GbxFA4mcXvlMmPgbuR4RbMn6tMuJNjwy0ASj%2B%2FVU%2F5VHvGs7T4JK7zPYWAtsrmwfMQZ33HD6j%2FX3%2BCmoBsnfB06pa9U4y3W8T612BCCLxK6sFDFhlvHvDBT29JT48nzueNF%2FMCyrSddgIEv7e2Cs%2F1fJacK07ouzQZ1zJ0223CYffnZ%2BnTc5aU7Rsz3eB4NuK7fiSzZlunfLNZyyATM4DI7mF5hH7BcT6jXa8M8UIAhFkQElf2eO60KyvUoZnCUWUVrJkDVN5LMN98o%2FjvDf7AGTcqTolVJmo2RaH5ORYHlIo3iu37RR%2BzcPd4bvTNWQ2euaEuPY0jOZ70k8pVQoEESH8YdrCWu4q16wMmUh06M95L5MpbiRMDpL%2FpLy267gKAsaWtJeGSIyYKv3MQzRgy5gnPtN3i%2FdeQHs%2BJaMtr%2B8lhtdd5vj1e9H9G1m12q9t1%2FKh8Ud2Ln7vdXQXU3BACN7rQcDYX63%2F8Y%2BRosEPgRSKRodgCroFrsjIfmEAEPTHm9yQ8h6M2nGFZGmXDHhjVoC9vcgS5D8cvEYk6ORbmbQ83oMUaRhBa33im2Rrfq%2FKRjIewU5RqhVftLyqD4GzAXvoJrd1asEevr2OLETLkZrpsNPuJlJZxGoRNHFWt76P1GTmrarz5YUpNGccJEzUAC3aQrkm8NEtOIN89wHuM6ouACbNUVtN5b0jWs1oAqFkah2HyoyYvIi4hTLp63bWqQs2SPd8cn6J77IoZCvX0Zt5t2R%2FP367ky5wZXxxqbefaxx3%2BVdQbIZpjCtnZzOBjqZAbeiZLouXnPrFrzeM%2Fx%2FltrEl%2B2lwYR1aHCydJqWlsikuZ%2FJEuDtvJYTVlMHFbh%2FYrjJiweERFrBneLs8cExD%2FyRvnyLUnqNHpGh2%2BnXCQAdyuXHYsxPfdGAx95C0QD5weHfPa%2Bu37SexfhyQvfeLYOrO2yNP10ctjrBOvnv22LgGTAHMaqNfy13meSueGxLuAoHTURSWSGcEw%3D%3D&Expires=1774656640) - The integration of advanced, autonomous research capabilities within the Epistemos environment neces...

5. [Epistemos-Next-Generation-Research-Mode-Migration-Blueprint-2-7.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/ea58b335-0fee-4186-9fe0-8363844f536f/Epistemos-Next-Generation-Research-Mode-Migration-Blueprint-2-7.md?AWSAccessKeyId=ASIA2F3EMEYETX27VVL3&Signature=4XaS8PPQCNQei8lFJqnRv%2FQOSPg%3D&x-amz-security-token=IQoJb3JpZ2luX2VjECAaCXVzLWVhc3QtMSJGMEQCID3grZFDEXq5tL8kb6CyTIm03ByoY%2BJ8S0p5dK%2Fy5%2F7wAiAeFwuQ%2BaN%2Fz4y1whDOk5nI8PJhtg3E8aULV7HEXeDqICr8BAjo%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAEaDDY5OTc1MzMwOTcwNSIMA4h3qND%2FJCBJ3mfeKtAEJefIrdV6GbxFA4mcXvlMmPgbuR4RbMn6tMuJNjwy0ASj%2B%2FVU%2F5VHvGs7T4JK7zPYWAtsrmwfMQZ33HD6j%2FX3%2BCmoBsnfB06pa9U4y3W8T612BCCLxK6sFDFhlvHvDBT29JT48nzueNF%2FMCyrSddgIEv7e2Cs%2F1fJacK07ouzQZ1zJ0223CYffnZ%2BnTc5aU7Rsz3eB4NuK7fiSzZlunfLNZyyATM4DI7mF5hH7BcT6jXa8M8UIAhFkQElf2eO60KyvUoZnCUWUVrJkDVN5LMN98o%2FjvDf7AGTcqTolVJmo2RaH5ORYHlIo3iu37RR%2BzcPd4bvTNWQ2euaEuPY0jOZ70k8pVQoEESH8YdrCWu4q16wMmUh06M95L5MpbiRMDpL%2FpLy267gKAsaWtJeGSIyYKv3MQzRgy5gnPtN3i%2FdeQHs%2BJaMtr%2B8lhtdd5vj1e9H9G1m12q9t1%2FKh8Ud2Ln7vdXQXU3BACN7rQcDYX63%2F8Y%2BRosEPgRSKRodgCroFrsjIfmEAEPTHm9yQ8h6M2nGFZGmXDHhjVoC9vcgS5D8cvEYk6ORbmbQ83oMUaRhBa33im2Rrfq%2FKRjIewU5RqhVftLyqD4GzAXvoJrd1asEevr2OLETLkZrpsNPuJlJZxGoRNHFWt76P1GTmrarz5YUpNGccJEzUAC3aQrkm8NEtOIN89wHuM6ouACbNUVtN5b0jWs1oAqFkah2HyoyYvIi4hTLp63bWqQs2SPd8cn6J77IoZCvX0Zt5t2R%2FP367ky5wZXxxqbefaxx3%2BVdQbIZpjCtnZzOBjqZAbeiZLouXnPrFrzeM%2Fx%2FltrEl%2B2lwYR1aHCydJqWlsikuZ%2FJEuDtvJYTVlMHFbh%2FYrjJiweERFrBneLs8cExD%2FyRvnyLUnqNHpGh2%2BnXCQAdyuXHYsxPfdGAx95C0QD5weHfPa%2Bu37SexfhyQvfeLYOrO2yNP10ctjrBOvnv22LgGTAHMaqNfy13meSueGxLuAoHTURSWSGcEw%3D%3D&Expires=1774656640) - The old research subsystem and SOAR were removed wholesale not because the product behavior was wron...

