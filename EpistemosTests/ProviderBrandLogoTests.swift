import Testing
import Foundation
@testable import Epistemos

/// P6.1 — locks the provider→logo map: every brand is render-safe (has a fallback),
/// the owner's provider list all map to a distinct brand, and the staged lobehub
/// assets are referenced.
@Suite("Provider brand logos (P6.1)")
struct ProviderBrandLogoTests {

    @Test("every brand has a display name + a non-empty SF-Symbol fallback (render-safe)")
    func everyBrandRenderable() {
        for brand in ProviderBrand.allCases {
            #expect(!brand.displayName.isEmpty)
            #expect(!brand.sfSymbolFallback.isEmpty)
        }
    }

    @Test("the owner's provider list all map to a distinct brand (cloud + account runtime + local + Apple)")
    func ownerListCovered() {
        // Cloud
        #expect(ProviderBrand.cloud(.anthropic) == .claude)
        #expect(ProviderBrand.cloud(.openAI) == .chatGPT)
        #expect(ProviderBrand.cloud(.google) == .gemini)
        #expect(ProviderBrand.cloud(.kimi) == .kimi)
        // Account runtimes (the distinction the owner called out: Claude Code / Codex)
        #expect(ProviderBrand.cloud(.anthropic, accountRuntime: true) == .claudeCode)
        #expect(ProviderBrand.cloud(.openAI, accountRuntime: true) == .codex)
        // Local families
        #expect(ProviderBrand.local(modelID: "gemma-3-4b") == .gemma)
        #expect(ProviderBrand.local(modelID: "qwen3_4B4Bit") == .qwen)
        #expect(ProviderBrand.local(modelID: "qwopus27Bv3") == .qwen)
        #expect(ProviderBrand.local(modelID: "something-else") == .generic)
        // Local long-tail families (P6.2): each gets its own brand mark. The
        // DeepSeek-R1-Distill-Qwen ids contain "qwen" but resolve to DeepSeek —
        // the matcher checks deepseek BEFORE qwen (was mislabeling them Qwen).
        #expect(ProviderBrand.local(modelID: "DeepSeek-R1-Distill-Qwen-7B-4bit") == .deepseek)
        #expect(ProviderBrand.local(modelID: "Llama-3.2-3B-Instruct") == .llama)
        #expect(ProviderBrand.local(modelID: "Mistral-Small-3.1-24B") == .mistral)
        #expect(ProviderBrand.local(modelID: "Devstral-Small-2505") == .mistral)
        #expect(ProviderBrand.local(modelID: "LFM2-24B") == .liquid)
        // QwQ is Alibaba's Qwen reasoning line (was falling to generic); the niche
        // local families now carry their maker's lobehub mark.
        #expect(ProviderBrand.local(modelID: "qwqFlagship32B4Bit") == .qwen)
        #expect(ProviderBrand.local(modelID: "smolLM3_3B4Bit") == .smolLM)
        #expect(ProviderBrand.local(modelID: "jamba3B") == .jamba)
        #expect(ProviderBrand.local(modelID: "falconH1R_7B4Bit") == .falcon)
        // Families with no real lobehub mark honestly stay generic (not faked).
        #expect(ProviderBrand.local(modelID: "mamba2_2B4Bit") == .generic)
        #expect(ProviderBrand.local(modelID: "bonsai8B2Bit") == .generic)
        // Apple is its own brand.
        #expect(ProviderBrand.apple.displayName == "Apple Intelligence")
        #expect(ProviderBrand.apple.sfSymbolFallback == "apple.logo")
    }

    @Test("the owner's full provider list references a staged lobehub SVG; only the long-tail falls back")
    func stagedAssetsReferenced() {
        // The owner's full list now has a real lobehub B&W SVG (MIT lobe-icons).
        #expect(ProviderBrand.claude.assetName == "ProviderLogoClaude")
        #expect(ProviderBrand.chatGPT.assetName == "ProviderLogoOpenAI")
        #expect(ProviderBrand.gemini.assetName == "ProviderLogoGemini")
        #expect(ProviderBrand.claudeCode.assetName == "ProviderLogoClaudeCode")
        #expect(ProviderBrand.codex.assetName == "ProviderLogoCodex")
        #expect(ProviderBrand.gemma.assetName == "ProviderLogoGemma")
        #expect(ProviderBrand.qwen.assetName == "ProviderLogoQwen")
        #expect(ProviderBrand.apple.assetName == "ProviderLogoApple")
        #expect(ProviderBrand.kimi.assetName == "ProviderLogoKimi")
        // P6.2 — the previously-bare cloud + local-family brands now have real
        // lobehub marks too (Z.AI, MiniMax, DeepSeek, Llama/Meta, Mistral, Liquid).
        #expect(ProviderBrand.zai.assetName == "ProviderLogoZai")
        #expect(ProviderBrand.minimax.assetName == "ProviderLogoMiniMax")
        #expect(ProviderBrand.deepseek.assetName == "ProviderLogoDeepSeek")
        #expect(ProviderBrand.llama.assetName == "ProviderLogoLlama")
        #expect(ProviderBrand.mistral.assetName == "ProviderLogoMistral")
        #expect(ProviderBrand.liquid.assetName == "ProviderLogoLiquid")
        // Niche local families carry their maker's lobehub mark (HF/AI21/TII).
        #expect(ProviderBrand.smolLM.assetName == "ProviderLogoHuggingFace")
        #expect(ProviderBrand.jamba.assetName == "ProviderLogoAI21")
        #expect(ProviderBrand.falcon.assetName == "ProviderLogoFalcon")
        // Only the unknown/generic brand still falls back to an SF Symbol.
        #expect(ProviderBrand.generic.assetName == nil)
    }

    @Test("every brand whose assetName is set has a real imageset on disk (no dangling reference)")
    func stagedAssetsExistOnDisk() throws {
        for brand in ProviderBrand.allCases {
            guard let asset = brand.assetName else { continue }
            let url = try sourceMirrorURL(for: "Epistemos/Assets.xcassets/\(asset).imageset")
            #expect(
                FileManager.default.fileExists(atPath: url.path),
                "missing imageset on disk for \(brand): \(asset).imageset"
            )
        }
    }

    @MainActor
    @Test("InferenceState resolves the brand honoring the active account runtime")
    func inferenceStateBrandDerivation() {
        let inference = InferenceState()
        // Without account runtimes active, the base brands resolve.
        #expect(inference.providerBrand(for: .anthropic) == .claude)
        #expect(inference.providerBrand(for: .openAI) == .chatGPT)
        #expect(inference.providerBrand(for: .google) == .gemini)
    }

    @Test("the provider logo is wired into a visible Settings surface (cloud access rows)")
    func wiredIntoSettings() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/APIKeysHealthRow.swift")
        #expect(src.contains("ProviderLogoView(brand: inference.providerBrand(for: provider)"))
    }

    @Test("fromLabel maps real per-message labels to the right brand")
    func fromLabelMapping() {
        #expect(ProviderBrand.fromLabel("Claude Opus 4.7") == .claude)
        #expect(ProviderBrand.fromLabel("GPT-5.4") == .chatGPT)
        #expect(ProviderBrand.fromLabel("Gemini 3.1 Pro") == .gemini)
        #expect(ProviderBrand.fromLabel("Qwen 3 4B") == .qwen)
        #expect(ProviderBrand.fromLabel("Gemma 4 E4B") == .gemma)
        #expect(ProviderBrand.fromLabel("Kimi K2") == .kimi)
        #expect(ProviderBrand.fromLabel("Apple Intelligence") == .apple)
        // Account-runtime names win over the base brand.
        #expect(ProviderBrand.fromLabel("Claude Code") == .claudeCode)
        #expect(ProviderBrand.fromLabel("Codex") == .codex)
        // A DeepSeek label resolves to DeepSeek even when it names its Qwen base.
        #expect(ProviderBrand.fromLabel("DeepSeek R1 Distill Qwen 7B") == .deepseek)
        #expect(ProviderBrand.fromLabel("Llama 3.2 3B") == .llama)
        #expect(ProviderBrand.fromLabel("Mistral Small 3.1") == .mistral)
        #expect(ProviderBrand.fromLabel("Mystery Model") == .generic)
    }

    @Test("the logo is wired into the picker rows")
    func wiredIntoPicker() throws {
        let picker = try loadMirroredSourceTextFile("Epistemos/Views/Chat/InlineRuntimePickerPanel.swift")
        #expect(picker.contains("ProviderLogoView("))
        #expect(picker.contains("ProviderBrand.local(modelID: option.id)"))
    }
}
