import Dispatch
import Foundation
import Observation
import os

nonisolated enum LocalTextModelID: String, Codable, Sendable, CaseIterable {
    // MARK: - Qwen 3.5 Family (base models)
    case qwen35_0_8B4Bit = "mlx-community/Qwen3.5-0.8B-4bit"
    case qwen35_2B4Bit = "mlx-community/Qwen3.5-2B-4bit"
    case qwen35_4B4Bit = "mlx-community/Qwen3.5-4B-4bit"
    case qwen35_9B4Bit = "mlx-community/Qwen3.5-9B-4bit"
    case qwen35_27B4Bit = "mlx-community/Qwen3.5-27B-4bit"
    case qwen35_35BA3B4Bit = "mlx-community/Qwen3.5-35B-A3B-4bit"
    case qwen36_35BA3B4Bit = "mlx-community/Qwen3.6-35B-A3B-4bit"
    // Qwen 3.6 35B A3B — upgraded quant variants (see MASTER_MODEL_STACK_PLAN).
    // Unsloth Dynamic 4-bit: best-quality quant, drop-in replacement.
    case qwen36_35BA3B_Unsloth4Bit = "unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit"
    // Dynamic Weight Quantization 4-bit: alternative high-quality quant.
    case qwen36_35BA3B_DWQ4Bit = "mlx-community/Qwen3.6-35B-A3B-4bit-DWQ"

    // MARK: - Qwen 3 Family (newer gen, official MLX, tool-calling native)
    case qwen3_4B4Bit = "Qwen/Qwen3-4B-MLX-4bit"
    case qwen3_8B4Bit = "Qwen/Qwen3-8B-MLX-4bit"
    case qwen3_4BThinking25074Bit = "mlx-community/Qwen3-4B-Thinking-2507-4bit"

    // MARK: - Qwen 3 Coder (tool-calling code specialists)
    case qwen3CoderNext4Bit = "mlx-community/Qwen3-Coder-Next-4bit"
    case qwen3Coder30BA3B4Bit = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit"

    // MARK: - LocalAgent 4.3 (function-calling flagship, ByteDance Seed 36B base)
    case localAgent43_36B4Bit = "leonsarmiento/Hermes-4.3-36B-4bit-mlx"
    case localAgent43_36B3Bit = "leonsarmiento/Hermes-4.3-36B-3bit-mlx"

    // MARK: - Gemma 4 Family (2026 frontier)
    // Gemma 4 dense tiers load via the native Apple Swift port vendored into
    // mlx-swift-lm (Gemma4Text.swift @ e3cb1e1b) — no longer preview-blocked on
    // a missing loader. The official dense E2B/E4B tiers are runnable (E2B is
    // installable as the on-device validation tier); the 26B-A4B MoE + 31B-JANG
    // third-party tiers are still gated (dense-only port / unverified config) —
    // see isAwaitingSwiftRuntimeLoader. Do not surface gemma4 as a default
    // triage pick; the validated default stays Qwen.
    case gemma4_2B4Bit = "mlx-community/gemma-4-e2b-it-4bit"
    case gemma4_4B4Bit = "mlx-community/gemma-4-e4b-it-4bit"
    case gemma4_27BA4B4Bit = "mlx-community/gemma-4-26b-a4b-it-4bit"
    case gemma4_31BJANG = "dealignai/Gemma-4-31B-JANG_4M-CRACK"

    // MARK: - Qwopus (Claude Opus distilled — best coding/tool-calling)
    case qwopus27Bv3 = "Jackrong/Qwopus3.5-27B-v3-GGUF"
    case qwopusMoE35BA3B = "samuelcardillo/Qwopus-MoE-35B-A3B-GGUF"

    // MARK: - Specialist Models
    case deepseekR1Distill7B = "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit"
    /// QwQ 32B — Qwen team's flagship reasoning model (comparable to DeepSeek-R1
    /// at 32B). Uses the existing Qwen MLX arch; no new loader required.
    case qwqFlagship32B4Bit = "mlx-community/QwQ-32B-4bit"
    case qwen25Coder7B = "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"
    case bonsai4B2Bit = "prism-ml/Ternary-Bonsai-4B-mlx-2bit"
    case bonsai8B2Bit = "prism-ml/Ternary-Bonsai-8B-mlx-2bit"

    // MARK: - LFM2.5 (Liquid Foundation Model 2.5 — SSM hybrid, on-device optimized)
    case lfm25_350M = "LiquidAI/LFM2.5-350M-MLX-4bit"
    case lfm25_1BInstruct = "LiquidAI/LFM2.5-1.2B-Instruct-MLX-4bit"
    case lfm25_1BThinking = "LiquidAI/LFM2.5-1.2B-Thinking-MLX-4bit"
    case lfm25_VL1B = "mlx-community/LFM2.5-VL-1.6B-4bit"
    case lfm25_Audio1B = "mlx-community/LFM2.5-Audio-1.5B-4bit"

    // MARK: - LFM2 (Liquid Foundation Model 2 — larger SSM variants)
    case lfm2_2B4Bit = "mlx-community/LFM2-2.6B-4bit"
    case lfm2_8BA1B3Bit = "mlx-community/LFM2-8B-A1B-3bit-MLX"
    case lfm2_24BA2B4Bit = "LiquidAI/LFM2-24B-A2B-MLX-4bit"

    // MARK: - Other SSM Models (Mamba2, Jamba, FalconH1)
    case mamba2_2B4Bit = "mlx-community/mamba2-2.7b-4bit"
    case jamba3B = "mlx-community/AI21-Jamba-Reasoning-3B-bf16"
    case falconH1_1B4Bit = "mlx-community/Falcon-H1-1.5B-Instruct-4bit"
    case falconH1R_7B4Bit = "mlx-community/Falcon-H1R-7B-4bit"

    // MARK: - Other Families
    case llama32_3BInstruct4Bit = "mlx-community/Llama-3.2-3B-Instruct-4bit"
    case smolLM3_3B4Bit = "mlx-community/SmolLM3-3B-4bit"
    case devstralSmall2505_4Bit = "mlx-community/Devstral-Small-2505-4bit"
    case mistralSmall31_24B4Bit = "mlx-community/Mistral-Small-3.1-24B-Instruct-2503-4bit"
    case gemma3_4BQAT4Bit = "mlx-community/gemma-3-4b-it-qat-4bit"
    case gemma3_27BQAT4Bit = "mlx-community/gemma-3-27b-it-qat-4bit"
    case llama4Scout17B16E4Bit = "mlx-community/meta-llama-Llama-4-Scout-17B-16E-4bit"

    static let hermes43_36B4Bit: Self = .localAgent43_36B4Bit
    static let hermes43_36B3Bit: Self = .localAgent43_36B3Bit

    var runtimeKind: BackendRuntimeKind {
        switch self {
        case .qwopus27Bv3, .qwopusMoE35BA3B:
            .gguf
        default:
            .mlx
        }
    }

    var displayName: String {
        switch self {
        case .qwen35_0_8B4Bit: "Qwen 3.5 0.8B"
        case .qwen35_2B4Bit: "Qwen 3.5 2B"
        case .qwen35_4B4Bit: "Qwen 3.5 4B"
        case .qwen35_9B4Bit: "Qwen 3.5 9B"
        case .qwen35_27B4Bit: "Qwen 3.5 27B"
        case .qwen35_35BA3B4Bit: "Qwen 3.5 35B APEXMini"
        case .qwen36_35BA3B4Bit: "Qwen 3.6 35B A3B"
        case .qwen36_35BA3B_Unsloth4Bit: "Qwen 3.6 35B A3B — Unsloth UD"
        case .qwen36_35BA3B_DWQ4Bit: "Qwen 3.6 35B A3B — DWQ"
        case .qwen3_4B4Bit: "Qwen 3 4B"
        case .qwen3_8B4Bit: "Qwen 3 8B"
        case .qwen3_4BThinking25074Bit: "Qwen 3 4B Thinking"
        case .qwen3CoderNext4Bit: "Qwen 3 Coder Next"
        case .qwen3Coder30BA3B4Bit: "Qwen 3 Coder 30B A3B"
        case .localAgent43_36B4Bit: "LocalAgent 4.3 36B"
        case .localAgent43_36B3Bit: "LocalAgent 4.3 36B (3-bit)"
        case .gemma4_2B4Bit: "Gemma 4 2B"
        case .gemma4_4B4Bit: "Gemma 4 E4B"
        case .gemma4_27BA4B4Bit: "Gemma 4 26B A4B"
        case .gemma4_31BJANG: "Gemma 4 31B JANG"
        case .qwopus27Bv3: "Qwopus 27B v3"
        case .qwopusMoE35BA3B: "Qwopus MoE 35B"
        case .deepseekR1Distill7B: "DeepSeek R1 7B"
        case .qwqFlagship32B4Bit: "QwQ 32B"
        case .qwen25Coder7B: "Qwen 2.5 Coder 7B"
        case .bonsai4B2Bit: "Ternary Bonsai 4B"
        case .bonsai8B2Bit: "Ternary Bonsai 8B"
        case .lfm25_350M: "LFM2.5 350M"
        case .lfm25_1BInstruct: "LFM2.5 1.2B"
        case .lfm25_1BThinking: "LFM2.5 1.2B Thinking"
        case .lfm25_VL1B: "LFM2.5 VL 1.6B"
        case .lfm25_Audio1B: "LFM2.5 Audio 1.5B"
        case .lfm2_2B4Bit: "LFM2 2.6B"
        case .lfm2_8BA1B3Bit: "LFM2 8B MoE"
        case .lfm2_24BA2B4Bit: "LFM2 24B MoE"
        case .mamba2_2B4Bit: "Mamba2 2.7B"
        case .jamba3B: "Jamba Reasoning 3B"
        case .falconH1_1B4Bit: "FalconH1 1.5B"
        case .falconH1R_7B4Bit: "FalconH1R 7B"
        case .llama32_3BInstruct4Bit: "Llama 3.2 3B"
        case .smolLM3_3B4Bit: "SmolLM3 3B"
        case .devstralSmall2505_4Bit: "Devstral Small"
        case .mistralSmall31_24B4Bit: "Mistral Small 24B"
        case .gemma3_4BQAT4Bit: "Gemma 3 4B"
        case .gemma3_27BQAT4Bit: "Gemma 3 27B"
        case .llama4Scout17B16E4Bit: "Llama 4 Scout"
        }
    }

    var compactDisplayName: String {
        switch self {
        case .qwen35_0_8B4Bit: "Qwen 0.8B"
        case .qwen35_2B4Bit: "Qwen 2B"
        case .qwen35_4B4Bit: "Qwen 4B"
        case .qwen35_9B4Bit: "Qwen 9B"
        case .qwen35_27B4Bit: "Qwen 27B"
        case .qwen35_35BA3B4Bit: "Qwen 35B APEX"
        case .qwen36_35BA3B4Bit: "Qwen3.6 35B"
        case .qwen36_35BA3B_Unsloth4Bit: "Qwen3.6 UD"
        case .qwen36_35BA3B_DWQ4Bit: "Qwen3.6 DWQ"
        case .qwen3_4B4Bit: "Qwen3 4B"
        case .qwen3_8B4Bit: "Qwen3 8B"
        case .qwen3_4BThinking25074Bit: "Qwen3 Think 4B"
        case .qwen3CoderNext4Bit: "Qwen3 Coder"
        case .qwen3Coder30BA3B4Bit: "Qwen3 Coder 30B"
        case .localAgent43_36B4Bit: "LocalAgent 4.3"
        case .localAgent43_36B3Bit: "LocalAgent 4.3 (3b)"
        case .gemma4_2B4Bit: "Gemma 2B"
        case .gemma4_4B4Bit: "Gemma E4B"
        case .gemma4_27BA4B4Bit: "Gemma 26B A4B"
        case .gemma4_31BJANG: "Gemma 31B"
        case .qwopus27Bv3: "Qwopus 27B"
        case .qwopusMoE35BA3B: "Qwopus 35B"
        case .deepseekR1Distill7B: "R1 7B"
        case .qwqFlagship32B4Bit: "QwQ 32B"
        case .qwen25Coder7B: "Coder 7B"
        case .bonsai4B2Bit: "Bonsai 4B"
        case .bonsai8B2Bit: "Bonsai 8B"
        case .llama32_3BInstruct4Bit: "Llama3.2 3B"
        case .smolLM3_3B4Bit: "SmolLM3"
        case .devstralSmall2505_4Bit: "Devstral"
        case .mistralSmall31_24B4Bit: "Mistral 24B"
        case .gemma3_4BQAT4Bit: "Gemma3 4B"
        case .gemma3_27BQAT4Bit: "Gemma3 27B"
        case .llama4Scout17B16E4Bit: "Llama 4"
        case .lfm25_350M: "LFM 350M"
        case .lfm25_1BInstruct: "LFM2.5"
        case .lfm25_1BThinking: "LFM2.5 Think"
        case .lfm25_VL1B: "LFM2.5 VL"
        case .lfm25_Audio1B: "LFM2.5 Audio"
        case .lfm2_2B4Bit: "LFM2 2.6B"
        case .lfm2_8BA1B3Bit: "LFM2 8B"
        case .lfm2_24BA2B4Bit: "LFM2 24B"
        case .mamba2_2B4Bit: "Mamba2"
        case .jamba3B: "Jamba 3B"
        case .falconH1_1B4Bit: "FalconH1"
        case .falconH1R_7B4Bit: "FalconH1R"
        }
    }

    var familyName: String {
        switch self {
        case .qwen35_0_8B4Bit, .qwen35_2B4Bit, .qwen35_4B4Bit,
             .qwen35_9B4Bit, .qwen35_27B4Bit, .qwen35_35BA3B4Bit:
            "Qwen 3.5"
        case .qwen36_35BA3B4Bit,
             .qwen36_35BA3B_Unsloth4Bit,
             .qwen36_35BA3B_DWQ4Bit:
            "Qwen 3.6"
        case .qwen3_4B4Bit, .qwen3_8B4Bit, .qwen3_4BThinking25074Bit:
            "Qwen 3"
        case .qwen3CoderNext4Bit, .qwen3Coder30BA3B4Bit:
            "Qwen 3 Coder"
        case .localAgent43_36B4Bit, .localAgent43_36B3Bit:
            "LocalAgent 4.3"
        case .gemma4_2B4Bit, .gemma4_4B4Bit,
             .gemma4_27BA4B4Bit, .gemma4_31BJANG:
            "Gemma 4"
        case .qwopus27Bv3, .qwopusMoE35BA3B:
            "Qwopus"
        case .deepseekR1Distill7B:
            "DeepSeek R1"
        case .qwqFlagship32B4Bit:
            "QwQ"
        case .qwen25Coder7B:
            "Qwen Coder"
        case .bonsai4B2Bit, .bonsai8B2Bit:
            "Ternary Bonsai"
        case .llama32_3BInstruct4Bit:
            "Llama 3.2"
        case .smolLM3_3B4Bit:
            "SmolLM3"
        case .devstralSmall2505_4Bit:
            "Devstral"
        case .mistralSmall31_24B4Bit:
            "Mistral"
        case .gemma3_4BQAT4Bit, .gemma3_27BQAT4Bit:
            "Gemma 3"
        case .llama4Scout17B16E4Bit:
            "Llama 4"
        case .lfm25_350M, .lfm25_1BInstruct, .lfm25_1BThinking, .lfm25_VL1B, .lfm25_Audio1B:
            "LFM2.5"
        case .lfm2_2B4Bit, .lfm2_8BA1B3Bit, .lfm2_24BA2B4Bit:
            "LFM2"
        case .mamba2_2B4Bit:
            "Mamba2"
        case .jamba3B:
            "Jamba"
        case .falconH1_1B4Bit, .falconH1R_7B4Bit:
            "FalconH1"
        }
    }

    /// Whether this model uses SSM (State Space Model) architecture.
    /// SSM models have fixed-size hidden state (not KV cache) enabling
    /// infinite context with constant memory. Used as the "Neocortex" layer.
    var isSSM: Bool {
        switch self {
        case .lfm25_350M, .lfm25_1BInstruct, .lfm25_1BThinking, .lfm25_VL1B, .lfm25_Audio1B,
             .lfm2_2B4Bit, .lfm2_8BA1B3Bit, .lfm2_24BA2B4Bit,
             .mamba2_2B4Bit, .jamba3B,
             .falconH1_1B4Bit, .falconH1R_7B4Bit:
            true
        default:
            false
        }
    }

    var minimumRecommendedMemoryGB: Int {
        switch self {
        case .qwen35_0_8B4Bit, .gemma4_2B4Bit, .falconH1_1B4Bit,
             .lfm25_350M, .lfm25_1BInstruct, .lfm25_1BThinking, .lfm25_VL1B, .lfm25_Audio1B: 8
        case .qwen35_2B4Bit, .lfm2_2B4Bit, .mamba2_2B4Bit: 8
        case .qwen35_4B4Bit, .gemma4_4B4Bit, .qwen3_4B4Bit,
             .qwen3_4BThinking25074Bit, .llama32_3BInstruct4Bit,
             .smolLM3_3B4Bit, .bonsai4B2Bit, .bonsai8B2Bit,
             .gemma3_4BQAT4Bit: 8
        // Realistic working set for a 4-bit 7B is ~6 GB (3.5 GB weights + 1 GB
        // KV at 8K ctx + ~1 GB buffers). 12 GB gives 2× headroom and lets
        // a 16 GB Mac load DeepSeek R1 with ~6 GB free instead of requiring
        // 10 GB free. Coding 7B keeps its higher ceiling (longer contexts).
        case .deepseekR1Distill7B, .lfm2_8BA1B3Bit, .falconH1R_7B4Bit, .qwen3_8B4Bit: 12
        case .qwen25Coder7B: 16
        case .qwqFlagship32B4Bit: 24
        case .qwen35_9B4Bit, .jamba3B: 18
        case .lfm2_24BA2B4Bit: 24
        case .gemma4_27BA4B4Bit, .gemma4_31BJANG: 18
        case .qwen36_35BA3B4Bit,
             .qwen36_35BA3B_Unsloth4Bit,
             .qwen36_35BA3B_DWQ4Bit: 24
        case .qwen3CoderNext4Bit: 12
        case .qwen3Coder30BA3B4Bit: 24
        case .localAgent43_36B4Bit: 24
        case .localAgent43_36B3Bit: 18
        case .qwopus27Bv3, .devstralSmall2505_4Bit,
             .mistralSmall31_24B4Bit, .gemma3_27BQAT4Bit: 24
        case .qwen35_27B4Bit: 48
        case .qwen35_35BA3B4Bit: 18
        case .qwopusMoE35BA3B, .llama4Scout17B16E4Bit: 24
        }
    }

    /// Estimated weight memory in GB at this catalog entry's quantization.
    /// For 4-bit models: ≈ params × 0.5 GB (the canonical Epistemos quant).
    /// For 3-bit / 2-bit / bf16 catalog variants the value reflects the
    /// actual quant footprint (3-bit ≈ params × 0.375, 2-bit ≈ params ×
    /// 0.25, bf16 ≈ params × 2).
    ///
    /// Used by the D4 faculty-roster memory-budget arithmetic to keep the
    /// default local agent fitting the 16 GB Mac realistic 11 GB working
    /// budget (weights + KV cache + app overhead). Per
    /// `docs/CANONICAL_AUDIT_LOG.md` Blocker D4: prior default LocalAgent 4.3
    /// 36B at 4-bit ≈ 18 GB resident exceeds the 16 GB hardware ceiling;
    /// `LocalModelCatalog.fallbackPrimaryAgentModel` (Qwen 3 8B 4-bit ≈
    /// 4 GB) keeps the working set inside the budget.
    var estimated4BitWeightsGB: Double {
        switch self {
        // 4-bit dense
        case .qwen35_0_8B4Bit: 0.4
        case .qwen35_2B4Bit, .lfm2_2B4Bit, .mamba2_2B4Bit: 1.0
        case .gemma4_2B4Bit, .falconH1_1B4Bit, .lfm25_350M,
             .lfm25_1BInstruct, .lfm25_1BThinking, .lfm25_VL1B, .lfm25_Audio1B,
             .llama32_3BInstruct4Bit, .smolLM3_3B4Bit: 1.5
        case .qwen35_4B4Bit, .qwen3_4B4Bit, .qwen3_4BThinking25074Bit,
             .gemma4_4B4Bit, .gemma3_4BQAT4Bit: 2.0
        case .qwen3CoderNext4Bit: 4.0
        case .deepseekR1Distill7B, .qwen25Coder7B,
             .falconH1R_7B4Bit, .qwen3_8B4Bit: 4.0
        case .qwen35_9B4Bit: 4.5
        case .devstralSmall2505_4Bit: 11.5
        case .mistralSmall31_24B4Bit: 12.0
        case .qwen35_27B4Bit, .gemma3_27BQAT4Bit, .qwopus27Bv3: 13.5
        case .qwqFlagship32B4Bit: 16.0
        case .localAgent43_36B4Bit: 18.0

        // 4-bit MoE — total params × 0.5 (all weights resident; active
        // experts smaller per token but full footprint in memory)
        case .qwen35_35BA3B4Bit, .qwen36_35BA3B4Bit,
             .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
             .qwopusMoE35BA3B: 17.5
        case .gemma4_27BA4B4Bit: 13.5
        case .qwen3Coder30BA3B4Bit: 15.0
        case .gemma4_31BJANG: 15.5
        case .lfm2_24BA2B4Bit: 12.0
        case .llama4Scout17B16E4Bit: 8.5

        // 3-bit (params × 0.375)
        case .localAgent43_36B3Bit: 13.5
        case .lfm2_8BA1B3Bit: 3.0

        // 2-bit (params × 0.25)
        case .bonsai4B2Bit: 1.0
        case .bonsai8B2Bit: 2.0

        // bf16 (params × 2)
        case .jamba3B: 6.0
        }
    }

    var minimumRecommendedInteractiveMemoryGB: Int {
        switch self {
        case .qwen25Coder7B:
            24
        case .qwen35_35BA3B4Bit:
            24
        case .qwen36_35BA3B4Bit,
             .qwen36_35BA3B_Unsloth4Bit,
             .qwen36_35BA3B_DWQ4Bit:
            32
        case .qwen3Coder30BA3B4Bit:
            32
        case .localAgent43_36B4Bit:
            32
        case .localAgent43_36B3Bit:
            24
        default:
            minimumRecommendedMemoryGB
        }
    }

    nonisolated static var ascendingBySize: [LocalTextModelID] {
        allCases.sorted { lhs, rhs in
            if lhs.minimumRecommendedMemoryGB == rhs.minimumRecommendedMemoryGB {
                let lhsIndex = allCases.firstIndex(of: lhs) ?? 0
                let rhsIndex = allCases.firstIndex(of: rhs) ?? 0
                return lhsIndex < rhsIndex
            }
            return lhs.minimumRecommendedMemoryGB < rhs.minimumRecommendedMemoryGB
        }
    }

    var supportsThinkingMode: Bool {
        switch self {
        case .qwen35_27B4Bit, .qwen35_35BA3B4Bit, .qwen36_35BA3B4Bit,
             .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
             .gemma4_27BA4B4Bit, .gemma4_31BJANG,
             .lfm25_1BThinking, .jamba3B,
             .qwopus27Bv3, .qwopusMoE35BA3B,
             .deepseekR1Distill7B, .qwen3_8B4Bit, .qwen3_4BThinking25074Bit,
             .qwqFlagship32B4Bit,
             .localAgent43_36B4Bit, .localAgent43_36B3Bit:
            true
        default:
            false
        }
    }

    /// Some local families expose "thinking" as an always-on behavior in
    /// the runtime/template path Epistemos currently uses. Fast mode must
    /// not auto-route to them until a real disable switch exists.
    var cannotDisableThinkingInFast: Bool {
        switch self {
        case .deepseekR1Distill7B,
             .qwen3_4BThinking25074Bit,
             .qwopus27Bv3, .qwopusMoE35BA3B,
             .qwen25Coder7B:
            true
        default:
            false
        }
    }

    var canActAsAgent: Bool {
        // RCA-LOCAL-AGENT-GRAMMAR-001 (2026-05-14): Gemma 3 / Gemma 4
        // and Mistral families REMOVED from the canActAsAgent list.
        // The Hermes-style `<tool_call>` XML grammar this app uses is
        // a Qwen / Hermes / DeepSeek-distill convention; Gemma family
        // models emit malformed output (e.g. `xml\`\`\`xml <tool_response`)
        // when asked to call tools through that grammar — observed on
        // gemma3_4BQAT4Bit per user 2026-05-14 screenshot. Until we
        // wire Gemma-family-specific tool-call grammars (Gemma uses a
        // different convention — function-call JSON inside the natural
        // assistant turn, not `<tool_call>` XML), the router escalates
        // these to Qwen (local) or to the cloud agent loop when an
        // agent-intent query lands. Mistral family same rationale.
        //
        // To re-enable a model here: prove its tool-call grammar is
        // honored by MLXStructured strict masking OR document a working
        // soft-guidance template in LocalToolGrammar.swift, then add a
        // source-guard test that exercises a `vault.write` round-trip
        // for the model and confirms the tool_call is parsed correctly.
        switch self {
        case .qwen35_4B4Bit, .qwen35_9B4Bit, .qwen35_27B4Bit, .qwen35_35BA3B4Bit,
             .qwen36_35BA3B4Bit, .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
             .qwen3_4B4Bit, .qwen3_8B4Bit,
             .qwen3CoderNext4Bit, .qwen3Coder30BA3B4Bit,
             .localAgent43_36B4Bit, .localAgent43_36B3Bit,
             .qwopus27Bv3, .qwopusMoE35BA3B,
             .deepseekR1Distill7B, .qwqFlagship32B4Bit, .qwen25Coder7B,
             .llama4Scout17B16E4Bit,
             .lfm2_2B4Bit,
             .lfm2_8BA1B3Bit, .lfm2_24BA2B4Bit,
             .jamba3B, .falconH1R_7B4Bit:
            true
        // Gemma 3/4 family + Mistral family: parked until grammar
        // support lands. They remain great for Fast/Thinking direct-
        // stream chat — just not exposed as agent-tier tool callers.
        case .gemma4_4B4Bit, .gemma4_27BA4B4Bit, .gemma4_31BJANG,
             .gemma3_4BQAT4Bit, .gemma3_27BQAT4Bit,
             .devstralSmall2505_4Bit, .mistralSmall31_24B4Bit:
            false
        default:
            false
        }
    }

    /// Actual local agent-loop execution capability.
    /// This stays broader than `supportsAgentMode` because the local runtime
    /// can still execute tool plans through the soft-guidance fallback when
    /// true constrained decoding packages are not linked into the app target.
    var canRunLocalAgentLoop: Bool {
        canActAsAgent && LocalToolGrammar.supportsLocalAgentLoop
    }

    /// User-visible agent mode exposure for the regular chat picker.
    /// The UI remains conservative and only advertises agent mode when the
    /// strict structured-decoding stack is available in this build target.
    var supportsAgentMode: Bool {
        canActAsAgent && LocalToolGrammar.supportsStructuredToolCalling
    }

    /// Master Fusion Plan §B.4 / "Brief Is Better" doctrine — the per-model
    /// soft cap on the `<think>...</think>` reasoning block in tokens.
    /// `0` means "no cap; emit unbounded reasoning".
    ///
    /// Doctrine: small models (≤4B) get a tight cap because they wander when
    /// allowed to reason for long; mid models (7-9B) get a moderate cap;
    /// MoE / large dense models get the canonical doctrine default 256. The
    /// `~32 for Qwen 7B` literal value in the audit text is the floor for
    /// the smallest agent-tier coder; everything below it has even tighter
    /// caps per the Brief-Is-Better study.
    ///
    /// Wiring status today: this method is the **doctrine surface**. Live
    /// enforcement at GBNF compile is deferred — MLXStructured's
    /// `AnyTextFormat()` does not currently expose a maxLength parameter, so
    /// the cap is enforced at a higher layer (post-decode token-budget
    /// trimming in the agent loop) until either (a) MLXStructured grows a
    /// bounded-text format OR (b) we ship a small post-decode reasoning
    /// trimmer. Either way, callers that need the cap NOW can read it
    /// from this method; the test suite pins the values so a future
    /// refactor that erodes the doctrine fails CI.
    ///
    /// See:
    /// - `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §B.4
    /// - `docs/fusion/jordan's research/deterministicapp.md` §1 (Brief Is Better)
    var reasoningTokenCap: Int {
        switch self {
        // Tiny (≤2B): tightest cap. These reason in chains-of-thought that
        // drift quickly; force concise reasoning.
        case .qwen35_0_8B4Bit, .qwen35_2B4Bit,
             .lfm25_350M, .lfm25_1BInstruct, .lfm25_1BThinking,
             .lfm25_VL1B, .lfm25_Audio1B,
             .lfm2_2B4Bit, .mamba2_2B4Bit, .falconH1_1B4Bit:
            return 16

        // Small (3-4B): "Brief Is Better" canonical floor — 32 tokens.
        // Includes Gemma 4 4B, Qwen 3 4B, Qwen 3.5 4B, DeepSeek-R1-Distill
        // smaller variants, Llama 3.2 3B, SmolLM3, gemma 3 4B QAT.
        case .qwen35_4B4Bit, .qwen3_4B4Bit, .qwen3_4BThinking25074Bit,
             .gemma4_2B4Bit, .gemma4_4B4Bit, .gemma3_4BQAT4Bit,
             .llama32_3BInstruct4Bit, .smolLM3_3B4Bit, .jamba3B,
             .bonsai4B2Bit:
            return 32

        // Mid (7-9B): moderate cap. Qwen 3 8B + Qwen 3.5 9B + Falcon-H1R
        // 7B + DeepSeek-R1-Distill-Qwen-7B + Devstral.
        case .qwen35_9B4Bit, .qwen3_8B4Bit,
             .falconH1R_7B4Bit, .deepseekR1Distill7B,
             .qwen25Coder7B, .bonsai8B2Bit,
             .devstralSmall2505_4Bit:
            return 64

        // Larger dense + MoE coding/agentic models: canonical doctrine
        // default 256 tokens. These have the headroom to reason at length
        // without drifting; the cap exists to prevent runaway thinking
        // chains, not to throttle them.
        case .qwen35_27B4Bit,
             .qwen35_35BA3B4Bit, .qwen36_35BA3B4Bit,
             .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
             .qwen3CoderNext4Bit, .qwen3Coder30BA3B4Bit,
             .localAgent43_36B4Bit, .localAgent43_36B3Bit,
             .qwopus27Bv3, .qwopusMoE35BA3B,
             .qwqFlagship32B4Bit, .llama4Scout17B16E4Bit,
             .lfm2_8BA1B3Bit, .lfm2_24BA2B4Bit,
             .gemma4_27BA4B4Bit, .gemma4_31BJANG,
             .gemma3_27BQAT4Bit, .mistralSmall31_24B4Bit:
            return 256
        }
    }

    var isExperimentalForEpistemos: Bool {
        switch self {
        case .lfm25_350M, .lfm25_1BInstruct, .lfm25_1BThinking,
             .lfm25_VL1B, .lfm25_Audio1B,
             .lfm2_2B4Bit, .lfm2_8BA1B3Bit, .lfm2_24BA2B4Bit,
             .mamba2_2B4Bit, .jamba3B,
             .falconH1_1B4Bit, .falconH1R_7B4Bit:
            true
        default:
            false
        }
    }

    var isEpistemosShippedLocalModel: Bool {
        switch self {
        // Current shipping stack (2026-04-18 refresh).
        // Fast local: Qwen3-4B official, Bonsai fallback.
        case .qwen3_4B4Bit,
             .qwen3_8B4Bit,
             .qwen3_4BThinking25074Bit,
             .llama32_3BInstruct4Bit,
             .gemma3_4BQAT4Bit,
             .bonsai4B2Bit,
             .bonsai8B2Bit,
             // Reasoning local (DeepSeek R1 7B + QwQ 32B flagship).
             .deepseekR1Distill7B,
             .qwqFlagship32B4Bit,
             // Coding local (Qwen 3 gen + legacy).
             .qwen3CoderNext4Bit,
             .qwen3Coder30BA3B4Bit,
             .qwen25Coder7B,
             // Function-calling local.
             .localAgent43_36B4Bit,
             .localAgent43_36B3Bit,
             // Flagship local (Qwen 3.6 35B A3B — two upgraded quants).
             .qwen36_35BA3B_Unsloth4Bit,
             .qwen36_35BA3B_DWQ4Bit,
             // Legacy plain 4-bit Qwen 3.6 kept shippable so existing
             // installs still resolve; new installs prefer UD/DWQ via
             // TriageService preferredOrder.
             .qwen36_35BA3B4Bit,
             // Gemma 4 tiers — installable. The dense E4B tier now loads via
             // the native Apple MLX port (Gemma4Text.swift); the 26B-A4B MoE
             // tier stays triage-excluded because the Swift port is dense-only.
             .gemma4_4B4Bit,
             .gemma4_27BA4B4Bit:
            true
        default:
            false
        }
    }

    var isReleaseValidatedForLocalAgentLoop: Bool {
        !isExperimentalForEpistemos
    }

    var isReleaseValidatedForInteractiveChat: Bool {
        switch self {
        case .qwen35_4B4Bit, .qwen35_9B4Bit, .qwen25Coder7B:
            false
        // The MLX Gemma 4 enum tiers are NOT chat-selectable: the MLX/Swift
        // loader does not decode `gemma4` (selecting one errors at runtime with
        // "Unsupported model type: gemma4" — verified on-device 2026-06-16), so
        // the dense E2B/E4B MLX repos stay hidden, and 26B-A4B (MoE, dense-only
        // port can't run it) + 31B-JANG (unverified third-party, oversized) stay
        // out too. The RUNNABLE Gemma 4 is the separate GGUF llama-cli lane
        // (descriptor ids `google/gemma-4-…-gguf`), surfaced via
        // supportedAvailableGemmaQATRuntimeCandidates — NOT these enum ids.
        case .gemma4_2B4Bit, .gemma4_4B4Bit, .gemma4_27BA4B4Bit, .gemma4_31BJANG:
            false
        default:
            !isExperimentalForEpistemos
        }
    }

    /// True while a model's weights are installable but its Swift MLX
    /// decoder isn't ported yet. Callers (picker, triage, startup
    /// migration) should treat these as "not runnable today" so the user
    /// never hits the raw "Unsupported model type" error.
    var isAwaitingSwiftRuntimeLoader: Bool {
        switch self {
        // The whole Gemma 4 MLX family is awaiting a working Swift loader: the
        // mlx-swift-lm decoder does NOT support `gemma4` (selecting a dense
        // E2B/E4B MLX tier errors at runtime with "Unsupported model type:
        // gemma4", verified on-device 2026-06-16), the 26B-A4B MoE tier has no
        // dense-only Swift path, and 31B-JANG is unverified + oversized. The
        // runnable Gemma 4 is the separate GGUF llama-cli lane, not these MLX
        // enum ids — so treat ALL of them as "not runnable today" so the user
        // never hits the raw load error from the picker.
        case .gemma4_2B4Bit, .gemma4_4B4Bit, .gemma4_27BA4B4Bit, .gemma4_31BJANG:
            true
        default:
            false
        }
    }

    /// True for models that are fully selectable when the user *explicitly*
    /// pins them, but must never be chosen by *automatic* local routing.
    /// The triage engine keeps the validated automatic default on the Qwen
    /// stack; Gemma 4 is a deliberate user choice, not a silent fallback.
    ///
    /// This is the honest-capability-gating backstop that survives the runtime
    /// becoming available: the dense E2B/E4B tiers now run (native Apple MLX
    /// port + GGUF llama-cli lane), so `isAwaitingSwiftRuntimeLoader` is no
    /// longer false-for-the-right-reason for them. Without this explicit
    /// hold-out, flipping the loader flag would let Gemma 4 leak into the
    /// last-resort automatic fallback — exactly the "never silently swap the
    /// user's route to Gemma" rule the routing source guards defend. Gemma 3
    /// is intentionally NOT held out (it has a stable loader and stays in the
    /// automatic preferredOrder for pro/fast work).
    var isHeldOutOfAutomaticLocalRouting: Bool {
        switch self {
        case .gemma4_2B4Bit, .gemma4_4B4Bit,
             .gemma4_27BA4B4Bit, .gemma4_31BJANG:
            true
        default:
            false
        }
    }

    var releasePickerVisibilityReason: String? {
        if isAwaitingSwiftRuntimeLoader {
            return "Hidden from the release picker: this Gemma 4 MLX tier has no runnable Swift loader. The mlx-swift-lm decoder does not support `gemma4` (selecting a dense E2B/E4B MLX tier errors with \"Unsupported model type: gemma4\" at runtime); 26B-A4B is Mixture-of-Experts (no dense-only Swift path) and 31B-JANG is unverified + oversized. Weights install fine but loading one would fail at runtime. The runnable Gemma 4 is the separate GGUF llama-cli lane, not these MLX repos."
        }
        if isExperimentalForEpistemos {
            switch self {
            case .mamba2_2B4Bit:
                return "Hidden from the release chat picker because the installed MLX artifact has no chat template, the April 9 Mamba-only live sweep rerun corrupted its result bundle, and interactive chat is not release-validated yet."
            case .lfm25_350M, .lfm25_1BInstruct, .lfm25_1BThinking,
                 .lfm25_VL1B, .lfm25_Audio1B,
                 .lfm2_2B4Bit, .lfm2_8BA1B3Bit, .lfm2_24BA2B4Bit,
                 .jamba3B, .falconH1_1B4Bit, .falconH1R_7B4Bit:
                return "Hidden from the release picker and agent picker until the Epistemos local-tool path is stable on this family. These SSM tiers remain installable for advanced testing, but they are not promoted for normal chat yet."
            default:
                break
            }
        }

        switch self {
        case .qwen35_4B4Bit:
            return "Hidden from the release chat picker after the April 8 live sweep failed long-context grounding."
        case .qwen35_9B4Bit:
            return "Hidden from the release chat picker after the April 8 live sweep failed long-context grounding."
        case .qwen25Coder7B:
            return "Hidden from the release chat picker until the cold-load freeze path is fully verified. Qwen 3 Coder Next is the validated shipping coder tier."
        default:
            return nil
        }
    }

    // MARK: - Per-Model Native Capabilities
    // Ensures each model is utilized to its full potential — context windows,
    // vision, tool calling, optimal generation parameters, KV cache sizing.
    // Based on research: Gemma 4, Qwopus, Qwen 3.5, DeepSeek R1 specs.

    /// Maximum context window in tokens — actual architecture spec per model.
    /// Sources: Gemma 4 model card, Qwen 3.5 Unsloth docs, DeepSeek R1 HF card.
    var maxContextTokens: Int {
        switch self {
        // Gemma 4: all variants support 128K-256K (model card: 256K with p-RoPE)
        case .gemma4_2B4Bit: 128_000       // E2B: 128K (model card)
        case .gemma4_4B4Bit: 128_000       // E4B: 128K
        case .gemma4_27BA4B4Bit: 256_000   // 26B A4B: 256K
        case .gemma4_31BJANG: 256_000      // 31B JANG: 256K
        // Qwen 3.5: ALL variants support 262K (Unsloth docs, architecture spec)
        case .qwen35_0_8B4Bit: 262_144
        case .qwen35_2B4Bit: 262_144
        case .qwen35_4B4Bit: 262_144
        case .qwen35_9B4Bit: 262_144
        case .qwen35_27B4Bit: 262_144
        case .qwen35_35BA3B4Bit: 262_144
        case .qwen36_35BA3B4Bit: 262_144
        case .qwen36_35BA3B_Unsloth4Bit: 262_144
        case .qwen36_35BA3B_DWQ4Bit: 262_144
        // Qwen 3 4B (official): 128K
        case .qwen3_4B4Bit: 128_000
        case .qwen3_8B4Bit: 128_000
        case .qwen3_4BThinking25074Bit: 32_768
        // Qwen 3 Coder: 128K+ (architecture spec)
        case .qwen3CoderNext4Bit: 128_000
        case .qwen3Coder30BA3B4Bit: 262_144
        // LocalAgent 4.3 36B: Llama-3 chat format, ~128K context from base model
        case .localAgent43_36B4Bit: 131_072
        case .localAgent43_36B3Bit: 131_072
        // Qwopus: Qwen 3.5 base → 262K / MoE → 131K
        case .qwopus27Bv3: 262_144
        case .qwopusMoE35BA3B: 131_072
        // Specialists
        case .deepseekR1Distill7B: 128_000   // DeepSeek R1 HF card: 128K
        case .qwqFlagship32B4Bit: 131_072   // QwQ 32B: Qwen2 base → 131K
        case .qwen25Coder7B: 131_072         // Qwen 2.5 Coder: 131K
        case .bonsai4B2Bit: 32_768
        case .bonsai8B2Bit: 65_536
        // Others
        case .llama32_3BInstruct4Bit: 128_000 // Llama 3.2 3B: 128K
        case .smolLM3_3B4Bit: 128_000        // SmolLM3: 128K (with YaRN)
        case .devstralSmall2505_4Bit: 256_000 // Devstral: 256K
        case .mistralSmall31_24B4Bit: 128_000 // Mistral Small 3.1: 128K
        case .gemma3_4BQAT4Bit: 131_072
        case .gemma3_27BQAT4Bit: 131_072
        case .llama4Scout17B16E4Bit: 131_072
        // SSM / State Space Models — context is theoretically infinite (fixed state)
        // but practical limits depend on training data and positional encoding
        case .lfm25_350M: 128_000                           // LFM2.5 350M: 128K
        case .lfm25_1BInstruct, .lfm25_1BThinking: 128_000 // LFM2.5: 128K
        case .lfm25_VL1B: 128_000                           // LFM2.5 VL: 128K
        case .lfm25_Audio1B: 32_768                         // Audio path not yet surfaced locally
        case .lfm2_2B4Bit: 128_000                          // LFM2: 128K
        case .lfm2_8BA1B3Bit: 128_000                       // LFM2 8B MoE: 128K
        case .lfm2_24BA2B4Bit: 128_000                      // LFM2 24B MoE: 128K
        case .mamba2_2B4Bit: 128_000                         // Mamba2 2.7B: long-context SSM path
        case .jamba3B: 262_144                               // Jamba: 256K
        case .falconH1_1B4Bit: 131_072                       // Falcon H1 1.5B Instruct: 128K
        case .falconH1R_7B4Bit: 262_144                      // Falcon H1R 7B: 256K
        }
    }

    /// Whether the model natively supports vision (image/video input).
    var supportsVision: Bool {
        switch self {
        case .gemma4_2B4Bit, .gemma4_4B4Bit:
            // The Gemma 4 architecture is multimodal, but the vendored Apple Swift
            // port (Gemma4Text @ e3cb1e1b) is DENSE TEXT-ONLY and is registered in
            // LLMModelFactory — NOT VLMModelFactory. Advertising vision here routed
            // these dense tiers to VLMModelFactory (no gemma4 loader) → crash on
            // load with "Unsupported model type: gemma4". Gate honestly to the
            // Swift runtime's actual capability so they load via LLMModelFactory.
            false
        case .gemma4_27BA4B4Bit, .gemma4_31BJANG:
            true  // multimodal architecture; gated off by isAwaitingSwiftRuntimeLoader (no runnable Swift loader)
        case .lfm25_VL1B:
            true  // LFM2.5 Vision-Language
        case .gemma3_4BQAT4Bit, .gemma3_27BQAT4Bit:
            true  // Gemma 3 is multimodal
        case .llama4Scout17B16E4Bit:
            true  // Llama 4 Scout supports images
        default:
            false // Qwen, Qwopus, DeepSeek, SmolLM, Mistral, Devstral = text only
        }
    }

    /// Whether the model can reliably produce structured tool calls (JSON function calling).
    /// This is distinct from canActAsAgent — agent mode uses text-based tool descriptions,
    /// while this flag indicates native JSON tool call output parsing.
    var supportsNativeToolCalling: Bool {
        switch self {
        case .qwopus27Bv3, .qwopusMoE35BA3B:
            true  // Trained with RL specifically for tool calling
        case .gemma4_27BA4B4Bit, .gemma4_31BJANG:
            true  // Gemma 4 supports native JSON tool use
        case .qwen35_27B4Bit, .qwen35_35BA3B4Bit,
             .qwen36_35BA3B4Bit, .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
             .qwen3_4B4Bit, .qwen3_8B4Bit,
             .qwen3CoderNext4Bit, .qwen3Coder30BA3B4Bit,
             .localAgent43_36B4Bit, .localAgent43_36B3Bit:
            true  // Qwen/LocalAgent families here are validated for structured tool output
        case .devstralSmall2505_4Bit:
            true  // Devstral designed for coding + tool use
        case .qwen25Coder7B:
            true  // Qwen Coder supports function calling
        case .lfm2_8BA1B3Bit, .lfm2_24BA2B4Bit:
            true  // LFM2 has native tool call format (.lfm2)
        case .jamba3B:
            true  // Jamba supports structured tool calling
        default:
            false // Small models lack reliable tool call formatting
        }
    }

    /// File types this model can process natively.
    /// Vision models handle images; all models handle text, CSV, and PDF.
    var supportedFileTypes: Set<AttachmentType> {
        supportsVision ? [.text, .csv, .pdf, .image] : [.text, .csv, .pdf]
    }

    /// Optimal temperature for FAST (non-thinking) mode.
    /// Sources: Gemma 4 model card (trained at 1.0), Qwen 3.5 spec (0.7),
    /// DeepSeek R1 card (0.6), Devstral/Mistral (0.4 for code).
    var optimalTemperature: Float {
        switch self {
        // Gemma 4: trained at temp=1.0 (official model card spec)
        case .gemma4_2B4Bit, .gemma4_4B4Bit,
             .gemma4_27BA4B4Bit, .gemma4_31BJANG:
            1.0
        // Qwen 3.5: official spec recommends 0.7 for fast mode
        case .qwen35_0_8B4Bit, .qwen35_2B4Bit, .qwen35_4B4Bit,
             .qwen35_9B4Bit, .qwen35_27B4Bit, .qwen35_35BA3B4Bit:
            0.7
        case .qwen36_35BA3B4Bit,
             .qwen36_35BA3B_Unsloth4Bit,
             .qwen36_35BA3B_DWQ4Bit:
            0.7
        // Qwen 3 family — 0.7 is Qwen's recommendation across generations.
        case .qwen3_4B4Bit,
             .qwen3_8B4Bit,
             .qwen3_4BThinking25074Bit,
             .qwen3CoderNext4Bit,
             .qwen3Coder30BA3B4Bit:
            0.7
        // LocalAgent 4.3 — Llama-3 chat base, 0.7 is Nous Research's recommended
        // default for instruction following and tool calling.
        case .localAgent43_36B4Bit, .localAgent43_36B3Bit:
            0.7
        // Qwopus: Qwen base, 0.7 for instruction following
        case .qwopus27Bv3, .qwopusMoE35BA3B:
            0.7
        // DeepSeek R1: 0.6 in fast mode (HF card recommendation)
        case .deepseekR1Distill7B:
            0.6
        case .qwqFlagship32B4Bit:
            0.6   // QwQ: Qwen team recommendation
        // Code models: low temp for correct code
        case .qwen25Coder7B:
            0.4
        case .bonsai4B2Bit, .bonsai8B2Bit:
            0.7
        case .llama32_3BInstruct4Bit, .devstralSmall2505_4Bit, .mistralSmall31_24B4Bit:
            0.4
        // SmolLM3: moderate
        case .smolLM3_3B4Bit:
            0.7
        // Others
        case .gemma3_4BQAT4Bit, .gemma3_27BQAT4Bit:
            0.7
        case .llama4Scout17B16E4Bit:
            0.6
        // SSM models: Liquid AI recommends 0.7, Mamba2/Falcon similar
        case .lfm25_350M, .lfm25_1BInstruct, .lfm25_VL1B, .lfm25_Audio1B: 0.7  // LFM2.5 fast mode
        case .lfm25_1BThinking: 0.6                         // LFM2.5 thinking variant: slightly lower
        case .lfm2_2B4Bit, .lfm2_8BA1B3Bit, .lfm2_24BA2B4Bit: 0.7  // LFM2 family
        case .mamba2_2B4Bit: 0.8                             // Mamba2: Cartesia default
        case .jamba3B: 0.7                                   // Jamba: AI21 default
        case .falconH1_1B4Bit, .falconH1R_7B4Bit: 0.7       // FalconH1: TII default
        }
    }

    /// Optimal temperature for THINKING mode. Nil if model doesn't support thinking.
    /// Qwen 3.5 spec: thinking temp = 0.0 (greedy). DeepSeek R1: 0.1.
    var thinkingTemperature: Float? {
        switch self {
        case .qwen35_4B4Bit, .qwen35_9B4Bit, .qwen35_27B4Bit, .qwen35_35BA3B4Bit:
            0.0   // Qwen 3.5 official: temp=0.0 for thinking mode
        case .qwen36_35BA3B4Bit:
            1.0   // Qwen 3.6 model card recommends temp=1.0 for general thinking
        case .qwen3_8B4Bit, .qwen3_4BThinking25074Bit:
            0.6   // Qwen 3 thinking checkpoints and /think mode prefer a slightly lower temp
        case .qwopus27Bv3, .qwopusMoE35BA3B:
            0.0   // Qwopus inherits Qwen thinking behavior
        case .deepseekR1Distill7B:
            0.1   // DeepSeek R1: very low but not greedy (HF card)
        case .qwqFlagship32B4Bit:
            0.6   // QwQ 32B model card: thinking temp 0.6, top_p 0.95
        case .gemma4_27BA4B4Bit, .gemma4_31BJANG:
            1.0   // Gemma 4: trained at temp=1.0, thinking uses same (model card)
        case .lfm25_1BThinking:
            0.6   // LFM2.5 Thinking: optimized for CoT (Liquid AI docs)
        default:
            nil   // No thinking mode
        }
    }

    /// Optimal top-p for this model.
    var optimalTopP: Float {
        switch self {
        case .qwen36_35BA3B4Bit:
            0.80
        case .qwopus27Bv3, .qwopusMoE35BA3B:
            0.90
        case .deepseekR1Distill7B, .qwen25Coder7B:
            0.85
        case .qwqFlagship32B4Bit:
            0.95   // QwQ 32B model card: top_p 0.95 for thinking
        case .devstralSmall2505_4Bit, .mistralSmall31_24B4Bit:
            0.90
        default:
            0.95
        }
    }

    /// Optimal top-k for this model (0 = disabled).
    var optimalTopK: Int {
        switch self {
        case .qwen36_35BA3B4Bit, .qwopus27Bv3, .qwopusMoE35BA3B:
            20
        default:
            0
        }
    }

    /// Whether thinking mode loop detection should be enabled.
    /// Small/MoE thinking models are most prone to repetition loops.
    var requiresThinkingLoopGuard: Bool {
        switch self {
        case .qwen35_4B4Bit:         true  // Small thinking model, loop-prone
        case .qwen3_4BThinking25074Bit: true
        case .deepseekR1Distill7B:   true  // Notorious for thinking loops
        case .qwen25Coder7B:         true  // User-reported freeze path
        case .qwopusMoE35BA3B:       true  // MoE can loop in thinking
        case .qwen35_35BA3B4Bit:     true  // MoE thinking, loop-prone
        default:                     false
        }
    }

    /// Whether this model has been abliterated (refusal-removal fine-tune).
    /// Abliterated models should NOT receive refusal-coaching system prompts.
    var isAbliterated: Bool {
        switch self {
        case .gemma4_31BJANG: true   // JANG_4M-CRACK abliteration
        default:              false
        }
    }

    /// Optimal KV cache size for this model on the target hardware.
    /// Balances VRAM usage against context capacity.
    var optimalKVCacheSize: Int {
        switch self {
        // Tiny models: can afford large KV
        case .qwen35_0_8B4Bit, .gemma4_2B4Bit:
            8_192
        case .qwen35_2B4Bit, .smolLM3_3B4Bit:
            6_144
        // Small models: moderate KV
        case .qwen35_4B4Bit, .gemma4_4B4Bit, .bonsai4B2Bit,
             .qwen3_4B4Bit, .qwen3_4BThinking25074Bit,
             .llama32_3BInstruct4Bit, .gemma3_4BQAT4Bit:
            4_096
        // Medium models: balanced KV
        case .deepseekR1Distill7B, .qwen25Coder7B, .bonsai8B2Bit, .qwen3_8B4Bit:
            3_072
        // QwQ 32B (dense reasoning flagship, 24GB class)
        case .qwqFlagship32B4Bit:
            2_048
        case .qwen35_9B4Bit:
            2_560
        // Large models: conservative KV (VRAM constrained)
        case .devstralSmall2505_4Bit, .mistralSmall31_24B4Bit:
            2_048
        case .gemma3_27BQAT4Bit:
            2_048
        case .gemma4_27BA4B4Bit:
            2_048  // MoE: 4B active = can handle more KV
        case .gemma4_31BJANG:
            1_536  // Dense 31B: very VRAM tight at 18GB
        case .qwen35_27B4Bit:
            1_536
        case .qwopus27Bv3:
            1_536
        // MoE large: sparse activation = more KV headroom
        case .qwen35_35BA3B4Bit,
             .qwen36_35BA3B4Bit, .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
             .qwen3Coder30BA3B4Bit,
             .qwopusMoE35BA3B:
            2_048
        // Qwen 3 4B / 8B and Qwen 3 Coder Next — small + native tool-calling.
        case .qwen3CoderNext4Bit:
            3_072
        // LocalAgent 4.3 36B dense (ByteDance Seed base) — moderate KV
        // headroom; 3-bit variant tightens it further.
        case .localAgent43_36B4Bit:
            2_048
        case .localAgent43_36B3Bit:
            1_536
        case .llama4Scout17B16E4Bit:
            1_024
        // SSM models: no KV cache (fixed state), but MLX still allocates a buffer
        // Use generous sizes since SSM state is tiny (~6-24MB)
        case .lfm25_350M, .lfm25_1BInstruct, .lfm25_1BThinking, .lfm25_VL1B, .lfm25_Audio1B: 8_192
        case .lfm2_2B4Bit, .mamba2_2B4Bit: 6_144
        case .falconH1_1B4Bit: 8_192
        case .lfm2_8BA1B3Bit, .falconH1R_7B4Bit: 4_096
        case .jamba3B: 4_096
        case .lfm2_24BA2B4Bit: 2_048
        }
    }

    /// Whether this model uses a Mixture of Experts architecture.
    /// MoE models are faster per token due to sparse activation.
    var isMoE: Bool {
        switch self {
        case .gemma4_27BA4B4Bit,
             .qwen35_35BA3B4Bit,
             .qwen36_35BA3B4Bit, .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
             .qwen3Coder30BA3B4Bit,
             .qwopusMoE35BA3B,
             .llama4Scout17B16E4Bit,
             .lfm2_8BA1B3Bit, .lfm2_24BA2B4Bit:  // LFM2 MoE variants
            true
        default:
            false
        }
    }

    /// Active parameters per token (for MoE models, much less than total).
    var activeParametersBillions: Float {
        switch self {
        case .qwen35_0_8B4Bit: 0.8
        case .qwen35_2B4Bit, .gemma4_2B4Bit: 2.0
        case .llama32_3BInstruct4Bit, .smolLM3_3B4Bit: 3.0
        case .qwen35_4B4Bit, .gemma4_4B4Bit, .qwen3_4B4Bit,
             .qwen3_4BThinking25074Bit, .gemma3_4BQAT4Bit: 4.0
        case .bonsai4B2Bit: 4.0
        case .deepseekR1Distill7B, .qwen25Coder7B: 7.0
        case .qwen3_8B4Bit: 8.0
        case .qwqFlagship32B4Bit: 32.0
        case .bonsai8B2Bit: 8.0
        case .qwen35_9B4Bit: 9.0
        case .gemma4_27BA4B4Bit: 4.0  // MoE: 26B total, 4B active
        case .qwen35_27B4Bit, .qwopus27Bv3: 27.0
        case .gemma4_31BJANG, .gemma3_27BQAT4Bit: 27.0
        case .devstralSmall2505_4Bit, .mistralSmall31_24B4Bit: 24.0
        case .qwen35_35BA3B4Bit,
             .qwen36_35BA3B4Bit, .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
             .qwopusMoE35BA3B: 3.0  // MoE: 35B total, 3B active
        // Qwen 3 Coder Next — small dense.
        case .qwen3CoderNext4Bit: 7.0
        // Qwen 3 Coder 30B A3B — MoE, 3B active out of 30B.
        case .qwen3Coder30BA3B4Bit: 3.0
        // LocalAgent 4.3 36B — dense, 36B active.
        case .localAgent43_36B4Bit, .localAgent43_36B3Bit: 36.0
        case .llama4Scout17B16E4Bit: 17.0
        // SSM models
        case .lfm25_350M: 0.35
        case .lfm25_1BInstruct, .lfm25_1BThinking: 1.2
        case .lfm25_VL1B: 1.6
        case .lfm25_Audio1B: 1.5
        case .lfm2_2B4Bit: 2.6
        case .lfm2_8BA1B3Bit: 1.0   // MoE: 8B total, ~1B active per token
        case .lfm2_24BA2B4Bit: 2.0  // MoE: 24B total, ~2B active per token
        case .mamba2_2B4Bit: 2.7
        case .jamba3B: 3.0
        case .falconH1_1B4Bit: 1.5
        case .falconH1R_7B4Bit: 7.0
        }
    }

    /// Best use case for this model — used for smart routing.
    var primaryUseCase: LocalModelUseCase {
        switch self {
        case .qwopus27Bv3, .qwopusMoE35BA3B,
             .qwen3CoderNext4Bit, .qwen3Coder30BA3B4Bit,
             .devstralSmall2505_4Bit:
            .coding       // Claude Opus distilled, 95.73% HumanEval
        case .qwen25Coder7B:
            .coding       // Coding specialist
        case .deepseekR1Distill7B, .qwen3_4BThinking25074Bit,
             .jamba3B, .falconH1R_7B4Bit:
            .reasoning    // DeepSeek R1 reasoning distilled
        case .qwqFlagship32B4Bit:
            .reasoning    // QwQ 32B — flagship on-device reasoner
        case .qwen36_35BA3B4Bit,
             .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
             .qwen3_8B4Bit,
             .localAgent43_36B4Bit, .localAgent43_36B3Bit,
             .gemma4_31BJANG, .mistralSmall31_24B4Bit:
            .general      // High-end local agentic/generalist tier
        case .gemma4_27BA4B4Bit,
             .gemma3_4BQAT4Bit, .gemma3_27BQAT4Bit,
             .llama4Scout17B16E4Bit, .lfm25_VL1B:
            .multimodal   // Vision + reasoning
        case .gemma4_2B4Bit, .gemma4_4B4Bit,
             .bonsai4B2Bit, .bonsai8B2Bit,
             .qwen35_0_8B4Bit, .qwen35_2B4Bit,
             .llama32_3BInstruct4Bit, .smolLM3_3B4Bit,
             .qwen3_4B4Bit, .lfm25_350M, .lfm25_1BInstruct,
             .falconH1_1B4Bit:
            .routing      // Fast intent classification
        case .lfm25_1BThinking:
            .reasoning
        default:
            .general      // General assistant
        }
    }
}

nonisolated struct LocalRuntimeHealthSnapshot: Sendable, Equatable {
    let requestedRuntimeKind: BackendRuntimeKind?
    let resolvedRuntimeKind: BackendRuntimeKind
    let executionMode: BackendExecutionMode
    let modelID: String
    let artifactID: String?
    let fallbackMode: String
    let executionPhase: String
    let timeToFirstTokenMS: Double?
    let totalDurationMS: Double
    let tokensPerSecond: Double?
    let outputTokenCount: Int
    let outputCharacterCount: Int
    let availableMemoryBytes: UInt64?
    let runtimeResourceURL: URL?
}

extension LocalRuntimeHealthSnapshot {
    init(_ profile: LocalMLXRunProfile) {
        self.init(
            requestedRuntimeKind: profile.requestedRuntimeKind,
            resolvedRuntimeKind: profile.resolvedRuntimeKind,
            executionMode: profile.executionMode,
            modelID: profile.modelID,
            artifactID: profile.artifactID,
            fallbackMode: profile.fallbackMode,
            executionPhase: profile.serialPhase,
            timeToFirstTokenMS: profile.firstTokenLatencyMS,
            totalDurationMS: profile.totalDurationMS,
            tokensPerSecond: profile.tokensPerSecond,
            outputTokenCount: profile.outputTokenCount,
            outputCharacterCount: profile.outputCharacterCount,
            availableMemoryBytes: profile.availableMemoryBytes,
            runtimeResourceURL: nil
        )
    }

    init(_ profile: LocalGGUFRunProfile) {
        self.init(
            requestedRuntimeKind: profile.requestedRuntimeKind,
            resolvedRuntimeKind: profile.resolvedRuntimeKind,
            executionMode: profile.executionMode,
            modelID: profile.modelID,
            artifactID: profile.artifactID,
            fallbackMode: profile.fallbackMode,
            executionPhase: profile.executionPhase,
            timeToFirstTokenMS: profile.firstTokenLatencyMS,
            totalDurationMS: profile.totalDurationMS,
            tokensPerSecond: profile.tokensPerSecond,
            outputTokenCount: profile.outputTokenCount,
            outputCharacterCount: profile.outputCharacterCount,
            availableMemoryBytes: profile.availableMemoryBytes,
            runtimeResourceURL: profile.modelURL
        )
    }
}

/// Use case categories for smart model routing.
nonisolated enum LocalModelUseCase: String, Sendable {
    case coding      // Code generation, debugging, refactoring
    case reasoning   // Math, logic, multi-step deduction
    case multimodal  // Vision + text tasks
    case routing     // Intent classification, quick responses
    case general     // Catch-all assistant tasks
}

/// Tool capability tiers for local agent — larger models get more tools.
/// Prevents small models from attempting complex tool chains they can't handle.
nonisolated enum LocalAgentToolTier: String, Sendable {
    case readOnly      // Vault search/read only — safe for any model
    case readWrite     // + Read-only file system + web search
    case fullAgent     // + Shell, browser, file write, computer use
}

private extension LocalAgentToolTier {
    var priority: Int {
        switch self {
        case .readOnly:
            0
        case .readWrite:
            1
        case .fullAgent:
            2
        }
    }
}

extension LocalTextModelID {
    /// What tool tier this model is capable of handling reliably.
    /// Specialist models (Coder, R1) get elevated access despite smaller size.
    var agentToolTier: LocalAgentToolTier {
        switch self {
        // Tiny models (≤2B): vault only — too small for tool chains
        case .qwen35_0_8B4Bit, .qwen35_2B4Bit, .gemma4_2B4Bit,
             .llama32_3BInstruct4Bit, .smolLM3_3B4Bit, .bonsai4B2Bit:
            .readOnly
        // Small general models (4B): vault + read
        case .qwen35_4B4Bit, .gemma4_4B4Bit, .bonsai8B2Bit,
             .qwen3_4BThinking25074Bit, .gemma3_4BQAT4Bit:
            .readWrite
        // Specialist 7B models: elevated to full agent — these are specifically
        // trained for tool calling (Coder) and reasoning (R1)
        case .qwen25Coder7B:
            .fullAgent    // Best sub-10B coding model, native tool calling
        case .deepseekR1Distill7B:
            .readWrite    // Strong reasoning but tool call JSON can be unreliable
        case .qwqFlagship32B4Bit:
            .fullAgent    // QwQ 32B: flagship reasoning with reliable tool calling
        // Medium local models: Qwen 9B gets full agent (thinking + 262K)
        case .qwen35_9B4Bit:
            .fullAgent
        // Qwen 3 4B (official, native tool-calling): full agent despite
        // size — the whole point of this tier is reliable tool use.
        case .qwen3_4B4Bit, .qwen3_8B4Bit:
            .fullAgent
        // Qwen 3 Coder (Next + 30B A3B): coding + tools, first-class.
        case .qwen3CoderNext4Bit, .qwen3Coder30BA3B4Bit:
            .fullAgent
        // LocalAgent 4.3 36B (4bit + 3bit): function-calling specialist —
        // built for tool use, full agent tier.
        case .localAgent43_36B4Bit, .localAgent43_36B3Bit:
            .fullAgent
        // Qwen 3.6 35B A3B — three quant variants, all flagship tier.
        case .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit:
            .fullAgent
        // Large models (27B+): full tool set — smart enough for shell/browser
        case .qwopus27Bv3, .qwopusMoE35BA3B,
             .gemma4_27BA4B4Bit, .gemma4_31BJANG,
             .qwen35_27B4Bit, .qwen35_35BA3B4Bit, .qwen36_35BA3B4Bit,
             .devstralSmall2505_4Bit, .mistralSmall31_24B4Bit,
             .gemma3_27BQAT4Bit, .llama4Scout17B16E4Bit:
            .fullAgent
        // SSM models: tool tier based on size and architecture
        case .lfm25_350M, .lfm25_1BInstruct, .lfm25_1BThinking, .lfm25_VL1B, .lfm25_Audio1B,
             .falconH1_1B4Bit:
            .readOnly    // Small SSMs: vault/search only
        case .lfm2_2B4Bit:
            .readWrite   // Mid SSMs: vault read/write
        case .mamba2_2B4Bit:
            .readOnly    // Custom Metal path is warmup-only in this release; keep agent loop hidden
        case .jamba3B, .falconH1R_7B4Bit,
             .lfm2_8BA1B3Bit, .lfm2_24BA2B4Bit:
            .fullAgent   // Large SSMs: full tool use
        }
    }

    /// Whether this model can use shell/bash commands.
    var canUseShell: Bool { agentToolTier == .fullAgent }

    /// Whether this model can browse the web (beyond search).
    var canUseBrowser: Bool { agentToolTier == .fullAgent }

    /// Whether this model can write files outside the vault.
    var canWriteFiles: Bool { agentToolTier == .fullAgent }
}

nonisolated enum CloudModelProvider: String, Codable, Sendable, CaseIterable {
    case openAI
    case anthropic
    case google
    case zai
    case kimi
    case minimax
    case deepseek

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .google: "Google"
        case .zai: "Z.AI / GLM"
        case .kimi: "Kimi / Moonshot"
        case .minimax: "MiniMax"
        case .deepseek: "DeepSeek"
        }
    }

    var apiKeyKeychainKey: String {
        switch self {
        case .openAI: "epistemos.openai.apiKey"
        case .anthropic: "epistemos.anthropic.apiKey"
        case .google: "epistemos.google.apiKey"
        case .zai: "epistemos.zai.apiKey"
        case .kimi: "epistemos.kimi.apiKey"
        case .minimax: "epistemos.minimax.apiKey"
        case .deepseek: "epistemos.deepseek.apiKey"
        }
    }

    var oauthKeychainKey: String {
        switch self {
        case .openAI: "epistemos.openai.oauth"
        case .anthropic: "epistemos.anthropic.oauth"
        case .google: "epistemos.google.oauth"
        case .zai: "epistemos.zai.oauth"
        case .kimi: "epistemos.kimi.oauth"
        case .minimax: "epistemos.minimax.oauth"
        case .deepseek: "epistemos.deepseek.oauth"
        }
    }

    var legacyAPIKeyKeychainKeys: [String] {
        switch self {
        case .openAI:
            ["epistemos.apiKey.openai"]
        case .anthropic:
            ["epistemos.apiKey.anthropic"]
        case .google:
            ["epistemos.apiKey.google"]
        case .zai, .kimi, .minimax, .deepseek:
            []
        }
    }

    /// Whether this cloud provider is eligible for the agent tier
    /// (main-chat-driven Rust agent_core loop with tool execution).
    /// Matches the product rule: OpenAI + Anthropic support
    /// Claude/OpenAI-shaped tool-calling well enough to ship as first-
    /// class agent drivers; Google/Z.AI/Kimi/MiniMax/DeepSeek are
    /// accepted for chat and research but not promoted to agent tier.
    /// Local models never qualify (enforced in Rust via
    /// `ProviderRuntime::Local` + `AgentError::LocalProviderNotAllowed`).
    var supportsAgentTier: Bool {
        switch self {
        case .openAI, .anthropic: true
        case .google, .zai, .kimi, .minimax, .deepseek: false
        }
    }
}

nonisolated enum AIProviderSelection: String, Codable, Sendable, CaseIterable {
    case openAI
    case anthropic
    case google
    case zai
    case kimi
    case minimax
    case deepseek
    case localOnly

    init(cloudProvider: CloudModelProvider) {
        switch cloudProvider {
        case .openAI:
            self = .openAI
        case .anthropic:
            self = .anthropic
        case .google:
            self = .google
        case .zai:
            self = .zai
        case .kimi:
            self = .kimi
        case .minimax:
            self = .minimax
        case .deepseek:
            self = .deepseek
        }
    }

    var cloudProvider: CloudModelProvider? {
        switch self {
        case .openAI:
            .openAI
        case .anthropic:
            .anthropic
        case .google:
            .google
        case .zai:
            .zai
        case .kimi:
            .kimi
        case .minimax:
            .minimax
        case .deepseek:
            .deepseek
        case .localOnly:
            nil
        }
    }

    var displayName: String {
        switch self {
        case .openAI:
            "OpenAI"
        case .anthropic:
            "Anthropic"
        case .google:
            "Google"
        case .zai:
            "Z.AI / GLM"
        case .kimi:
            "Kimi / Moonshot"
        case .minimax:
            "MiniMax"
        case .deepseek:
            "DeepSeek"
        case .localOnly:
            "Local Only"
        }
    }

    var systemImage: String {
        switch self {
        case .openAI:
            "sparkles"
        case .anthropic:
            "brain"
        case .google:
            "globe.americas.fill"
        case .zai:
            "bolt.horizontal.circle"
        case .kimi:
            "moon.stars.fill"
        case .minimax:
            "paperplane.circle.fill"
        case .deepseek:
            "water.waves"
        case .localOnly:
            "memorychip"
        }
    }

    var summary: String {
        switch self {
        case .openAI:
            "Use OpenAI as the active cloud provider with ChatGPT account access or a legacy API key while keeping local models available."
        case .anthropic:
            "Use Anthropic as the active cloud provider with Claude Code credentials or a legacy API key while keeping local models available."
        case .google:
            "Use Google Gemini as the active cloud provider with Desktop OAuth or a legacy API key while keeping local models available."
        case .zai:
            "Use Z.AI / GLM as the active cloud provider. The public API path is direct-key today, while local models remain available."
        case .kimi:
            "Use Kimi / Moonshot as the active cloud provider. The public API path is direct-key today, while local models remain available."
        case .minimax:
            "Use MiniMax as the active cloud provider. The public API path is direct-key today, while local models remain available."
        case .deepseek:
            "Use DeepSeek as the active cloud provider. The public API path is direct-key today, while local models remain available."
        case .localOnly:
            "Hide cloud models from the picker and stay on-device with Apple Intelligence plus local models."
        }
    }

    nonisolated static let preferredOrder: [AIProviderSelection] = [
        .openAI,
        .anthropic,
        .google,
        .localOnly,
    ]
}

nonisolated enum CloudTextModelID: String, Codable, Sendable, CaseIterable {
    case openAIGPT54 = "openai:gpt-5.4"
    case openAIGPT54Mini = "openai:gpt-5.4-mini"
    case openAIGPT54Nano = "openai:gpt-5.4-nano"
    case openAIGPT52 = "openai:gpt-5.2"
    case openAIGPT41 = "openai:gpt-4.1"
    case openAIGPT41Mini = "openai:gpt-4.1-mini"
    case openAIO3 = "openai:o3"
    case openAIO3Mini = "openai:o3-mini"
    case anthropicClaudeOpus47 = "anthropic:claude-opus-4-7"
    case anthropicClaudeSonnet46 = "anthropic:claude-sonnet-4-6"
    case anthropicClaudeOpus41 = "anthropic:claude-opus-4-1"
    case anthropicClaudeOpus4 = "anthropic:claude-opus-4"
    case anthropicClaudeSonnet4 = "anthropic:claude-sonnet-4"
    case anthropicClaudeSonnet37 = "anthropic:claude-3-7-sonnet"
    case anthropicClaudeHaiku35 = "anthropic:claude-3-5-haiku"
    case googleGemini25Pro = "google:gemini-2.5-pro"
    case googleGemini25Flash = "google:gemini-2.5-flash"
    case googleGemini3FlashPreview = "google:gemini-3-flash-preview"
    case googleGemini3ProPreview = "google:gemini-3-pro-preview"
    case googleGemini31ProPreview = "google:gemini-3.1-pro-preview"
    case zaiGLM5 = "zai:glm-5"
    case zaiGLM45Flash = "zai:glm-4.5-flash"
    case kimiK25 = "kimi:kimi-k2.5"
    case kimiK2Thinking = "kimi:kimi-k2-thinking"
    case kimiK2TurboPreview = "kimi:kimi-k2-turbo-preview"
    case minimaxM25 = "minimax:MiniMax-M2.5"
    case minimaxM25HighSpeed = "minimax:MiniMax-M2.5-highspeed"
    case minimaxM21 = "minimax:MiniMax-M2.1"
    case deepseekChat = "deepseek:deepseek-chat"
    case deepseekReasoner = "deepseek:deepseek-reasoner"

    var provider: CloudModelProvider {
        switch self {
        case .openAIGPT54, .openAIGPT54Mini, .openAIGPT54Nano, .openAIGPT52, .openAIGPT41,
             .openAIGPT41Mini, .openAIO3, .openAIO3Mini:
            .openAI
        case .anthropicClaudeOpus47, .anthropicClaudeSonnet46,
             .anthropicClaudeOpus41, .anthropicClaudeOpus4, .anthropicClaudeSonnet4,
             .anthropicClaudeSonnet37, .anthropicClaudeHaiku35:
            .anthropic
        case .googleGemini25Pro, .googleGemini25Flash, .googleGemini3FlashPreview,
             .googleGemini3ProPreview, .googleGemini31ProPreview:
            .google
        case .zaiGLM5, .zaiGLM45Flash:
            .zai
        case .kimiK25, .kimiK2Thinking, .kimiK2TurboPreview:
            .kimi
        case .minimaxM25, .minimaxM25HighSpeed, .minimaxM21:
            .minimax
        case .deepseekChat, .deepseekReasoner:
            .deepseek
        }
    }

    var vendorModelID: String {
        switch self {
        case .openAIGPT54: "gpt-4o"
        case .openAIGPT54Mini: "gpt-4o-mini"
        case .openAIGPT54Nano: "gpt-5.4-nano"
        case .openAIGPT52: "gpt-5.2"
        case .openAIGPT41: "gpt-4.1"
        case .openAIGPT41Mini: "gpt-4.1-mini"
        case .openAIO3: "o3"
        case .openAIO3Mini: "o3-mini"
        case .anthropicClaudeOpus47: "claude-opus-4-7"
        case .anthropicClaudeSonnet46: "claude-sonnet-4-6"
        case .anthropicClaudeOpus41: "claude-opus-4-1-20250805"
        case .anthropicClaudeOpus4: "claude-opus-4-20250514"
        case .anthropicClaudeSonnet4: "claude-sonnet-4-20250514"
        case .anthropicClaudeSonnet37: "claude-3-7-sonnet-20250219"
        case .anthropicClaudeHaiku35: "claude-3-5-haiku-latest"
        case .googleGemini25Pro: "gemini-2.5-pro"
        case .googleGemini25Flash: "gemini-2.5-flash"
        case .googleGemini3FlashPreview: "gemini-3-flash-preview"
        case .googleGemini3ProPreview: "gemini-3-pro-preview"
        case .googleGemini31ProPreview: "gemini-3.1-pro-preview"
        case .zaiGLM5: "glm-5"
        case .zaiGLM45Flash: "glm-4.5-flash"
        case .kimiK25: "kimi-k2.5"
        case .kimiK2Thinking: "kimi-k2-thinking"
        case .kimiK2TurboPreview: "kimi-k2-turbo-preview"
        case .minimaxM25: "MiniMax-M2.5"
        case .minimaxM25HighSpeed: "MiniMax-M2.5-highspeed"
        case .minimaxM21: "MiniMax-M2.1"
        case .deepseekChat: "deepseek-chat"
        case .deepseekReasoner: "deepseek-reasoner"
        }
    }

    var displayName: String {
        switch self {
        case .openAIGPT54: "GPT-4o"
        case .openAIGPT54Mini: "GPT-4o Mini"
        case .openAIGPT54Nano: "GPT-5.4 Nano"
        case .openAIGPT52: "GPT-5.2"
        case .openAIGPT41: "GPT-4.1"
        case .openAIGPT41Mini: "GPT-4.1 Mini"
        case .openAIO3: "o3"
        case .openAIO3Mini: "o3-mini"
        case .anthropicClaudeOpus47: "Claude Opus 4.7"
        case .anthropicClaudeSonnet46: "Claude Sonnet 4.6"
        case .anthropicClaudeOpus41: "Claude Opus 4.1 (Latest Opus)"
        case .anthropicClaudeOpus4: "Claude Opus 4"
        case .anthropicClaudeSonnet4: "Claude Sonnet 4 (Latest Sonnet)"
        case .anthropicClaudeSonnet37: "Claude Sonnet 3.7"
        case .anthropicClaudeHaiku35: "Claude Haiku 3.5 (Latest Haiku)"
        case .googleGemini25Pro: "Gemini 2.5 Pro"
        case .googleGemini25Flash: "Gemini 2.5 Flash"
        case .googleGemini3FlashPreview: "Gemini 3 Flash Preview"
        case .googleGemini3ProPreview: "Gemini 3 Pro Preview"
        case .googleGemini31ProPreview: "Gemini 3.1 Pro Preview"
        case .zaiGLM5: "GLM-5"
        case .zaiGLM45Flash: "GLM-4.5 Flash"
        case .kimiK25: "Kimi K2.5"
        case .kimiK2Thinking: "Kimi K2 Thinking"
        case .kimiK2TurboPreview: "Kimi K2 Turbo Preview"
        case .minimaxM25: "MiniMax M2.5"
        case .minimaxM25HighSpeed: "MiniMax M2.5 High-Speed"
        case .minimaxM21: "MiniMax M2.1"
        case .deepseekChat: "DeepSeek Chat"
        case .deepseekReasoner: "DeepSeek Reasoner"
        }
    }

    var compactDisplayName: String {
        switch self {
        case .openAIGPT54: "GPT-4o"
        case .openAIGPT54Mini: "GPT-4o Mini"
        case .openAIGPT54Nano: "GPT-5.4 Nano"
        case .openAIGPT52: "GPT-5.2"
        case .openAIGPT41: "GPT-4.1"
        case .openAIGPT41Mini: "GPT-4.1 Mini"
        case .openAIO3: "o3"
        case .openAIO3Mini: "o3-mini"
        case .anthropicClaudeOpus47: "Opus 4.7"
        case .anthropicClaudeSonnet46: "Sonnet 4.6"
        case .anthropicClaudeOpus41: "Opus 4.1"
        case .anthropicClaudeOpus4: "Opus 4"
        case .anthropicClaudeSonnet4: "Sonnet 4"
        case .anthropicClaudeSonnet37: "Sonnet 3.7"
        case .anthropicClaudeHaiku35: "Haiku 3.5"
        case .googleGemini25Pro: "Gemini 2.5 Pro"
        case .googleGemini25Flash: "Gemini 2.5 Flash"
        case .googleGemini3FlashPreview: "Gemini 3 Flash"
        case .googleGemini3ProPreview: "Gemini 3 Pro"
        case .googleGemini31ProPreview: "Gemini 3.1 Pro"
        case .zaiGLM5: "GLM-5"
        case .zaiGLM45Flash: "GLM 4.5 Flash"
        case .kimiK25: "Kimi K2.5"
        case .kimiK2Thinking: "Kimi K2 Thinking"
        case .kimiK2TurboPreview: "Kimi K2 Turbo"
        case .minimaxM25: "MiniMax M2.5"
        case .minimaxM25HighSpeed: "M2.5 High-Speed"
        case .minimaxM21: "MiniMax M2.1"
        case .deepseekChat: "DeepSeek Chat"
        case .deepseekReasoner: "DeepSeek Reasoner"
        }
    }

    var providerDisplayName: String {
        provider.displayName
    }

    var aboutSheetBadge: String {
        provider.displayName
    }

    var aboutSheetModeSummary: String {
        supportedOperatingModes.map { mode in
            switch mode {
            case .agent:
                "Inline Tools"
            default:
                mode.displayName
            }
        }.joined(separator: ", ")
    }

    var aboutSheetStructuredOutputSummary: String {
        supportsStructuredOutput ? "Structured JSON" : "Prompt JSON fallback"
    }

    var aboutSheetPurposeSummary: String {
        switch self {
        case .openAIGPT54:
            "General-purpose multimodal OpenAI cloud work and tool-heavy chat."
        case .openAIGPT54Mini:
            "Fast OpenAI cloud chat, subagents, and lower-latency tool work."
        case .openAIGPT54Nano:
            "Cheap high-volume routing, rewrites, and lightweight automation."
        case .openAIGPT52:
            "Balanced GPT-5 cloud work when GPT-5.4 is unavailable."
        case .openAIGPT41:
            "Older general-purpose OpenAI cloud chat and multimodal work."
        case .openAIGPT41Mini:
            "Lightweight OpenAI fallback for fast simple cloud tasks."
        case .openAIO3:
            "Deliberate reasoning-heavy fallback when GPT-5 is not the right fit."
        case .openAIO3Mini:
            "Lean reasoning and lightweight tool loops."
        case .anthropicClaudeOpus47, .anthropicClaudeOpus41, .anthropicClaudeOpus4:
            "High-rigor writing, careful analysis, and long-form synthesis."
        case .anthropicClaudeSonnet46, .anthropicClaudeSonnet4, .anthropicClaudeSonnet37:
            "Fast general Anthropic reasoning, planning, and agent work."
        case .anthropicClaudeHaiku35:
            "Low-latency Anthropic chat and lightweight automation."
        case .googleGemini25Pro, .googleGemini3ProPreview, .googleGemini31ProPreview:
            "Very long-context multimodal analysis and grounded research."
        case .googleGemini25Flash, .googleGemini3FlashPreview:
            "Fast multimodal cloud turns and tool-oriented chat."
        case .zaiGLM5:
            "Broad general-purpose GLM reasoning and multilingual chat."
        case .zaiGLM45Flash:
            "Fast GLM chat and lightweight cloud routing."
        case .kimiK25:
            "Large-context synthesis and general-purpose Kimi work."
        case .kimiK2Thinking:
            "Longer-horizon Kimi reasoning and deliberate planning."
        case .kimiK2TurboPreview:
            "Fast Kimi cloud turns and tool-oriented chat."
        case .minimaxM25:
            "Large-context MiniMax reasoning and synthesis."
        case .minimaxM25HighSpeed:
            "Lower-latency MiniMax chat and automation."
        case .minimaxM21:
            "Balanced MiniMax reasoning with broad multimodal support."
        case .deepseekChat:
            "Fast DeepSeek cloud chat and lower-latency tool use."
        case .deepseekReasoner:
            "DeepSeek reasoning-heavy cloud work and deliberate analysis."
        }
    }

    /// Whether this model supports native structured output (JSON schema).
    /// OpenAI GPT models support json_schema response format.
    /// Anthropic supports structured output via tool_use with forced tool_choice.
    /// Reasoning models (o3, o3-mini) may not support structured output.
    var supportsStructuredOutput: Bool {
        switch self {
        case .openAIGPT54, .openAIGPT54Mini, .openAIGPT54Nano, .openAIGPT52,
             .openAIGPT41, .openAIGPT41Mini:
            return true
        case .openAIO3, .openAIO3Mini:
            return false // reasoning models — structured output not guaranteed
        case .anthropicClaudeOpus47, .anthropicClaudeSonnet46,
             .anthropicClaudeOpus41, .anthropicClaudeOpus4, .anthropicClaudeSonnet4,
             .anthropicClaudeSonnet37, .anthropicClaudeHaiku35:
            return true // via tool_use forced tool_choice
        case .googleGemini25Pro, .googleGemini25Flash, .googleGemini3FlashPreview,
             .googleGemini3ProPreview, .googleGemini31ProPreview:
            return true // Gemini supports responseSchema
        default:
            return false
        }
    }

    var supportedOperatingModes: [EpistemosOperatingMode] {
        switch self {
        case .openAIGPT54:
            [.fast, .thinking, .pro, .agent]
        case .openAIGPT54Mini:
            [.fast, .agent]
        case .openAIGPT54Nano:
            [.fast]
        case .openAIGPT52:
            [.fast, .thinking, .pro, .agent]
        case .openAIGPT41:
            [.fast, .agent]
        case .openAIGPT41Mini:
            [.fast]
        case .openAIO3:
            [.thinking, .pro, .agent]
        case .openAIO3Mini:
            [.fast, .thinking, .agent]
        case .anthropicClaudeOpus47,
             .anthropicClaudeOpus41,
             .anthropicClaudeOpus4:
            [.fast, .thinking, .pro, .agent]
        case .anthropicClaudeSonnet46,
             .anthropicClaudeSonnet4,
             .anthropicClaudeSonnet37:
            [.fast, .thinking, .agent]
        case .anthropicClaudeHaiku35:
            [.fast]
        case .googleGemini25Pro,
             .googleGemini3ProPreview,
             .googleGemini31ProPreview:
            [.fast, .thinking, .pro, .agent]
        case .googleGemini25Flash,
             .googleGemini3FlashPreview:
            [.fast, .agent]
        case .zaiGLM5:
            [.fast, .thinking, .pro, .agent]
        case .zaiGLM45Flash:
            [.fast]
        case .kimiK25:
            [.fast, .thinking, .pro, .agent]
        case .kimiK2Thinking:
            [.thinking, .pro, .agent]
        case .kimiK2TurboPreview:
            [.fast, .agent]
        case .minimaxM25:
            [.fast, .thinking, .pro, .agent]
        case .minimaxM25HighSpeed:
            [.fast, .agent]
        case .minimaxM21:
            [.fast, .thinking, .agent]
        case .deepseekChat:
            [.fast, .agent]
        case .deepseekReasoner:
            [.thinking, .pro, .agent]
        }
    }

    var supportsNativeReasoningEffortControl: Bool {
        switch self {
        case .openAIGPT54Nano, .openAIGPT52:
            true
        case .anthropicClaudeOpus47, .anthropicClaudeSonnet46,
             .anthropicClaudeOpus41, .anthropicClaudeOpus4, .anthropicClaudeSonnet4,
             .anthropicClaudeSonnet37:
            true
        case .googleGemini25Pro, .googleGemini25Flash, .googleGemini3FlashPreview,
             .googleGemini3ProPreview, .googleGemini31ProPreview:
            true
        default:
            false
        }
    }

    var supportsProviderNativeFeatureControls: Bool {
        switch provider {
        case .openAI, .anthropic, .google:
            true
        case .zai, .kimi, .minimax, .deepseek:
            false
        }
    }

    var preferredRuntimeControlTitle: String {
        switch provider {
        case .anthropic:
            "Claude"
        default:
            provider.displayName
        }
    }

    var nativeReasoningModes: [EpistemosOperatingMode] {
        guard supportsNativeReasoningEffortControl else { return [] }
        return supportedOperatingModes.filter { !$0.availableReasoningTiers.isEmpty }
    }

    nonisolated func availableReasoningTiers(
        for operatingMode: EpistemosOperatingMode
    ) -> [ChatReasoningTier] {
        guard supportsNativeReasoningEffortControl else {
            return operatingMode.availableReasoningTiers
        }
        switch operatingMode {
        case .fast:
            return []
        case .thinking, .pro, .agent:
            return [.low, .medium, .high, .heavy]
        }
    }

    nonisolated func sanitizedReasoningTier(
        _ tier: ChatReasoningTier,
        for operatingMode: EpistemosOperatingMode
    ) -> ChatReasoningTier {
        let tiers = availableReasoningTiers(for: operatingMode)
        guard !tiers.isEmpty else { return .off }
        guard tiers.contains(tier) else {
            return tiers.contains(operatingMode.defaultReasoningTier)
                ? operatingMode.defaultReasoningTier
                : (tiers.first ?? .off)
        }
        return tier
    }

    nonisolated func reasoningTierLabel(
        for tier: ChatReasoningTier,
        operatingMode: EpistemosOperatingMode
    ) -> String {
        let tiers = availableReasoningTiers(for: operatingMode)
        guard tiers.contains(tier) else {
            return operatingMode.reasoningTierLabel(for: tier)
        }
        guard supportsNativeReasoningEffortControl,
              operatingMode != .thinking else {
            return tier.displayName
        }

        switch provider {
        case .openAI:
            return tier == .heavy ? "Extra High" : tier.displayName
        case .anthropic:
            return tier == .heavy ? "Max" : tier.displayName
        case .google:
            return tier.displayName
        case .zai, .kimi, .minimax, .deepseek:
            return operatingMode.reasoningTierLabel(for: tier)
        }
    }

    var maxContextTokens: Int {
        switch self {
        case .openAIGPT54, .openAIGPT54Mini, .openAIGPT41:
            128_000
        case .openAIGPT52:
            1_048_576  // 1M tokens
        case .openAIGPT54Nano, .openAIGPT41Mini:
            131_072
        case .openAIO3, .openAIO3Mini:
            200_000
        case .anthropicClaudeOpus47, .anthropicClaudeSonnet46,
             .anthropicClaudeOpus41, .anthropicClaudeOpus4, .anthropicClaudeSonnet4:
            200_000
        case .anthropicClaudeSonnet37, .anthropicClaudeHaiku35:
            200_000
        case .googleGemini25Pro, .googleGemini25Flash:
            1_048_576
        case .googleGemini3FlashPreview, .googleGemini3ProPreview, .googleGemini31ProPreview:
            1_048_576
        case .zaiGLM5, .zaiGLM45Flash:
            128_000
        case .kimiK25, .kimiK2Thinking, .kimiK2TurboPreview:
            131_072
        case .minimaxM25, .minimaxM25HighSpeed, .minimaxM21:
            1_048_576
        case .deepseekChat, .deepseekReasoner:
            128_000
        }
    }

    var supportsVision: Bool {
        switch self {
        case .openAIGPT54, .openAIGPT54Mini, .openAIGPT54Nano, .openAIGPT52,
             .openAIGPT41, .openAIGPT41Mini:
            true
        case .openAIO3, .openAIO3Mini:
            false  // reasoning-only, no vision
        case .anthropicClaudeOpus47, .anthropicClaudeSonnet46,
             .anthropicClaudeOpus41, .anthropicClaudeOpus4, .anthropicClaudeSonnet4,
             .anthropicClaudeSonnet37, .anthropicClaudeHaiku35:
            true
        case .googleGemini25Pro, .googleGemini25Flash, .googleGemini3FlashPreview,
             .googleGemini3ProPreview, .googleGemini31ProPreview:
            true
        case .zaiGLM5:
            true
        case .zaiGLM45Flash:
            false
        case .kimiK25, .kimiK2Thinking, .kimiK2TurboPreview:
            true
        case .minimaxM25, .minimaxM25HighSpeed, .minimaxM21:
            false
        case .deepseekChat, .deepseekReasoner:
            false
        }
    }

    var supportedFileTypes: Set<AttachmentType> {
        supportsVision ? [.text, .csv, .pdf, .image] : [.text, .csv, .pdf]
    }

    func resolvedModel(for operatingMode: EpistemosOperatingMode) -> CloudTextModelID {
        switch (self, operatingMode) {
        case (.openAIGPT54, .fast):
            .openAIGPT54Mini
        case (.zaiGLM5, .fast):
            .zaiGLM45Flash
        case (.kimiK25, .fast):
            .kimiK2TurboPreview
        case (.kimiK25, .thinking):
            .kimiK2Thinking
        case (.minimaxM25, .fast):
            .minimaxM25HighSpeed
        case (.deepseekChat, .thinking), (.deepseekChat, .pro):
            .deepseekReasoner
        default:
            self
        }
    }

    nonisolated static func models(for provider: CloudModelProvider) -> [CloudTextModelID] {
        allCases.filter { $0.provider == provider }
    }

    nonisolated static func from(rawValueOrVendorID value: String) -> CloudTextModelID? {
        if let direct = CloudTextModelID(rawValue: value) {
            return direct
        }

        if let exactVendorMatch = allCases.first(where: { $0.vendorModelID == value }) {
            return exactVendorMatch
        }

        return legacyMigrationMap[value]
    }

    private nonisolated static let legacyMigrationMap: [String: CloudTextModelID] = [
        "gpt-4o": .openAIGPT54,
        "openai:gpt-4o": .openAIGPT54,
        "gpt-4o-mini": .openAIGPT54Mini,
        "openai:gpt-4o-mini": .openAIGPT54Mini,
        "gpt-5.4": .openAIGPT54,
        "openai:gpt-5.4": .openAIGPT54,
        "gpt-5.4-mini": .openAIGPT54Mini,
        "openai:gpt-5.4-mini": .openAIGPT54Mini,
        "gpt-5.3": .openAIGPT54,
        "gpt-5.2": .openAIGPT52,
        "gpt-5.1": .openAIGPT52,
        "gpt-4.1": .openAIGPT41,
        "gpt-4.1-mini": .openAIGPT41Mini,
        "o1-pro": .openAIO3,
        "o3": .openAIO3,
        "o3-mini": .openAIO3Mini,
        "claude-opus-4-7": .anthropicClaudeOpus47,
        "claude-opus-4-6": .anthropicClaudeOpus47,
        "claude-opus-4-1": .anthropicClaudeOpus41,
        "claude-opus-4-20250514": .anthropicClaudeOpus4,
        "claude-sonnet-4-6": .anthropicClaudeSonnet46,
        "claude-sonnet-4-5": .anthropicClaudeSonnet46,
        "claude-sonnet-4-5-20250929": .anthropicClaudeSonnet46,
        "claude-sonnet-4-20250514": .anthropicClaudeSonnet4,
        "claude-3-7-sonnet-20250219": .anthropicClaudeSonnet37,
        "claude-haiku-4-5-20251001": .anthropicClaudeHaiku35,
        "claude-3-5-haiku-latest": .anthropicClaudeHaiku35,
        "gemini-1.5-pro": .googleGemini31ProPreview,
        "gemini-1.5-flash": .googleGemini3FlashPreview,
        "gemini-2.0-flash": .googleGemini3FlashPreview,
        "gemini-2.0-flash-lite": .googleGemini3FlashPreview,
        "gemini-2.5-pro": .googleGemini31ProPreview,
        "gemini-2.5-flash": .googleGemini3FlashPreview,
        "gemini-3-flash-preview": .googleGemini3FlashPreview,
        "gemini-3-pro-preview": .googleGemini31ProPreview,
        "gemini-3.1-pro-preview": .googleGemini31ProPreview,
        "glm-5": .zaiGLM5,
        "glm-4.5-flash": .zaiGLM45Flash,
        "kimi-k2.5": .kimiK25,
        "kimi-k2-thinking": .kimiK2Thinking,
        "kimi-k2-turbo-preview": .kimiK2TurboPreview,
        "MiniMax-M2.5": .minimaxM25,
        "MiniMax-M2.5-highspeed": .minimaxM25HighSpeed,
        "MiniMax-M2.1": .minimaxM21,
        "deepseek-chat": .deepseekChat,
        "deepseek-reasoner": .deepseekReasoner,
    ]
}

nonisolated enum CloudProviderValidationState: Sendable, Equatable {
    case missing
    case unchecked
    case checking
    case valid(message: String, checkedAt: Date)
    case invalid(message: String, checkedAt: Date)

    var isChecking: Bool {
        if case .checking = self {
            return true
        }
        return false
    }

    var isVerified: Bool {
        if case .valid = self {
            return true
        }
        return false
    }

    var statusBadge: String {
        switch self {
        case .missing:
            "Not Connected"
        case .unchecked:
            "Saved"
        case .checking:
            "Checking"
        case .valid:
            "Verified"
        case .invalid:
            "Needs Attention"
        }
    }

    var statusText: String {
        return switch self {
        case .missing:
            "Connect provider access to unlock these cloud models."
        case .unchecked:
            "Access is stored locally but not verified yet. Run a live check before making this provider active."
        case .checking:
            "Verifying this provider with a live request. This check times out after 90 seconds."
        case .valid(let message, let checkedAt):
            "\(message) • Checked \(checkedAt.formatted(date: .omitted, time: .shortened))"
        case .invalid(let message, let checkedAt):
            "\(message) • Checked \(checkedAt.formatted(date: .omitted, time: .shortened))"
        }
    }

    var systemImage: String {
        switch self {
        case .missing:
            "person.crop.circle.badge.exclamationmark"
        case .unchecked:
            "clock.badge.exclamationmark"
        case .checking:
            "arrow.triangle.2.circlepath"
        case .valid:
            "checkmark.shield.fill"
        case .invalid:
            "exclamationmark.triangle.fill"
        }
    }

    var tintColor: ColorRole {
        switch self {
        case .missing:
            .secondary
        case .unchecked, .checking:
            .accent
        case .valid:
            .success
        case .invalid:
            .warning
        }
    }
}

nonisolated enum CloudProviderAccountConnectionState: Sendable, Equatable {
    case disconnected
    case pendingVerification
    case checking
    case connected
    case failure
}

nonisolated struct CloudProviderAccountConnectionSummary: Sendable, Equatable {
    let state: CloudProviderAccountConnectionState
    let title: String
    let detail: String
}

nonisolated enum ColorRole: Sendable, Equatable {
    case accent
    case secondary
    case success
    case warning
}

extension CloudModelProvider {
    var supportsAccountConnection: Bool {
        switch self {
        case .openAI, .anthropic, .google:
            true
        case .zai, .kimi, .minimax, .deepseek:
            false
        }
    }

    var manualCredentialTitle: String {
        supportsAccountConnection ? "Legacy API Key" : "API Key"
    }

    var manualCredentialTitleLowercase: String {
        manualCredentialTitle.lowercased()
    }

    var missingManualCredentialMessage: String {
        "Paste or type a non-empty \(manualCredentialTitleLowercase) before saving."
    }

    var missingClipboardCredentialMessage: String {
        "Clipboard doesn't contain a non-empty \(manualCredentialTitleLowercase) for \(displayName)."
    }

    var systemImage: String {
        switch self {
        case .openAI:
            "sparkles"
        case .anthropic:
            "brain"
        case .google:
            "globe.americas.fill"
        case .zai:
            "bolt.horizontal.circle"
        case .kimi:
            "moon.stars.fill"
        case .minimax:
            "paperplane.circle.fill"
        case .deepseek:
            "water.waves"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .openAI:
            "sk-..."
        case .anthropic:
            "sk-ant-..."
        case .google:
            "AIza..."
        case .zai:
            "za-..."
        case .kimi:
            "sk-..."
        case .minimax:
            "eyJ..."
        case .deepseek:
            "sk-..."
        }
    }

    var setupHelpText: String {
        switch self {
        case .openAI:
            "Recommended account path. Sign in with ChatGPT and Epistemos uses the OpenAI Codex session directly. Legacy API keys stay available only as a fallback."
        case .anthropic:
            "Preferred account path. Import your Claude Code session so Epistemos can use Claude access without a pasted key. Legacy API keys stay available only as a fallback."
        case .google:
            "Real OAuth path. In Google Cloud Console, create an OAuth client ID for a Desktop app, download that client JSON, enter the matching Google Cloud project ID, then sign in with Google for Gemini without a pasted API key."
        case .zai:
            "Z.AI / GLM currently uses the direct API route in Epistemos. Open the platform, create an API key, then save it here."
        case .kimi:
            "Kimi / Moonshot currently uses the direct API route in Epistemos. Open the platform, create an API key, then save it here."
        case .minimax:
            "MiniMax documents OAuth for OpenClaw, but the public API path available to Epistemos today is the direct API route. Create a key, then save it here."
        case .deepseek:
            "DeepSeek currently uses the direct API route in Epistemos. Open the platform, create an API key, then save it here."
        }
    }

    var automationHintText: String {
        switch self {
        case .openAI:
            "Best path: Sign in with ChatGPT. If you already use Codex CLI, you can import that session. Manual API keys are now the legacy path."
        case .anthropic:
            "Best path: import Claude Code credentials. If you prefer the direct API console route, the legacy key path is still tucked away below."
        case .google:
            "Best path: in Google Cloud Console, create an OAuth client ID for a Desktop app, download that client JSON, choose it here, enter the same Google Cloud project ID, then sign in with your Google account. Legacy Gemini API keys are only the fallback."
        case .zai:
            "Fastest path: open Z.AI, create an API key, then use Paste + Save."
        case .kimi:
            "Fastest path: open Moonshot, create an API key, then use Paste + Save."
        case .minimax:
            "Fastest path in Epistemos today: open MiniMax, create an API key, then use Paste + Save."
        case .deepseek:
            "Fastest path: open DeepSeek, create an API key, then use Paste + Save."
        }
    }

    var accountSetupTitle: String {
        switch self {
        case .openAI:
            "Use your OpenAI account"
        case .anthropic:
            "Use your Anthropic account"
        case .google:
            "Use your Google account"
        case .zai:
            "Connect Z.AI / GLM"
        case .kimi:
            "Connect Kimi / Moonshot"
        case .minimax:
            "Connect MiniMax"
        case .deepseek:
            "Connect DeepSeek"
        }
    }

    var accountSetupHelpText: String {
        switch self {
        case .openAI:
            "Sign in with ChatGPT first. Manual API key tools stay tucked under Legacy API Key if you need them."
        case .anthropic:
            "Use your Claude account first by importing Claude Code credentials. Expand Legacy API Key only if you want the console-key path."
        case .google:
            "Connect Google OAuth first with the Desktop-app client JSON from Google Cloud Console and the matching Google Cloud project ID, then fall back to Legacy API Key only when needed."
        case .zai:
            "Use the provider portal to create an API key, then save it here. Z.AI's public API path in Epistemos is direct-key today."
        case .kimi:
            "Use the provider portal to create an API key, then save it here. Kimi's public API path in Epistemos is direct-key today."
        case .minimax:
            "Use the provider portal to create an API key, then save it here. MiniMax's public API path in Epistemos is direct-key today."
        case .deepseek:
            "Use the provider portal to create an API key, then save it here. DeepSeek's public API path in Epistemos is direct-key today."
        }
    }

    var accountActionTitle: String {
        switch self {
        case .openAI:
            "Sign in with ChatGPT"
        case .anthropic:
            "Use Claude Code Account"
        case .google:
            "Connect Google OAuth"
        case .zai:
            "Open Z.AI API Keys"
        case .kimi:
            "Open Moonshot API Keys"
        case .minimax:
            "Open MiniMax API Keys"
        case .deepseek:
            "Open DeepSeek API Keys"
        }
    }

    var credentialActionTitle: String {
        switch self {
        case .openAI:
            "Open API Keys"
        case .anthropic:
            "Open Console"
        case .google:
            "Open AI Studio"
        case .zai:
            "Open Z.AI API Keys"
        case .kimi:
            "Open Moonshot API Keys"
        case .minimax:
            "Open MiniMax API Keys"
        case .deepseek:
            "Open DeepSeek API Keys"
        }
    }

    var credentialManagementURL: URL? {
        switch self {
        case .openAI:
            URL(string: "https://platform.openai.com/api-keys")
        case .anthropic:
            URL(string: "https://console.anthropic.com/settings/keys")
        case .google:
            URL(string: "https://aistudio.google.com/app/apikey")
        case .zai:
            URL(string: "https://z.ai/manage-apikey/apikey-list")
        case .kimi:
            URL(string: "https://platform.moonshot.ai/console/api-keys")
        case .minimax:
            URL(string: "https://platform.minimax.io/docs/api-reference/text-ai-coding-refer")
        case .deepseek:
            URL(string: "https://platform.deepseek.com/api_keys")
        }
    }

    var documentationActionTitle: String {
        switch self {
        case .google:
            "Open Gemini Docs"
        case .openAI, .anthropic, .zai, .kimi, .minimax, .deepseek:
            "Open API Docs"
        }
    }

    var documentationURL: URL? {
        switch self {
        case .openAI:
            URL(string: "https://developers.openai.com/api-reference/authentication")
        case .anthropic:
            URL(string: "https://docs.anthropic.com/en/api/getting-started")
        case .google:
            URL(string: "https://ai.google.dev/gemini-api/docs/api-key")
        case .zai:
            URL(string: "https://docs.z.ai/guides/development-guide/introduction")
        case .kimi:
            URL(string: "https://platform.moonshot.ai/docs/guide/start-using-kimi-api")
        case .minimax:
            URL(string: "https://platform.minimax.io/docs/api-reference/text-ai-coding-refer")
        case .deepseek:
            URL(string: "https://api-docs.deepseek.com/")
        }
    }

    var modelSummary: String {
        switch self {
        case .openAI:
            "GPT-4o, GPT-4o Mini"
        case .anthropic:
            "Claude Opus 4.7, Sonnet 4.6"
        case .google:
            "Gemini 3.1 Pro, Gemini 3 Flash"
        case .zai:
            "GLM-5, GLM-4.5 Flash"
        case .kimi:
            "Kimi K2.5, K2 Thinking, K2 Turbo"
        case .minimax:
            "MiniMax M2.5, M2.5 High-Speed, M2.1"
        case .deepseek:
            "DeepSeek Chat, DeepSeek Reasoner"
        }
    }

    var validationModel: CloudTextModelID {
        switch self {
        case .openAI:
            .openAIGPT54Mini
        case .anthropic:
            .anthropicClaudeSonnet46
        case .google:
            .googleGemini3FlashPreview
        case .zai:
            .zaiGLM45Flash
        case .kimi:
            .kimiK2TurboPreview
        case .minimax:
            .minimaxM25HighSpeed
        case .deepseek:
            .deepseekChat
        }
    }

    var defaultChatModel: CloudTextModelID {
        switch self {
        case .openAI:
            .openAIGPT54
        case .anthropic:
            .anthropicClaudeSonnet46
        case .google:
            .googleGemini31ProPreview
        case .zai:
            .zaiGLM5
        case .kimi:
            .kimiK25
        case .minimax:
            .minimaxM25
        case .deepseek:
            .deepseekChat
        }
    }

    func accountConnectionSummary(
        oauthCredential: CloudProviderOAuthCredential?,
        hasSavedAPIKey: Bool,
        validationState: CloudProviderValidationState
    ) -> CloudProviderAccountConnectionSummary? {
        guard supportsAccountConnection else { return nil }

        if let oauthCredential {
            let accountLabel = oauthCredential.displayAccountLabel
            switch validationState {
            case .valid:
                return CloudProviderAccountConnectionSummary(
                    state: .connected,
                    title: "Verified account connected",
                    detail: verifiedAccountDetail(accountLabel: accountLabel)
                )
            case .checking:
                return CloudProviderAccountConnectionSummary(
                    state: .checking,
                    title: "Verifying account access",
                    detail: checkingAccountDetail(accountLabel: accountLabel)
                )
            case .invalid(let message, _):
                return CloudProviderAccountConnectionSummary(
                    state: .failure,
                    title: "Account needs attention",
                    detail: failureAccountDetail(accountLabel: accountLabel, message: message)
                )
            case .unchecked, .missing:
                return CloudProviderAccountConnectionSummary(
                    state: .pendingVerification,
                    title: "Account saved, not verified",
                    detail: pendingAccountDetail(accountLabel: accountLabel)
                )
            }
        }

        let detail: String
        switch self {
        case .openAI:
            detail = hasSavedAPIKey
                ? "No account session connected. Legacy API key saved as fallback."
                : "No account session connected. Sign in with ChatGPT to keep setup account-first."
        case .anthropic:
            detail = hasSavedAPIKey
                ? "No account session connected. Legacy API key saved as fallback."
                : "No account session connected. Import Claude Code to connect Anthropic without pasting a key."
        case .google:
            detail = hasSavedAPIKey
                ? "No account session connected. Legacy API key saved as fallback."
                : "No account session connected. Finish Google OAuth to keep Gemini setup account-first."
        case .zai, .kimi, .minimax, .deepseek:
            return nil
        }
        return CloudProviderAccountConnectionSummary(
            state: .disconnected,
            title: "No account session connected",
            detail: detail
        )
    }

    func accountGuidanceText(
        validationState: CloudProviderValidationState
    ) -> String? {
        guard supportsAccountConnection else { return nil }

        switch self {
        case .openAI:
            return switch validationState {
            case .valid:
                nil
            case .checking:
                "If OpenAI asks you to enable access first, finish that browser step now. Verification stops after 90 seconds."
            case .unchecked, .missing:
                "Sign in with ChatGPT, then verify live access before making this provider active."
            case .invalid:
                "If OpenAI asked you to enable access first, finish that browser step and then retry OpenAI sign-in."
            }
        case .anthropic:
            return switch validationState {
            case .valid:
                nil
            case .checking:
                "Claude Code needs to be signed in first. Epistemos verifies that imported account with a live check and stops after 90 seconds."
            case .unchecked, .missing:
                "Claude Code needs to be signed in first. Import that connected account, then verify live access before making this provider active."
            case .invalid:
                "Claude Code needs to be signed in first. Reopen Claude Code, reconnect if needed, and then retry import."
            }
        case .google:
            return switch validationState {
            case .valid:
                nil
            case .checking:
                "Finish the Google browser consent flow now. If Google asks for extra setup, complete it there and retry."
            case .unchecked, .missing:
                "Verify live access before making this provider active."
            case .invalid:
                "If Google asked for extra setup in the browser, complete that step and then retry Google OAuth."
            }
        case .zai, .kimi, .minimax, .deepseek:
            return nil
        }
    }

    private func verifiedAccountDetail(accountLabel: String?) -> String {
        if let accountLabel {
            return "Connected as \(accountLabel)."
        }

        return switch self {
        case .openAI:
            "Verified OpenAI account session is stored in Apple Keychain."
        case .anthropic:
            "Verified Claude Code account session is stored in Apple Keychain."
        case .google:
            "Verified Google account session is stored in Apple Keychain."
        case .zai, .kimi, .minimax, .deepseek:
            ""
        }
    }

    private func pendingAccountDetail(accountLabel: String?) -> String {
        if let accountLabel {
            return "Stored account: \(accountLabel). Tap Check Access before making this provider active."
        }

        return switch self {
        case .openAI:
            "OpenAI account session is stored, but you still need a live verification check. Tap Check Access before making this provider active."
        case .anthropic:
            "Claude Code account session is stored, but you still need a live verification check. Tap Check Access before making this provider active."
        case .google:
            "Google account session is stored, but you still need a live verification check. Tap Check Access before making this provider active."
        case .zai, .kimi, .minimax, .deepseek:
            ""
        }
    }

    private func checkingAccountDetail(accountLabel: String?) -> String {
        if let accountLabel {
            return "Checking \(accountLabel) with a live request. This stops after 90 seconds."
        }

        return switch self {
        case .openAI:
            "Checking the stored OpenAI account with a live request. This stops after 90 seconds."
        case .anthropic:
            "Checking the imported Claude Code account with a live request. This stops after 90 seconds."
        case .google:
            "Checking the stored Google account with a live request. This stops after 90 seconds."
        case .zai, .kimi, .minimax, .deepseek:
            ""
        }
    }

    private func failureAccountDetail(accountLabel: String?, message: String) -> String {
        if let accountLabel {
            return "Stored account: \(accountLabel). \(message)"
        }
        return message
    }
}

nonisolated enum ChatModelSelection: Codable, Sendable, Equatable, Identifiable {
    var id: String { rawValue }
    case appleIntelligence
    case localMLX(String)
    case cloud(CloudTextModelID)

    init?(rawValue: String) {
        if rawValue == "apple-intelligence" {
            self = .appleIntelligence
            return
        }
        if rawValue.hasPrefix("cloud:") {
            let cloudRawValue = String(rawValue.dropFirst("cloud:".count))
            let legacyVendorModelID = cloudRawValue.split(separator: ":", maxSplits: 1).last.map(String.init)
            guard let model = CloudTextModelID.from(rawValueOrVendorID: cloudRawValue)
                ?? legacyVendorModelID.flatMap(CloudTextModelID.from(rawValueOrVendorID:))
            else { return nil }
            self = .cloud(model)
            return
        }
        guard LocalTextModelID(rawValue: rawValue) != nil
            || GemmaQATRuntimeLadder.candidate(forID: rawValue) != nil
        else { return nil }
        self = .localMLX(rawValue)
    }

    var rawValue: String {
        switch self {
        case .appleIntelligence:
            "apple-intelligence"
        case .localMLX(let modelID):
            modelID
        case .cloud(let model):
            "cloud:\(model.rawValue)"
        }
    }

    var displayName: String {
        switch self {
        case .appleIntelligence:
            "Apple Intelligence"
        case .localMLX(let modelID):
            LocalTextModelID(rawValue: modelID)?.displayName
                ?? GemmaQATRuntimeLadder.candidate(forID: modelID)?.displayName
                ?? modelID
        case .cloud(let model):
            model.displayName
        }
    }

    var activeMaxContextTokens: Int {
        switch self {
        case .appleIntelligence:
            return 128_000
        case .localMLX(let id):
            if GemmaQATRuntimeLadder.candidate(forID: id) != nil {
                return 128_000
            }
            return LocalTextModelID(rawValue: id)?.maxContextTokens ?? 128_000
        case .cloud(let model):
            return model.maxContextTokens
        }
    }

    var activeSupportsVision: Bool {
        switch self {
        case .appleIntelligence:
            return false
        case .localMLX(let id):
            if GemmaQATRuntimeLadder.candidate(forID: id) != nil {
                return false
            }
            return LocalTextModelID(rawValue: id)?.supportsVision ?? false
        case .cloud(let model):
            return model.supportsVision
        }
    }

    var activeSupportedFileTypes: Set<AttachmentType> {
        switch self {
        case .appleIntelligence: [.text, .csv, .pdf]
        case .localMLX(let id): LocalTextModelID(rawValue: id)?.supportedFileTypes ?? [.text, .csv, .pdf]
        case .cloud(let model): model.supportedFileTypes
        }
    }

    var supportsThinking: Bool {
        switch self {
        case .appleIntelligence:
            return false
        case .localMLX(let id):
            if GemmaQATRuntimeLadder.candidate(forID: id) != nil {
                return false
            }
            return LocalTextModelID(rawValue: id)?.supportsThinkingMode ?? false
        case .cloud(let model):
            return model.supportedOperatingModes.contains(.thinking)
        }
    }

    var compactDisplayName: String {
        switch self {
        case .appleIntelligence:
            "Apple Intelligence"
        case .localMLX(let modelID):
            LocalTextModelID(rawValue: modelID)?.compactDisplayName
                ?? GemmaQATRuntimeLadder.candidate(forID: modelID)?.displayName
                ?? modelID
        case .cloud(let model):
            model.compactDisplayName
        }
    }
}

nonisolated struct ChatSurfaceRouteDescription: Sendable, Equatable {
    let operatingMode: EpistemosOperatingMode
    let selection: ChatModelSelection
    let headline: String
    let summary: String
    let systemImage: String
    let usesAutomaticRouting: Bool
}

nonisolated enum LocalRoutingMode: String, Codable, Sendable, CaseIterable {
    case auto
    case localOnly

    var displayName: String {
        switch self {
        case .auto: "Auto"
        case .localOnly: "Local Only"
        }
    }

    var summary: String {
        switch self {
        case .auto:
            "Auto keeps the local runtime primary. Apple Intelligence remains available when you explicitly select it or when no usable local runtime is ready."
        case .localOnly:
            "Always use the prepared or installed local runtime. Apple Intelligence is bypassed."
        }
    }
}

nonisolated enum LocalReasoningMode: String, Codable, Sendable, CaseIterable {
    case fast
    case thinking

    var displayName: String {
        switch self {
        case .fast: "Fast"
        case .thinking: "Thinking"
        }
    }
}

nonisolated enum EpistemosOperatingMode: String, Codable, Sendable, CaseIterable {
    case fast
    case thinking
    case pro
    case agent

    /// Fallback reasoning tiers for this mode when the active runtime
    /// does not expose a provider-native effort ladder. Cloud models
    /// with native effort control can widen Pro / Agent via
    /// `CloudTextModelID.availableReasoningTiers(for:)`.
    var availableReasoningTiers: [ChatReasoningTier] {
        switch self {
        case .fast: []
        case .thinking: [.low, .medium, .high, .heavy]
        case .pro, .agent: [.medium, .heavy]
        }
    }

    /// Fallback mode-specific label for a reasoning tier. Provider-
    /// native runtimes can override these labels (for example Codex
    /// showing "Extra High") via `CloudTextModelID.reasoningTierLabel`.
    nonisolated func reasoningTierLabel(for tier: ChatReasoningTier) -> String {
        switch (self, tier) {
        case (.pro, .medium), (.agent, .medium): "Standard"
        case (.pro, .heavy), (.agent, .heavy): "Extended"
        default: tier.displayName
        }
    }

    nonisolated var defaultReasoningTier: ChatReasoningTier {
        switch self {
        case .fast:
            .off
        case .thinking, .pro, .agent:
            .medium
        }
    }

    nonisolated func sanitizedReasoningTier(_ tier: ChatReasoningTier) -> ChatReasoningTier {
        guard !availableReasoningTiers.isEmpty else { return .off }
        guard availableReasoningTiers.contains(tier) else { return defaultReasoningTier }
        return tier
    }

    nonisolated var capturesReasoningTrace: Bool {
        switch self {
        case .fast:
            false
        case .thinking, .pro, .agent:
            true
        }
    }

    var displayName: String {
        switch self {
        case .fast: "Fast"
        case .thinking: "Think"
        case .pro: "Code"
        case .agent: "Tools"
        }
    }

    var systemImage: String {
        switch self {
        case .fast: "bolt.fill"
        case .thinking: "brain.head.profile"
        case .pro: "chevron.left.forwardslash.chevron.right"
        case .agent: "cpu.fill"
        }
    }

    var helpText: String {
        switch self {
        case .fast:
            "Quick answers. On a local model this runs Gemma 4, sized to the task."
        case .thinking:
            "Deeper reasoning. On a local model this runs VibeThinker; on cloud it spends more reasoning budget."
        case .pro:
            "Code & deepest reasoning. On a local model this runs the Gemma 4 coder; on cloud it uses the provider's deepest route."
        case .agent:
            "Keep the turn in this chat while enabling the full tools/runtime path (web search, file ops, shell/terminal commands with approval, code, computer use)."
        }
    }

    var localReasoningMode: LocalReasoningMode? {
        switch self {
        case .fast: .fast
        case .thinking, .pro: .thinking
        case .agent: .thinking  // Agent mode uses cloud with thinking enabled
        }
    }

    var handoffMessage: String? {
        switch self {
        case .agent:
            nil  // No handoff needed — agent runs inline in main chat
        case .fast, .thinking, .pro:
            nil
        }
    }
}

nonisolated struct OperatingModeCapabilities: Sendable, Equatable {
    let availableModes: [EpistemosOperatingMode]

    var supportsThinking: Bool {
        availableModes.contains(.thinking)
    }
}

nonisolated enum LocalModelInstallStateSummary: String, Codable, Sendable {
    case none
    case prepared
    case installed

    var displayName: String {
        switch self {
        case .none: "None"
        case .prepared: "Prepared"
        case .installed: "Installed"
        }
    }
}

nonisolated enum LocalRuntimeThermalState: String, Codable, Sendable, Equatable {
    case nominal
    case fair
    case serious
    case critical

    init(_ thermalState: ProcessInfo.ThermalState) {
        switch thermalState {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .serious
        }
    }

    var isSeverelyConstrained: Bool {
        switch self {
        case .serious, .critical:
            true
        case .nominal, .fair:
            false
        }
    }
}

nonisolated struct LocalRuntimeConditions: Sendable, Equatable {
    let lowPowerModeEnabled: Bool
    let appActive: Bool
    let thermalState: LocalRuntimeThermalState

    static func current(appActive: Bool = true) -> LocalRuntimeConditions {
        let systemLPM = ProcessInfo.processInfo.isLowPowerModeEnabled
        let ecoToggle = UserDefaults.standard.bool(forKey: "epistemos.ecoMode")
        return LocalRuntimeConditions(
            lowPowerModeEnabled: systemLPM || ecoToggle,
            appActive: appActive,
            thermalState: LocalRuntimeThermalState(ProcessInfo.processInfo.thermalState)
        )
    }

    var prefersConstrainedLocalModel: Bool {
        lowPowerModeEnabled || !appActive || thermalState != .nominal
    }

    var allowsAutomaticLocalRouting: Bool {
        appActive && thermalState != .critical
    }
}

nonisolated enum LocalModelSelectionSurface: String, Sendable, Equatable {
    case mainChat
    case miniChat
    case noteChat
    case graph
}

nonisolated struct LocalModelSelection: Sendable, Equatable {
    let modelID: String
    let reasoningMode: LocalReasoningMode
    let contentBudget: Int

    var canActAsAgent: Bool {
        guard let model = LocalTextModelID(rawValue: modelID) else {
            return false
        }
        return model.canRunLocalAgentLoop
    }
}

extension CloudModelProvider {
    var recommendedFallbackCloudModel: (EpistemosOperatingMode) -> CloudTextModelID {
        { operatingMode in
            switch (self, operatingMode) {
            case (.openAI, .fast):
                .openAIGPT54Mini
            case (.openAI, .thinking):
                .openAIGPT54
            case (.openAI, .pro), (.openAI, .agent):
                .openAIGPT54
            case (.anthropic, .pro):
                .anthropicClaudeOpus47
            case (.anthropic, .agent), (.anthropic, .thinking), (.anthropic, .fast):
                .anthropicClaudeSonnet46
            case (.google, .fast):
                .googleGemini3FlashPreview
            case (.google, .thinking), (.google, .pro), (.google, .agent):
                .googleGemini31ProPreview
            case (.zai, .fast):
                .zaiGLM45Flash
            case (.zai, .thinking), (.zai, .pro), (.zai, .agent):
                .zaiGLM5
            case (.kimi, .fast):
                .kimiK2TurboPreview
            case (.kimi, .thinking):
                .kimiK2Thinking
            case (.kimi, .pro), (.kimi, .agent):
                .kimiK25
            case (.minimax, .fast):
                .minimaxM25HighSpeed
            case (.minimax, .thinking), (.minimax, .pro), (.minimax, .agent):
                .minimaxM25
            case (.deepseek, .fast):
                .deepseekChat
            case (.deepseek, .thinking), (.deepseek, .pro), (.deepseek, .agent):
                .deepseekReasoner
            }
        }
    }
}

nonisolated struct LocalHardwareCapabilitySnapshot: Sendable, Equatable {
    let physicalMemoryBytes: UInt64
    let roundedMemoryGB: Int
    let maxRecommendedLocalContentLength: Int

    static var current: LocalHardwareCapabilitySnapshot {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let roundedGB = max(8, Int((physicalMemory + 999_999_999) / 1_000_000_000))
        let maxContentLength: Int
        switch roundedGB {
        case ..<16:
            maxContentLength = 4_000
        case ..<24:
            maxContentLength = 10_000
        case ..<36:
            maxContentLength = 18_000
        default:
            maxContentLength = 28_000
        }
        return LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: physicalMemory,
            roundedMemoryGB: roundedGB,
            maxRecommendedLocalContentLength: maxContentLength
        )
    }

    nonisolated func supports(textModelID: String) -> Bool {
        guard let model = LocalTextModelID(rawValue: textModelID) else { return false }
        return roundedMemoryGB >= model.minimumRecommendedMemoryGB
    }

    nonisolated func supportsInteractiveChatModel(textModelID: String) -> Bool {
        guard let model = LocalTextModelID(rawValue: textModelID) else { return false }
        return roundedMemoryGB >= model.minimumRecommendedInteractiveMemoryGB
    }

    /// Recommends the default interactive local model Epistemos should
    /// seed on new installs and sanitized fallbacks. Keep this pinned to
    /// a release-validated, loader-working tier until larger families
    /// are proven end-to-end in the shipped runtime.
    nonisolated var recommendedLocalTextModelID: LocalTextModelID {
        .qwen3_4B4Bit
    }

    nonisolated func smallerLocalTextModelID(than modelID: LocalTextModelID) -> LocalTextModelID? {
        switch modelID {
        case .gemma4_2B4Bit:
            return nil
        case .gemma4_4B4Bit:
            return .qwen3_4B4Bit
        case .llama32_3BInstruct4Bit:
            return .bonsai4B2Bit
        case .qwen3_4B4Bit:
            return .bonsai4B2Bit
        case .qwen3_4BThinking25074Bit:
            return .qwen3_4B4Bit
        case .gemma3_4BQAT4Bit:
            return .qwen3_4B4Bit
        case .bonsai4B2Bit:
            return nil
        case .bonsai8B2Bit:
            return .bonsai4B2Bit
        case .deepseekR1Distill7B:
            return .qwen3_4B4Bit
        case .qwen3_8B4Bit:
            return .qwen3_4B4Bit
        case .qwen25Coder7B:
            return .qwen3_4B4Bit
        case .gemma4_27BA4B4Bit:
            return .deepseekR1Distill7B
        case .qwen36_35BA3B4Bit, .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit:
            return .deepseekR1Distill7B
        default:
            break
        }

        let installableModelIDs = Set(
            LocalModelCatalog.textDescriptors.compactMap { LocalTextModelID(rawValue: $0.id) }
        )
        let orderedModelIDs = LocalTextModelID.ascendingBySize.filter {
            installableModelIDs.contains($0)
                && $0.isReleaseValidatedForInteractiveChat
                && $0.isEpistemosShippedLocalModel
        }
        if let currentIndex = orderedModelIDs.firstIndex(of: modelID), currentIndex > 0 {
            return orderedModelIDs[currentIndex - 1]
        }

        return orderedModelIDs
            .last { candidate in
                candidate != modelID
                    && candidate.minimumRecommendedMemoryGB <= modelID.minimumRecommendedMemoryGB
            }
    }

    nonisolated var recommendedConstrainedLocalTextModelID: LocalTextModelID? {
        smallerLocalTextModelID(than: recommendedLocalTextModelID)
    }

    /// Content length derived from the recommended model's actual context window.
    /// Uses a fraction of the model's max to leave room for output + KV cache.
    nonisolated var baseLocalRuntimeContentLength: Int {
        baseLocalRuntimeContentLength(for: recommendedLocalTextModelID)
    }

    nonisolated func baseLocalRuntimeContentLength(for model: LocalTextModelID) -> Int {
        // Use 60% of the model's context window for input, leaving 40% for output + overhead
        let modelBudget = Int(Double(model.maxContextTokens) * 0.6)
        // Cap at a practical maximum to avoid VRAM pressure from KV cache
        let vramCap: Int = switch roundedMemoryGB {
        case ..<12:  4_000
        case ..<16:  6_000
        case ..<24:  12_000
        case ..<48:  20_000
        default:     32_000
        }
        return min(modelBudget, vramCap)
    }

    nonisolated func recommendedLocalTextModelID(for conditions: LocalRuntimeConditions) -> LocalTextModelID {
        let baseline = recommendedLocalTextModelID
        guard conditions.prefersConstrainedLocalModel,
              let constrained = smallerLocalTextModelID(than: baseline) else {
            return baseline
        }
        return constrained
    }

    nonisolated func recommendedLocalContentLength(
        for conditions: LocalRuntimeConditions,
        reasoningMode: LocalReasoningMode = .fast
    ) -> Int {
        recommendedLocalContentLength(
            for: recommendedLocalTextModelID,
            conditions: conditions,
            reasoningMode: reasoningMode
        )
    }

    nonisolated func recommendedLocalContentLength(
        for model: LocalTextModelID,
        conditions: LocalRuntimeConditions,
        reasoningMode: LocalReasoningMode = .fast
    ) -> Int {
        _ = reasoningMode
        var total = min(maxRecommendedLocalContentLength, baseLocalRuntimeContentLength(for: model))
        if conditions.lowPowerModeEnabled {
            total = Int(Double(total) * 0.82)
        }
        if !conditions.appActive {
            total = Int(Double(total) * 0.72)
        }
        switch conditions.thermalState {
        case .nominal:
            break
        case .fair:
            total = Int(Double(total) * 0.92)
        case .serious:
            total = Int(Double(total) * 0.75)
        case .critical:
            total = Int(Double(total) * 0.60)
        }
        return max(1_800, total)
    }
}

// MARK: - Inference State
// Manages chat model availability and selection: Apple Intelligence,
// local models, cloud providers, and runtime conditions.

nonisolated final class InferenceKeychainClosureBox: @unchecked Sendable {
    let load: (String) -> String?
    let save: (String, String) -> Bool
    let delete: (String) -> Void

    init(
        load: @escaping (String) -> String?,
        save: @escaping (String, String) -> Bool,
        delete: @escaping (String) -> Void
    ) {
        self.load = load
        self.save = save
        self.delete = delete
    }
}

@MainActor @Observable
final class InferenceState {
    private nonisolated static let legacyRemoteDefaultsKeys = [
        "epistemos.apiProvider",
        "epistemos.kimiModel",
        "epistemos.ollamaBaseUrl",
        "epistemos.ollamaModel",
        "epistemos.preferredVoiceEngineID",
        "epistemos.preferredVoiceID",
        "epistemos.localAutoDownloadEnabled",
        "epistemos.smartRoutingEnabled",
        "epistemos.offlineOnlyEnabled",
        "epistemos.preferredFallbackLocalTextModelID",
    ]
    private nonisolated static let activeAIProviderDefaultsKey = "epistemos.activeAIProvider"
    private nonisolated static let lastNonLocalAIProviderDefaultsKey = "epistemos.lastNonLocalAIProvider"
    private nonisolated static let openAIWebSearchDefaultsKey = "epistemos.openAIWebSearchEnabled"
    private nonisolated static let openAICodeInterpreterDefaultsKey = "epistemos.openAICodeInterpreterEnabled"
    private nonisolated static let anthropicAdaptiveThinkingDefaultsKey = "epistemos.anthropicExtendedThinkingEnabled"
    private nonisolated static let anthropicWebSearchDefaultsKey = "epistemos.anthropicWebSearchEnabled"
    private nonisolated static let anthropicWebFetchDefaultsKey = "epistemos.anthropicWebFetchEnabled"
    private nonisolated static let anthropicCodeExecutionDefaultsKey = "epistemos.anthropicCodeExecutionEnabled"
    private nonisolated static let structuredJSONOutputDefaultsKey = "epistemos.structuredJSONOutputEnabled"
    private nonisolated static let googleGroundingDefaultsKey = "epistemos.googleGroundingEnabled"
    private nonisolated static let chatAutoRouteToCloudDefaultsKey = "epistemos.chatAutoRouteToCloud"
    private nonisolated static let cloudAutoFallbackDefaultsKey = "epistemos.cloudAutoFallback"
    /// Stores the user's preferred reasoning/thinking tier (off / standard
    /// / extended). Wire-level mapping to each provider's native field
    /// happens in LLMService; this key just holds the user's policy.
    private nonisolated static let chatReasoningTierDefaultsKey = "epistemos.chatReasoningTier"
    /// One-time migration flag: users who were pinned to OpenAI GPT-5.2
    /// when 5.2 was the flagship get bumped to GPT-5.4 (the current
    /// flagship per docs/MASTER_MODEL_STACK_PLAN.md). Users who later
    /// explicitly pick 5.2 again won't be migrated a second time because
    /// this flag persists.
    private nonisolated static let migratedOpenAI52To54DefaultsKey = "epistemos.migratedOpenAI52To54"
    private nonisolated static let firecrawlAPIKeyKeychainKey = "epistemos.firecrawl.apiKey"
    private nonisolated static let cloudSetupHintShownDefaultsKey = "epistemos.cloudSetupHintShown"
    private nonisolated static let cloudValidationTimeout: Duration = .seconds(90)
    private nonisolated static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private nonisolated static func defaultKeychainLoad(_ key: String) -> String? {
        guard !isRunningTests else { return nil }
        return Keychain.load(for: key)
    }

    private nonisolated static func defaultKeychainSave(_ value: String, _ key: String) -> Bool {
        guard !isRunningTests else { return false }
        return Keychain.save(value, for: key)
    }

    private nonisolated static func defaultKeychainDelete(_ key: String) {
        guard !isRunningTests else { return }
        Keychain.delete(for: key)
    }

    private nonisolated static func resolvedKeychainClosures(
        keychainLoad: @escaping (String) -> String? = InferenceState.defaultKeychainLoad,
        keychainSave: @escaping (String, String) -> Bool = InferenceState.defaultKeychainSave,
        keychainDelete: @escaping (String) -> Void = InferenceState.defaultKeychainDelete
    ) -> (
        load: @Sendable (String) -> String?,
        save: @Sendable (String, String) -> Bool,
        delete: @Sendable (String) -> Void
    ) {
        let box = InferenceKeychainClosureBox(
            load: keychainLoad,
            save: keychainSave,
            delete: keychainDelete
        )
        return (
            load: { key in box.load(key) },
            save: { value, key in box.save(value, key) },
            delete: { key in box.delete(key) }
        )
    }

    /// Transient image URLs for the current inference request.
    /// Set by ChatCoordinator before inference, consumed by MLXInferenceService, cleared after.
    var pendingImageURLs: [URL] = []

    var inferenceMode: InferenceMode {
        if pendingUnavailableCloudSelection != nil {
            return .api
        }
        switch preferredChatModelSelection {
        case .appleIntelligence: return .appleIntelligence
        case .localMLX: return .local
        case .cloud: return .api
        }
    }
    var routingMode: LocalRoutingMode = .auto
    /// When false (default), cloud requests use only the selected model and fail with
    /// a descriptive error instead of silently falling back to other models.
    /// When true, enables the automatic fallback chain across cloud providers and local models.
    var cloudAutoFallback: Bool = false
    var chatAutoRouteToCloud: Bool = false
    /// Owner 2026-06-18: model ids the user has explicitly force-loaded past the
    /// P1.4 memory blocker ("Run anyway"). The honest default keeps blocking;
    /// this is an EXPLICIT user-forced load (NOT a silent swap — fully allowed).
    /// Persisted so the choice survives restarts.
    private(set) var memoryGateForcedModelIDs: Set<String> = []
    // Owner 2026-06-18: the default chat model is a Fast GEMMA, never Qwen
    // (both Qwens are explicit-only picks). EpistemosFoundationLineup.defaultChatModelID
    // = the Fast tier representative (smallest Gemma GGUF).
    var preferredLocalTextModelID: String = EpistemosFoundationLineup.defaultChatModelID
    var preferredChatModelSelection: ChatModelSelection = .localMLX(
        EpistemosFoundationLineup.defaultChatModelID
    )
    var activeAIProvider: AIProviderSelection = .openAI
    private let keychainLoad: @Sendable (String) -> String?
    private let keychainSave: @Sendable (String, String) -> Bool
    private let keychainDelete: @Sendable (String) -> Void
    private let authService: CloudProviderAuthService
    private var isBootstrappingCloudCredentials = false
    private(set) var cachedCloudAPIKeys: [CloudModelProvider: String] = [:]
    private var missingCloudAPIKeyProviders: Set<CloudModelProvider> = []
    private(set) var cachedCloudOAuthCredentials: [CloudModelProvider: CloudProviderOAuthCredential] = [:]
    private var missingCloudOAuthProviders: Set<CloudModelProvider> = []
    private(set) var cloudProviderValidationStates: [CloudModelProvider: CloudProviderValidationState] = [:]
    private(set) var installedLocalTextModelIDs: Set<String> = []
    private(set) var preparedLocalTextModelIDs: Set<String> = []
    private(set) var availableLocalGenerationRuntimeKinds: Set<BackendRuntimeKind> = [.mlx]
    private(set) var localRuntimeConditions: LocalRuntimeConditions = LocalRuntimeConditions(
        lowPowerModeEnabled: false,
        appActive: true,
        thermalState: .nominal
    )
    private(set) var latestLocalRuntimeHealth: LocalRuntimeHealthSnapshot?
    private(set) var latestLocalRuntimeProfile: LocalMLXRunProfile?
    let hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot
    private let policyEngine = InferencePolicyEngine()

    var appleIntelligenceAvailable: Bool = false
    var appleIntelligenceUnavailableReason: String?

    /// Max tokens for user-visible chat responses. 0 = no cap (model default, ~16k).
    var chatOutputTokens: Int = 0
    var openAIWebSearchEnabled = false
    var openAICodeInterpreterEnabled = false
    var anthropicAdaptiveThinkingEnabled = false
    /// Whether Anthropic's hosted web-search tool is enabled on chat
    /// turns going through the `/v1/messages` endpoint. When true we
    /// attach the `web_search_20250305` server-side tool + required
    /// `anthropic-beta: web-search-2025-03-05` header. Fresh installs
    /// default this on so main chat can actually use provider-native
    /// search without a hidden settings trip, while an explicit false
    /// preference is still honored on reload.
    var anthropicWebSearchEnabled = false
    /// Anthropic's `web_fetch_20250910` beta — single-URL grounding.
    /// Complements web search: the model can pull a specific page the
    /// user mentioned (or that a prior turn's search surfaced) rather
    /// than having to re-search. Requires the matching
    /// `web-fetch-2025-09-10` beta header.
    var anthropicWebFetchEnabled = false
    /// Anthropic's `code_execution_20250825` beta — server-side Python
    /// sandbox for data analysis / plotting tasks. Parity sibling of
    /// OpenAI's `code_interpreter`. Requires the matching
    /// `code-execution-2025-08-25` beta header.
    var anthropicCodeExecutionEnabled = false
    /// Cross-provider "force JSON output" toggle. Attaches the right
    /// wire-level knob per provider so the model's reply is guaranteed
    /// valid JSON (OpenAI Responses `text.format`, Anthropic prompt
    /// nudge backed by `structured-outputs-2025-11-13`, Gemini
    /// `responseMimeType: application/json`, OpenAI chat-completions
    /// `response_format`). Off by default — enabling is a per-user
    /// preference for Pro/Agent JSON workflows.
    var structuredJSONOutputEnabled = false
    /// The user's current reasoning/thinking tier. Providers that
    /// support native reasoning map this to their own controls:
    /// OpenAI `reasoning.effort` + `text.verbosity`,
    /// Anthropic `thinking.type`/`effort`,
    /// Google `thinkingConfig.thinkingLevel`/`thinkingBudget`.
    var chatReasoningTier: ChatReasoningTier = .medium
    var googleGroundingEnabled = false
    private(set) var hasShownCloudSetupHint = false
    /// Observed mirror of the user's preferred cloud model per provider.
    /// `loadPreferredCloudModel` seeds entries lazily from UserDefaults;
    /// `persistPreferredCloudModel` writes here so SwiftUI observers
    /// (the chat picker's "selected" indicator) re-render immediately
    /// after a selection — without this @Observable mirror, the UI read
    /// straight from UserDefaults and missed the update.
    private(set) var observedPreferredCloudModels: [CloudModelProvider: CloudTextModelID] = [:]
    private var pendingUnavailableCloudSelection: CloudTextModelID?

    nonisolated static func shouldSkipCloudCredentialBootstrapOnLaunch(
        isRunningTests: Bool = InferenceState.isRunningTests,
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        !isRunningTests && !VaultSyncService.shouldRestoreVaultFromBookmark(
            processInfoEnvironment: processInfoEnvironment
        )
    }

    nonisolated static func shouldDeferCloudCredentialBootstrapOnLaunch(
        isRunningTests: Bool = InferenceState.isRunningTests,
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        !isRunningTests
            && !shouldSkipCloudCredentialBootstrapOnLaunch(
                isRunningTests: isRunningTests,
                processInfoEnvironment: processInfoEnvironment
            )
    }

    init(
        hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot = .current,
        keychainLoad: @escaping @Sendable (String) -> String? = InferenceState.defaultKeychainLoad,
        keychainSave: @escaping @Sendable (String, String) -> Bool = InferenceState.defaultKeychainSave,
        keychainDelete: @escaping @Sendable (String) -> Void = InferenceState.defaultKeychainDelete,
        deferCloudCredentialBootstrapOnLaunch: Bool = InferenceState.shouldDeferCloudCredentialBootstrapOnLaunch(),
        skipCloudCredentialBootstrapOnLaunch: Bool = InferenceState.shouldSkipCloudCredentialBootstrapOnLaunch()
    ) {
        let resolvedKeychainClosures = InferenceState.resolvedKeychainClosures(
            keychainLoad: keychainLoad,
            keychainSave: keychainSave,
            keychainDelete: keychainDelete
        )
        self.hardwareCapabilitySnapshot = hardwareCapabilitySnapshot
        self.keychainLoad = resolvedKeychainClosures.load
        self.keychainSave = resolvedKeychainClosures.save
        self.keychainDelete = resolvedKeychainClosures.delete
        self.preferredLocalTextModelID = hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue
        self.preferredChatModelSelection = .localMLX(
            hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue
        )
        self.localRuntimeConditions = .current()
        self.authService = CloudProviderAuthService(
            keychainLoad: resolvedKeychainClosures.load,
            keychainSave: resolvedKeychainClosures.save,
            keychainDelete: resolvedKeychainClosures.delete
        )

        // Keep Apple Intelligence passive on launch. Calling FoundationModels
        // availability can warm TokenGenerationCore/model assets, so the app
        // only probes it from explicit user work or a Settings refresh.
        self.appleIntelligenceAvailable = false
        self.appleIntelligenceUnavailableReason = nil
        if skipCloudCredentialBootstrapOnLaunch {
            initializeDeferredCloudCredentialState()
        } else if deferCloudCredentialBootstrapOnLaunch {
            initializeDeferredCloudCredentialState()
            startDeferredCloudCredentialBootstrap()
        } else {
            if Self.isRunningTests {
                refreshCachedCloudAPIKeys()
            } else {
                migrateLegacyCloudAPIKeysIfNeeded()
                refreshCachedCloudAPIKeys()
            }
        }

        let defaults = UserDefaults.standard
        Self.migrateLegacyOpenAI52To54(defaults: defaults)
        Self.migrateStaleGemma4Selection(defaults: defaults)
        if let saved = defaults.string(forKey: "epistemos.localRoutingMode"),
           let mode = LocalRoutingMode(rawValue: saved) {
            self.routingMode = mode
        } else if defaults.object(forKey: "epistemos.offlineOnlyEnabled") != nil,
                  defaults.bool(forKey: "epistemos.offlineOnlyEnabled") {
            self.routingMode = .localOnly
        }
        if let saved = defaults.string(forKey: "epistemos.preferredLocalTextModelID"),
           LocalTextModelID(rawValue: saved) != nil {
            self.preferredLocalTextModelID = saved
        }
        if let saved = defaults.string(forKey: "epistemos.preferredChatModelSelection"),
           let selection = ChatModelSelection(rawValue: saved) {
            // Honor the saved cloud selection even when the keychain /
            // OAuth check returns false at init time. The check races with
            // keychain cold-load and sandbox auth under real-world
            // conditions: users who sign in, quit, and relaunch have seen
            // their cloud selection silently revert to
            // `.localMLX(qwen3_4B)` and then watch GPT-5.4 turns route to
            // DeepSeek with a memory error that had nothing to do with
            // their actual problem. If credentials really are missing,
            // the next cloud turn will fail with a specific
            // "API key not configured" error — which is actionable and
            // doesn't lie about which model is active.
            self.preferredChatModelSelection = normalizedChatModelSelection(selection)
        } else if let migratedSelection = Self.migrateLegacyCloudSelection(defaults: defaults) {
            self.preferredChatModelSelection = normalizedChatModelSelection(migratedSelection)
            defaults.set(
                preferredChatModelSelection.rawValue,
                forKey: "epistemos.preferredChatModelSelection"
            )
        } else {
            self.preferredChatModelSelection = .localMLX(preferredLocalTextModelID)
        }
        if let savedProvider = defaults.string(forKey: Self.activeAIProviderDefaultsKey),
           let provider = AIProviderSelection(rawValue: savedProvider) {
            self.activeAIProvider = normalizedVisibleAIProvider(provider)
        } else if case .cloud(let model) = self.preferredChatModelSelection {
            self.activeAIProvider = AIProviderSelection(
                cloudProvider: normalizedVisibleCloudProvider(model.provider)
            )
        } else {
            self.activeAIProvider = .openAI
        }
        if case .cloud(let model) = self.preferredChatModelSelection {
            persistPreferredCloudModel(model, defaults: defaults)
            // Honor the user's explicit cloud pick. If activeAIProvider
            // is .localOnly, align the provider to match the selection
            // rather than silently reverting to local (which is exactly
            // the "selected GPT-5.4 but got DeepSeek" bug).
            if activeAIProvider == .localOnly || activeAIProvider.cloudProvider != model.provider {
                self.activeAIProvider = AIProviderSelection(cloudProvider: model.provider)
            }
        }
        self.chatOutputTokens = defaults.integer(forKey: "epistemos.chatOutputTokens")  // 0 if unset
        self.openAIWebSearchEnabled = Self.boolPreference(
            defaults: defaults,
            key: Self.openAIWebSearchDefaultsKey,
            defaultIfUnset: true
        )
        self.openAICodeInterpreterEnabled = defaults.bool(forKey: Self.openAICodeInterpreterDefaultsKey)
        self.anthropicAdaptiveThinkingEnabled = defaults.bool(forKey: Self.anthropicAdaptiveThinkingDefaultsKey)
        self.anthropicWebSearchEnabled = Self.boolPreference(
            defaults: defaults,
            key: Self.anthropicWebSearchDefaultsKey,
            defaultIfUnset: true
        )
        self.anthropicWebFetchEnabled = Self.boolPreference(
            defaults: defaults,
            key: Self.anthropicWebFetchDefaultsKey,
            defaultIfUnset: true
        )
        self.anthropicCodeExecutionEnabled = Self.boolPreference(
            defaults: defaults,
            key: Self.anthropicCodeExecutionDefaultsKey,
            defaultIfUnset: true
        )
        self.structuredJSONOutputEnabled = defaults.bool(forKey: Self.structuredJSONOutputDefaultsKey)
        // Migrating initializer honors old `"standard"` / `"extended"`
        // UserDefaults values (the pre-refactor tier names) by aliasing
        // them to the closest new tier — standard→medium, extended→high.
        // Falls through to the raw-value init for the current names.
        if let savedTier = defaults.string(forKey: Self.chatReasoningTierDefaultsKey),
           let tier = ChatReasoningTier(migrating: savedTier) {
            self.chatReasoningTier = tier
        }
        self.googleGroundingEnabled = Self.boolPreference(
            defaults: defaults,
            key: Self.googleGroundingDefaultsKey,
            defaultIfUnset: true
        )
        self.chatAutoRouteToCloud = Self.boolPreference(
            defaults: defaults,
            key: Self.chatAutoRouteToCloudDefaultsKey
        )
        self.cloudAutoFallback = defaults.bool(forKey: Self.cloudAutoFallbackDefaultsKey)
        self.hasShownCloudSetupHint = defaults.bool(forKey: Self.cloudSetupHintShownDefaultsKey)
        if let forced = defaults.array(forKey: Self.memoryGateForcedModelIDsKey) as? [String] {
            self.memoryGateForcedModelIDs = Set(forced)
        }

        Self.purgeLegacyRemoteConfiguration(defaults: defaults)
    }

    func refreshAppleIntelligenceAvailability() {
        let (available, reason) = AppleIntelligenceService.shared.checkAvailability()
        appleIntelligenceAvailable = available
        appleIntelligenceUnavailableReason = reason
    }

    private nonisolated static func boolPreference(
        defaults: UserDefaults,
        key: String,
        defaultIfUnset: Bool = false
    ) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultIfUnset
        }
        return defaults.bool(forKey: key)
    }

    static func purgeLegacyRemoteConfiguration(defaults: UserDefaults = .standard) {
        for key in legacyRemoteDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
    }

    private func migrateLegacyCloudAPIKeysIfNeeded() {
        Self.migrateLegacyCloudAPIKeysIfNeeded(
            keychainLoad: keychainLoad,
            keychainSave: keychainSave,
            keychainDelete: keychainDelete
        )
    }

    private func refreshCachedCloudAPIKeys() {
        applyCloudCredentialSnapshot(Self.loadCloudCredentialSnapshot(keychainLoad: keychainLoad))
        AppBootstrap.populateAgentCoreEnvironment(keychainLoad: keychainLoad)
    }

    private func initializeDeferredCloudCredentialState() {
        isBootstrappingCloudCredentials = true
        missingCloudAPIKeyProviders = Set(CloudModelProvider.allCases)
        missingCloudOAuthProviders = Set(CloudModelProvider.allCases)
        cachedCloudAPIKeys.removeAll()
        cachedCloudOAuthCredentials.removeAll()
        cloudProviderValidationStates = Dictionary(
            uniqueKeysWithValues: CloudModelProvider.allCases.map { ($0, .missing) }
        )
    }

    private func startDeferredCloudCredentialBootstrap() {
        guard isBootstrappingCloudCredentials else { return }
        let load = keychainLoad
        let save = keychainSave
        let delete = keychainDelete

        DispatchQueue.global(qos: .utility).async {
            Self.migrateLegacyCloudAPIKeysIfNeeded(
                keychainLoad: load,
                keychainSave: save,
                keychainDelete: delete
            )
            let snapshot = Self.loadCloudCredentialSnapshot(keychainLoad: load)
            AppBootstrap.populateAgentCoreEnvironment(keychainLoad: load)

            Task { @MainActor in
                self.applyCloudCredentialSnapshot(snapshot)
            }
        }
    }

    private func applyCloudCredentialSnapshot(_ snapshot: CloudCredentialSnapshot) {
        cachedCloudAPIKeys = snapshot.apiKeys
        missingCloudAPIKeyProviders = snapshot.missingAPIKeyProviders
        cachedCloudOAuthCredentials = snapshot.oauthCredentials
        missingCloudOAuthProviders = snapshot.missingOAuthProviders
        cloudProviderValidationStates = CloudModelProvider.allCases.reduce(into: [:]) { partialResult, provider in
            let hasConfiguredAccess = snapshot.apiKeys[provider] != nil
                || snapshot.oauthCredentials[provider] != nil
            partialResult[provider] = hasConfiguredAccess ? .unchecked : .missing
        }
        isBootstrappingCloudCredentials = false
    }

    private nonisolated static func migrateLegacyCloudAPIKeysIfNeeded(
        keychainLoad: (String) -> String?,
        keychainSave: (String, String) -> Bool,
        keychainDelete: (String) -> Void
    ) {
        for provider in CloudModelProvider.allCases {
            if let existing = keychainLoad(provider.apiKeyKeychainKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !existing.isEmpty {
                continue
            }

            for legacyKey in provider.legacyAPIKeyKeychainKeys {
                guard let legacyValue = keychainLoad(legacyKey)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !legacyValue.isEmpty else {
                    continue
                }

                guard keychainSave(legacyValue, provider.apiKeyKeychainKey) else { break }
                keychainDelete(legacyKey)
                break
            }
        }
    }

    private nonisolated static func loadCloudCredentialSnapshot(
        keychainLoad: (String) -> String?
    ) -> CloudCredentialSnapshot {
        var apiKeys: [CloudModelProvider: String] = [:]
        var missingAPIKeyProviders: Set<CloudModelProvider> = []
        var oauthCredentials: [CloudModelProvider: CloudProviderOAuthCredential] = [:]
        var missingOAuthProviders: Set<CloudModelProvider> = []

        for provider in CloudModelProvider.allCases {
            if let key = keychainLoad(provider.apiKeyKeychainKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !key.isEmpty {
                apiKeys[provider] = key
            } else {
                missingAPIKeyProviders.insert(provider)
            }

            if let rawValue = keychainLoad(provider.oauthKeychainKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !rawValue.isEmpty,
               let credential = CloudProviderOAuthCredential.decode(from: rawValue) {
                oauthCredentials[provider] = credential
            } else {
                missingOAuthProviders.insert(provider)
            }
        }

        return CloudCredentialSnapshot(
            apiKeys: apiKeys,
            missingAPIKeyProviders: missingAPIKeyProviders,
            oauthCredentials: oauthCredentials,
            missingOAuthProviders: missingOAuthProviders
        )
    }

    private struct CloudCredentialSnapshot: Sendable {
        let apiKeys: [CloudModelProvider: String]
        let missingAPIKeyProviders: Set<CloudModelProvider>
        let oauthCredentials: [CloudModelProvider: CloudProviderOAuthCredential]
        let missingOAuthProviders: Set<CloudModelProvider>
    }

    /// Migrate any persisted local-model selection that currently points
    /// at a Gemma 4 tier. Gemma 4 weights download but the Swift MLX
    /// loader isn't ported yet (see `isAwaitingSwiftRuntimeLoader`), so a
    /// user pinned to Gemma 4 hits a runtime "Unsupported model type:
    /// gemma4" error every turn. Move them to the documented default
    /// (the Fast Gemma GGUF — same family, and it actually runs via the GGUF
    /// lane) so chat works again; NOT gated by a one-time flag — if a user
    /// somehow re-pins to an MLX Gemma 4 tier before the loader lands, the next
    /// launch re-migrates them to the runnable Fast Gemma. (Owner 2026-06-18:
    /// never migrate to Qwen — the default is a Fast Gemma.)
    nonisolated static func migrateStaleGemma4Selection(defaults: UserDefaults) {
        let fallbackLocalModelID = EpistemosFoundationLineup.defaultChatModelID

        let localKey = "epistemos.preferredLocalTextModelID"
        if let saved = defaults.string(forKey: localKey),
           let model = LocalTextModelID(rawValue: saved),
           model.isAwaitingSwiftRuntimeLoader {
            defaults.set(fallbackLocalModelID, forKey: localKey)
        }

        let selectionKey = "epistemos.preferredChatModelSelection"
        if let saved = defaults.string(forKey: selectionKey),
           case .localMLX(let modelID) = ChatModelSelection(rawValue: saved) ?? .appleIntelligence,
           let model = LocalTextModelID(rawValue: modelID),
           model.isAwaitingSwiftRuntimeLoader {
            defaults.set(
                ChatModelSelection.localMLX(fallbackLocalModelID).rawValue,
                forKey: selectionKey
            )
        }
    }

    /// One-time migration from the legacy OpenAI GPT-5.2 default to the
    /// current GPT-5.4 flagship. Runs once per install (gated by a
    /// UserDefaults flag) and only flips persisted values that are
    /// exactly `.openAIGPT52`; users who explicitly pick 5.2 after the
    /// migration flag is set keep their choice.
    nonisolated static func migrateLegacyOpenAI52To54(defaults: UserDefaults) {
        guard !defaults.bool(forKey: migratedOpenAI52To54DefaultsKey) else { return }
        defer { defaults.set(true, forKey: migratedOpenAI52To54DefaultsKey) }

        let preferredKey = preferredCloudModelDefaultsKey(for: .openAI)
        if defaults.string(forKey: preferredKey) == CloudTextModelID.openAIGPT52.rawValue {
            defaults.set(CloudTextModelID.openAIGPT54.rawValue, forKey: preferredKey)
        }

        let selectionKey = "epistemos.preferredChatModelSelection"
        let legacyRaw = ChatModelSelection.cloud(.openAIGPT52).rawValue
        if defaults.string(forKey: selectionKey) == legacyRaw {
            defaults.set(
                ChatModelSelection.cloud(.openAIGPT54).rawValue,
                forKey: selectionKey
            )
        }
    }

    private nonisolated static func migrateLegacyCloudSelection(
        defaults: UserDefaults
    ) -> ChatModelSelection? {
        guard let legacyProvider = defaults.string(forKey: "epistemos.apiProvider")?.lowercased() else {
            return nil
        }

        let modelKey: String
        switch legacyProvider {
        case "openai":
            modelKey = "epistemos.openaiModel"
        case "anthropic":
            modelKey = "epistemos.anthropicModel"
        case "google":
            modelKey = "epistemos.googleModel"
        default:
            return nil
        }

        guard let legacyModel = defaults.string(forKey: modelKey),
              let model = CloudTextModelID.from(rawValueOrVendorID: legacyModel) else {
            return nil
        }
        return .cloud(model)
    }

    private nonisolated static func preferredCloudModelDefaultsKey(
        for provider: CloudModelProvider
    ) -> String {
        "epistemos.preferredCloudModel.\(provider.rawValue)"
    }

    private func loadPreferredCloudModel(for provider: CloudModelProvider) -> CloudTextModelID {
        // Read the observed mirror first so SwiftUI dependencies register
        // on every read; falls back to UserDefaults on the cold path.
        if let cached = observedPreferredCloudModels[provider] {
            return normalizedPreferredCloudModel(cached)
        }
        let defaults = UserDefaults.standard
        let resolved: CloudTextModelID = {
            if let saved = defaults.string(forKey: Self.preferredCloudModelDefaultsKey(for: provider)),
               let model = CloudTextModelID.from(rawValueOrVendorID: saved),
               model.provider == provider {
                return model
            }
            return provider.defaultChatModel
        }()
        observedPreferredCloudModels[provider] = resolved
        return normalizedPreferredCloudModel(resolved)
    }

    /// Public read of the user's preferred cloud model for a given
    /// provider. Used by the simplified chat model picker to surface a
    /// single cloud row without exposing every CloudTextModelID.
    func preferredCloudModel(for provider: CloudModelProvider) -> CloudTextModelID {
        loadPreferredCloudModel(for: provider)
    }

    private func persistPreferredCloudModel(
        _ model: CloudTextModelID,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(
            model.rawValue,
            forKey: Self.preferredCloudModelDefaultsKey(for: model.provider)
        )
        // Publish to the @Observable mirror so the chat picker refreshes
        // immediately — the old direct-UserDefaults read never triggered
        // a SwiftUI update, which looked like "I can't change the model".
        observedPreferredCloudModels[model.provider] = model
    }

    private func persistActiveAIProvider(
        _ provider: AIProviderSelection,
        defaults: UserDefaults = .standard
    ) {
        let normalizedProvider = normalizedVisibleAIProvider(provider)
        activeAIProvider = normalizedProvider
        defaults.set(normalizedProvider.rawValue, forKey: Self.activeAIProviderDefaultsKey)
        if normalizedProvider != .localOnly {
            defaults.set(
                normalizedProvider.rawValue,
                forKey: Self.lastNonLocalAIProviderDefaultsKey
            )
        }
    }

    private func lastNonLocalAIProvider(
        defaults: UserDefaults = .standard
    ) -> AIProviderSelection {
        if let savedProvider = defaults.string(forKey: Self.lastNonLocalAIProviderDefaultsKey),
           let provider = AIProviderSelection(rawValue: savedProvider),
           provider != .localOnly {
            return normalizedVisibleAIProvider(provider)
        }
        return .openAI
    }


    var localModelInstallStateSummary: LocalModelInstallStateSummary {
        if !supportedInstalledLocalTextModels.isEmpty {
            return .installed
        }
        if !supportedPreparedLocalTextModels.isEmpty {
            return .prepared
        }
        return .none
    }

    var localRuntimeFallbackMode: LocalInferenceSerialFallbackMode? {
        guard let rawValue = currentLocalRuntimeHealth?.fallbackMode else {
            return nil
        }
        guard let mode = LocalInferenceSerialFallbackMode(rawValue: rawValue),
              mode == .ssdStreaming else {
            return nil
        }
        return mode
    }

    var localRuntimeStatusSummary: String {
        guard let currentLocalRuntimeHealth else {
            return hasUsableLocalTextModel
                ? "Idle until the next local request."
                : "No local runtime activity yet."
        }

        if localRuntimeFallbackMode == .ssdStreaming {
            return "SSD streaming fallback active"
        }

        let modelLabel = LocalTextModelID(rawValue: currentLocalRuntimeHealth.modelID)?.compactDisplayName
            ?? currentLocalRuntimeHealth.modelID

        switch currentLocalRuntimeHealth.resolvedRuntimeKind {
        case .gguf:
            return "GGUF local runtime (\(modelLabel))"
        case .mlx:
            return "Resident local runtime (\(modelLabel))"
        case .remote:
            return "Remote runtime (\(modelLabel))"
        }
    }

    var localRuntimeStatusDetail: String? {
        guard let currentLocalRuntimeHealth else {
            return nil
        }

        let phaseLabel = currentLocalRuntimeHealth.executionPhase
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        if let availableMemoryBytes = currentLocalRuntimeHealth.availableMemoryBytes {
            let memoryLabel = ByteCountFormatter.string(
                fromByteCount: Int64(clamping: availableMemoryBytes),
                countStyle: .memory
            )
            return "\(phaseLabel) - available \(memoryLabel)"
        }

        if let runtimeResourceURL = currentLocalRuntimeHealth.runtimeResourceURL {
            if runtimeResourceURL.isFileURL {
                return "\(phaseLabel) - model \(runtimeResourceURL.lastPathComponent)"
            }
            return "\(phaseLabel) - endpoint \(runtimeResourceURL.absoluteString)"
        }

        return phaseLabel
    }

    var localRuntimeLastRunSummary: String? {
        guard let currentLocalRuntimeHealth else {
            return nil
        }

        let rawDuration = currentLocalRuntimeHealth.totalDurationMS.rounded()
        let totalDuration = rawDuration.isFinite ? Int(rawDuration) : 0
        if let firstToken = currentLocalRuntimeHealth.timeToFirstTokenMS {
            let ftMs = firstToken.rounded()
            return "First token \(ftMs.isFinite ? Int(ftMs) : 0) ms, total \(totalDuration) ms"
        }
        return "Completed in \(totalDuration) ms"
    }

    private var currentLocalRuntimeHealth: LocalRuntimeHealthSnapshot? {
        latestLocalRuntimeHealth ?? latestLocalRuntimeProfile.map(LocalRuntimeHealthSnapshot.init)
    }

    var policyContext: InferencePolicyContext {
        InferencePolicyContext(
            routingMode: routingMode,
            appleIntelligenceAvailable: appleIntelligenceAvailable,
            cloudAutoRouteEnabled: chatAutoRouteToCloud,
            hasConfiguredCloudModels: hasConfiguredCloudModels,
            preferredChatModelSelection: preferredChatModelSelection,
            preferredLocalTextModelID: sanitizedInteractiveLocalTextModelID(
                for: preferredLocalTextModelID
            ) ?? preferredLocalTextModelID,
            installedLocalTextModelIDs: Set(releaseSelectableInstalledLocalTextModelIDs),
            hardwareCapabilitySnapshot: hardwareCapabilitySnapshot,
            runtimeConditions: localRuntimeConditions
        )
    }

    private var supportedInstalledLocalTextModels: [LocalTextModelID] {
        supportedInteractiveLocalTextModels(
            from: installedLocalTextModelIDs
        )
    }

    private var supportedPreparedLocalTextModels: [LocalTextModelID] {
        supportedInteractiveLocalTextModels(
            from: preparedLocalTextModelIDs
        )
    }

    private var supportedAvailableLocalTextModels: [LocalTextModelID] {
        supportedInteractiveLocalTextModels(
            from: installedLocalTextModelIDs.union(preparedLocalTextModelIDs)
        )
    }

    private var supportedAvailableGemmaQATRuntimeCandidates: [GemmaQATRuntimeCandidate] {
        supportedGemmaQATRuntimeCandidates(
            from: installedLocalTextModelIDs.union(preparedLocalTextModelIDs)
        )
    }

    private var qwen3UnifiedPickerPairAvailable: Bool {
        // The legacy "Qwen 3" unified Fast/Think pair is disabled under the
        // simplified Fast/Think/Code lineup — the modes bind to the foundation
        // models (Gemma / VibeThinker / coder), never Qwen.
        guard !EpistemosFoundationLineup.simplifiedLineupActive else { return false }
        return supportedAvailableLocalTextModels.contains(.qwen3_4B4Bit)
            && supportedAvailableLocalTextModels.contains(.qwen3_4BThinking25074Bit)
    }

    private func normalizedReleaseSelectableLocalTextModelID(_ modelID: String) -> String {
        guard qwen3UnifiedPickerPairAvailable,
              let model = LocalTextModelID(rawValue: modelID) else {
            return modelID
        }
        switch model {
        case .qwen3_4BThinking25074Bit:
            return LocalTextModelID.qwen3_4B4Bit.rawValue
        default:
            return modelID
        }
    }

    private var supportedAvailableLocalAgentModels: [LocalTextModelID] {
        let models = supportedLocalAgentTextModels(
            from: installedLocalTextModelIDs.union(preparedLocalTextModelIDs)
        )
        // Owner hotfix 2026-06-17f — NO hidden Qwen on the agent/tool/attachment
        // seam. Under the simplified lineup the user picks a foundation tier
        // (Fast→Gemma, Think→VibeThinker, Code→coder); the tool loop must NEVER
        // resurrect a still-installed non-foundation MLX agent model (a legacy
        // Qwen 3 8B) to back that turn — the reported "Qwen 3 8B needs ~12 GB …
        // pick Qwen 3 4B" blocker came from exactly this fallback. Foundation
        // tiers are GGUF (not LocalTextModelID enum cases), so this filters to an
        // empty set and the tool loop honestly degrades to a direct stream on the
        // SELECTED foundation model (or routes to cloud) instead of a hidden
        // swap. If a future foundation model is an enum + agent-capable, it is
        // kept (tier(forModelID:) != nil); everything else is dropped.
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return models }
        return models.filter { EpistemosFoundationLineup.tier(forModelID: $0.rawValue) != nil }
    }

    private func supportedInteractiveLocalTextModels(
        from ids: Set<String>
    ) -> [LocalTextModelID] {
        let supportedModels = ids
            .compactMap(LocalTextModelID.init(rawValue:))
            .filter {
                availableLocalGenerationRuntimeKinds.contains($0.runtimeKind)
                    && hardwareCapabilitySnapshot.supportsInteractiveChatModel(textModelID: $0.rawValue)
                    && $0.isReleaseValidatedForInteractiveChat
            }
            .sorted { lhs, rhs in
                if lhs.minimumRecommendedMemoryGB == rhs.minimumRecommendedMemoryGB {
                    return lhs.rawValue < rhs.rawValue
                }
                return lhs.minimumRecommendedMemoryGB < rhs.minimumRecommendedMemoryGB
            }
        let shippedModels = supportedModels.filter(\.isEpistemosShippedLocalModel)
        return shippedModels.isEmpty ? supportedModels : shippedModels
    }

    private func supportedLocalAgentTextModels(
        from ids: Set<String>
    ) -> [LocalTextModelID] {
        let supportedModels = ids
            .compactMap(LocalTextModelID.init(rawValue:))
            .filter {
                availableLocalGenerationRuntimeKinds.contains($0.runtimeKind)
                    && hardwareCapabilitySnapshot.supportsInteractiveChatModel(textModelID: $0.rawValue)
                    && $0.isReleaseValidatedForLocalAgentLoop
                    && $0.canRunLocalAgentLoop
            }
            .sorted { lhs, rhs in
                if lhs.agentToolTier.priority == rhs.agentToolTier.priority {
                    if lhs.minimumRecommendedMemoryGB == rhs.minimumRecommendedMemoryGB {
                        return lhs.rawValue < rhs.rawValue
                    }
                    return lhs.minimumRecommendedMemoryGB > rhs.minimumRecommendedMemoryGB
                }
                return lhs.agentToolTier.priority > rhs.agentToolTier.priority
            }
        let shippedModels = supportedModels.filter(\.isEpistemosShippedLocalModel)
        return shippedModels.isEmpty ? supportedModels : shippedModels
    }

    private func supportedGemmaQATRuntimeCandidates(
        from ids: Set<String>
    ) -> [GemmaQATRuntimeCandidate] {
        guard availableLocalGenerationRuntimeKinds.contains(.gguf) else { return [] }
        // Selectability policy (owner-approved 2026-06-16): ANY *installed*
        // foundation GGUF candidate the hardware supports is manually
        // selectable — the user explicitly downloaded it and it rides the
        // proven llama-cli runtime. `ids` here is the installed∪prepared set
        // (incl. on-disk active/ detection), so reaching this filter already
        // means installed. The route-evidence proof chain
        // (`isProductRouteIntegrationCandidate`) still gates *auto-routing* /
        // default-route authority (TriageService, AppBootstrap availability
        // probe, ladder statics) — it no longer blocks a manual pick. This is
        // what makes VibeThinker (Think) and the 12B coder (Code) — both
        // receipt-pending — selectable alongside the proof-complete Gemmas.
        return ids
            .compactMap(GemmaQATRuntimeLadder.candidate(forID:))
            .filter { candidate in
                guard let descriptor = LocalModelCatalog.descriptor(for: candidate.id) else {
                    return false
                }
                return hardwareCapabilitySnapshot.supports(descriptor: descriptor)
            }
            .sorted { lhs, rhs in
                if lhs.minimumRecommendedMemoryGB == rhs.minimumRecommendedMemoryGB {
                    return lhs.id < rhs.id
                }
                return lhs.minimumRecommendedMemoryGB < rhs.minimumRecommendedMemoryGB
            }
    }

    func setAvailableLocalGenerationRuntimeKinds(_ runtimeKinds: Set<BackendRuntimeKind>) {
        availableLocalGenerationRuntimeKinds = runtimeKinds.isEmpty ? [.mlx] : runtimeKinds
        sanitizeStoredLocalChatSelectionIfNeeded()
    }

    /// True once at least one Epistemos foundation GGUF model (Gemma /
    /// VibeThinker / coder) is installed and hardware-supported. Gates the
    /// simplified-lineup behaviors — picker curation AND the branded
    /// Fast/Think/Code mode tiers — so nothing changes before the foundation
    /// package lands (the picker is never empty, legacy tests that install no
    /// GGUF keep their model-derived mode set).
    var hasInstalledFoundationModel: Bool {
        !supportedAvailableGemmaQATRuntimeCandidates.isEmpty
    }

    var releaseSelectableInstalledLocalTextModelIDs: [String] {
        var seen: Set<String> = []
        let gguf = supportedAvailableGemmaQATRuntimeCandidates.map(\.id)
        // Simplified Fast/Think/Code lineup: once at least one foundation GGUF
        // model is installed, hide the legacy non-foundation MLX chat models so
        // the picker shows only the Epistemos lineup (Gemma / VibeThinker /
        // coder). Until a foundation model is installed, keep the legacy models
        // so the picker is never empty. Internal helper models are unaffected
        // (they are not chat-picker entries). Reversible via
        // EPISTEMOS_SIMPLIFIED_LINEUP=0.
        let hideLegacyMLX = EpistemosFoundationLineup.simplifiedLineupActive && hasInstalledFoundationModel
        let mlx = hideLegacyMLX
            ? []
            : supportedAvailableLocalTextModels
                .map(\.rawValue)
                .map(normalizedReleaseSelectableLocalTextModelID)
        return (mlx + gguf).filter { seen.insert($0).inserted }
    }

    var releaseHiddenInstalledLocalTextModelCount: Int {
        installedLocalTextModelIDs
            .union(preparedLocalTextModelIDs)
            .compactMap(LocalTextModelID.init(rawValue:))
            .filter {
                hardwareCapabilitySnapshot.supports(textModelID: $0.rawValue)
                    && !$0.isReleaseValidatedForInteractiveChat
            }
            .count
    }

    var effectiveLocalTextModelID: String? {
        sanitizedInteractiveLocalTextModelID(for: preferredLocalTextModelID)
    }

    private func effectiveLocalTextModelID(for operatingMode: EpistemosOperatingMode) -> String? {
        guard let baseModelID = effectiveLocalTextModelID else { return nil }

        // Buttons-become-tiers (owner decision 2026-06-16): a tier mode binds to
        // its foundation model — Fast→Gemma, Think→VibeThinker, Code→coder.
        // Tools/agent has no model tier. Respect the user's within-tier pick:
        // if their current selection already belongs to this tier (e.g. they
        // chose a specific Gemma size under Fast), keep it; only switch when the
        // selection is in a DIFFERENT tier.
        if EpistemosFoundationLineup.simplifiedLineupActive,
           let tier = operatingMode.epistemosModelTier {
            if EpistemosFoundationLineup.tier(forModelID: baseModelID) == tier {
                // Respect the within-tier pick — EXCEPT for Fast, where a
                // memory-tight pick (the 12B on a 16 GB Mac) defeats "quick."
                // When the pinned Fast model doesn't fit with comfortable
                // headroom, fall to the tier's headroom-aware default (E4B on
                // 16 GB). This is the root of "Gemma 12B is always selected" —
                // a stored 12B kept sticking even though Fast should stay light.
                // Picks that DO fit (any size on a roomy Mac) are still honored.
                if tier == .fast,
                   let descriptor = LocalModelCatalog.descriptor(for: baseModelID),
                   hardwareCapabilitySnapshot.roundedMemoryGB < descriptor.minimumRecommendedMemoryGB + 4,
                   let headroomDefault = installedFoundationModelID(for: .fast) {
                    return headroomDefault
                }
                return baseModelID
            }
            if let tierModelID = installedFoundationModelID(for: tier) {
                return tierModelID
            }
            // Owner hotfix 2026-06-17: once the foundation lineup is live (≥1
            // foundation model installed), a foundation tier whose OWN model is
            // not installed must NOT fall through to a different tier's model.
            // Think is VibeThinker-3B; it must NEVER resolve (or later label /
            // prompt) as a Fast Gemma 4 12B, and Code must never serve a Fast
            // Gemma either. Return nil so the surface is honestly "not ready"
            // (Send disabled / install-the-tier / route to cloud) instead of
            // silently serving the wrong-tier model. Gemma 4 12B is only ever
            // Fast's hard-query size or the Code/coder tier — never Think.
            // (Pre-foundation legacy MLX-only setups still fall through below so
            // nothing breaks before the foundation package lands.)
            if hasInstalledFoundationModel {
                return nil
            }
        }

        guard qwen3UnifiedPickerPairAvailable,
              let baseModel = LocalTextModelID(rawValue: baseModelID),
              baseModel == .qwen3_4B4Bit || baseModel == .qwen3_4BThinking25074Bit else {
            return baseModelID
        }

        switch operatingMode {
        case .thinking:
            return LocalTextModelID.qwen3_4BThinking25074Bit.rawValue
        case .fast, .pro, .agent:
            return LocalTextModelID.qwen3_4B4Bit.rawValue
        }
    }

    /// The foundation model a tier mode auto-selects when the user switches into
    /// it from a different tier, or nil if none is installed/fits. Think and Code
    /// have a single model. Fast has three Gemma sizes: it auto-picks the largest
    /// that fits *with memory headroom* so "Fast" stays quick — e.g. on a 16 GB
    /// Mac 12B fits but with no headroom, so Fast defaults to E4B; 12B stays
    /// explicitly selectable (and is the target for high-complexity per-query
    /// routing, a follow-up). The user's within-tier pick is always respected by
    /// the caller, so this only sets the cross-tier default.
    private func installedFoundationModelID(for tier: EpistemosModelTier) -> String? {
        let installed = installedLocalTextModelIDs.union(preparedLocalTextModelIDs)
        let fitting = EpistemosFoundationLineup.candidates(for: tier)
            .filter { installed.contains($0.id) }
            .filter { candidate in
                guard let descriptor = LocalModelCatalog.descriptor(for: candidate.id) else {
                    return false
                }
                return hardwareCapabilitySnapshot.supports(descriptor: descriptor)
            }
        guard !fitting.isEmpty else { return nil }

        // Fast: prefer the largest model that fits with comfortable headroom so
        // the "quick" tier doesn't default to the heaviest (memory-tight) model.
        if tier == .fast {
            let headroomGB = 4
            let comfortable = fitting.filter {
                hardwareCapabilitySnapshot.roundedMemoryGB >= $0.minimumRecommendedMemoryGB + headroomGB
            }
            if let best = comfortable.max(by: { $0.minimumRecommendedMemoryGB < $1.minimumRecommendedMemoryGB }) {
                return best.id
            }
        }

        return fitting.max { $0.minimumRecommendedMemoryGB < $1.minimumRecommendedMemoryGB }?.id
    }

    /// P1.5 — Fast "three efforts" per-query sizing. When the simplified lineup
    /// is active and the operating mode is the Fast tier AND the user is on the
    /// tier's headroom-aware default (not a deliberate smaller within-Fast pick),
    /// choose the Gemma size proportional to the query's analyzed `complexity`
    /// (0...1) among the installed candidates that fit the current hardware *with
    /// headroom*. Returns `nil` when sizing does not apply, so the caller keeps
    /// the default resolution.
    ///
    /// Never returns a memory-tight model: the candidate pool is the same
    /// comfortable-fit set the Fast default is drawn from
    /// (`installedFoundationModelID(for: .fast)`), so on a 16 GB Mac sizing walks
    /// E2B ↔ E4B (the 12B is excluded for headroom) while a 64 GB Mac can reach
    /// the 12B for hard queries. An explicit within-Fast pick (Advanced →
    /// Models) is honored — it resolves to a model that is *not* the tier
    /// default, so the guard below skips sizing and the pick stands.
    func sizedFastLocalTextModelID(
        forComplexity complexity: Double,
        operatingMode: EpistemosOperatingMode
    ) -> String? {
        guard EpistemosFoundationLineup.simplifiedLineupActive,
              operatingMode.epistemosModelTier == .fast else { return nil }
        let candidates = comfortableInstalledFastCandidatesAscending()
        guard candidates.count > 1 else { return nil }
        // Only auto-size when the user is on the tier default. The default is the
        // comfortable-fit max (== `candidates.last`, == the migrated stored pick);
        // a deliberate smaller pick resolves to a different id and is left alone.
        guard let resolved = effectiveLocalTextModelID(for: operatingMode),
              resolved == candidates.last?.id else { return nil }
        let index = EpistemosFastEffortSizing.candidateIndex(
            forComplexity: complexity,
            candidateCount: candidates.count
        )
        return candidates[index].id
    }

    /// P1.9 — human-readable Fast effort + the model it sized to, for the
    /// composer / picker / route-reason diagnostics. Returns e.g. "Fast · Medium
    /// effort → Gemma 4 E4B QAT GGUF" when the Fast tier sizes this query, or nil
    /// when sizing doesn't apply (non-Fast tier, explicit pick, <2 candidates) so
    /// the caller can hide the hint. Makes "why E2B vs E4B vs 12B" visible without
    /// making the raw model choice the required UX.
    func fastEffortRouteReason(
        forComplexity complexity: Double,
        operatingMode: EpistemosOperatingMode
    ) -> String? {
        guard let sized = sizedFastLocalTextModelID(
            forComplexity: complexity,
            operatingMode: operatingMode
        ) else { return nil }
        let effort = EpistemosFastEffortSizing.effort(forComplexity: complexity)
        return "Fast · \(effort.displayName) effort → \(localModelPickerDisplayName(for: sized))"
    }

    /// Installed Fast-tier foundation candidates that fit the current hardware
    /// with comfortable headroom, ascending by recommended memory. Mirrors the
    /// headroom-aware filter `installedFoundationModelID(for: .fast)` draws its
    /// default from, so per-query sizing never selects a model the default
    /// resolution would reject as memory-tight.
    private func comfortableInstalledFastCandidatesAscending() -> [GemmaQATRuntimeCandidate] {
        let installed = installedLocalTextModelIDs.union(preparedLocalTextModelIDs)
        let headroomGB = 4
        return EpistemosFoundationLineup.candidates(for: .fast)
            .filter { installed.contains($0.id) }
            .filter { candidate in
                guard let descriptor = LocalModelCatalog.descriptor(for: candidate.id) else {
                    return false
                }
                return hardwareCapabilitySnapshot.supports(descriptor: descriptor)
                    && hardwareCapabilitySnapshot.roundedMemoryGB
                        >= candidate.minimumRecommendedMemoryGB + headroomGB
            }
    }

    /// P1.4 — honest local-runtime blocker (#43). When the resolved primary chat
    /// model for `operatingMode` is a local model that cannot load into the
    /// current free-memory budget, returns a one-line reason for the composer to
    /// show (and to disable Send on). Returns `nil` when the model fits, when the
    /// selection is cloud / Apple Intelligence, or when memory data is
    /// unavailable — we never block silently and never block on missing data, and
    /// we never swap to a different model behind the user's back.
    ///
    /// For the Fast tier (P1.5 per-query sizing can drop to the smallest Gemma)
    /// the gate checks the smallest installed Fast size, so we only block when
    /// even that can't run — a trivial query the E2B would answer is never
    /// refused.
    /// The model id the P1.4 memory blocker gates for this mode (mirrors the
    /// blocker's resolution: the smallest installed Fast candidate under the
    /// simplified lineup, else the effective selection). nil when no local model
    /// is selected. Shared by the blocker and the "Run anyway" override so they
    /// always target the same model.
    func memoryGateModelID(for operatingMode: EpistemosOperatingMode) -> String? {
        guard case .localMLX(let resolvedModelID) = effectiveChatSurfaceSelection(for: operatingMode) else {
            return nil
        }
        if EpistemosFoundationLineup.simplifiedLineupActive,
           operatingMode.epistemosModelTier == .fast,
           let smallestFast = comfortableInstalledFastCandidatesAscending().first?.id {
            return smallestFast
        }
        return resolvedModelID
    }

    func localChatModelMemoryBlocker(for operatingMode: EpistemosOperatingMode) -> String? {
        guard let modelID = memoryGateModelID(for: operatingMode) else { return nil }
        // Owner 2026-06-18: an explicit "Run anyway" force-load overrides the
        // gate for this model — the user accepted the slow/swap risk. Honest:
        // it's a deliberate, recorded choice, not a silent substitution.
        if memoryGateForcedModelIDs.contains(modelID) { return nil }
        guard let requiredGB = LocalModelCatalog.descriptor(for: modelID)?.minimumRecommendedMemoryGB,
              requiredGB > 0 else { return nil }
        let availableBytes = latestLocalRuntimeHealth?.availableMemoryBytes
            ?? LocalInferenceMemoryPressureMonitor.availableMemoryBytes()
        guard availableBytes > 0 else { return nil }
        let availableGB = Int(availableBytes / 1_073_741_824)
        guard !LocalChatModelMemoryGate.fits(requiredGB: requiredGB, availableGB: availableGB) else {
            return nil
        }
        return LocalChatModelMemoryGate.blockerReason(
            modelDisplayName: localModelPickerDisplayName(for: modelID),
            requiredGB: requiredGB,
            availableGB: availableGB
        )
    }

    func localModelPickerDisplayName(for modelID: String) -> String {
        if qwen3UnifiedPickerPairAvailable,
           let model = LocalTextModelID(rawValue: modelID),
           model == .qwen3_4B4Bit || model == .qwen3_4BThinking25074Bit {
            return "Qwen 3"
        }
        return localRouteDisplayName(for: modelID)
    }

    private func localRouteDisplayName(for modelID: String) -> String {
        LocalTextModelID(rawValue: modelID)?.displayName
            ?? GemmaQATRuntimeLadder.candidate(forID: modelID)?.displayName
            ?? modelID
    }

    var effectiveLocalAgentTextModelID: String? {
        let strongestInstalledAgentModel = supportedAvailableLocalAgentModels.first
        let strongestFittingAgentModel = supportedAvailableLocalAgentModels.first(
            where: localAgentModelFitsCurrentMemoryBudget(_:)
        )
        if let interactiveModelID = effectiveLocalTextModelID,
           let interactiveModel = LocalTextModelID(rawValue: interactiveModelID),
           interactiveModel.canRunLocalAgentLoop {
            if let strongestFittingAgentModel,
               shouldPreferDedicatedLocalAgentModel(
                strongestFittingAgentModel,
                over: interactiveModel
               ) {
                return strongestFittingAgentModel.rawValue
            }
            return interactiveModelID
        }
        return strongestFittingAgentModel?.rawValue ?? strongestInstalledAgentModel?.rawValue
    }

    /// The strongest installed agent-capable local model that ACTUALLY fits the
    /// current memory budget, or `nil` when none fit. Unlike
    /// `effectiveLocalAgentTextModelID` — which falls back to the strongest
    /// *installed* agent model even when it would OOM — this never names a model
    /// that cannot load right now. The hidden agent tier uses it to decide
    /// whether it can legitimately back a non-agent chat selection (e.g. a GGUF
    /// Gemma) for tool execution. When it returns `nil`, the caller must degrade
    /// to a direct stream on the selected model rather than silently swapping to
    /// a model that will OOM — the user-reported "routed to Qwen again" bug
    /// (Qwen 3 8B needs ~12 GB but only ~2 GB is free while Gemma 12B is
    /// resident).
    var fittingLocalAgentTextModelID: String? {
        if let interactiveModelID = effectiveLocalTextModelID,
           let interactiveModel = LocalTextModelID(rawValue: interactiveModelID),
           interactiveModel.canRunLocalAgentLoop,
           localAgentModelFitsCurrentMemoryBudget(interactiveModel) {
            let strongestFittingAgentModel = supportedAvailableLocalAgentModels.first(
                where: localAgentModelFitsCurrentMemoryBudget(_:)
            )
            if let strongestFittingAgentModel,
               shouldPreferDedicatedLocalAgentModel(
                strongestFittingAgentModel,
                over: interactiveModel
               ) {
                return strongestFittingAgentModel.rawValue
            }
            return interactiveModelID
        }
        return supportedAvailableLocalAgentModels.first(
            where: localAgentModelFitsCurrentMemoryBudget(_:)
        )?.rawValue
    }

    private func shouldPreferDedicatedLocalAgentModel(
        _ candidate: LocalTextModelID,
        over interactiveModel: LocalTextModelID
    ) -> Bool {
        guard candidate != interactiveModel else { return false }
        guard interactiveModel.primaryUseCase == .routing else { return false }
        return candidate.primaryUseCase != .routing
    }

    private func localAgentModelFitsCurrentMemoryBudget(_ model: LocalTextModelID) -> Bool {
        let requiredGB = model.minimumRecommendedInteractiveMemoryGB
        guard requiredGB > 0 else { return true }

        let availableBytes = latestLocalRuntimeHealth?.availableMemoryBytes
            ?? LocalInferenceMemoryPressureMonitor.availableMemoryBytes()
        guard availableBytes > 0 else { return true }

        let bytesPerGB: UInt64 = 1_073_741_824
        let availableGB = Int(availableBytes / bytesPerGB)
        let headroomGB = 6
        return availableGB + headroomGB >= requiredGB
    }

    var hasUsableLocalTextModel: Bool {
        effectiveLocalTextModelID != nil
    }

    var supportsLocalAgentLoop: Bool {
        effectiveLocalAgentTextModelID != nil
    }

    var chatAutoRouteActive: Bool {
        usesAutomaticCloudRouteForChatSurfaces
    }

    private func baseOperatingModeCapabilities(
        for selection: ChatModelSelection
    ) -> OperatingModeCapabilities {
        switch selection {
        case .appleIntelligence:
            return OperatingModeCapabilities(availableModes: [.fast])
        case .cloud(let model):
            return OperatingModeCapabilities(availableModes: model.supportedOperatingModes)
        case .localMLX(let modelID):
            let activeModelID = LocalTextModelID(rawValue: modelID) != nil ? modelID : activeLocalTextModelID
            guard let activeModelID,
                  let model = LocalTextModelID(
                    rawValue: normalizedReleaseSelectableLocalTextModelID(activeModelID)
                  ) else {
                return OperatingModeCapabilities(availableModes: [.fast])
            }
            if qwen3UnifiedPickerPairAvailable,
               model == .qwen3_4B4Bit {
                var modes: [EpistemosOperatingMode] = [.fast, .thinking]
                if model.canRunLocalAgentLoop {
                    modes.append(.agent)
                }
                return OperatingModeCapabilities(availableModes: modes)
            }
            var modes: [EpistemosOperatingMode] = []
            if !model.cannotDisableThinkingInFast {
                modes.append(.fast)
            }
            if model.supportsThinkingMode {
                modes.append(.thinking)
            }
            if model.canRunLocalAgentLoop {
                modes.append(.agent)
            }
            return OperatingModeCapabilities(availableModes: modes.isEmpty ? [.fast] : modes)
        }
    }

    private var baseOperatingModeCapabilities: OperatingModeCapabilities {
        baseOperatingModeCapabilities(for: preferredChatModelSelection)
    }

    private var usesAutomaticCloudRouteForChatSurfaces: Bool {
        chatAutoRouteToCloud
            && preferredAutoRouteCloudProvider != nil
            && {
                switch preferredChatModelSelection {
                case .cloud:
                    return false
                case .localMLX(let modelID):
                    return effectiveLocalTextModelID == nil
                        || sanitizedStoredLocalChatModelID(for: modelID) != modelID
                case .appleIntelligence:
                    return true
                }
            }()
    }

    /// Human-readable label for whichever model will actually serve a turn
    /// at this operating mode — the Perplexity-style "effective model" so
    /// the UI can render a small badge on each assistant message. Matches
    /// the resolution logic of effectiveChatSurfaceSelection.
    func effectiveModelLabel(for operatingMode: EpistemosOperatingMode) -> String {
        switch effectiveChatSurfaceSelection(for: operatingMode) {
        case .appleIntelligence:
            return "Apple Intelligence"
        case .localMLX(let modelID):
            return localRouteDisplayName(for: modelID)
        case .cloud(let model):
            return "\(runtimeProviderDisplayName(for: model.provider)) \(model.displayName)"
        }
    }

    func availableReasoningTiers(for operatingMode: EpistemosOperatingMode) -> [ChatReasoningTier] {
        switch effectiveChatSurfaceSelection(for: operatingMode) {
        case .cloud(let model):
            return model.availableReasoningTiers(for: operatingMode)
        case .appleIntelligence, .localMLX:
            return operatingMode.availableReasoningTiers
        }
    }

    func sanitizedReasoningTier(
        _ tier: ChatReasoningTier,
        for operatingMode: EpistemosOperatingMode
    ) -> ChatReasoningTier {
        switch effectiveChatSurfaceSelection(for: operatingMode) {
        case .cloud(let model):
            return model.sanitizedReasoningTier(tier, for: operatingMode)
        case .appleIntelligence, .localMLX:
            return operatingMode.sanitizedReasoningTier(tier)
        }
    }

    func reasoningTierLabel(
        for tier: ChatReasoningTier,
        operatingMode: EpistemosOperatingMode
    ) -> String {
        switch effectiveChatSurfaceSelection(for: operatingMode) {
        case .cloud(let model):
            return model.reasoningTierLabel(for: tier, operatingMode: operatingMode)
        case .appleIntelligence, .localMLX:
            return operatingMode.reasoningTierLabel(for: tier)
        }
    }

    func runtimeProviderDisplayName(for provider: CloudModelProvider) -> String {
        switch provider {
        case .openAI where openAIUsesCodexAccountRuntime:
            return "Codex"
        case .anthropic where anthropicUsesClaudeCodeAccountRuntime:
            return "Claude Code"
        default:
            return provider.displayName
        }
    }

    func runtimeControlTitle(for provider: CloudModelProvider) -> String {
        switch provider {
        case .openAI where openAIUsesCodexAccountRuntime:
            return "Codex"
        case .anthropic where anthropicUsesClaudeCodeAccountRuntime:
            return "Claude Code"
        case .anthropic:
            return "Claude"
        default:
            return provider.displayName
        }
    }

    func effectiveChatSurfaceSelection(for operatingMode: EpistemosOperatingMode) -> ChatModelSelection {
        if let pendingSelection = pendingUnavailableCloudIntentSelection(for: operatingMode) {
            return pendingSelection
        }

        if usesAutomaticCloudRouteForChatSurfaces,
           let autoModel = preferredAutoRouteCloudModel(for: operatingMode) {
            // Auto-route to the cloud workhorse ONLY when the user has not
            // explicitly pinned a runnable local/cloud tier. Apple
            // Intelligence acts as the local-first baseline for auto-route,
            // not as a higher-priority pin.
            let userHasExplicitPin: Bool = {
                switch preferredChatModelSelection {
                case .localMLX(let modelID):
                    return sanitizedStoredLocalChatModelID(for: modelID) == modelID
                        && effectiveLocalTextModelID != nil
                case .appleIntelligence:
                    return false
                case .cloud:
                    return true
                }
            }()

            if !userHasExplicitPin {
                switch operatingMode {
                case .pro:
                    // LOCAL FOR ALL MODES (owner mandate 2026-06-18): Code/Pro
                    // stays on the local coder tier when one can serve; cloud is
                    // an escalation only when NO local model (nor Apple
                    // Intelligence) can — mirrors .fast/.thinking/.agent. Closes
                    // the hidden-GPT route for Code: picking Code with a working
                    // local coder no longer silently routes to cloud.
                    if effectiveLocalTextModelID(for: operatingMode) == nil
                        && !appleIntelligenceAvailable {
                        return .cloud(autoModel)
                    }
                case .agent:
                    // LOCAL FOR ALL MODES (owner mandate 2026-06-18): Act must
                    // NEVER silently route to GPT/cloud when the owner has a
                    // local agent-capable model. Cloud auto-route is an
                    // escalation, not an override of a working local agent loop
                    // — fall to cloud ONLY when no local model can actually run
                    // the agent loop (mirrors the .fast guard below). When a
                    // local agent model exists, fall through to the local
                    // resolution at the bottom, which returns
                    // `.localMLX(effectiveLocalAgentTextModelID)`.
                    if effectiveLocalAgentTextModelID == nil {
                        return .cloud(autoModel)
                    }
                case .thinking:
                    // LOCAL FOR ALL MODES (owner mandate 2026-06-18): Think stays
                    // on the local reasoning tier when one can serve; cloud is an
                    // escalation only when none can — mirrors .fast/.pro/.agent.
                    // Closes the hidden-GPT route for Think.
                    if effectiveLocalTextModelID(for: operatingMode) == nil
                        && !appleIntelligenceAvailable {
                        return .cloud(autoModel)
                    }
                case .fast:
                    if effectiveLocalTextModelID == nil && !appleIntelligenceAvailable {
                        return .cloud(autoModel)
                    }
                }
            }
        }

        // Owner hotfix 2026-06-17: under the simplified lineup a foundation tier
        // must present as ITS OWN model. When the tier's model isn't installed,
        // `effectiveLocalTextModelID(for:)` is nil — but the generic `.localMLX`
        // fallback below would surface the raw stored CROSS-TIER pick (e.g. a
        // Fast Gemma 4 12B) for Think/Code. Pin to the tier's representative id
        // instead so the label, route, and readiness check all read as the
        // correct tier (VibeThinker for Think, coder for Code, smallest Gemma for
        // Fast) and the surface is honestly "not ready" until that model is
        // installed — never a wrong-tier Gemma. Skipped for `.agent` (no model
        // tier) and whenever the tier resolves normally (non-nil above).
        if EpistemosFoundationLineup.simplifiedLineupActive,
           case .localMLX = preferredChatModelSelection,
           let tier = operatingMode.epistemosModelTier,
           effectiveLocalTextModelID(for: operatingMode) == nil,
           let representative = EpistemosFoundationLineup.representativeModelID(for: tier) {
            return .localMLX(representative)
        }

        switch preferredChatModelSelection {
        case .localMLX:
            if operatingMode == .agent,
               let agentModelID = effectiveLocalAgentTextModelID {
                return .localMLX(agentModelID)
            }
            if let activeLocalTextModelID = effectiveLocalTextModelID(for: operatingMode) {
                return .localMLX(activeLocalTextModelID)
            }
            if appleIntelligenceAvailable {
                return .appleIntelligence
            }
            return preferredChatModelSelection
        case .appleIntelligence:
            if appleIntelligenceAvailable {
                return .appleIntelligence
            }
            if operatingMode == .agent,
               let agentModelID = effectiveLocalAgentTextModelID {
                return .localMLX(agentModelID)
            }
            if let activeLocalTextModelID = effectiveLocalTextModelID(for: operatingMode) {
                return .localMLX(activeLocalTextModelID)
            }
            return preferredChatModelSelection
        case .cloud:
            return preferredChatModelSelection
        }
    }

    func isChatSurfaceRuntimeReady(for operatingMode: EpistemosOperatingMode) -> Bool {
        switch effectiveChatSurfaceSelection(for: operatingMode) {
        case .appleIntelligence:
            return appleIntelligenceAvailable
        case .cloud(let model):
            return hasConfiguredCloudAccess(for: model.provider)
        case .localMLX:
            return effectiveLocalTextModelID(for: operatingMode) != nil
        }
    }

    func capabilityToolNames(
        for operatingMode: EpistemosOperatingMode,
        executionPlan: OverseerComplexityRouter.ExecutionPlan? = nil
    ) -> [String] {
        var names = executionPlan.map(\.allowedToolNames) ?? Set<String>()
        names.formUnion(
            providerNativeCapabilityToolNames(
                for: effectiveChatSurfaceSelection(for: operatingMode)
            )
        )
        return Array(names).sorted()
    }

    /// Sorted list of provider-native tools the current cloud
    /// selection actually attaches to direct-stream requests (web
    /// search, code execution, etc.). Used by the direct-stream
    /// manifest path so it only advertises tools the runtime can
    /// honor, not app tools the Rust agent would otherwise execute.
    func providerNativeCapabilityToolNameList(
        for operatingMode: EpistemosOperatingMode
    ) -> [String] {
        let selection = capabilityPreviewSelection(for: operatingMode)
        return Array(providerNativeCapabilityToolNames(for: selection)).sorted()
    }

    func providerNativeCapabilityToolNameList(
        for selection: ChatModelSelection
    ) -> [String] {
        Array(providerNativeCapabilityToolNames(for: selection)).sorted()
    }

    private func providerNativeCapabilityToolNames(
        for selection: ChatModelSelection
    ) -> Set<String> {
        guard case .cloud(let model) = selection else { return [] }

        var names: Set<String> = []
        switch model.provider {
        case .openAI:
            if openAIWebSearchEnabled {
                names.insert("web_search")
            }
        case .anthropic:
            if anthropicWebSearchEnabled {
                names.insert("web_search")
            }
            if anthropicWebFetchEnabled {
                names.insert("web_fetch")
            }
            if anthropicCodeExecutionEnabled {
                names.insert("code_execution")
            }
        case .google:
            if googleGroundingEnabled {
                names.insert("google_search")
            }
        case .zai, .kimi, .minimax, .deepseek:
            break
        }
        return names
    }

    var preferredAutoRouteCloudProvider: CloudModelProvider? {
        guard chatAutoRouteToCloud else { return nil }

        var candidates: [CloudModelProvider] = []
        if let active = activeAIProvider.cloudProvider {
            candidates.append(normalizedVisibleCloudProvider(active))
        }
        if let last = lastNonLocalAIProvider().cloudProvider {
            candidates.append(normalizedVisibleCloudProvider(last))
        }
        candidates.append(contentsOf: CloudModelProvider.preferredOrder)

        var seen: Set<CloudModelProvider> = []
        for provider in candidates where seen.insert(provider).inserted {
            guard hasConfiguredCloudAccess(for: provider) else { continue }
            return provider
        }
        return nil
    }

    func preferredAutoRouteCloudModel(for operatingMode: EpistemosOperatingMode) -> CloudTextModelID? {
        guard let provider = preferredAutoRouteCloudProvider else { return nil }
        let preferredModel = loadPreferredCloudModel(for: provider)
        if preferredModel.supportedOperatingModes.contains(operatingMode) {
            return compatibleCloudModel(
                preferredModel.resolvedModel(for: operatingMode),
                for: operatingMode
            )
        }
        return compatibleCloudModel(
            provider.recommendedFallbackCloudModel(operatingMode),
            for: operatingMode
        )
    }

    private var automaticCloudOperatingModes: [EpistemosOperatingMode] {
        guard usesAutomaticCloudRouteForChatSurfaces else { return [] }
        return EpistemosOperatingMode.allCases.filter { mode in
            preferredAutoRouteCloudModel(for: mode) != nil
        }
    }

    private var unavailableCloudPreviewOperatingModes: [EpistemosOperatingMode] {
        guard let model = pendingUnavailableCloudSelection else { return [] }
        return model.supportedOperatingModes
    }

    private var chatSurfaceSelections: [ChatModelSelection] {
        var selections: [ChatModelSelection] = [preferredChatModelSelection]
        if usesAutomaticCloudRouteForChatSurfaces {
            selections.append(contentsOf: EpistemosOperatingMode.allCases.compactMap { mode in
                preferredAutoRouteCloudModel(for: mode).map(ChatModelSelection.cloud)
            })
        }

        var seen: Set<String> = []
        return selections.filter { selection in
            seen.insert(selection.rawValue).inserted
        }
    }

    var operatingModeCapabilities: OperatingModeCapabilities {
        var mergedModes = Set(baseOperatingModeCapabilities.availableModes)
        mergedModes.formUnion(unavailableCloudPreviewOperatingModes)
        mergedModes.formUnion(automaticCloudOperatingModes)
        // Simplified lineup (owner 2026-06-16): the three Epistemos efforts —
        // Fast / Think / Code — ARE the picker. They are always offered as
        // branded tiers, each binding to its foundation model (Fast→Gemma,
        // Think→VibeThinker, Code→coder) and gracefully using the best installed
        // foundation model until its dedicated model lands. Without this, a GGUF
        // Gemma selection can't map to a LocalTextModelID in
        // `baseOperatingModeCapabilities`, so the picker collapsed to Fast-only
        // (the "I only see Fast" report). `.agent` (Tools) still comes from the
        // cloud merges above when an agent route exists. Gated on an installed
        // foundation model so legacy MLX-only setups (and tests that install no
        // GGUF) keep their model-derived mode set unchanged.
        if EpistemosFoundationLineup.simplifiedLineupActive, hasInstalledFoundationModel {
            mergedModes.formUnion([.fast, .thinking, .pro])
        }
        let orderedModes = EpistemosOperatingMode.allCases.filter { mergedModes.contains($0) }
        return OperatingModeCapabilities(availableModes: orderedModes.isEmpty ? [.fast] : orderedModes)
    }

    var availableOperatingModes: [EpistemosOperatingMode] {
        operatingModeCapabilities.availableModes
    }

    func availableOperatingModes(
        for selection: ChatModelSelection
    ) -> [EpistemosOperatingMode] {
        baseOperatingModeCapabilities(for: selection).availableModes
    }

    var supportsThinkingOperatingMode: Bool {
        operatingModeCapabilities.supportsThinking
    }

    func sanitizedOperatingMode(_ mode: EpistemosOperatingMode) -> EpistemosOperatingMode {
        guard availableOperatingModes.contains(mode) else {
            return availableOperatingModes.first ?? .fast
        }
        return mode
    }

    var activeLocalTextModelID: String? {
        return effectiveLocalTextModelID
    }

    var activeLocalTextModelDisplayName: String {
        guard let modelID = activeLocalTextModelID else {
            return "Local Model"
        }
        return localRouteDisplayName(for: modelID)
    }

    var activeChatModelDisplayName: String {
        // Owner #1 (no hidden GPT route, 2026-06-18): an explicit LOCAL pick must
        // show the local model name — never "Auto Route" or a cloud/GPT fallback.
        // Previously the `usesAutomaticCloudRouteForChatSurfaces` check fired FIRST
        // and returned "Auto Route" for ANY selection, so a user who picked a local
        // model saw "Auto Route" (read as "showing GPT, not my local"). Auto-route
        // may still escalate the chat stack to cloud, but the user's PICK is local,
        // so the row reflects it; only a genuine cloud/Apple pick shows "Auto Route".
        switch preferredChatModelSelection {
        case .localMLX:
            return activeLocalTextModelDisplayName
        case .appleIntelligence, .cloud:
            return usesAutomaticCloudRouteForChatSurfaces ? "Auto Route" : preferredChatModelSelection.displayName
        }
    }

    func chatSurfaceRouteDescription(
        for operatingMode: EpistemosOperatingMode
    ) -> ChatSurfaceRouteDescription {
        let selection = effectiveChatSurfaceSelection(for: operatingMode)
        let headline = selection.compactDisplayName
        let summary: String = {
            switch selection {
            case .appleIntelligence:
                return usesAutomaticCloudRouteForChatSurfaces
                    ? "\(operatingMode.displayName) stays on Apple Intelligence until a cloud escalation is needed."
                    : "\(operatingMode.displayName) runs directly on Apple Intelligence."
            case .localMLX(let modelID):
                let label = localRouteDisplayName(for: modelID)
                return usesAutomaticCloudRouteForChatSurfaces
                    ? "\(operatingMode.displayName) stays local on \(label) unless the chat stack needs a cloud escalation."
                    : "\(operatingMode.displayName) runs directly on \(label)."
            case .cloud(let model):
                let providerLabel = runtimeProviderDisplayName(for: model.provider)
                return usesAutomaticCloudRouteForChatSurfaces
                    ? "\(operatingMode.displayName) escalates to \(model.displayName) on \(providerLabel)."
                    : "\(operatingMode.displayName) runs directly on \(model.displayName) on \(providerLabel)."
            }
        }()
        let systemImage: String = {
            switch selection {
            case .appleIntelligence:
                "apple.logo"
            case .localMLX:
                "memorychip"
            case .cloud(let model):
                model.provider.systemImage
            }
        }()
        return ChatSurfaceRouteDescription(
            operatingMode: operatingMode,
            selection: selection,
            headline: headline,
            summary: summary,
            systemImage: systemImage,
            usesAutomaticRouting: usesAutomaticCloudRouteForChatSurfaces
        )
    }

    var chatSurfaceMaxContextTokens: Int {
        chatSurfaceMaxContextTokens(for: .fast)
    }

    func chatSurfaceMaxContextTokens(for operatingMode: EpistemosOperatingMode) -> Int {
        effectiveChatSurfaceSelection(for: operatingMode).activeMaxContextTokens
    }

    var chatSurfaceSupportsVision: Bool {
        chatSurfaceSupportsVision(for: .fast)
    }

    func chatSurfaceSupportsVision(for operatingMode: EpistemosOperatingMode) -> Bool {
        effectiveChatSurfaceSelection(for: operatingMode).activeSupportsVision
    }

    var chatSurfaceSupportedFileTypes: Set<AttachmentType> {
        chatSurfaceSupportedFileTypes(for: .fast)
    }

    func chatSurfaceSupportedFileTypes(for operatingMode: EpistemosOperatingMode) -> Set<AttachmentType> {
        effectiveChatSurfaceSelection(for: operatingMode).activeSupportedFileTypes
    }

    var activeCloudProvider: CloudModelProvider? {
        activeAIProvider.cloudProvider
    }

    var cloudModelsEnabled: Bool {
        activeAIProvider != .localOnly
    }

    var activeCloudModels: [CloudTextModelID] {
        guard let provider = activeCloudProvider else { return [] }
        if provider == .openAI, openAIUsesCodexAccountRuntime {
            return supportedCloudModels(for: provider)
        }
        return CloudTextModelID.models(for: provider)
    }

    func cloudModels(for provider: CloudModelProvider) -> [CloudTextModelID] {
        supportedCloudModels(for: provider)
    }

    var configuredCloudProviders: [CloudModelProvider] {
        CloudModelProvider.preferredOrder.filter { provider in
            hasConfiguredCloudAccess(for: provider)
        }
    }

    var visibleModelVaultModelIDs: Set<String> {
        var modelIDs: Set<String> = ["apple-intelligence"]
        for provider in configuredCloudProviders {
            modelIDs.formUnion(cloudModels(for: provider).map(\.vendorModelID))
        }
        modelIDs.formUnion(releaseSelectableInstalledLocalTextModelIDs)
        return modelIDs
    }

    func modelVaultTargets() -> [ModelVaultTarget] {
        var targets: [ModelVaultTarget] = [
            ModelVaultTarget(
                modelID: "apple-intelligence",
                displayName: "Apple Intelligence",
                conceptLimit: 12,
                activeWindowDays: 7
            )
        ]

        for provider in configuredCloudProviders {
            targets.append(
                contentsOf: cloudModels(for: provider).map {
                    ModelVaultTarget(
                        modelID: $0.vendorModelID,
                        displayName: $0.displayName,
                        conceptLimit: 60,
                        activeWindowDays: 7
                    )
                }
            )
        }

        targets.append(
            contentsOf: LocalModelCatalog.allDescriptors
                .filter { descriptor in
                    guard releaseSelectableInstalledLocalTextModelIDs.contains(descriptor.id),
                          let model = LocalTextModelID(rawValue: descriptor.id) else {
                        return false
                    }
                    return model.isReleaseValidatedForInteractiveChat
                }
                .map {
                    ModelVaultTarget(
                        modelID: $0.id,
                        displayName: $0.displayName,
                        conceptLimit: 24,
                        activeWindowDays: 7
                    )
                }
        )

        // Owner 2026-06-18 (per-model vaults, part 1): the loop above only sees
        // LocalTextModelID-backed models, so it MISSES the foundation GGUF chat
        // lane — the runnable Gemma / VibeThinker / coder tiers, which are
        // descriptor IDs (`google/gemma-4-…-gguf`), NOT enum cases (the MLX
        // gemma4 enum IDs are honestly excluded above because their Swift loader
        // errors). `supportedAvailableGemmaQATRuntimeCandidates` is exactly the
        // INSTALLED + hardware-supported foundation candidates, so each real
        // foundation model now gets its own vault target. Honest: vision-only or
        // not-installed models never appear here; dedup below drops any overlap.
        targets.append(
            contentsOf: supportedAvailableGemmaQATRuntimeCandidates.map {
                ModelVaultTarget(
                    modelID: $0.id,
                    displayName: $0.displayName,
                    conceptLimit: 24,
                    activeWindowDays: 7
                )
            }
        )

        var seen = Set<String>()
        return targets.filter { seen.insert($0.modelID).inserted }
    }

    var hasConfiguredCloudModels: Bool {
        !configuredCloudProviders.isEmpty
    }

    var isDeferredCloudCredentialBootstrapInFlight: Bool {
        isBootstrappingCloudCredentials
    }

    var shouldShowCloudSetupHint: Bool {
        !hasShownCloudSetupHint && !isBootstrappingCloudCredentials && !hasConfiguredCloudModels
    }

    /// Read-only lookup. Must NOT mutate any `@Observable` state — SwiftUI
    /// views read this during `body` evaluation, and any mutation would
    /// invalidate the same body that just read it (classic infinite-layout
    /// loop via `StackLayout.sizeThatFits`). Cache population happens in
    /// explicit refresh paths: `applyCloudCredentialSnapshot`, `setAPIKey`,
    /// `clearAPIKey`. If no snapshot has landed yet, a cache miss falls
    /// through to a transient keychain read; callers get a correct answer
    /// and observable state stays stable.
    func apiKey(for provider: CloudModelProvider) -> String? {
        if let cached = cachedCloudAPIKeys[provider] {
            return cached
        }
        guard !missingCloudAPIKeyProviders.contains(provider) else {
            return nil
        }
        guard let key = keychainLoad(provider.apiKeyKeychainKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return nil
        }
        return key
    }

    /// Read-only lookup. Same SwiftUI-safety contract as `apiKey(for:)`.
    /// Cache writes happen only on explicit refresh / set / clear paths.
    func oauthCredential(for provider: CloudModelProvider) -> CloudProviderOAuthCredential? {
        if let cached = cachedCloudOAuthCredentials[provider] {
            return cached
        }
        guard !missingCloudOAuthProviders.contains(provider) else {
            return nil
        }
        guard let rawValue = keychainLoad(provider.oauthKeychainKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              let credential = CloudProviderOAuthCredential.decode(from: rawValue) else {
            return nil
        }
        return credential
    }

    func resolvedCloudCredential(for provider: CloudModelProvider) async throws -> CloudProviderResolvedCredential {
        try await authService.resolvedCredential(
            for: provider,
            apiKey: apiKey(for: provider)
        )
    }

    func cloudValidationState(for provider: CloudModelProvider) -> CloudProviderValidationState {
        cloudProviderValidationStates[provider] ?? .missing
    }

    func resetCloudProviderValidationState(for provider: CloudModelProvider) {
        cloudProviderValidationStates[provider] = hasConfiguredCloudAccess(for: provider)
            ? .unchecked
            : .missing
    }

    private func hasConfiguredAPIKey(for provider: CloudModelProvider) -> Bool {
        guard let value = apiKey(for: provider)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !value.isEmpty
    }

    func hasConfiguredCloudAccess(for provider: CloudModelProvider) -> Bool {
        if hasConfiguredAPIKey(for: provider) {
            return true
        }
        return oauthCredential(for: provider) != nil
    }

    private func persistPreferredChatModelSelection(_ selection: ChatModelSelection) {
        let normalizedSelection = normalizedChatModelSelection(selection)
        if case .localMLX(let modelID) = normalizedSelection {
            let persistedModelID = sanitizedStoredLocalChatModelID(for: modelID)
            preferredChatModelSelection = .localMLX(persistedModelID)
            UserDefaults.standard.set(
                preferredChatModelSelection.rawValue,
                forKey: "epistemos.preferredChatModelSelection"
            )
            preferredLocalTextModelID = persistedModelID
            UserDefaults.standard.set(
                persistedModelID,
                forKey: "epistemos.preferredLocalTextModelID"
            )
        } else {
            preferredChatModelSelection = normalizedSelection
            UserDefaults.standard.set(
                normalizedSelection.rawValue,
                forKey: "epistemos.preferredChatModelSelection"
            )
        }

        if case .cloud(let model) = normalizedSelection {
            persistPreferredCloudModel(model)
            persistActiveAIProvider(AIProviderSelection(cloudProvider: model.provider))
        }
    }

    @discardableResult
    func setAPIKey(_ value: String, for provider: CloudModelProvider) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            keychainDelete(provider.apiKeyKeychainKey)
            cachedCloudAPIKeys.removeValue(forKey: provider)
            missingCloudAPIKeyProviders.insert(provider)
            AppBootstrap.populateAgentCoreEnvironment(keychainLoad: keychainLoad)
            cloudProviderValidationStates[provider] = hasConfiguredCloudAccess(for: provider)
                ? .unchecked
                : .missing
            if case .cloud(let model) = preferredChatModelSelection,
               model.provider == provider,
               !hasConfiguredCloudAccess(for: provider) {
                persistPreferredChatModelSelection(.localMLX(preferredLocalTextModelID))
            }
            return true
        }
        if Self.isRunningTests {
            cachedCloudAPIKeys[provider] = trimmed
            missingCloudAPIKeyProviders.remove(provider)
            cloudProviderValidationStates[provider] = .unchecked
            return true
        }
        let didSave = keychainSave(trimmed, provider.apiKeyKeychainKey)
        if didSave {
            cachedCloudAPIKeys[provider] = trimmed
            missingCloudAPIKeyProviders.remove(provider)
            AppBootstrap.populateAgentCoreEnvironment(keychainLoad: keychainLoad)
            cloudProviderValidationStates[provider] = .unchecked
        } else {
            cloudProviderValidationStates[provider] = .invalid(
                message: "Couldn't store this key in the Apple Keychain.",
                checkedAt: Date()
            )
        }
        return didSave
    }

    @discardableResult
    func setOAuthCredential(_ credential: CloudProviderOAuthCredential?, for provider: CloudModelProvider) -> Bool {
        guard let credential else {
            keychainDelete(provider.oauthKeychainKey)
            cachedCloudOAuthCredentials.removeValue(forKey: provider)
            missingCloudOAuthProviders.insert(provider)
            AppBootstrap.populateAgentCoreEnvironment(keychainLoad: keychainLoad)
            cloudProviderValidationStates[provider] = hasConfiguredCloudAccess(for: provider)
                ? .unchecked
                : .missing
            if case .cloud(let model) = preferredChatModelSelection,
               model.provider == provider,
               !hasConfiguredCloudAccess(for: provider) {
                persistPreferredChatModelSelection(.localMLX(preferredLocalTextModelID))
            }
            return true
        }

        let didSave = authService.storeOAuthCredential(credential)
        if didSave {
            cachedCloudOAuthCredentials[provider] = credential
            missingCloudOAuthProviders.remove(provider)
            AppBootstrap.populateAgentCoreEnvironment(keychainLoad: keychainLoad)
            cloudProviderValidationStates[provider] = .unchecked
            if case .cloud(let model) = preferredChatModelSelection,
               model.provider == provider {
                persistPreferredChatModelSelection(.cloud(model))
            }
        } else {
            cloudProviderValidationStates[provider] = .invalid(
                message: "Couldn't store this account session in the Apple Keychain.",
                checkedAt: Date()
            )
        }
        return didSave
    }

    func validateCloudAccess(for provider: CloudModelProvider) async -> ConnectionTestResult {
        guard hasConfiguredCloudAccess(for: provider) else {
            cloudProviderValidationStates[provider] = .missing
            return ConnectionTestResult(
                success: false,
                message: provider.supportsAccountConnection
                    ? "No \(provider.displayName) account session or API key is saved yet."
                    : "No \(provider.displayName) API key is saved yet."
            )
        }

        cloudProviderValidationStates[provider] = .checking
        let result = await withCloudValidationTimeout(for: provider) {
            await CloudLLMClient(inference: self).testConnection(provider: provider)
        }
        let checkedAt = Date()
        cloudProviderValidationStates[provider] = result.success
            ? .valid(message: result.message, checkedAt: checkedAt)
            : .invalid(message: result.message, checkedAt: checkedAt)
        return result
    }

    private func withCloudValidationTimeout(
        for provider: CloudModelProvider,
        operation: @escaping @MainActor @Sendable () async -> ConnectionTestResult
    ) async -> ConnectionTestResult {
        let timeoutMessage = "\(provider.displayName) verification timed out after 90 seconds. Retry to run another live check."
        let validationTask = Task { @MainActor in
            await operation()
        }
        defer { validationTask.cancel() }

        return await withTaskGroup(of: ConnectionTestResult.self) { group in
            group.addTask {
                await validationTask.value
            }
            group.addTask {
                try? await Task.sleep(for: Self.cloudValidationTimeout)
                return ConnectionTestResult(success: false, message: timeoutMessage)
            }

            let result = await group.next() ?? ConnectionTestResult(
                success: false,
                message: timeoutMessage
            )
            group.cancelAll()
            return result
        }
    }

    func validateAPIKey(for provider: CloudModelProvider) async -> ConnectionTestResult {
        await validateCloudAccess(for: provider)
    }

    func recordCloudProviderValidationFailure(
        for provider: CloudModelProvider,
        message: String
    ) -> ConnectionTestResult {
        cloudProviderValidationStates[provider] = .invalid(
            message: message,
            checkedAt: Date()
        )
        return ConnectionTestResult(success: false, message: message)
    }

    func signInToOpenAI(
        onDeviceCodeReady: @escaping @MainActor @Sendable (OpenAIDeviceAuthorization) -> Void = { _ in }
    ) async -> ConnectionTestResult {
        cloudProviderValidationStates[.openAI] = .checking
        do {
            try await authService.signInToOpenAI(onDeviceCodeReady: onDeviceCodeReady)
            refreshCachedCloudAPIKeys()
            return await validateCloudAccess(for: .openAI)
        } catch {
            let checkedAt = Date()
            cloudProviderValidationStates[.openAI] = .invalid(
                message: error.localizedDescription,
                checkedAt: checkedAt
            )
            return ConnectionTestResult(success: false, message: error.localizedDescription)
        }
    }

    func importOpenAIAccount() async -> ConnectionTestResult {
        cloudProviderValidationStates[.openAI] = .checking
        guard authService.importOpenAICodexCLIIfPresent() else {
            let message = "No Codex account session was found in ~/.codex/auth.json."
            cloudProviderValidationStates[.openAI] = .invalid(
                message: message,
                checkedAt: Date()
            )
            return ConnectionTestResult(
                success: false,
                message: message
            )
        }
        refreshCachedCloudAPIKeys()
        return await validateCloudAccess(for: .openAI)
    }

    func importAnthropicAccount() async -> ConnectionTestResult {
        cloudProviderValidationStates[.anthropic] = .checking
        switch authService.importAnthropicClaudeCodeCredentials() {
        case .imported:
            refreshCachedCloudAPIKeys()
            return await validateCloudAccess(for: .anthropic)
        case .failure(let message):
            let checkedAt = Date()
            cloudProviderValidationStates[.anthropic] = .invalid(
                message: message,
                checkedAt: checkedAt
            )
            return ConnectionTestResult(success: false, message: message)
        }
    }

    func signInToGoogle(configuration: GoogleOAuthClientConfiguration) async -> ConnectionTestResult {
        cloudProviderValidationStates[.google] = .checking
        do {
            try await authService.signInToGoogle(configuration: configuration)
            refreshCachedCloudAPIKeys()
            return await validateCloudAccess(for: .google)
        } catch {
            let checkedAt = Date()
            cloudProviderValidationStates[.google] = .invalid(
                message: error.localizedDescription,
                checkedAt: checkedAt
            )
            return ConnectionTestResult(success: false, message: error.localizedDescription)
        }
    }

    func clearCloudAccess(for provider: CloudModelProvider) {
        _ = setOAuthCredential(nil, for: provider)
        _ = setAPIKey("", for: provider)
    }

    private func effectivePolicyContext(
        for operatingMode: EpistemosOperatingMode,
        sizedFastComplexity: Double? = nil
    ) -> InferencePolicyContext {
        let base = policyContext
        // P1.5 — Fast "three efforts": when a per-query complexity is supplied,
        // size the loaded Fast model to the task. Falls back to the stored
        // preference for every other mode / non-default pick.
        let resolvedPreferredLocalTextModelID = sizedFastComplexity
            .flatMap { complexity in
                sizedFastLocalTextModelID(
                    forComplexity: complexity,
                    operatingMode: operatingMode
                )
            }
            ?? base.preferredLocalTextModelID
        return InferencePolicyContext(
            routingMode: base.routingMode,
            appleIntelligenceAvailable: base.appleIntelligenceAvailable,
            cloudAutoRouteEnabled: base.cloudAutoRouteEnabled,
            hasConfiguredCloudModels: base.hasConfiguredCloudModels,
            preferredChatModelSelection: effectiveChatSurfaceSelection(for: operatingMode),
            preferredLocalTextModelID: resolvedPreferredLocalTextModelID,
            installedLocalTextModelIDs: base.installedLocalTextModelIDs,
            hardwareCapabilitySnapshot: base.hardwareCapabilitySnapshot,
            runtimeConditions: base.runtimeConditions
        )
    }

    func routeDecision(for profile: InferenceRequestProfile) -> InferenceRouteDecision {
        policyEngine.decide(
            profile: profile,
            context: effectivePolicyContext(
                for: profile.operatingMode,
                sizedFastComplexity: profile.queryComplexity
            )
        )
    }

    func localModelSelection(for profile: InferenceRequestProfile) -> LocalModelSelection? {
        policyEngine.localSelection(
            for: profile,
            context: effectivePolicyContext(
                for: profile.operatingMode,
                sizedFastComplexity: profile.queryComplexity
            )
        )
    }

    func canAutomaticallyRouteToLocalMLX(for profile: InferenceRequestProfile) -> Bool {
        guard localRuntimeConditions.allowsAutomaticLocalRouting else { return false }
        guard let selection = localModelSelection(for: profile) else { return false }
        guard hardwareCapabilitySnapshot.supports(textModelID: selection.modelID) else { return false }
        return profile.contentLength <= selection.contentBudget
    }

    func canRouteToLocalMLX(contentLength: Int) -> Bool {
        canAutomaticallyRouteToLocalMLX(
            for: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: contentLength,
                promptLength: contentLength,
                contextBlockCount: max(1, contentLength / 2_400),
                estimatedTokenLoad: max(1, contentLength / 4),
                baseComplexity: 0.35,
                queryComplexity: 0,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            )
        )
    }

    func canRouteToLocalAgentLoop(for profile: InferenceRequestProfile) -> Bool {
        guard localRuntimeConditions.allowsAutomaticLocalRouting else { return false }
        guard let modelID = effectiveLocalAgentTextModelID,
              let model = LocalTextModelID(rawValue: modelID),
              model.canRunLocalAgentLoop,
              hardwareCapabilitySnapshot.supports(textModelID: modelID) else {
            return false
        }
        let contentBudget = hardwareCapabilitySnapshot.recommendedLocalContentLength(
            for: model,
            conditions: localRuntimeConditions,
            reasoningMode: profile.requestedReasoningMode
        )
        return profile.contentLength <= contentBudget
    }

    func setChatOutputTokens(_ tokens: Int) {
        chatOutputTokens = max(0, tokens)
        UserDefaults.standard.set(chatOutputTokens, forKey: "epistemos.chatOutputTokens")
    }

    func setOpenAIWebSearchEnabled(_ isEnabled: Bool) {
        openAIWebSearchEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.openAIWebSearchDefaultsKey)
    }

    func setOpenAICodeInterpreterEnabled(_ isEnabled: Bool) {
        openAICodeInterpreterEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.openAICodeInterpreterDefaultsKey)
    }

    func setAnthropicAdaptiveThinkingEnabled(_ isEnabled: Bool) {
        anthropicAdaptiveThinkingEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.anthropicAdaptiveThinkingDefaultsKey)
    }

    func setAnthropicWebSearchEnabled(_ isEnabled: Bool) {
        anthropicWebSearchEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.anthropicWebSearchDefaultsKey)
    }

    func setAnthropicWebFetchEnabled(_ isEnabled: Bool) {
        anthropicWebFetchEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.anthropicWebFetchDefaultsKey)
    }

    func setAnthropicCodeExecutionEnabled(_ isEnabled: Bool) {
        anthropicCodeExecutionEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.anthropicCodeExecutionDefaultsKey)
    }

    func setStructuredJSONOutputEnabled(_ isEnabled: Bool) {
        structuredJSONOutputEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.structuredJSONOutputDefaultsKey)
    }

    func setGoogleGroundingEnabled(_ isEnabled: Bool) {
        googleGroundingEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.googleGroundingDefaultsKey)
    }

    func markCloudSetupHintShown() {
        hasShownCloudSetupHint = true
        UserDefaults.standard.set(true, forKey: Self.cloudSetupHintShownDefaultsKey)
    }

    func firecrawlAPIKey() -> String? {
        guard let value = keychainLoad(Self.firecrawlAPIKeyKeychainKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    @discardableResult
    func setFirecrawlAPIKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            keychainDelete(Self.firecrawlAPIKeyKeychainKey)
            return true
        }
        return keychainSave(trimmed, Self.firecrawlAPIKeyKeychainKey)
    }

    func setRoutingMode(_ mode: LocalRoutingMode) {
        routingMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "epistemos.localRoutingMode")
    }

    /// Owner 2026-06-18 — "Run anyway": force-load a model past the P1.4 memory
    /// blocker (or clear the force). An explicit, persisted user choice; the
    /// honest blocker stays the default for everything else.
    static let memoryGateForcedModelIDsKey = "epistemos.memoryGateForcedModelIDs"
    func setMemoryGateForced(_ modelID: String, forced: Bool) {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if forced {
            memoryGateForcedModelIDs.insert(trimmed)
        } else {
            memoryGateForcedModelIDs.remove(trimmed)
        }
        UserDefaults.standard.set(Array(memoryGateForcedModelIDs), forKey: Self.memoryGateForcedModelIDsKey)
    }

    func setChatAutoRouteToCloud(_ isEnabled: Bool) {
        chatAutoRouteToCloud = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.chatAutoRouteToCloudDefaultsKey)
    }

    func setCloudAutoFallback(_ isEnabled: Bool) {
        cloudAutoFallback = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.cloudAutoFallbackDefaultsKey)
    }

    func setChatReasoningTier(_ tier: ChatReasoningTier) {
        chatReasoningTier = tier
        UserDefaults.standard.set(tier.rawValue, forKey: Self.chatReasoningTierDefaultsKey)
    }

    func setChatReasoningTier(_ tier: ChatReasoningTier, for operatingMode: EpistemosOperatingMode) {
        setChatReasoningTier(sanitizedReasoningTier(tier, for: operatingMode))
    }

    func setActiveAIProvider(_ provider: AIProviderSelection) {
        let provider = normalizedVisibleAIProvider(provider)
        if provider != .localOnly, routingMode == .localOnly {
            setRoutingMode(.auto)
        }
        persistActiveAIProvider(provider)

        switch preferredChatModelSelection {
        case .appleIntelligence, .localMLX:
            return
        case .cloud(let currentModel):
            guard let activeCloudProvider = provider.cloudProvider else {
                persistPreferredChatModelSelection(.localMLX(preferredLocalTextModelID))
                return
            }
            guard currentModel.provider != activeCloudProvider else {
                persistPreferredCloudModel(currentModel)
                return
            }
            guard hasConfiguredCloudAccess(for: activeCloudProvider) else {
                persistPreferredChatModelSelection(.localMLX(preferredLocalTextModelID))
                return
            }
            persistPreferredChatModelSelection(.cloud(loadPreferredCloudModel(for: activeCloudProvider)))
        }
    }

    func setCloudModelsEnabled(_ isEnabled: Bool) {
        if isEnabled {
            let restoredProvider = lastNonLocalAIProvider()
            guard let cloudProvider = restoredProvider.cloudProvider else {
                persistActiveAIProvider(.openAI)
                return
            }
            let restoredSelection = AIProviderSelection(cloudProvider: cloudProvider)
            persistActiveAIProvider(restoredSelection)
            if hasConfiguredCloudAccess(for: cloudProvider) {
                persistPreferredChatModelSelection(
                    .cloud(loadPreferredCloudModel(for: cloudProvider))
                )
            }
            return
        }

        setActiveAIProvider(.localOnly)
    }

    func setPreferredLocalTextModelID(_ modelID: String) {
        guard LocalTextModelID(rawValue: modelID) != nil
            || GemmaQATRuntimeLadder.candidate(forID: modelID) != nil
        else { return }
        let persistedModelID = sanitizedStoredLocalChatModelID(for: modelID)
        preferredLocalTextModelID = persistedModelID
        UserDefaults.standard.set(
            persistedModelID,
            forKey: "epistemos.preferredLocalTextModelID"
        )
        if case .localMLX = preferredChatModelSelection {
            preferredChatModelSelection = .localMLX(persistedModelID)
            UserDefaults.standard.set(
                preferredChatModelSelection.rawValue,
                forKey: "epistemos.preferredChatModelSelection"
            )
        }
    }

    func setPreferredCloudModel(_ model: CloudTextModelID) {
        let normalizedModel = normalizedPreferredCloudModel(model)
        persistPreferredCloudModel(normalizedModel)
        persistActiveAIProvider(AIProviderSelection(cloudProvider: normalizedModel.provider))

        if case .cloud(let currentModel) = preferredChatModelSelection,
           currentModel.provider == normalizedModel.provider {
            persistPreferredChatModelSelection(.cloud(normalizedModel))
        }
    }

    /// AR4 (Wave 14 Focus filters) — when the active Focus has set
    /// `EpistemosFocusKeys.forceLocalModelsOnly`, an explicit cloud
    /// pick collapses to the user's preferred local MLX model. The
    /// model picker reads `isCloudPickBlockedByFocus` to surface a
    /// one-line "Focus" badge so the user understands why the cloud
    /// option was suppressed.
    var isCloudPickBlockedByFocus: Bool {
        UserDefaults.standard.bool(forKey: EpistemosFocusKeys.forceLocalModelsOnly)
    }

    func setPreferredChatModelSelection(_ selection: ChatModelSelection) {
        let normalizedSelection = normalizedChatModelSelection(selection)
        switch normalizedSelection {
        case .cloud(let model):
            if isCloudPickBlockedByFocus {
                pendingUnavailableCloudSelection = model
                persistPreferredChatModelSelection(.localMLX(preferredLocalTextModelID))
                return
            }
            guard hasConfiguredCloudAccess(for: model.provider) else {
                persistPreferredCloudModel(model)
                pendingUnavailableCloudSelection = model
                persistPreferredChatModelSelection(.localMLX(preferredLocalTextModelID))
                return
            }
            pendingUnavailableCloudSelection = nil
            if routingMode == .localOnly {
                setRoutingMode(.auto)
            }
        case .appleIntelligence:
            pendingUnavailableCloudSelection = nil
            if routingMode == .localOnly {
                setRoutingMode(.auto)
            }
        case .localMLX:
            pendingUnavailableCloudSelection = nil
            break
        }
        persistPreferredChatModelSelection(normalizedSelection)
    }

    private func capabilityPreviewSelection(
        for operatingMode: EpistemosOperatingMode
    ) -> ChatModelSelection {
        if let pendingSelection = pendingUnavailableCloudIntentSelection(for: operatingMode) {
            return pendingSelection
        }
        return effectiveChatSurfaceSelection(for: operatingMode)
    }

    private func pendingUnavailableCloudIntentSelection(
        for operatingMode: EpistemosOperatingMode
    ) -> ChatModelSelection? {
        guard let model = pendingUnavailableCloudSelection,
              model.supportedOperatingModes.contains(operatingMode) else {
            return nil
        }
        return .cloud(model)
    }

    func cloudFallbackChain(for operatingMode: EpistemosOperatingMode) -> [CloudTextModelID] {
        let primaryModel: CloudTextModelID
        let isExplicitCloudSelection: Bool

        switch preferredChatModelSelection {
        case .cloud(let selectedModel):
            primaryModel = selectedModel
            isExplicitCloudSelection = true
        default:
            guard let autoModel = preferredAutoRouteCloudModel(for: operatingMode) else {
                return []
            }
            primaryModel = autoModel
            isExplicitCloudSelection = false
        }

        let primaryResolved: CloudTextModelID = {
            if isExplicitCloudSelection {
                let base: CloudTextModelID
                if cloudAutoFallback,
                   !(primaryModel.provider == .openAI && openAIUsesCodexAccountRuntime) {
                    base = primaryModel.resolvedModel(for: operatingMode)
                } else {
                    base = primaryModel
                }
                return compatibleCloudModel(base, for: operatingMode)
            }
            return compatibleCloudModel(primaryModel, for: operatingMode)
        }()

        var chain: [CloudTextModelID] = [primaryResolved]

        guard cloudAutoFallback else { return chain }

        for provider in CloudModelProvider.fallbackPriority(after: primaryModel.provider) {
            guard hasConfiguredCloudAccess(for: provider) else { continue }

            let preferredModel = loadPreferredCloudModel(for: provider)
            let fallbackModel: CloudTextModelID
            if preferredModel.supportedOperatingModes.contains(operatingMode) {
                fallbackModel = compatibleCloudModel(
                    preferredModel.resolvedModel(for: operatingMode),
                    for: operatingMode
                )
            } else {
                fallbackModel = compatibleCloudModel(
                    provider.recommendedFallbackCloudModel(operatingMode),
                    for: operatingMode
                )
            }
            chain.append(fallbackModel)
        }

        var seen: Set<String> = []
        return chain.filter { model in
            seen.insert(model.rawValue).inserted
        }
    }

    private func normalizedChatModelSelection(_ selection: ChatModelSelection) -> ChatModelSelection {
        switch selection {
        case .localMLX(let modelID):
            return .localMLX(sanitizedStoredLocalChatModelID(for: modelID))
        case .appleIntelligence:
            return selection
        case .cloud(let model):
            return .cloud(normalizedPreferredCloudModel(model))
        }
    }

    private func normalizedVisibleCloudProvider(_ provider: CloudModelProvider) -> CloudModelProvider {
        return provider
    }

    private func normalizedVisibleAIProvider(_ provider: AIProviderSelection) -> AIProviderSelection {
        guard let cloudProvider = provider.cloudProvider else { return provider }
        return AIProviderSelection(cloudProvider: normalizedVisibleCloudProvider(cloudProvider))
    }

    private func normalizedPreferredCloudModel(_ model: CloudTextModelID) -> CloudTextModelID {
        switch model.provider {
        case .openAI:
            switch model {
            case .openAIGPT54, .openAIGPT54Mini:
                return model
            default:
                return .openAIGPT54
            }
        case .anthropic:
            switch model {
            case .anthropicClaudeOpus47, .anthropicClaudeSonnet46:
                return model
            case .anthropicClaudeOpus41, .anthropicClaudeOpus4:
                return .anthropicClaudeOpus47
            default:
                return .anthropicClaudeSonnet46
            }
        case .google:
            switch model {
            case .googleGemini31ProPreview, .googleGemini3FlashPreview:
                return model
            case .googleGemini25Flash:
                return .googleGemini3FlashPreview
            default:
                return .googleGemini31ProPreview
            }
        case .zai, .kimi, .minimax, .deepseek:
            return model
        }
    }

    private func compatibleCloudModel(
        _ model: CloudTextModelID,
        for operatingMode: EpistemosOperatingMode
    ) -> CloudTextModelID {
        let normalized = normalizedPreferredCloudModel(model)
        guard normalized.provider == .openAI,
              openAIUsesCodexAccountRuntime else {
            return normalized
        }

        switch operatingMode {
        case .fast:
            switch normalized {
            case .openAIGPT54, .openAIGPT54Mini, .openAIGPT52:
                return normalized
            default:
                return .openAIGPT54Mini
            }
        case .thinking, .pro:
            switch normalized {
            case .openAIGPT54, .openAIGPT52:
                return normalized
            default:
                return .openAIGPT54
            }
        case .agent:
            switch normalized {
            case .openAIGPT54, .openAIGPT54Mini, .openAIGPT52:
                return normalized
            default:
                return .openAIGPT54
            }
        }
    }

    private func supportedCloudModels(for provider: CloudModelProvider) -> [CloudTextModelID] {
        switch provider {
        case .openAI:
            return [.openAIGPT54, .openAIGPT54Mini]
        case .anthropic:
            return [.anthropicClaudeOpus47, .anthropicClaudeSonnet46]
        case .google:
            return [.googleGemini31ProPreview, .googleGemini3FlashPreview]
        case .zai, .kimi, .minimax, .deepseek:
            return CloudTextModelID.models(for: provider)
        }
    }

    private var openAIUsesCodexAccountRuntime: Bool {
        oauthCredential(for: .openAI)?.authMode == .openAICodex
    }

    private var anthropicUsesClaudeCodeAccountRuntime: Bool {
        oauthCredential(for: .anthropic)?.authMode == .anthropicClaudeCode
    }

    func setLocalRuntimeConditions(_ conditions: LocalRuntimeConditions) {
        localRuntimeConditions = conditions
    }

    func setLatestLocalRuntimeProfile(_ profile: LocalMLXRunProfile?) {
        latestLocalRuntimeProfile = profile
        latestLocalRuntimeHealth = profile.map(LocalRuntimeHealthSnapshot.init)
    }

    func setLatestLocalRuntimeHealth(_ snapshot: LocalRuntimeHealthSnapshot?) {
        latestLocalRuntimeHealth = snapshot
    }

    func setInstalledLocalTextModelIDs(_ ids: Set<String>) {
        installedLocalTextModelIDs = ids
        sanitizeStoredLocalChatSelectionIfNeeded()
    }

    func setPreparedLocalTextModelIDs(_ ids: Set<String>) {
        preparedLocalTextModelIDs = ids
        sanitizeStoredLocalChatSelectionIfNeeded()
    }

    private func sanitizedInteractiveLocalTextModelID(for modelID: String) -> String? {
        // Simplified lineup: migrate a stored LEGACY local selection (an MLX
        // enum model that isn't part of the foundation lineup — e.g. a Qwen the
        // user had pinned) onto the foundation lineup, so they land on Gemma
        // rather than a now-hidden legacy model. Only when a foundation GGUF is
        // actually installed; otherwise fall through and keep their selection so
        // nothing breaks before the foundation package is installed.
        if EpistemosFoundationLineup.simplifiedLineupActive,
           LocalTextModelID(rawValue: modelID) != nil,
           EpistemosFoundationLineup.tier(forModelID: modelID) == nil,
           // Migrate onto the HARDWARE-APPROPRIATE everyday model — the Fast
           // tier's headroom-aware pick (E4B on a 16 GB Mac), NOT the largest
           // installed candidate. The old `.last` landed every 16 GB user on the
           // memory-tight 12B ("Gemma 12B is always selected"). Falls back to the
           // smallest installed foundation candidate when no Fast Gemma is present.
           let foundation = installedFoundationModelID(for: .fast)
               ?? supportedAvailableGemmaQATRuntimeCandidates.first?.id {
            return foundation
        }
        if supportedAvailableLocalTextModels.contains(where: { $0.rawValue == modelID }) {
            return modelID
        }
        if supportedAvailableGemmaQATRuntimeCandidates.contains(where: { $0.id == modelID }) {
            return modelID
        }
        let recommendedModelID = hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue
        if supportedAvailableLocalTextModels.contains(where: { $0.rawValue == recommendedModelID }) {
            return recommendedModelID
        }
        if let constrainedModelID = hardwareCapabilitySnapshot.recommendedConstrainedLocalTextModelID?.rawValue,
           supportedAvailableLocalTextModels.contains(where: { $0.rawValue == constrainedModelID }) {
            return constrainedModelID
        }
        return supportedAvailableLocalTextModels.first?.rawValue
    }

    private func sanitizedStoredLocalChatModelID(for modelID: String) -> String {
        if let sanitizedModelID = sanitizedInteractiveLocalTextModelID(for: modelID) {
            return normalizedReleaseSelectableLocalTextModelID(sanitizedModelID)
        }
        // A model whose Swift loader is missing (e.g. the MLX Gemma 4 tiers,
        // which error "Unsupported model type: gemma4") is rewritten to the
        // recommended default so the user never lands on an unrunnable pick.
        // A staged GGUF Gemma is NOT awaiting-loader and IS resolved by
        // sanitizedInteractiveLocalTextModelID above (via the active/ detection
        // in detectedOnDiskActiveGgufModelIDs), so it is never swapped to Qwen.
        // Any other model the caller set deliberately is left in place even if
        // not currently runnable (the picker simply surfaces nothing effective).
        if let model = LocalTextModelID(rawValue: modelID),
           model.isAwaitingSwiftRuntimeLoader {
            // Owner 2026-06-18: under the simplified lineup, rewrite an unrunnable
            // MLX Gemma 4 to the WORKING Fast Gemma GGUF (same family), never Qwen.
            if EpistemosFoundationLineup.simplifiedLineupActive {
                return EpistemosFoundationLineup.defaultChatModelID
            }
            return hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue
        }
        return modelID
    }

    private func sanitizeStoredLocalChatSelectionIfNeeded() {
        let sanitizedModelID = sanitizedStoredLocalChatModelID(for: preferredLocalTextModelID)

        if sanitizedModelID != preferredLocalTextModelID {
            preferredLocalTextModelID = sanitizedModelID
            UserDefaults.standard.set(
                sanitizedModelID,
                forKey: "epistemos.preferredLocalTextModelID"
            )
        }

        guard case .localMLX(let selectedModelID) = preferredChatModelSelection else { return }
        guard sanitizedModelID != selectedModelID else { return }

        preferredChatModelSelection = .localMLX(sanitizedModelID)
        UserDefaults.standard.set(
            preferredChatModelSelection.rawValue,
            forKey: "epistemos.preferredChatModelSelection"
        )
    }
}

extension CloudModelProvider {
    nonisolated static let preferredOrder: [CloudModelProvider] = [
        .openAI,
        .anthropic,
        .google,
    ]

    nonisolated static func fallbackPriority(after primary: CloudModelProvider) -> [CloudModelProvider] {
        preferredOrder.filter { $0 != primary }
    }
}
